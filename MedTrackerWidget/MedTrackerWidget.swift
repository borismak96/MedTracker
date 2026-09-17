import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Providers
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), log: nil, profile: nil, dayStreak: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = fetchEntry()
        var nextUpdate = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        if let log = entry.log {
            let now = Date()
            let upcoming = log.sortedDoseRecords.compactMap { record -> Date? in
                if let until = record.snoozedUntil, until > now { return until }
                if record.isOpen {
                    let scheduled = record.scheduledDate(on: log.date)
                    return scheduled > now ? scheduled : nil
                }
                return nil
            }
            if let soonest = upcoming.min(), soonest < nextUpdate {
                nextUpdate = soonest
            }
        }
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchEntry() -> SimpleEntry {
        let container = SharedDatabase.shared.container
        let modelContext = ModelContext(container)
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(profileDescriptor)) ?? []
        let profile = ActiveProfileStore.resolve(from: profiles)
        
        let logDescriptor = FetchDescriptor<MedicationLog>()
        let logs = (try? modelContext.fetch(logDescriptor)) ?? []
        let profileLogs = profile.map { HouseholdData.logs(for: $0, in: logs) } ?? logs
        let todayLog = profileLogs.first(where: { Calendar.current.startOfDay(for: $0.date) == todayStart })
        
        let currentStreak = AdherenceStats.consecutiveDayStreak(logs: profileLogs)
        
        return SimpleEntry(date: Date(), log: todayLog, profile: profile, dayStreak: currentStreak)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let log: MedicationLog?
    let profile: UserProfile?
    let dayStreak: Int
}

// MARK: - 1. Small Widget (Status & Streak)
struct MedTrackerWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 12) {
            if let log = entry.log, log.isTaken {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                Text(AppLocalization.string("Taken Today"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            } else if let log = entry.log, log.doseRecords.contains(where: { $0.isDue || $0.isSnoozed }) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(AppLocalization.string("Due now"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            } else if let log = entry.log, log.skippedTime != nil || log.doseRecords.contains(where: { $0.isSkipped || $0.isMissed }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                Text(AppLocalization.string("Skipped"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            } else {
                Image(systemName: "pill.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.mint)
                Text(AppLocalization.string("Not Taken"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(entry.dayStreak) \(AppLocalization.string("Days"))")
                    .font(.system(.caption, design: .rounded, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.2))
            .cornerRadius(10)
        }
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct MedTrackerWidget: Widget {
    let kind: String = "MedTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MedTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(AppLocalization.string("Daily Status"))
        .description(AppLocalization.string("Shows your medication status and day streak."))
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 2. Medium Widget (Medications & BP Trend)
struct MedTrackerMediumWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Medications
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppLocalization.string("Medications"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.mint)
                    Spacer()
                    if let profile = entry.profile {
                        Text(profile.displayName)
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let profile = entry.profile, !profile.medications.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(profile.medications.prefix(3)) { med in
                            HStack {
                                Text(med.name)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(med.dose)
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .background(Color.mint.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        if profile.medications.count > 3 {
                            Text("...")
                                .font(.system(.caption))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(AppLocalization.string("No medications added."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Right: Blood Pressure / Status
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.string("Status"))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.blue)
                
                if let log = entry.log, let sys = log.systolic, let dia = log.diastolic {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLocalization.string("Blood Pressure"))
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(sys)")
                                .font(.system(.title3, design: .rounded, weight: .black))
                                .foregroundColor(sys > 130 ? .red : .primary)
                            Text("/")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(dia)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                        }
                    }
                } else {
                    Text(AppLocalization.string("No BP recorded today."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let log = entry.log, log.isTaken {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(AppLocalization.string("Taken")).font(.caption.bold())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(4)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct MedTrackerMediumWidget: Widget {
    let kind: String = "MedTrackerMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MedTrackerMediumWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(AppLocalization.string("Overview"))
        .description(AppLocalization.string("Shows medications and recent health data."))
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 3. Small Interactive Widget (Take / Skip)
struct MedTrackerInteractiveWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 10) {
            Text(AppLocalization.string("Today's Medication"))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let log = entry.log, log.isTaken {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text(AppLocalization.string("Taken Today"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
            } else if let log = entry.log, log.doseRecords.contains(where: { $0.isDue || $0.isSnoozed }) {
                VStack(spacing: 6) {
                    Text(AppLocalization.string("Due now"))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.orange)
                    HStack(spacing: 12) {
                        Button(intent: LogMedicationIntent(isTaken: true)) {
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                Text(AppLocalization.string("Take"))
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.mint)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Button(intent: LogMedicationIntent(isTaken: false)) {
                            VStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                Text(AppLocalization.string("Skip"))
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxHeight: 80)
                }
            } else if let log = entry.log, log.skippedTime != nil {
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    Text(AppLocalization.string("Skipped"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
            } else {
                HStack(spacing: 12) {
                    Button(intent: LogMedicationIntent(isTaken: true)) {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                            Text(AppLocalization.string("Take"))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.mint)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button(intent: LogMedicationIntent(isTaken: false)) {
                        VStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                            Text(AppLocalization.string("Skip"))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxHeight: 80)
            }
        }
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct MedTrackerInteractiveWidget: Widget {
    let kind: String = "MedTrackerInteractiveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MedTrackerInteractiveWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(AppLocalization.string("Quick Action"))
        .description(AppLocalization.string("Log your medication directly from the Home Screen."))
        .supportedFamilies([.systemSmall])
    }
}