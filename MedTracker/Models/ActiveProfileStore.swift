import Foundation
import SwiftData

/// Active household member for the app and widget (App Group, no account).
enum ActiveProfileStore {
    static let idKey = "activeProfileID"
    
    static var activeProfileID: UUID? {
        get {
            guard let raw = AppLocalization.sharedDefaults.string(forKey: idKey),
                  let uuid = UUID(uuidString: raw) else { return nil }
            return uuid
        }
        set {
            if let newValue {
                AppLocalization.sharedDefaults.set(newValue.uuidString, forKey: idKey)
            } else {
                AppLocalization.sharedDefaults.removeObject(forKey: idKey)
            }
        }
    }
    
    static func resolve(from profiles: [UserProfile]) -> UserProfile? {
        let ordered = profiles.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
        if let id = activeProfileID, let match = ordered.first(where: { $0.id == id }) {
            return match
        }
        if let first = ordered.first {
            activeProfileID = first.id
            return first
        }
        return nil
    }
    
    static func select(_ profile: UserProfile) {
        activeProfileID = profile.id
    }
}

enum NotificationPreferences {
    static let enabledKey = "isNotificationEnabled"
    static let soundKey = "isNotificationSoundEnabled"
    static let followUpMinutesKey = "followUpReminderMinutes"
    
    static func migrateIfNeeded() {
        let group = AppLocalization.sharedDefaults
        if group.object(forKey: enabledKey) == nil,
           UserDefaults.standard.object(forKey: enabledKey) != nil {
            group.set(UserDefaults.standard.bool(forKey: enabledKey), forKey: enabledKey)
        }
        if group.object(forKey: soundKey) == nil,
           UserDefaults.standard.object(forKey: soundKey) != nil {
            group.set(UserDefaults.standard.bool(forKey: soundKey), forKey: soundKey)
        }
    }
    
    static var isEnabled: Bool {
        AppLocalization.sharedDefaults.bool(forKey: enabledKey)
    }
    
    static var playSound: Bool {
        if AppLocalization.sharedDefaults.object(forKey: soundKey) == nil { return true }
        return AppLocalization.sharedDefaults.bool(forKey: soundKey)
    }
    
    /// Minutes after the scheduled (or snoozed) fire time to send one follow-up. Default 20.
    static var followUpMinutes: Int {
        let stored = AppLocalization.sharedDefaults.object(forKey: followUpMinutesKey) as? Int
        let minutes = stored ?? DoseTiming.defaultFollowUpMinutes
        return min(max(minutes, 10), 60)
    }
}

enum ElderMode {
    static let enabledKey = "isElderModeEnabled"
    
    static var isEnabled: Bool {
        AppLocalization.sharedDefaults.bool(forKey: enabledKey)
    }
    
    static let titleSize: Double = 32
    static let headlineSize: Double = 24
    static let bodySize: Double = 22
    static let buttonHeight: Double = 52
    static let minTap: Double = 44
}

enum HouseholdData {
    static let maxProfiles = 8
    
    static func logs(for profile: UserProfile, in logs: [MedicationLog]) -> [MedicationLog] {
        logs.filter { $0.isStoredInContext && $0.belongs(to: profile) }
    }
    
    static func todayLog(for profile: UserProfile, in logs: [MedicationLog], now: Date = Date()) -> MedicationLog? {
        let today = Calendar.current.startOfDay(for: now)
        return logs.first {
            $0.isStoredInContext &&
            $0.belongs(to: profile) &&
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
    }
    
    static func bootstrap(profiles: [UserProfile], logs: [MedicationLog], context: ModelContext) {
        NotificationPreferences.migrateIfNeeded()
        
        if profiles.isEmpty {
            let me = UserProfile()
            me.sortOrder = 0
            context.insert(me)
            ActiveProfileStore.select(me)
            let today = Calendar.current.startOfDay(for: Date())
            context.insert(MedicationLog(date: today, profileId: me.id))
            try? context.save()
            return
        }
        
        let ordered = profiles.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
        if profiles.count > 1 && Set(profiles.map(\.sortOrder)).count == 1 {
            for (index, profile) in ordered.enumerated() {
                profile.sortOrder = index
            }
        }
        
        let primary = ordered[0]
        for log in logs where log.isStoredInContext && log.profileId == nil {
            log.profileId = primary.id
        }
        
        let active = ActiveProfileStore.resolve(from: profiles) ?? primary
        ensureTodayLog(for: active, logs: logs, context: context)
        try? context.save()
    }
    
    @discardableResult
    static func ensureTodayLog(for profile: UserProfile, logs: [MedicationLog], context: ModelContext) -> MedicationLog {
        let today = Calendar.current.startOfDay(for: Date())
        // Prefer a live context fetch so @Query snapshots from a seed erase/reinsert
        // are not reused after their backing data has detached.
        let fetched = (try? context.fetch(FetchDescriptor<MedicationLog>())) ?? logs
        if let existing = todayLog(for: profile, in: fetched) {
            existing.syncDoseRecords(with: profile)
            existing.refreshOccurrenceStates()
            try? context.save()
            return existing
        }
        let log = MedicationLog(date: today, profileId: profile.id)
        context.insert(log)
        log.syncDoseRecords(with: profile)
        log.refreshOccurrenceStates()
        try? context.save()
        return log
    }
    
    @discardableResult
    static func addProfile(name: String, among profiles: [UserProfile], context: ModelContext) -> UserProfile? {
        guard profiles.count < maxProfiles else { return nil }
        let next = UserProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        next.sortOrder = (profiles.map(\.sortOrder).max() ?? -1) + 1
        context.insert(next)
        let today = Calendar.current.startOfDay(for: Date())
        context.insert(MedicationLog(date: today, profileId: next.id))
        ActiveProfileStore.select(next)
        try? context.save()
        return next
    }
    
    static func deleteProfile(_ profile: UserProfile, logs: [MedicationLog], remaining: [UserProfile], context: ModelContext) {
        guard remaining.count > 1 else { return }
        for log in logs where log.isStoredInContext && log.belongs(to: profile) {
            _ = log.liveDoseRecords
            _ = log.liveBPReadings
            _ = log.liveHRReadings
            context.delete(log)
        }
        let next = remaining.first { $0.id != profile.id }
        context.delete(profile)
        if let next {
            ActiveProfileStore.select(next)
        }
        try? context.save()
    }
}
