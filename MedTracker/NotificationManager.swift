import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    /// Schedules one repeating daily notification per reminder slot.
    func scheduleReminders(_ reminders: [ReminderSlot], playSound: Bool = true, medicationsForReminder: (ReminderSlot) -> [MedicationItem]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        let title = AppLocalization.string("Medication Reminder")
        
        for reminder in reminders {
            let meds = medicationsForReminder(reminder)
            let medNames = meds.map(\.name).filter { !$0.isEmpty }
            let medName = medNames.isEmpty
                ? AppLocalization.string("your medication")
                : medNames.joined(separator: ", ")
            
            let labelPrefix = reminder.localizedLabel.isEmpty ? "" : "\(reminder.localizedLabel): "
            let body = labelPrefix + AppLocalization.format("It's time to take %@", medName)
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            
            // Set interruption level to Time Sensitive for iOS 15+
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }
            if playSound {
                content.sound = .default
            }
            
            var dateComponents = DateComponents()
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "medReminder-\(reminder.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                } else {
                    print("Notification scheduled for \(reminder.displayTitle)")
                }
            }
        }
    }
    
    /// Legacy single-alarm helper (kept for compatibility).
    func scheduleNotification(hour: Int, minute: Int, title: String, body: String, playSound: Bool = true) {
        let slot = ReminderSlot(hour: hour, minute: minute, label: "")
        scheduleReminders([slot], playSound: playSound) { _ in [] }
        
        // Re-schedule with custom title/body for the single slot
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        if playSound {
            content.sound = .default
        }
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyMedicationReminder", content: content, trigger: trigger)
        center.add(request)
    }
    
    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All notifications cancelled")
    }
}
