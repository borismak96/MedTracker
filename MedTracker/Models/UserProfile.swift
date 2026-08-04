import Foundation
import SwiftData

struct ReminderSlot: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var hour: Int = 8
    var minute: Int = 0
    var label: String = "Morning"
    
    var timeDescription: String {
        AppLocalization.shortTime(hour: hour, minute: minute)
    }
    
    var displayTitle: String {
        label.isEmpty ? timeDescription : "\(label) · \(timeDescription)"
    }
    
    /// Localized label for UI (Morning / Afternoon / Night / Custom).
    var localizedLabel: String {
        Self.localizedLabel(for: label)
    }
    
    var localizedDisplayTitle: String {
        localizedLabel.isEmpty ? timeDescription : "\(localizedLabel) · \(timeDescription)"
    }
    
    static func localizedLabel(for label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        
        switch trimmed.lowercased() {
        case "morning", "早上":
            return AppLocalization.string("Morning")
        case "afternoon", "下午":
            return AppLocalization.string("Afternoon")
        case "night", "晚上", "evening":
            return AppLocalization.string("Night")
        case "custom", "自訂", "自定义":
            return AppLocalization.string("Custom")
        case "reminder", "提醒":
            return AppLocalization.string("Reminder")
        default:
            return trimmed
        }
    }
    
    /// Map a displayed/edited label back to the stored English key when possible.
    static func storageLabel(from displayed: String) -> String {
        let trimmed = displayed.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "morning", "早上":
            return "Morning"
        case "afternoon", "下午":
            return "Afternoon"
        case "night", "晚上", "evening":
            return "Night"
        case "custom", "自訂", "自定义", "":
            return ""
        case "reminder", "提醒":
            return "Reminder"
        default:
            return trimmed
        }
    }
}

struct MedicationItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var dose: String = "1"
    /// Reminder slot IDs this medicine should alert for. Empty = all reminders.
    var reminderIds: [UUID] = []
}

enum AgeRange: String, CaseIterable, Identifiable {
    case under18 = "Under 18"
    case age18to24 = "18–24"
    case age25to34 = "25–34"
    case age35to44 = "35–44"
    case age45to54 = "45–54"
    case age55to64 = "55–64"
    case age65Plus = "65+"
    
    var id: String { rawValue }
    
    /// Literal localization keys so String Catalog sync can extract them.
    var localizedName: String {
        switch self {
        case .under18: AppLocalization.string("Under 18")
        case .age18to24: AppLocalization.string("18–24")
        case .age25to34: AppLocalization.string("25–34")
        case .age35to44: AppLocalization.string("35–44")
        case .age45to54: AppLocalization.string("45–54")
        case .age55to64: AppLocalization.string("55–64")
        case .age65Plus: AppLocalization.string("65+")
        }
    }
}

@Model
class UserProfile {
    var name: String = ""
    var ageRange: String = ""
    var targetTimeHour: Int = 10
    var targetTimeMinute: Int = 0
    var profileImageData: Data? = nil
    var medications: [MedicationItem] = []
    var reminders: [ReminderSlot] = []
    
    // Legacy fields to prevent database crashes
    var medicationName: String = ""
    var dose: String = ""
    
    init(name: String = "", ageRange: String = "", targetTimeHour: Int = 10, targetTimeMinute: Int = 0, profileImageData: Data? = nil, medications: [MedicationItem] = [], reminders: [ReminderSlot] = []) {
        self.name = name
        self.ageRange = ageRange
        self.targetTimeHour = targetTimeHour
        self.targetTimeMinute = targetTimeMinute
        self.profileImageData = profileImageData
        self.medications = medications
        self.reminders = reminders
    }
    
    /// Ensures at least one reminder exists (migrates from legacy single time).
    func ensureRemindersMigrated() {
        guard reminders.isEmpty else { return }
        reminders = [
            ReminderSlot(hour: targetTimeHour, minute: targetTimeMinute, label: "Morning")
        ]
    }
    
    @Transient
    var sortedReminders: [ReminderSlot] {
        reminders.sorted {
            ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute)
        }
    }
    
    @Transient
    var targetTimeDescription: String {
        let source = reminders.isEmpty
            ? [ReminderSlot(hour: targetTimeHour, minute: targetTimeMinute, label: "Morning")]
            : sortedReminders
        let times = source.map(\.timeDescription)
        if times.isEmpty { return "--" }
        return times.joined(separator: ", ")
    }
    
    func medications(for reminder: ReminderSlot) -> [MedicationItem] {
        medications.filter { med in
            guard !med.name.isEmpty else { return false }
            if med.reminderIds.isEmpty { return true }
            return med.reminderIds.contains(reminder.id)
        }
    }
    
    /// Current medication names still in the profile (trimmed).
    var activeMedicationNames: Set<String> {
        Set(
            medications
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
    
    /// Keep only medication/dose lines that still exist in the profile.
    static func filteredMedicationLines(
        names: String?,
        doses: String?,
        activeNames: Set<String>
    ) -> (names: String?, doses: String?) {
        guard let names, !names.isEmpty else { return (nil, nil) }
        let nameParts = names.components(separatedBy: "\n")
        let doseParts = doses?.components(separatedBy: "\n") ?? []
        var keptNames: [String] = []
        var keptDoses: [String] = []
        
        for (index, rawName) in nameParts.enumerated() {
            let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, activeNames.contains(trimmed) else { continue }
            keptNames.append(rawName)
            keptDoses.append(index < doseParts.count ? doseParts[index] : "")
        }
        
        guard !keptNames.isEmpty else { return (nil, nil) }
        let doseValue = keptDoses.contains(where: { !$0.isEmpty })
            ? keptDoses.joined(separator: "\n")
            : nil
        return (keptNames.joined(separator: "\n"), doseValue)
    }
    
    /// Remove deleted medication names from stored history dose records.
    func pruneRemovedMedications(from logs: [MedicationLog]) {
        let active = activeMedicationNames
        for log in logs {
            if !log.doseRecords.isEmpty {
                var records = log.doseRecords
                for index in records.indices {
                    let filtered = Self.filteredMedicationLines(
                        names: records[index].medicineName,
                        doses: records[index].dose,
                        activeNames: active
                    )
                    records[index].medicineName = filtered.names
                    records[index].dose = filtered.doses
                }
                log.doseRecords = records
                log.refreshAggregateFlags()
            } else {
                let filtered = Self.filteredMedicationLines(
                    names: log.medicineName,
                    doses: log.dose,
                    activeNames: active
                )
                log.medicineName = filtered.names
                log.dose = filtered.doses
            }
        }
    }
}
