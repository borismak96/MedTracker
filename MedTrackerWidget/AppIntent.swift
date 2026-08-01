import WidgetKit
import AppIntents
import SwiftData
import SwiftUI

struct LogMedicationIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Medication"
    static var description = IntentDescription("Marks medication as taken or skipped for the next reminder time today.")

    @Parameter(title: "Is Taken")
    var isTaken: Bool

    init() {}

    init(isTaken: Bool) {
        self.isTaken = isTaken
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = SharedDatabase.shared.container
        let context = ModelContext(container)
        
        let todayStart = Calendar.current.startOfDay(for: Date())
        var targetLog: MedicationLog
        
        let descriptor = FetchDescriptor<MedicationLog>()
        if let logs = try? context.fetch(descriptor),
           let log = logs.first(where: { Calendar.current.startOfDay(for: $0.date) == todayStart }) {
            targetLog = log
        } else {
            targetLog = MedicationLog(date: todayStart)
            context.insert(targetLog)
        }
        
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profile = (try? context.fetch(profileDescriptor))?.first
        
        if let profile {
            targetLog.syncDoseRecords(with: profile)
            
            if let pending = targetLog.sortedDoseRecords.first(where: \.isPending) {
                let reminder = profile.sortedReminders.first(where: { $0.id == pending.id })
                let meds = reminder.map { profile.medications(for: $0) } ?? []
                
                if isTaken {
                    targetLog.markTaken(
                        reminderId: pending.id,
                        mood: nil,
                        remark: nil,
                        medications: meds
                    )
                } else {
                    targetLog.markSkipped(
                        reminderId: pending.id,
                        time: Date(),
                        reaction: nil,
                        notes: nil
                    )
                }
            } else if targetLog.doseRecords.isEmpty {
                // Fallback for unexpected empty state
                applyLegacyUpdate(to: targetLog, profile: profile)
            }
        } else {
            applyLegacyUpdate(to: targetLog, profile: nil)
        }
        
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
    
    @MainActor
    private func applyLegacyUpdate(to targetLog: MedicationLog, profile: UserProfile?) {
        targetLog.isTaken = isTaken
        if isTaken {
            if let profile {
                let medNames = profile.medications.map(\.name).filter { !$0.isEmpty }
                let medDoses = profile.medications.map(\.dose).filter { !$0.isEmpty }
                targetLog.medicineName = medNames.isEmpty ? nil : medNames.joined(separator: "\n")
                targetLog.dose = medDoses.isEmpty ? nil : medDoses.joined(separator: "\n")
            }
            targetLog.skippedTime = nil
            targetLog.physicalReaction = nil
            targetLog.notes = nil
        } else {
            targetLog.skippedTime = Date()
        }
    }
}
