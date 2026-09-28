import SwiftUI
import SwiftData

struct CareDayboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \MedicationLog.date, order: .reverse) private var allLogs: [MedicationLog]
    @AppStorage(ActiveProfileStore.idKey, store: AppLocalization.sharedDefaults) private var activeProfileID = ""
    @AppStorage(ElderMode.enabledKey, store: AppLocalization.sharedDefaults) private var elderMode = false
    @AppStorage(DayboardSelection.key, store: AppLocalization.sharedDefaults) private var selectedRaw = ""
    
    @State private var skipTarget: DayboardSkipTarget?
    
    private var orderedProfiles: [UserProfile] {
        profiles.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }
    
    private var visibleProfiles: [UserProfile] {
        _ = selectedRaw
        return DayboardSelection.visibleProfiles(from: profiles)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(spacing: elderMode ? 20 : 16) {
                            if orderedProfiles.isEmpty {
                                emptyCard(
                                    title: AppLocalization.string("No profiles yet"),
                                    message: AppLocalization.string("Add a person in Profile to start household care.")
                                )
                            } else {
                                profileFilter
                                elderToggle
                                
                                if visibleProfiles.isEmpty {
                                    emptyCard(
                                        title: AppLocalization.string("No one selected"),
                                        message: AppLocalization.string("Choose at least one person on this iPhone.")
                                    )
                                } else {
                                    ForEach(visibleProfiles, id: \.id) { member in
                                        profileBoard(member)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $skipTarget) { target in
                dayboardSkipSheet(target)
            }
            .onAppear {
                refreshLogs()
            }
            .onChange(of: profiles.count) { _, _ in
                refreshLogs()
            }
        }
    }
    
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.string("Care"))
                    .font(.system(elderMode ? .largeTitle : .title, design: .rounded, weight: .heavy))
                    .foregroundColor(ink)
                Text(AppLocalization.mediumDate())
                    .font(.system(elderMode ? .title3 : .subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(mutedInk)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
    
    private var elderToggle: some View {
        Toggle(isOn: $elderMode) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.string("樂齡 Mode"))
                    .font(.system(elderMode ? .title3 : .headline, design: .rounded, weight: .bold))
                    .foregroundColor(ink)
                Text(AppLocalization.string("Larger text and high-contrast buttons for easier tapping."))
                    .font(.system(elderMode ? .body : .caption, design: .rounded))
                    .foregroundColor(mutedInk)
            }
        }
        .tint(actionMint)
        .padding(elderMode ? 20 : 16)
        .background(Color.white)
        .foregroundColor(ink)
        .cornerRadius(22)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    private var profileFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalization.string("Show today for"))
                .font(.system(elderMode ? .title3 : .subheadline, design: .rounded, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(orderedProfiles, id: \.id) { member in
                        let on = DayboardSelection.isIncluded(member)
                        Button {
                            DayboardSelection.toggle(member, among: profiles)
                            selectedRaw = AppLocalization.sharedDefaults.string(forKey: DayboardSelection.key) ?? ""
                        } label: {
                            Text(member.displayName)
                                .font(.system(elderMode ? .title3 : .subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(on ? .white : actionMint)
                                .padding(.horizontal, elderMode ? 18 : 14)
                                .padding(.vertical, elderMode ? 14 : 8)
                                .frame(minHeight: ElderMode.minTap)
                                .background(on ? actionMint : actionMint.opacity(elderMode ? 0.18 : 0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(elderMode ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .foregroundColor(ink)
        .cornerRadius(22)
    }
    
    @ViewBuilder
    private func profileBoard(_ member: UserProfile) -> some View {
        let log = todayLog(for: member)
        let records = log?.sortedDoseRecords ?? []
        let remaining = records.filter(\.isOpen)
        let done = records.filter { !$0.isOpen }
        
        VStack(alignment: .leading, spacing: elderMode ? 16 : 12) {
            HStack {
                Text(member.displayName)
                    .font(.system(elderMode ? .title : .title3, design: .rounded, weight: .heavy))
                    .foregroundColor(ink)
                Spacer()
                Text(AppLocalization.format("%lld of %lld doses done", done.count, max(records.count, 0)))
                    .font(.system(elderMode ? .body : .caption, design: .rounded, weight: .semibold))
                    .foregroundColor(mutedInk)
            }
            
            if records.isEmpty {
                emptyCard(
                    title: AppLocalization.string("No doses scheduled today."),
                    message: AppLocalization.string("Add reminder times in Reminder Times settings."),
                    embedded: true
                )
            } else {
                if remaining.isEmpty {
                    Text(AppLocalization.string("All done for today"))
                        .font(.system(elderMode ? .title3 : .subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(statusGreen)
                } else {
                    Text(AppLocalization.string("Remaining"))
                        .font(.system(elderMode ? .title3 : .headline, design: .rounded, weight: .bold))
                    ForEach(remaining) { record in
                        doseRow(profile: member, log: log, record: record, remaining: true)
                    }
                }
                
                if !done.isEmpty {
                    Text(AppLocalization.string("Done"))
                        .font(.system(elderMode ? .title3 : .headline, design: .rounded, weight: .bold))
                        .padding(.top, 4)
                    ForEach(done) { record in
                        doseRow(profile: member, log: log, record: record, remaining: false)
                    }
                }
            }
        }
        .padding(elderMode ? 22 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .foregroundColor(ink)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    @ViewBuilder
    private func doseRow(profile: UserProfile, log: MedicationLog?, record: ReminderDoseRecord, remaining: Bool) -> some View {
        let meds = profile.medications(for: ReminderSlot(id: record.id, hour: record.hour, minute: record.minute, label: record.label))
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.localizedDisplayTitle)
                        .font(.system(elderMode ? .title2 : .headline, design: .rounded, weight: .bold))
                    if meds.isEmpty {
                        Text(AppLocalization.string("No medicines assigned yet."))
                            .font(.system(elderMode ? .body : .caption, design: .rounded))
                            .foregroundColor(mutedInk)
                    } else {
                        Text(meds.map { $0.dose.isEmpty ? $0.name : "\($0.name) · \($0.dose)" }.joined(separator: ", "))
                            .font(.system(elderMode ? .body : .caption, design: .rounded))
                            .foregroundColor(mutedInk)
                    }
                }
                Spacer()
                statusLabel(record)
            }
            
            if remaining, let log {
                HStack(spacing: 10) {
                    Button {
                        log.markTaken(reminderId: record.id, mood: nil, remark: nil, medications: meds)
                    } label: {
                        Text(AppLocalization.string("Take"))
                            .font(.system(elderMode ? .title2 : .headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: elderMode ? ElderMode.buttonHeight : 44.0)
                            .background(actionMint)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if elderMode {
                            log.markMissed(reminderId: record.id)
                        } else {
                            skipTarget = DayboardSkipTarget(profileID: profile.id, reminderId: record.id)
                        }
                    } label: {
                        Text(AppLocalization.string("Missed"))
                            .font(.system(elderMode ? .title2 : .headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: elderMode ? ElderMode.buttonHeight : 44.0)
                            .background(statusRed)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(elderMode ? 16 : 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private func statusLabel(_ record: ReminderDoseRecord) -> some View {
        let title: String
        let tint: Color
        if record.isTaken {
            title = AppLocalization.string("Taken")
            tint = statusGreen
        } else if record.isSkipped || record.isMissed {
            title = record.isMissed ? AppLocalization.string("Missed") : AppLocalization.string("Skipped")
            tint = statusRed
        } else if record.isDue || record.isSnoozed {
            title = AppLocalization.string("Due")
            tint = statusOrange
        } else {
            title = AppLocalization.string("Scheduled")
            tint = actionMint
        }
        return Text(title)
            .font(.system(elderMode ? .headline : .caption, design: .rounded, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.18))
            .cornerRadius(10)
    }
    
    private func emptyCard(title: String, message: String, embedded: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(elderMode ? .title2 : .headline, design: .rounded, weight: .bold))
            Text(message)
                .font(.system(elderMode ? .body : .subheadline, design: .rounded))
                .foregroundColor(mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(elderMode ? 22 : 18)
        .background(embedded ? Color.clear : Color.white)
        .cornerRadius(22)
    }
    
    private var ink: Color {
        elderMode ? Color(red: 0.08, green: 0.08, blue: 0.10) : Color.primary
    }
    
    /// ~12:1 on white — system `.secondary` is too light for 樂齡.
    private var mutedInk: Color {
        elderMode ? Color(red: 0.20, green: 0.20, blue: 0.22) : Color.secondary
    }
    
    /// Darker mint so white button/chip text stays readable.
    private var actionMint: Color {
        elderMode ? Color(red: 0.00, green: 0.42, blue: 0.40) : Color.mint
    }
    
    private var statusGreen: Color {
        elderMode ? Color(red: 0.00, green: 0.42, blue: 0.20) : Color.green
    }
    
    private var statusRed: Color {
        elderMode ? Color(red: 0.72, green: 0.10, blue: 0.10) : Color.red.opacity(0.85)
    }
    
    private var statusOrange: Color {
        elderMode ? Color(red: 0.70, green: 0.34, blue: 0.00) : Color.orange
    }
    
    private func todayLog(for profile: UserProfile) -> MedicationLog? {
        let today = Calendar.current.startOfDay(for: Date())
        return allLogs.first { $0.belongs(to: profile) && Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    private func refreshLogs() {
        _ = activeProfileID
        for profile in visibleProfiles {
            profile.ensureRemindersMigrated()
            HouseholdData.ensureTodayLog(for: profile, logs: allLogs, context: modelContext)
        }
    }
    
    private func dayboardSkipSheet(_ target: DayboardSkipTarget) -> some View {
        let member = profiles.first(where: { $0.id == target.profileID })
        let log = member.flatMap { todayLog(for: $0) }
        return DayboardSkipSheet(
            title: log?.doseRecords.first(where: { $0.id == target.reminderId })?.localizedDisplayTitle
                ?? AppLocalization.string("Missed"),
            onCancel: { skipTarget = nil },
            onSave: { time, reaction, notes in
                log?.markSkipped(reminderId: target.reminderId, time: time, reaction: reaction, notes: notes)
                skipTarget = nil
            }
        )
    }
}

private struct DayboardSkipTarget: Identifiable {
    var id: String { "\(profileID.uuidString)-\(reminderId.uuidString)" }
    var profileID: UUID
    var reminderId: UUID
}

private struct DayboardSkipSheet: View {
    var title: String
    var onCancel: () -> Void
    var onSave: (Date, String?, String?) -> Void
    
    @State private var skippedTime = Date()
    @State private var skipReaction = ""
    @State private var skipNotes = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                VStack(spacing: 16) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    DatePicker(AppLocalization.string("Time"), selection: $skippedTime, displayedComponents: .hourAndMinute)
                    TextField(AppLocalization.string("Physical Reaction (Optional)"), text: $skipReaction)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(12)
                    TextField(AppLocalization.string("Additional Notes (Optional)"), text: $skipNotes)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(12)
                    Button {
                        onSave(
                            skippedTime,
                            skipReaction.isEmpty ? nil : skipReaction,
                            skipNotes.isEmpty ? nil : skipNotes
                        )
                    } label: {
                        Text(AppLocalization.string("Save"))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.mint)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("Cancel"), action: onCancel)
                        .foregroundColor(.mint)
                }
            }
        }
    }
}
