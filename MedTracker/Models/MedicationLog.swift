import Foundation

struct MedicationLog: Identifiable, Codable {
    let id: UUID
    let date: Date
    var isTaken: Bool
    var skippedTime: Date?
    var physicalReaction: String?
    var notes: String?
    
    init(id: UUID = UUID(), date: Date, isTaken: Bool = false, skippedTime: Date? = nil, physicalReaction: String? = nil, notes: String? = nil) {
        self.id = id
        self.date = date
        self.isTaken = isTaken
        self.skippedTime = skippedTime
        self.physicalReaction = physicalReaction
        self.notes = notes
    }
}
