import WidgetKit
import AppIntents
import SwiftData
import SwiftUI

struct LogMedicationIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Medication"
    static var description = IntentDescription("Marks medication as taken or skipped for today.")

    @Parameter(title: "Is Taken")
    var isTaken: Bool

    init() {}

    init(isTaken: Bool) {
        self.isTaken = isTaken
    }

    func perform() async throws -> some IntentResult {
        // Access SwiftData via shared container
        let container = SharedDatabase.shared.container
        let context = ModelContext(container)
        
        let todayStart = Calendar.current.startOfDay(for: Date())
        var targetLog: MedicationLog
        
        // Try to fetch existing log for today
        let descriptor = FetchDescriptor<MedicationLog>()
        if let logs = try? context.fetch(descriptor), let log = logs.first(where: { Calendar.current.startOfDay(for: $0.date) == todayStart }) {
            targetLog = log
        } else {
            targetLog = MedicationLog(date: todayStart)
            context.insert(targetLog)
        }
        
        // Update log
        targetLog.isTaken = isTaken
        
        // If taken, set the medication details from profile
        if isTaken {
            let profileDescriptor = FetchDescriptor<UserProfile>()
            if let profiles = try? context.fetch(profileDescriptor), let profile = profiles.first {
                let medNames = profile.medications.map { $0.name }.filter { !$0.isEmpty }
                let medDoses = profile.medications.map { $0.dose }.filter { !$0.isEmpty }
                
                targetLog.medicineName = medNames.isEmpty ? nil : medNames.joined(separator: "\n")
                targetLog.dose = medDoses.isEmpty ? nil : medDoses.joined(separator: "\n")
            }
            targetLog.skippedTime = nil
            targetLog.physicalReaction = nil
            targetLog.notes = nil
        } else {
            targetLog.skippedTime = Date()
        }
        
        try? context.save()
        
        return .result()
    }
}
