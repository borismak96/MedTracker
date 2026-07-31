import Foundation
import SwiftData

struct ReminderSlot: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var hour: Int = 8
    var minute: Int = 0
    var label: String = "Morning"
    
    var timeDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):\(String(format: "%02d", minute))"
    }
    
    var displayTitle: String {
        label.isEmpty ? timeDescription : "\(label) · \(timeDescription)"
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
}
