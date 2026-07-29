import Foundation
import SwiftData

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
    
    init(id: UUID = UUID(), date: Date, isTaken: Bool = false, skippedTime: Date? = nil, physicalReaction: String? = nil, notes: String? = nil, medicineName: String? = nil, dose: String? = nil) {
        self.id = id
        self.date = date
        self.isTaken = isTaken
        self.skippedTime = skippedTime
        self.physicalReaction = physicalReaction
        self.notes = notes
        self.medicineName = medicineName
        self.dose = dose
    }
}
