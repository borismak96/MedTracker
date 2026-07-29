import Foundation

struct UserProfile: Codable {
    var name: String
    var medicationName: String
    var targetTimeHour: Int
    var targetTimeMinute: Int
    
    init(name: String = "", medicationName: String = "", targetTimeHour: Int = 10, targetTimeMinute: Int = 0) {
        self.name = name
        self.medicationName = medicationName
        self.targetTimeHour = targetTimeHour
        self.targetTimeMinute = targetTimeMinute
    }
    
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
