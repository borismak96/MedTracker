import Foundation
import UserNotifications
import SwiftData
import WidgetKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    static let categoryIdentifier = "PILLPAL_DOSE_REMINDER"
    static let takeAction = "TAKE"
    static let snoozeAction = "SNOOZE"
    static let skipAction = "SKIP"
    
    /// Legacy identifiers so already-delivered banners still update dose state.
    static let legacyTakenAction = "TAKEN"
    static let legacySnooze10Action = "SNOOZE_10"
    static let legacySnooze30Action = "SNOOZE_30"
    static let legacySnooze60Action = "SNOOZE_60"
    
    private override init() {
        super.init()
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        registerCategories()
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            case .denied:
                DispatchQueue.main.async { completion(false) }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error {
                        print("Notification permission error: \(error)")
                    }
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            @unknown default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    func registerCategories() {
        let take = UNNotificationAction(
            identifier: Self.takeAction,
            title: AppLocalization.string("Take"),
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeAction,
            title: AppLocalization.string("Snooze"),
            options: []
        )
        let skip = UNNotificationAction(
            identifier: Self.skipAction,
            title: AppLocalization.string("Skip"),
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [take, snooze, skip],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    /// Rebuilds today's and tomorrow's dose + follow-up + snooze notifications for every profile.
    /// No-ops cleanly when permission is denied or reminders are turned off.
    func rescheduleFromStore() {
        registerCategories()
        let center = UNUserNotificationCenter.current()
        
        guard NotificationPreferences.isEnabled else {
            center.removeAllPendingNotificationRequests()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        
        Task {
            let settings = await center.notificationSettings()
            let allowed: Set<UNAuthorizationStatus> = [.authorized, .provisional, .ephemeral]
            guard allowed.contains(settings.authorizationStatus) else {
                center.removeAllPendingNotificationRequests()
                await MainActor.run {
                    WidgetCenter.shared.reloadAllTimelines()
                }
                return
            }
            await MainActor.run {
                self.scheduleAllPending()
            }
        }
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
              let reminderId = UUID(uuidString: reminderRaw) else { return }
        
        let dayStamp = (info["day"] as? TimeInterval)
            ?? (info["day"] as? Double)
        let day = Date(timeIntervalSince1970: dayStamp ?? Date().timeIntervalSince1970)
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
        case Self.takeAction, Self.legacyTakenAction:
            targetLog.markTaken(reminderId: reminderId, mood: nil, remark: nil, medications: meds)
        case Self.snoozeAction:
            targetLog.markSnoozed(reminderId: reminderId, minutes: DoseTiming.notificationSnoozeMinutes)
        case Self.legacySnooze10Action:
            targetLog.markSnoozed(reminderId: reminderId, minutes: 10)
        case Self.legacySnooze30Action:
            targetLog.markSnoozed(reminderId: reminderId, minutes: 30)
        case Self.legacySnooze60Action:
            targetLog.markSnoozed(reminderId: reminderId, minutes: 60)
        case Self.skipAction:
            targetLog.markSkipped(reminderId: reminderId, time: Date(), reaction: nil, notes: nil)
        default:
            break
        }
        
        try? context.save()
        // markTaken / markSkipped / markSnoozed already reschedule; default tap only needs a widget refresh.
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
    
    @MainActor
    private func scheduleAllPending() {
        let center = UNUserNotificationCenter.current()
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
                    let record = log?.liveDoseRecords.first { $0.id == reminder.id }
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
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 15 else { return }
        
        let meds = profile.medications(for: reminder)
        let medNames = meds.map(\.name).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let slotTitle = reminder.localizedDisplayTitle
        
        let content = UNMutableNotificationContent()
        if multipleProfiles {
            content.title = "\(AppBrand.displayName) · \(profile.displayName)"
        } else if isFollowUp {
            content.title = AppLocalization.string("Follow-up reminder")
        } else {
            content.title = AppLocalization.string("Medication Reminder")
        }
        
        if medNames.isEmpty {
            content.body = isFollowUp
                ? AppLocalization.string("Still time for your medication.")
                : AppLocalization.string("Time for your medication.")
        } else {
            let list = medNames.joined(separator: ", ")
            content.body = isFollowUp
                ? AppLocalization.format("Still time to take %@", list)
                : "\(slotTitle) · \(list)"
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
