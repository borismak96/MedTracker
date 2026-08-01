import Foundation
import SwiftData
import SwiftUI

enum MoodStatus: String, CaseIterable {
    case terrible = "Terrible"
    case bad = "Bad"
    case neutral = "Neutral"
    case good = "Good"
    case excellent = "Excellent"
    
    var icon: String {
        switch self {
        case .terrible: return "cloud.bolt.rain.fill"
        case .bad: return "cloud.heavyrain.fill"
        case .neutral: return "cloud.fill"
        case .good: return "cloud.sun.fill"
        case .excellent: return "sun.max.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .terrible: return .indigo
        case .bad: return .blue
        case .neutral: return .gray
        case .good: return .orange
        case .excellent: return .yellow
        }
    }
    
    static func from(string: String?) -> MoodStatus? {
        guard let string = string else { return nil }
        switch string {
        case "😫": return .terrible
        case "🙁": return .bad
        case "😐": return .neutral
        case "🙂": return .good
        case "😄": return .excellent
        default: return MoodStatus(rawValue: string)
        }
    }
}

enum DoseRecordStatus: String, Codable {
    case pending
    case taken
    case skipped
}

struct ReminderDoseRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var label: String
    var hour: Int
    var minute: Int
    var status: String = DoseRecordStatus.pending.rawValue
    var takenAt: Date? = nil
    var skippedTime: Date? = nil
    var physicalReaction: String? = nil
    var notes: String? = nil
    var medicineName: String? = nil
    var dose: String? = nil
    var mood: String? = nil
    
    var doseStatus: DoseRecordStatus {
        DoseRecordStatus(rawValue: status) ?? .pending
    }
    
    var isTaken: Bool { doseStatus == .taken }
    var isSkipped: Bool { doseStatus == .skipped }
    var isPending: Bool { doseStatus == .pending }
    
    var timeDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return String(format: "%d:%02d", hour, minute)
    }
    
    var displayTitle: String {
        label.isEmpty ? timeDescription : "\(label) · \(timeDescription)"
    }
}

@Model
class MedicationLog {
    var id: UUID
    var date: Date
    var isTaken: Bool
    var skippedTime: Date?
    var physicalReaction: String?
    var notes: String?
    var medicineName: String?
    var dose: String?
    
    var systolic: Int?
    var diastolic: Int?
    var mood: String?
    
    /// Per-reminder take / skip records for the day.
    var doseRecords: [ReminderDoseRecord] = []
    
    init(id: UUID = UUID(), date: Date, isTaken: Bool = false, skippedTime: Date? = nil, physicalReaction: String? = nil, notes: String? = nil, medicineName: String? = nil, dose: String? = nil, systolic: Int? = nil, diastolic: Int? = nil, mood: String? = nil, doseRecords: [ReminderDoseRecord] = []) {
        self.id = id
        self.date = date
        self.isTaken = isTaken
        self.skippedTime = skippedTime
        self.physicalReaction = physicalReaction
        self.notes = notes
        self.medicineName = medicineName
        self.dose = dose
        self.systolic = systolic
        self.diastolic = diastolic
        self.mood = mood
        self.doseRecords = doseRecords
    }
    
    var sortedDoseRecords: [ReminderDoseRecord] {
        doseRecords.sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
    }
    
    var takenDoseCount: Int {
        doseRecords.filter(\.isTaken).count
    }
    
    var pendingDoseCount: Int {
        doseRecords.filter(\.isPending).count
    }
    
