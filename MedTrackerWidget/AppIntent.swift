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
        
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? context.fetch(profileDescriptor)) ?? []
        let profile = ActiveProfileStore.resolve(from: profiles)
        
        let todayStart = Calendar.current.startOfDay(for: Date())
        var targetLog: MedicationLog
        
        let descriptor = FetchDescriptor<MedicationLog>()
        let logs = (try? context.fetch(descriptor)) ?? []
        if let profile,
           let log = logs.first(where: { $0.belongs(to: profile) && Calendar.current.startOfDay(for: $0.date) == todayStart }) {
            targetLog = log
        } else if let log = logs.first(where: { Calendar.current.startOfDay(for: $0.date) == todayStart }), profile == nil {
            targetLog = log
        } else {
            targetLog = MedicationLog(date: todayStart, profileId: profile?.id)
            context.insert(targetLog)
        }
        
        if let profile {
            targetLog.syncDoseRecords(with: profile)
            targetLog.refreshOccurrenceStates()
            
            let open = targetLog.sortedDoseRecords.first(where: { $0.isDue || $0.isSnoozed })
                ?? targetLog.sortedDoseRecords.first(where: \.isOpen)
            
            if let pending = open {
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
