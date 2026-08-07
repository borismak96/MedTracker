import Foundation
import SwiftData
import SwiftUI

enum MoodStatus: String, CaseIterable {
    case terrible = "Terrible"
    case bad = "Bad"
    case neutral = "Neutral"
    case good = "Good"
    case excellent = "Excellent"
    
    /// Weather SF Symbol (legacy / charts that still prefer symbols).
    var icon: String {
        switch self {
        case .terrible: return "cloud.bolt.rain.fill"
        case .bad: return "cloud.heavyrain.fill"
        case .neutral: return "cloud.fill"
        case .good: return "cloud.sun.fill"
        case .excellent: return "sun.max.fill"
        }
    }
    
    /// Face emoji used in mood pickers and summaries.
    var emoji: String {
        switch self {
        case .terrible: return "😫"
        case .bad: return "🙁"
        case .neutral: return "😐"
        case .good: return "🙂"
        case .excellent: return "😄"
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
        AppLocalization.shortTime(hour: hour, minute: minute)
    }
    
    var displayTitle: String {
        label.isEmpty ? timeDescription : "\(label) · \(timeDescription)"
    }
    
    var localizedLabel: String {
        ReminderSlot.localizedLabel(for: label)
    }
    
    var localizedDisplayTitle: String {
        localizedLabel.isEmpty ? timeDescription : "\(localizedLabel) · \(timeDescription)"
    }
}

/// Adult BP classification (based on 5 levels).
enum BloodPressureCategory: Int, Comparable {
    case low = 0
    case ideal = 1
    case normal = 2
    case highNormal = 3
    case high = 4
    
    static func < (lhs: BloodPressureCategory, rhs: BloodPressureCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    static func classify(systolic: Int, diastolic: Int) -> BloodPressureCategory {
        if systolic < 90 || diastolic < 60 {
            return .low
        }
        return max(classifySystolic(systolic), classifyDiastolic(diastolic))
    }
    
    private static func classifySystolic(_ value: Int) -> BloodPressureCategory {
        if value >= 140 { return .high }
        if value >= 130 { return .highNormal }
        if value >= 120 { return .normal }
        return .ideal
    }
    
    private static func classifyDiastolic(_ value: Int) -> BloodPressureCategory {
        if value >= 90 { return .high }
        if value >= 85 { return .highNormal }
        if value >= 80 { return .normal }
        return .ideal
    }
    
    var titleKey: String {
        switch self {
        case .low: return "Low Blood Pressure"
        case .ideal: return "Ideal Blood Pressure"
        case .normal: return "Normal Blood Pressure"
        case .highNormal: return "High-Normal Blood Pressure"
        case .high: return "High Blood Pressure"
        }
    }
    
    var adviceKey: String {
        switch self {
        case .low:
            return "Upper under 90 or lower under 60"
        case .ideal:
            return "Upper under 120 and lower under 80"
        case .normal:
            return "Upper 120–129 or lower 80–84"
        case .highNormal:
            return "Upper 130–139 or lower 85–89"
        case .high:
            return "Upper 140+ or lower 90+"
        }
    }
    
    var localizedTitle: String { AppLocalization.string(titleKey) }
    var localizedAdvice: String { AppLocalization.string(adviceKey) }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .ideal: return .green
        case .normal: return .mint
        case .highNormal: return .orange
        case .high: return .red
        }
    }
}

struct BloodPressureReading: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var recordedAt: Date = Date()
    var systolic: Int
    var diastolic: Int
    
    var valueDescription: String {
        "\(systolic) / \(diastolic) mmHg"
    }
    
    var timeDescription: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.timeStyle = .short
        return formatter.string(from: recordedAt)
    }
    
    var category: BloodPressureCategory {
        BloodPressureCategory.classify(systolic: systolic, diastolic: diastolic)
    }
}

/// Adult resting heart-rate bands (bpm).
enum HeartRateCategory: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    
    static func < (lhs: HeartRateCategory, rhs: HeartRateCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    static func classify(bpm: Int) -> HeartRateCategory {
        if bpm < 60 { return .low }
        if bpm > 100 { return .high }
        return .normal
    }
    
    var titleKey: String {
        switch self {
        case .low: return "Low Heart Rate"
        case .normal: return "Normal Heart Rate"
        case .high: return "High Heart Rate"
        }
    }
    
    var adviceKey: String {
        switch self {
        case .low:
            return "Your heart rate is a little low. If you feel dizzy or unwell, please talk to your family doctor."
        case .normal:
            return "Your heart rate looks healthy. Keep checking from time to time."
        case .high:
            return "Your heart rate is high. If you can, please talk to your family doctor."
        }
    }
    
    var localizedTitle: String { AppLocalization.string(titleKey) }
    var localizedAdvice: String { AppLocalization.string(adviceKey) }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .normal: return .green
        case .high: return .orange
        }
    }
}

