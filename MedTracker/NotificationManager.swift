import Foundation
import UserNotifications
import SwiftData
import WidgetKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    static let categoryIdentifier = "PILLPAL_DOSE_REMINDER"
    static let takenAction = "TAKEN"
    static let snooze10Action = "SNOOZE_10"
    static let snooze30Action = "SNOOZE_30"
    static let snooze60Action = "SNOOZE_60"
    
    private override init() {
        super.init()
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        registerCategories()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func registerCategories() {
        let taken = UNNotificationAction(
            identifier: Self.takenAction,
            title: AppLocalization.string("Taken"),
            options: []
        )
        let snooze10 = UNNotificationAction(
            identifier: Self.snooze10Action,
            title: AppLocalization.string("Snooze 10 min"),
            options: []
        )
        let snooze30 = UNNotificationAction(
            identifier: Self.snooze30Action,
            title: AppLocalization.string("Snooze 30 min"),
            options: []
        )
        let snooze60 = UNNotificationAction(
            identifier: Self.snooze60Action,
            title: AppLocalization.string("Snooze 1 hour"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [taken, snooze10, snooze30, snooze60],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    /// Rebuilds today's and tomorrow's dose + follow-up + snooze notifications for every profile.
    func rescheduleFromStore() {
        registerCategories()
        let center = UNUserNotificationCenter.current()
        
        guard NotificationPreferences.isEnabled else {
            center.removeAllPendingNotificationRequests()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        
        let context = ModelContext(SharedDatabase.shared.container)
        let profiles = ((try? context.fetch(FetchDescriptor<UserProfile>())) ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
        let logs = (try? context.fetch(FetchDescriptor<MedicationLog>())) ?? []
        
        center.removeAllPendingNotificationRequests()
        
        let playSound = NotificationPreferences.playSound
        let calendar = Calendar.current
        let now = Date()
        let multipleProfiles = profiles.count > 1
        
        for profile in profiles {
            profile.ensureRemindersMigrated()
            for reminder in profile.sortedReminders {
                for dayOffset in 0...1 {
                    guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
                    let log = logs.first { $0.belongs(to: profile) && calendar.isDate($0.date, inSameDayAs: day) }
                    let record = log?.doseRecords.first { $0.id == reminder.id }
                    if let record, !record.isOpen { continue }
                    
                    let scheduled = reminderScheduledDate(reminder, on: day, calendar: calendar)
                    let snoozedUntil = record?.snoozedUntil
                    let fireDate: Date
                    if let snoozedUntil, snoozedUntil > now {
                        fireDate = snoozedUntil
                    } else {
                        fireDate = scheduled
                    }
                    
                    if fireDate.timeIntervalSinceNow > 15 {
                        addRequest(
                            kind: (snoozedUntil != nil && snoozedUntil! > now) ? .snooze : .dose,
                            fireDate: fireDate,
                            profile: profile,
                            reminder: reminder,
                            day: day,
                            playSound: playSound,
                            multipleProfiles: multipleProfiles,
                            isFollowUp: false
                        )
                    }
                    
                    let followUpDate = fireDate.addingTimeInterval(DoseTiming.followUpDelay)
                    let missAfter = fireDate.addingTimeInterval(DoseTiming.missWindow)
                    if followUpDate.timeIntervalSinceNow > 15, followUpDate < missAfter {
                        addRequest(
                            kind: .followUp,
                            fireDate: followUpDate,
                            profile: profile,
                            reminder: reminder,
                            day: day,
                            playSound: playSound,
                            multipleProfiles: multipleProfiles,
                            isFollowUp: true
                        )
                    }
                }
            }
        }
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Legacy single-profile helper — rebuilds from the shared store so every profile stays in sync.
    func scheduleReminders(_ reminders: [ReminderSlot], playSound: Bool = true, medicationsForReminder: (ReminderSlot) -> [MedicationItem]) {
        rescheduleFromStore()
    }
    
    /// Legacy single-alarm helper (kept for compatibility).
    func scheduleNotification(hour: Int, minute: Int, title: String, body: String, playSound: Bool = true) {
        rescheduleFromStore()
    }
    
    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All notifications cancelled")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await handle(response)
            completionHandler()
        }
    }
    
    @MainActor
    private func handle(_ response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let profileRaw = info["profileId"] as? String,
              let reminderRaw = info["reminderId"] as? String,
              let profileId = UUID(uuidString: profileRaw),
              let reminderId = UUID(uuidString: reminderRaw),
              let dayStamp = info["day"] as? TimeInterval else { return }
        
        let day = Date(timeIntervalSince1970: dayStamp)
        let dayStart = Calendar.current.startOfDay(for: day)
        let context = ModelContext(SharedDatabase.shared.container)
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard let profile = profiles.first(where: { $0.id == profileId }) else { return }
        
        let logs = (try? context.fetch(FetchDescriptor<MedicationLog>())) ?? []
        let targetLog: MedicationLog
        if let existing = logs.first(where: { $0.belongs(to: profile) && Calendar.current.isDate($0.date, inSameDayAs: dayStart) }) {
            existing.syncDoseRecords(with: profile)
            targetLog = existing
        } else {
            let created = MedicationLog(date: dayStart, profileId: profile.id)
            context.insert(created)
            created.syncDoseRecords(with: profile)
            targetLog = created
        }
        
        let reminder = profile.sortedReminders.first(where: { $0.id == reminderId })
        let meds = reminder.map { profile.medications(for: $0) } ?? []
        
        switch response.actionIdentifier {
        case Self.takenAction:
            targetLog.markTaken(reminderId: reminderId, mood: nil, remark: nil, medications: meds)
        case Self.snooze10Action:
            targetLog.markSnoozed(reminderId: reminderId, minutes: 10)
        case Self.snooze30Action:
            targetLog.markSnoozed(reminderId: reminderId, minutes: 30)
        case Self.snooze60Action:
            targetLog.markSnoozed(reminderId: reminderId, minutes: 60)
        default:
            break
        }
        
        try? context.save()
        // markTaken already reschedules; default tap only needs a widget refresh.
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier
            || response.actionIdentifier == UNNotificationDismissActionIdentifier {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - Private
    
    private enum Kind: String {
        case dose
        case followUp
        case snooze
    }
    
    private func reminderScheduledDate(_ reminder: ReminderSlot, on day: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = reminder.hour
        components.minute = reminder.minute
        components.second = 0
        return calendar.date(from: components) ?? day
    }
    
    private func addRequest(
        kind: Kind,
        fireDate: Date,
        profile: UserProfile,
        reminder: ReminderSlot,
        day: Date,
        playSound: Bool,
        multipleProfiles: Bool,
        isFollowUp: Bool
    ) {
        let meds = profile.medications(for: reminder)
        let medNames = meds.map(\.name).filter { !$0.isEmpty }
        let medName = medNames.isEmpty
            ? AppLocalization.string("your medication")
            : medNames.joined(separator: ", ")
        
        let content = UNMutableNotificationContent()
        if multipleProfiles {
            content.title = "\(AppBrand.displayName) · \(profile.displayName)"
        } else {
            content.title = isFollowUp
                ? AppLocalization.string("Follow-up reminder")
                : AppLocalization.string("Medication Reminder")
        }
        
        let labelPrefix = reminder.localizedLabel.isEmpty ? "" : "\(reminder.localizedLabel): "
        if isFollowUp {
            content.body = labelPrefix + AppLocalization.format("Still time to take %@", medName)
        } else {
            content.body = labelPrefix + AppLocalization.format("It's time to take %@", medName)
        }
        
        content.categoryIdentifier = Self.categoryIdentifier
        content.threadIdentifier = profile.id.uuidString
        content.userInfo = [
            "profileId": profile.id.uuidString,
            "reminderId": reminder.id.uuidString,
            "day": Calendar.current.startOfDay(for: day).timeIntervalSince1970,
            "kind": kind.rawValue
        ]
        
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        if playSound {
            content.sound = .default
        }
        
        let identifier = "\(kind.rawValue)-\(profile.id.uuidString)-\(reminder.id.uuidString)-\(dayKey(day))"
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 15 else { return }
        let trigger: UNNotificationTrigger
        if interval < 12 * 60 * 60 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        } else {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
