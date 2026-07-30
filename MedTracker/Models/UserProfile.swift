import Foundation
import SwiftData

struct MedicationItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var dose: String = ""
}

@Model
class UserProfile {
    var name: String = ""
    var targetTimeHour: Int = 10
    var targetTimeMinute: Int = 0
    var profileImageData: Data? = nil
    var medications: [MedicationItem] = []
    
    // Legacy fields to prevent database crashes
    var medicationName: String = ""
    var dose: String = ""
    
    init(name: String = "", targetTimeHour: Int = 10, targetTimeMinute: Int = 0, profileImageData: Data? = nil, medications: [MedicationItem] = []) {
        self.name = name
        self.targetTimeHour = targetTimeHour
        self.targetTimeMinute = targetTimeMinute
        self.profileImageData = profileImageData
        self.medications = medications
    }
    
    @Transient
    var targetTimeDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        var components = DateComponents()
        components.hour = targetTimeHour
        components.minute = targetTimeMinute
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(targetTimeHour):\(String(format: "%02d", targetTimeMinute))"
    }
}