struct HeartRateReading: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var recordedAt: Date = Date()
    var bpm: Int
    
    var valueDescription: String {
        "\(bpm) bpm"
    }
    
    var timeDescription: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.timeStyle = .short
        return formatter.string(from: recordedAt)
    }
    
    var category: HeartRateCategory {
        HeartRateCategory.classify(bpm: bpm)
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
    
    /// Latest reading mirror for widgets / older code paths.
    var systolic: Int?
    var diastolic: Int?
    /// Latest heart-rate mirror (bpm).
    var heartRate: Int?
    var mood: String?
    
    /// Per-reminder take / skip records for the day.
    var doseRecords: [ReminderDoseRecord] = []
    
    /// Multiple blood-pressure readings for the day.
    var bpReadings: [BloodPressureReading] = []
    
    /// Multiple heart-rate readings for the day.
    var hrReadings: [HeartRateReading] = []
    
    init(id: UUID = UUID(), date: Date, isTaken: Bool = false, skippedTime: Date? = nil, physicalReaction: String? = nil, notes: String? = nil, medicineName: String? = nil, dose: String? = nil, systolic: Int? = nil, diastolic: Int? = nil, heartRate: Int? = nil, mood: String? = nil, doseRecords: [ReminderDoseRecord] = [], bpReadings: [BloodPressureReading] = [], hrReadings: [HeartRateReading] = []) {
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
        self.heartRate = heartRate
        self.mood = mood
        self.doseRecords = doseRecords
        self.bpReadings = bpReadings
        self.hrReadings = hrReadings
    }
    
    var sortedDoseRecords: [ReminderDoseRecord] {
        doseRecords.sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
    }
    
    var sortedBPReadings: [BloodPressureReading] {
        // Prefer persisted multi-readings; fall back to legacy pair without mutating.
        if !bpReadings.isEmpty {
            return bpReadings.sorted { $0.recordedAt < $1.recordedAt }
        }
        if let sys = systolic, let dia = diastolic {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 12
            components.minute = 0
            let recordedAt = Calendar.current.date(from: components) ?? date
            return [BloodPressureReading(recordedAt: recordedAt, systolic: sys, diastolic: dia)]
        }
        return []
    }
    
    var latestBPReading: BloodPressureReading? {
        sortedBPReadings.last
    }
    
    var takenDoseCount: Int {
        doseRecords.filter(\.isTaken).count
    }
    
    var pendingDoseCount: Int {
        doseRecords.filter(\.isPending).count
    }
    
    /// Seeds `bpReadings` from legacy single-pair fields when needed.
    @discardableResult
    func ensureBPReadingsMigrated() -> Bool {
        guard bpReadings.isEmpty, let sys = systolic, let dia = diastolic else { return false }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 12
        components.minute = 0
        let recordedAt = Calendar.current.date(from: components) ?? date
        bpReadings = [
            BloodPressureReading(recordedAt: recordedAt, systolic: sys, diastolic: dia)
        ]
        try? modelContext?.save()
        return true
    }
    
    func syncLegacyBPFields() {
        if let latest = bpReadings.sorted(by: { $0.recordedAt < $1.recordedAt }).last {
            systolic = latest.systolic
            diastolic = latest.diastolic
        } else {
            systolic = nil
            diastolic = nil
        }
    }
    
    func addBP(systolic sys: Int, diastolic dia: Int, recordedAt: Date = Date()) {
        ensureBPReadingsMigrated()
        var readings = bpReadings
        // If still empty after migration, start from a non-mutating legacy snapshot.
        if readings.isEmpty {
            readings = sortedBPReadings
        }
        readings.append(BloodPressureReading(recordedAt: recordedAt, systolic: sys, diastolic: dia))
        bpReadings = readings
        syncLegacyBPFields()
        try? modelContext?.save()
    }
    
    func updateBP(id: UUID, systolic sys: Int, diastolic dia: Int, recordedAt: Date) {
        ensureBPReadingsMigrated()
        var readings = bpReadings
        if readings.isEmpty {
            readings = sortedBPReadings
        }
        guard let index = readings.firstIndex(where: { $0.id == id }) else { return }
        readings[index].systolic = sys
        readings[index].diastolic = dia
        readings[index].recordedAt = recordedAt
        bpReadings = readings
        syncLegacyBPFields()
        try? modelContext?.save()
    }
    
    func removeBP(id: UUID) {
        ensureBPReadingsMigrated()
        var readings = bpReadings
        if readings.isEmpty {
            readings = sortedBPReadings
        }
        bpReadings = readings.filter { $0.id != id }
        syncLegacyBPFields()
        try? modelContext?.save()
    }
    
    /// All readings for charts/export.
    func allBPReadingsForExport() -> [BloodPressureReading] {
        sortedBPReadings
    }
    
    var sortedHRReadings: [HeartRateReading] {
        if !hrReadings.isEmpty {
            return hrReadings.sorted { $0.recordedAt < $1.recordedAt }
        }
        if let bpm = heartRate {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 12
            components.minute = 0
            let recordedAt = Calendar.current.date(from: components) ?? date
            return [HeartRateReading(recordedAt: recordedAt, bpm: bpm)]
        }
        return []
    }
    
    var latestHRReading: HeartRateReading? {
        sortedHRReadings.last
    }
    
    @discardableResult
    func ensureHRReadingsMigrated() -> Bool {
        guard hrReadings.isEmpty, let bpm = heartRate else { return false }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 12
        components.minute = 0
        let recordedAt = Calendar.current.date(from: components) ?? date
        hrReadings = [HeartRateReading(recordedAt: recordedAt, bpm: bpm)]
        try? modelContext?.save()
        return true
    }
    
    func syncLegacyHRFields() {
        if let latest = hrReadings.sorted(by: { $0.recordedAt < $1.recordedAt }).last {
            heartRate = latest.bpm
        } else {
            heartRate = nil
        }
    }
    
    func addHR(bpm: Int, recordedAt: Date = Date()) {
        ensureHRReadingsMigrated()
        var readings = hrReadings
        if readings.isEmpty {
            readings = sortedHRReadings
        }
        readings.append(HeartRateReading(recordedAt: recordedAt, bpm: bpm))
        hrReadings = readings
        syncLegacyHRFields()
        try? modelContext?.save()
    }
    
    func updateHR(id: UUID, bpm: Int, recordedAt: Date) {
        ensureHRReadingsMigrated()
        var readings = hrReadings
        if readings.isEmpty {
            readings = sortedHRReadings
        }
        guard let index = readings.firstIndex(where: { $0.id == id }) else { return }
        readings[index].bpm = bpm
        readings[index].recordedAt = recordedAt
        hrReadings = readings
        syncLegacyHRFields()
        try? modelContext?.save()
    }
    
    func removeHR(id: UUID) {
        ensureHRReadingsMigrated()
        var readings = hrReadings
        if readings.isEmpty {
            readings = sortedHRReadings
        }
        hrReadings = readings.filter { $0.id != id }
        syncLegacyHRFields()
        try? modelContext?.save()
    }
    
    func allHRReadingsForExport() -> [HeartRateReading] {
        sortedHRReadings
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
        try? modelContext?.save()
    }
    
    func markTaken(reminderId: UUID, mood: String?, remark: String?, medications: [MedicationItem]) {
        guard let index = doseRecords.firstIndex(where: { $0.id == reminderId }) else { return }
        let medNames = medications.map(\.name).filter { !$0.isEmpty }
        let medDoses = medications.map(\.dose).filter { !$0.isEmpty }
        
        // Reassign the array so SwiftData persists Codable element updates.
        var records = doseRecords
        records[index].status = DoseRecordStatus.taken.rawValue
        records[index].takenAt = Date()
        records[index].skippedTime = nil
        records[index].physicalReaction = nil
        records[index].mood = mood
        records[index].notes = remark?.isEmpty == false ? remark : nil
        records[index].medicineName = medNames.isEmpty ? nil : medNames.joined(separator: "\n")
        records[index].dose = medDoses.isEmpty ? nil : medDoses.joined(separator: "\n")
        doseRecords = records
        refreshAggregateFlags()
        try? modelContext?.save()
    }
    
    func markSkipped(reminderId: UUID, time: Date, reaction: String?, notes: String?) {
        guard let index = doseRecords.firstIndex(where: { $0.id == reminderId }) else { return }
        var records = doseRecords
        records[index].status = DoseRecordStatus.skipped.rawValue
        records[index].skippedTime = time
        records[index].takenAt = nil
        records[index].physicalReaction = reaction?.isEmpty == false ? reaction : nil
        records[index].notes = notes?.isEmpty == false ? notes : nil
        records[index].mood = nil
        doseRecords = records
        refreshAggregateFlags()
        try? modelContext?.save()
    }
    
    func undoDose(reminderId: UUID) {
        guard let index = doseRecords.firstIndex(where: { $0.id == reminderId }) else { return }
        var records = doseRecords
        records[index].status = DoseRecordStatus.pending.rawValue
        records[index].takenAt = nil
        records[index].skippedTime = nil
        records[index].physicalReaction = nil
        records[index].notes = nil
        records[index].mood = nil
        doseRecords = records
        refreshAggregateFlags()
        try? modelContext?.save()
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