    /// Keeps dose rows in sync with reminder slots and migrates legacy day-level status.
    func syncDoseRecords(with profile: UserProfile) {
        profile.ensureRemindersMigrated()
        let reminders = profile.sortedReminders
        guard !reminders.isEmpty else { return }
        
        var records = doseRecords
        let hadNoRecords = records.isEmpty
        
        if hadNoRecords {
            if isTaken {
                records = reminders.map { reminder in
                    let meds = profile.medications(for: reminder)
                    return ReminderDoseRecord(
                        id: reminder.id,
                        label: reminder.label,
                        hour: reminder.hour,
                        minute: reminder.minute,
                        status: DoseRecordStatus.taken.rawValue,
                        takenAt: date,
                        notes: notes,
                        medicineName: meds.map(\.name).filter { !$0.isEmpty }.joined(separator: "\n"),
                        dose: meds.map(\.dose).filter { !$0.isEmpty }.joined(separator: "\n"),
                        mood: mood
                    )
                }
            } else if skippedTime != nil {
                records = reminders.enumerated().map { index, reminder in
                    let meds = profile.medications(for: reminder)
                    let skipped = index == 0
                    return ReminderDoseRecord(
                        id: reminder.id,
                        label: reminder.label,
                        hour: reminder.hour,
                        minute: reminder.minute,
                        status: skipped ? DoseRecordStatus.skipped.rawValue : DoseRecordStatus.pending.rawValue,
                        skippedTime: skipped ? skippedTime : nil,
                        physicalReaction: skipped ? physicalReaction : nil,
                        notes: skipped ? notes : nil,
                        medicineName: meds.map(\.name).filter { !$0.isEmpty }.joined(separator: "\n"),
                        dose: meds.map(\.dose).filter { !$0.isEmpty }.joined(separator: "\n")
                    )
                }
            }
        }
        
        for reminder in reminders {
            if let index = records.firstIndex(where: { $0.id == reminder.id }) {
                records[index].label = reminder.label
                records[index].hour = reminder.hour
                records[index].minute = reminder.minute
            } else {
                let meds = profile.medications(for: reminder)
                records.append(
                    ReminderDoseRecord(
                        id: reminder.id,
                        label: reminder.label,
                        hour: reminder.hour,
                        minute: reminder.minute,
                        medicineName: meds.map(\.name).filter { !$0.isEmpty }.joined(separator: "\n"),
                        dose: meds.map(\.dose).filter { !$0.isEmpty }.joined(separator: "\n")
                    )
                )
            }
        }
        
        let reminderIds = Set(reminders.map(\.id))
        // Drop slots that no longer exist in settings (taken/skipped included).
        records.removeAll { !reminderIds.contains($0.id) }
        
        doseRecords = records.sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
        refreshAggregateFlags()
    }
    
    func markTaken(reminderId: UUID, mood: String?, remark: String?, medications: [MedicationItem]) {
        guard let index = doseRecords.firstIndex(where: { $0.id == reminderId }) else { return }
        let medNames = medications.map(\.name).filter { !$0.isEmpty }
        let medDoses = medications.map(\.dose).filter { !$0.isEmpty }
        
        doseRecords[index].status = DoseRecordStatus.taken.rawValue
        doseRecords[index].takenAt = Date()
        doseRecords[index].skippedTime = nil
        doseRecords[index].physicalReaction = nil
        doseRecords[index].mood = mood
        doseRecords[index].notes = remark?.isEmpty == false ? remark : nil
        doseRecords[index].medicineName = medNames.isEmpty ? nil : medNames.joined(separator: "\n")
        doseRecords[index].dose = medDoses.isEmpty ? nil : medDoses.joined(separator: "\n")
        refreshAggregateFlags()
    }
    
    func markSkipped(reminderId: UUID, time: Date, reaction: String?, notes: String?) {
        guard let index = doseRecords.firstIndex(where: { $0.id == reminderId }) else { return }
        doseRecords[index].status = DoseRecordStatus.skipped.rawValue
        doseRecords[index].skippedTime = time
        doseRecords[index].takenAt = nil
        doseRecords[index].physicalReaction = reaction?.isEmpty == false ? reaction : nil
        doseRecords[index].notes = notes?.isEmpty == false ? notes : nil
        doseRecords[index].mood = nil
        refreshAggregateFlags()
    }
    
    func undoDose(reminderId: UUID) {
        guard let index = doseRecords.firstIndex(where: { $0.id == reminderId }) else { return }
        doseRecords[index].status = DoseRecordStatus.pending.rawValue
        doseRecords[index].takenAt = nil
        doseRecords[index].skippedTime = nil
        doseRecords[index].physicalReaction = nil
        doseRecords[index].notes = nil
        doseRecords[index].mood = nil
        refreshAggregateFlags()
    }
    
    func refreshAggregateFlags() {
        guard !doseRecords.isEmpty else { return }
        
        isTaken = doseRecords.allSatisfy(\.isTaken)
        
        if let skipped = doseRecords.first(where: \.isSkipped) {
            skippedTime = skipped.skippedTime
            physicalReaction = skipped.physicalReaction
        } else {
            skippedTime = nil
            physicalReaction = nil
        }
        
        let takenRecords = doseRecords.filter(\.isTaken)
        if !takenRecords.isEmpty {
            medicineName = takenRecords.compactMap(\.medicineName).filter { !$0.isEmpty }.joined(separator: "\n")
            dose = takenRecords.compactMap(\.dose).filter { !$0.isEmpty }.joined(separator: "\n")
            notes = takenRecords.compactMap(\.notes).filter { !$0.isEmpty }.joined(separator: "\n")
            mood = takenRecords.compactMap(\.mood).last
        } else if doseRecords.contains(where: \.isSkipped) {
            let skippedRecords = doseRecords.filter(\.isSkipped)
            notes = skippedRecords.compactMap(\.notes).filter { !$0.isEmpty }.joined(separator: "\n")
            medicineName = nil
            dose = nil
            mood = nil
        } else {
            medicineName = nil
            dose = nil
            notes = nil
            mood = nil
        }
    }
}
