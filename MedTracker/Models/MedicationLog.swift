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
    
    init(id: UUID = UUID(), date: Date, isTaken: Bool = false, skippedTime: Date? = nil, physicalReaction: String? = nil, notes: String? = nil, medicineName: String? = nil, dose: String? = nil, systolic: Int? = nil, diastolic: Int? = nil, mood: String? = nil) {
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
    }
}
