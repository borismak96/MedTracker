import Foundation

enum AdherenceStats {
    static func isComplete(_ log: MedicationLog) -> Bool {
        if !log.doseRecords.isEmpty {
            return !log.doseRecords.isEmpty && log.doseRecords.allSatisfy(\.isTaken)
        }
        return log.isTaken
    }
    
    static func hasLoggedActivity(_ log: MedicationLog) -> Bool {
        if !log.doseRecords.isEmpty {
            return log.doseRecords.contains { $0.isTaken || $0.isSkipped || $0.isMissed }
        }
        return log.isTaken || log.skippedTime != nil
    }
    
    /// Consecutive complete days, including today when every dose is taken.
    static func consecutiveDayStreak(logs: [MedicationLog], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let byDay: [Date: MedicationLog] = Dictionary(
            logs.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        var day = calendar.startOfDay(for: now)
        if let today = byDay[day], isComplete(today) {
            // Count today.
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        
        var streak = 0
        while let log = byDay[day], isComplete(log) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
    
    struct WeekSummary {
        var takenDoses: Int
        var skippedDoses: Int
        var missedDoses: Int
        var openDoses: Int
        var completeDays: Int
        var daysWithActivity: Int
        var dayStatuses: [(date: Date, complete: Bool, hasActivity: Bool, taken: Int, remaining: Int)]
        var adherencePercent: Int
    }
    
    static func weekSummary(logs: [MedicationLog], now: Date = Date(), calendar: Calendar = .current) -> WeekSummary {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        
        var taken = 0
        var skipped = 0
        var missed = 0
        var open = 0
        var completeDays = 0
        var daysWithActivity = 0
        var dayStatuses: [(Date, Bool, Bool, Int, Int)] = []
        
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: date) }
            let records = log?.sortedDoseRecords ?? []
            let dayTaken = records.filter(\.isTaken).count
            let daySkipped = records.filter(\.isSkipped).count
            let dayMissed = records.filter(\.isMissed).count
            let dayOpen = records.filter(\.isOpen).count
            taken += dayTaken
            skipped += daySkipped
            missed += dayMissed
            if date <= today {
                open += dayOpen
            }
            let complete = log.map { isComplete($0) } ?? false
            let activity = log.map { hasLoggedActivity($0) } ?? false
            if complete { completeDays += 1 }
            if activity { daysWithActivity += 1 }
            dayStatuses.append((date, complete, activity, dayTaken, dayOpen + daySkipped + dayMissed))
        }
        
        let finished = taken + skipped + missed
        let percent = finished == 0 ? 0 : Int((Double(taken) / Double(finished) * 100).rounded())
        return WeekSummary(
            takenDoses: taken,
            skippedDoses: skipped,
            missedDoses: missed,
            openDoses: open,
            completeDays: completeDays,
            daysWithActivity: daysWithActivity,
            dayStatuses: dayStatuses,
            adherencePercent: percent
        )
    }
    
    struct WindowDay {
        var date: Date
        var taken: Int
        var skipped: Int
        var missed: Int
        var open: Int
        var complete: Bool
        var hasActivity: Bool
        var mood: String?
        var bpReadings: [BloodPressureReading]
        var hrReadings: [HeartRateReading]
    }
    
    struct WindowSummary {
        var days: Int
        var takenDoses: Int
        var skippedDoses: Int
        var missedDoses: Int
        var openDoses: Int
        var completeDays: Int
        var daysWithActivity: Int
        var adherencePercent: Int
        var dayRows: [WindowDay]
        var bpReadings: [BloodPressureReading]
        var hrReadings: [HeartRateReading]
        var moods: [String]
        
        var hasAdherenceHistory: Bool {
            takenDoses + skippedDoses + missedDoses > 0
        }
    }
    
    /// Inclusive rolling window ending today (7 or 14 days).
    static func windowSummary(logs: [MedicationLog], days: Int, now: Date = Date(), calendar: Calendar = .current) -> WindowSummary {
        let today = calendar.startOfDay(for: now)
        let span = max(days, 1)
        var taken = 0
        var skipped = 0
        var missed = 0
        var open = 0
        var completeDays = 0
        var daysWithActivity = 0
        var rows: [WindowDay] = []
        var bp: [BloodPressureReading] = []
        var hr: [HeartRateReading] = []
        var moods: [String] = []
        
        for offset in (0..<span).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: date) }
            let records = log?.sortedDoseRecords ?? []
            let dayTaken: Int
            let daySkipped: Int
            let dayMissed: Int
            let dayOpen: Int
            if records.isEmpty {
                dayTaken = (log?.isTaken == true) ? 1 : 0
                daySkipped = (log?.skippedTime != nil && log?.isTaken != true) ? 1 : 0
                dayMissed = 0
                dayOpen = (log == nil || (dayTaken == 0 && daySkipped == 0)) ? 0 : 0
            } else {
                dayTaken = records.filter(\.isTaken).count
                daySkipped = records.filter(\.isSkipped).count
                dayMissed = records.filter(\.isMissed).count
                dayOpen = records.filter(\.isOpen).count
            }
            taken += dayTaken
            skipped += daySkipped
            missed += dayMissed
            open += dayOpen
            let complete = log.map { isComplete($0) } ?? false
            let activity = log.map { hasLoggedActivity($0) } ?? false
            if complete { completeDays += 1 }
            if activity { daysWithActivity += 1 }
            
            let dayBP = log?.allBPReadingsForExport() ?? []
            let dayHR = log?.allHRReadingsForExport() ?? []
            bp.append(contentsOf: dayBP)
            hr.append(contentsOf: dayHR)
            
            var dayMoods: [String] = []
            if let mood = log?.mood, !mood.isEmpty { dayMoods.append(mood) }
            for record in records {
                if let mood = record.mood, !mood.isEmpty { dayMoods.append(mood) }
            }
            moods.append(contentsOf: dayMoods)
            
            rows.append(
                WindowDay(
                    date: date,
                    taken: dayTaken,
                    skipped: daySkipped,
                    missed: dayMissed,
                    open: dayOpen,
                    complete: complete,
                    hasActivity: activity,
                    mood: dayMoods.last,
                    bpReadings: dayBP,
                    hrReadings: dayHR
                )
            )
        }
        
        let finished = taken + skipped + missed
        let percent = finished == 0 ? 0 : Int((Double(taken) / Double(finished) * 100).rounded())
        return WindowSummary(
            days: span,
            takenDoses: taken,
            skippedDoses: skipped,
            missedDoses: missed,
            openDoses: open,
            completeDays: completeDays,
            daysWithActivity: daysWithActivity,
            adherencePercent: percent,
            dayRows: rows,
            bpReadings: bp,
            hrReadings: hr,
            moods: moods
        )
    }
}
