import Foundation
import SwiftData

@Model
class UserProfile {
    var name: String
    var medicationName: String
    var targetTimeHour: Int
    var targetTimeMinute: Int
    var profileImageData: Data?
    
    init(name: String = "", medicationName: String = "", targetTimeHour: Int = 10, targetTimeMinute: Int = 0, profileImageData: Data? = nil) {
        self.name = name
        self.medicationName = medicationName
        self.targetTimeHour = targetTimeHour
        self.targetTimeMinute = targetTimeMinute
        self.profileImageData = profileImageData
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
