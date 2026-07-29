import Foundation
import SwiftUI

class MedTrackerViewModel: ObservableObject {
    @Published var profile: UserProfile {
        didSet { saveProfile() }
    }
    
    @Published var logs: [MedicationLog] {
        didSet { saveLogs() }
    }
    
    private let profileKey = "userProfile"
    private let logsKey = "medicationLogs"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let savedProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = savedProfile
        } else {
            self.profile = UserProfile()
        }
        
        if let data = UserDefaults.standard.data(forKey: logsKey),
           let savedLogs = try? JSONDecoder().decode([MedicationLog].self, from: data) {
            self.logs = savedLogs
        } else {
            self.logs = []
            generateMissingLogs()
        }
        
        generateMissingLogs()
    }
    
    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
        }
    }
    
    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: logsKey)
        }
    }
    
    func generateMissingLogs() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Generate up to 30 days back if missing
        for i in 0..<31 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                if !logs.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    logs.append(MedicationLog(date: date))
                }
            }
        }
        
        logs.sort(by: { $0.date > $1.date })
    }
    
    func logForDate(_ date: Date) -> Binding<MedicationLog>? {
        guard let index = logs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        
        return Binding(
            get: { self.logs[index] },
            set: { self.logs[index] = $0 }
        )
    }
    
    var todayLog: Binding<MedicationLog>? {
        logForDate(Date())
    }
    
    var streakCount: Int {
        var streak = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for i in 0..<31 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today),
               let log = logs.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                if log.isTaken {
                    streak += 1
                } else if i > 0 { // If it's not today and it wasn't taken, break the streak
                    break
                }
            }
        }
        return streak
    }
}
