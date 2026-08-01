import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedTab: AppTab
    @Query private var profiles: [UserProfile]
    @Query(sort: \MedicationLog.date, order: .reverse) private var logs: [MedicationLog]
    
    @State private var showingSkipSheet = false
    @State private var skipNotes = ""
    @State private var skipReaction = ""
    @State private var skippedTime = Date()
    @State private var activeSkipReminderId: UUID?
    
    @State private var showingBPSheet = false
    @State private var bpSystolic = ""
    @State private var bpDiastolic = ""
    
    @State private var showingBPChart = false
    @State private var showingMedicalCard = false
    @State private var selectedRingSegment: RingSegmentModel?
    
    var profile: UserProfile? { profiles.first }
    
    var todayLog: MedicationLog? {
        let today = Calendar.current.startOfDay(for: Date())
        return logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if let profile = profile {
                            headerSection(profile: profile)
                                .padding(.top, 10)
                            
                            statsSection(profile: profile)
                            
                            if let log = todayLog {
                                TodayCard(
                                    log: log,
                                    profile: profile,
                                    showingSkipSheet: $showingSkipSheet,
                                    activeSkipReminderId: $activeSkipReminderId,
                                    skippedTime: $skippedTime,
                                    skipReaction: $skipReaction,
                                    skipNotes: $skipNotes
                                )
                                
                                VitalsCard(
                                    log: log,
                                    showingBPSheet: $showingBPSheet,
                                    showingBPChart: $showingBPChart,
                                    bpSystolic: $bpSystolic,
                                    bpDiastolic: $bpDiastolic
                                )
                                
                                MoodStatsCard(logs: logs)
                            }
                        } else {
                            ProgressView()
                                .padding(.top, 50)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                
                if showingMedicalCard {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingMedicalCard = false
                            }
                        }
                    
                    if let profile = profile {
                        MedicalCardView(profile: profile, isShowing: $showingMedicalCard)
                            .transition(.scale.combined(with: .opacity))
                            .zIndex(1)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSkipSheet) {
                if let log = todayLog {
                    skipSheetContent(for: log)
                }
            }
            .sheet(isPresented: $showingBPSheet) {
                if let log = todayLog {
                    bpSheetContent(for: log)
                }
            }
            .sheet(isPresented: $showingBPChart) {
                BloodPressureChartView(logs: logs)
            }
            .sheet(item: $selectedRingSegment) { segment in
                RingDetailSheet(segment: segment)
            }
            .onAppear {
                profile?.ensureRemindersMigrated()
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .today, showingMedicalCard {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingMedicalCard = false
                    }
                }
            }
        }
    }
    
    func headerSection(profile: UserProfile) -> some View {
        VStack(spacing: 20) {
            // App Title and Notification Bell
            HStack {
                Text("MedTracker")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingMedicalCard = true
                    }
                }) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.mint)
                        .padding(12)
                        .background(Circle().fill(Color.white))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            }
            
            // Greeting and Avatar
            HStack {
                if let data = profile.profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundStyle(.white, Color.mint)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if profile.name.isEmpty {
                        Text("Hello, Friend!")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    } else {
                        Text("Hello, \(profile.name)!")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    Text("Let's stay on track today.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
                
                Spacer()
            }
        }
    }
    
    func statsSection(profile: UserProfile) -> some View {
        let reminders = reminderSlots(for: profile)
        let calendar = Calendar.current
        let today = Date()
        let dayOfMonth = calendar.component(.day, from: today)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Day Streak"))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Text(LocalizedStringKey("Tap a ring for details"))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            if reminders.count == 1, let reminder = reminders.first {
                streakGaugeCard(
                    reminder: reminder,
                    color: StatsRingPalette.color(for: reminder),
                    profile: profile,
                    dayOfMonth: dayOfMonth,
                    daysInMonth: daysInMonth,
                    cardWidth: nil
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(reminders) { reminder in
                            streakGaugeCard(
                                reminder: reminder,
                                color: StatsRingPalette.color(for: reminder),
                                profile: profile,
                                dayOfMonth: dayOfMonth,
                                daysInMonth: daysInMonth,
                                cardWidth: 200
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private func reminderSlots(for profile: UserProfile) -> [ReminderSlot] {
        let reminders = profile.sortedReminders
        if reminders.isEmpty {
            return [ReminderSlot(hour: profile.targetTimeHour, minute: profile.targetTimeMinute, label: "Morning")]
        }
        return reminders
    }
    
    private func streakGaugeCard(
        reminder: ReminderSlot,
        color: Color,
        profile: UserProfile,
        dayOfMonth: Int,
        daysInMonth: Int,
        cardWidth: CGFloat?
    ) -> some View {
        let streak = streakCount(for: reminder.id, lookingBack: daysInMonth)
        let takenThisMonth = takenCountThisMonth(for: reminder.id)
        let meds = profile.medications(for: reminder)
        let medLines = meds.isEmpty
            ? [String(localized: "No medicines assigned yet.")]
            : meds.map { "\($0.name) · \($0.dose)" }
        let todayLabel = Date.now.formatted(.dateTime.month(.abbreviated).day())
        let details = [
            String(format: String(localized: "Reminder time: %@"), reminder.timeDescription),
            String(format: String(localized: "Today: %@"), todayLabel),
            String(format: String(localized: "Calendar day: %lld / %lld"), dayOfMonth, daysInMonth),
            String(format: String(localized: "Taken this month: %lld"), takenThisMonth),
            String(format: String(localized: "Current streak: %lld days"), streak)
        ] + medLines
        
        let titleText: String = {
            if reminder.label.isEmpty {
                return String(format: String(localized: "%@ dose"), reminder.timeDescription)
            }
            return String(format: String(localized: "%@ dose"), reminder.label)
        }()
        
        return Button {
            selectedRingSegment = RingSegmentModel(
                id: reminder.id,
                title: titleText,
                subtitle: reminder.displayTitle,
                detailLines: details,
                color: StatsRingPalette.accent(for: reminder),
                icon: StatsRingLayout.icon(for: reminder),
                startDegrees: 0,
                endDegrees: 0
            )
        } label: {
            let titleColor = StatsRingPalette.primaryText(for: reminder)
            let secondaryColor = StatsRingPalette.secondaryText(for: reminder)
            let accent = StatsRingPalette.accent(for: reminder)
            
            VStack(spacing: 12) {
                StreakGaugeView(
                    current: dayOfMonth,
                    goal: daysInMonth,
                    color: color,
                    lineWidth: 18,
                    progressColor: StatsRingPalette.prefersLightText(for: reminder) ? .white : accent,
                    onSolidBackground: true
                )
                .frame(width: 140, height: 140)
                
                VStack(spacing: 4) {
                    Text(titleText)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(titleColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(String(format: String(localized: "Scheduled · %@"), reminder.timeDescription))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(secondaryColor)
                        .multilineTextAlignment(.center)
                    
                    Text(String(format: String(localized: "Today · %@"), todayLabel))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(String(format: String(localized: "%lld day streak"), streak))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(secondaryColor)
                    
                    if !meds.isEmpty {
                        Text(meds.map(\.name).filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundColor(secondaryColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            }
            .padding(16)
            .frame(width: cardWidth)
            .frame(maxWidth: cardWidth == nil ? .infinity : nil)
            .background(color)
            .cornerRadius(22)
            .shadow(color: color.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    /// Consecutive days this reminder dose was taken (today counts if taken).
    private func streakCount(for reminderId: UUID, lookingBack: Int = 31) -> Int {
        var streak = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for i in 0..<max(lookingBack, 1) {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { break }
            
            if isReminderTaken(reminderId, on: date) {
                streak += 1
            } else if i > 0 {
                break
            }
        }
        return streak
    }
    
    private func takenCountThisMonth(for reminderId: UUID) -> Int {
        let calendar = Calendar.current
        let today = Date()
        return logs.filter { log in
            calendar.isDate(log.date, equalTo: today, toGranularity: .month)
            && isReminderTaken(reminderId, on: log.date)
        }.count
    }
    
    private func isReminderTaken(_ reminderId: UUID, on date: Date) -> Bool {
        let calendar = Calendar.current
        guard let log = logs.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) else {
            return false
        }
        if let record = log.doseRecords.first(where: { $0.id == reminderId }) {
            return record.isTaken
        }
        // Legacy day-level taken counts for all reminder slots.
        return log.isTaken
    }
    
    func skipSheetContent(for log: MedicationLog) -> some View {
        let reminderTitle = log.doseRecords.first(where: { $0.id == activeSkipReminderId })?.displayTitle
            ?? String(localized: "Missed Details")
        
        return NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        sheetHeader(
                            icon: "exclamationmark.triangle.fill",
                            title: String(localized: "Missed Medication"),
                            subtitle: reminderTitle
                        )
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text(LocalizedStringKey("Time"))
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Spacer()
                                DatePicker("", selection: $skippedTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(.mint)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 16)
                            
                            TextField(LocalizedStringKey("Physical Reaction (Optional)"), text: $skipReaction)
                                .font(.system(.body, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 16)
                            
                            TextField(LocalizedStringKey("Additional Notes (Optional)"), text: $skipNotes)
                                .font(.system(.body, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                        
                        Button {
                            if let reminderId = activeSkipReminderId {
                                log.markSkipped(
                                    reminderId: reminderId,
                                    time: skippedTime,
                                    reaction: skipReaction,
                                    notes: skipNotes
                                )
                            }
                            showingSkipSheet = false
                            activeSkipReminderId = nil
                            skipReaction = ""
                            skipNotes = ""
                        } label: {
                            Text(LocalizedStringKey("Save"))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.mint)
                                .cornerRadius(20)
                                .shadow(color: Color.mint.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) {
                        showingSkipSheet = false
                        activeSkipReminderId = nil
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.mint)
                }
            }
        }
    }
    
    func bpSheetContent(for log: MedicationLog) -> some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        sheetHeader(
                            icon: "heart.text.square.fill",
                            title: String(localized: "Log Blood Pressure"),
                            subtitle: String(localized: "Blood Pressure (mmHg)")
                        )
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.red.opacity(0.85))
                                TextField(LocalizedStringKey("Systolic (High)"), text: $bpSystolic)
                                    .font(.system(.body, design: .rounded))
                                    .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 16)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.blue.opacity(0.85))
                                TextField(LocalizedStringKey("Diastolic (Low)"), text: $bpDiastolic)
                                    .font(.system(.body, design: .rounded))
                                    .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                        
                        Button {
                            if let sys = Int(bpSystolic), let dia = Int(bpDiastolic) {
                                log.systolic = sys
                                log.diastolic = dia
                            }
                            showingBPSheet = false
                        } label: {
                            Text(LocalizedStringKey("Save"))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.mint)
                                .cornerRadius(20)
                                .shadow(color: Color.mint.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) {
                        showingBPSheet = false
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.mint)
                }
            }
        }
    }
    
    private func sheetHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(.mint)
            }
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
}

struct TodayCard: View {
    @Bindable var log: MedicationLog
    var profile: UserProfile
    @Binding var showingSkipSheet: Bool
    @Binding var activeSkipReminderId: UUID?
    @Binding var skippedTime: Date
    @Binding var skipReaction: String
    @Binding var skipNotes: String
    
    @State private var selectedMood: MoodStatus? = nil
    @State private var remarkText: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Medication")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(LocalizedStringKey("Log each reminder time"))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                        Text(String(format: String(localized: "%lld of %lld doses done"), log.takenDoseCount, max(log.doseRecords.count, 1)))
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.mint)
                }
                
                Spacer(minLength: 12)
                
                ZStack {
                    Circle()
                        .fill(Color.mint.opacity(0.15))
                        .frame(width: 70, height: 70)
                    Image(systemName: "pills.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.mint)
                }
            }
            
            if log.sortedDoseRecords.contains(where: \.isPending) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("How are you feeling today?")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(MoodStatus.allCases, id: \.self) { mood in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMood = mood
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(selectedMood == mood ? mood.color.opacity(0.2) : Color(UIColor.systemGray6))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: mood.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedMood == mood ? mood.color : .gray)
                                }
                                .scaleEffect(selectedMood == mood ? 1.08 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    TextField(LocalizedStringKey("Add remark (optional)"), text: $remarkText)
                        .font(.system(.body, design: .rounded))
                        .padding(12)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                }
            }
            
            VStack(spacing: 12) {
                ForEach(log.sortedDoseRecords) { record in
                    let reminder = profile.sortedReminders.first(where: { $0.id == record.id })
                        ?? ReminderSlot(id: record.id, hour: record.hour, minute: record.minute, label: record.label)
                    doseSlotCard(
                        record: record,
                        color: StatsRingPalette.color(for: reminder),
                        prefersLightText: StatsRingPalette.prefersLightText(for: reminder)
                    )
                }
            }
            
            if log.isTaken {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text(LocalizedStringKey("All reminder times taken today"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(14)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(30)
        .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
        .onAppear {
            log.syncDoseRecords(with: profile)
        }
        .onChange(of: profile.reminders) { _, _ in
            log.syncDoseRecords(with: profile)
        }
        .onChange(of: profile.medications) { _, _ in
            log.syncDoseRecords(with: profile)
        }
    }
    
    @ViewBuilder
    private func doseSlotCard(record: ReminderDoseRecord, color: Color, prefersLightText: Bool) -> some View {
        let reminder = profile.sortedReminders.first(where: { $0.id == record.id })
            ?? ReminderSlot(id: record.id, hour: record.hour, minute: record.minute, label: record.label)
        let meds = profile.medications(for: reminder)
        let accent = StatsRingPalette.accent(for: reminder)
        let titleColor = StatsRingPalette.primaryText(for: reminder)
        let secondaryColor = StatsRingPalette.secondaryText(for: reminder)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(prefersLightText ? Color.white : Color(white: 0.15))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.label.isEmpty ? record.timeDescription : record.label)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(titleColor)
                    Text(record.timeDescription)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(secondaryColor)
                }
                
                Spacer()
                
                statusChip(for: record, onSolid: true)
            }
            
            if meds.isEmpty {
                Text(LocalizedStringKey("No medicines assigned yet."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(secondaryColor)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(meds) { med in
                        Text("\(med.name)\(med.dose.isEmpty ? "" : " · \(med.dose)")")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(titleColor.opacity(0.9))
                    }
                }
            }
            
            if record.isTaken {
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(secondaryColor)
                }
                Button {
                    withAnimation { log.undoDose(reminderId: record.id) }
                } label: {
                    Text("Undo")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundColor(secondaryColor)
                }
                .buttonStyle(.plain)
            } else if record.isSkipped {
                if let reaction = record.physicalReaction, !reaction.isEmpty {
                    Text(String(format: String(localized: "Reaction: %@"), reaction))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(secondaryColor)
                }
                Button {
                    withAnimation { log.undoDose(reminderId: record.id) }
                } label: {
                    Text("Undo")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundColor(secondaryColor)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    Button {
                        withAnimation {
                            log.markTaken(
                                reminderId: record.id,
                                mood: selectedMood?.rawValue,
                                remark: remarkText.isEmpty ? nil : remarkText,
                                medications: meds
                            )
                        }
                    } label: {
                        Text("Take Now")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accent)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        activeSkipReminderId = record.id
                        skippedTime = Date()
                        skipReaction = ""
                        skipNotes = ""
                        showingSkipSheet = true
                    } label: {
                        Text("Skip / Missed")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(titleColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.55))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(color)
        .cornerRadius(18)
        .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 3)
    }
    
    private func statusChip(for record: ReminderDoseRecord, onSolid: Bool = false) -> some View {
        let title: String
        let tint: Color
        if record.isTaken {
            title = String(localized: "Taken")
            tint = .green
        } else if record.isSkipped {
            title = String(localized: "Skipped")
            tint = .red
        } else {
            title = String(localized: "Pending")
            tint = .orange
        }
        
        return Text(title)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundColor(onSolid ? tint : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(onSolid ? Color.white.opacity(0.92) : tint.opacity(0.15))
            .cornerRadius(10)
    }
}

struct VitalsCard: View {
    @Bindable var log: MedicationLog
    @Binding var showingBPSheet: Bool
    @Binding var showingBPChart: Bool
    @Binding var bpSystolic: String
    @Binding var bpDiastolic: String
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vitals")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text("Blood Pressure")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 70, height: 70)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.red)
                }
            }
            
            if let sys = log.systolic, let dia = log.diastolic {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title3)
                            .foregroundColor(.red)
                        Text("\(sys) / \(dia) mmHg")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(16)
                
                HStack(spacing: 16) {
                    Button(action: {
                        bpSystolic = "\(sys)"
                        bpDiastolic = "\(dia)"
                        showingBPSheet = true
                    }) {
                        Text("Edit")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(20)
                    }
                    
                    Button(action: {
                        log.systolic = nil
                        log.diastolic = nil
                    }) {
                        Text("Remove")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
                
                Button(action: { showingBPChart = true }) {
                    Text("View BP Trends")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(20)
                }
            } else {
                Button(action: {
                    bpSystolic = ""
                    bpDiastolic = ""
                    showingBPSheet = true
                }) {
                    Text("Log Blood Pressure")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(20)
                        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button(action: { showingBPChart = true }) {
                    Text("View BP Trends")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(20)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(30)
        .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
    }
}

struct MoodStatsCard: View {
    let logs: [MedicationLog]
    
    private var monthMoodLogs: [MedicationLog] {
        let calendar = Calendar.current
        let today = Date()
        return logs.filter {
            calendar.isDate($0.date, equalTo: today, toGranularity: .month)
            && MoodStatus.from(string: $0.mood) != nil
        }
    }
    
    private var moodCounts: [(mood: MoodStatus, count: Int)] {
        MoodStatus.allCases.map { mood in
            let count = monthMoodLogs.filter { MoodStatus.from(string: $0.mood) == mood }.count
            return (mood, count)
        }
    }
    
    private var mostCommonMood: MoodStatus? {
        moodCounts.max(by: { $0.count < $1.count }).flatMap { $0.count > 0 ? $0.mood : nil }
    }
    
    private var maxCount: Int {
        max(moodCounts.map(\.count).max() ?? 1, 1)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mood Trends")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text("This Month")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 70, height: 70)
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                }
            }
            
            if monthMoodLogs.isEmpty {
                Text("No mood data yet this month.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
            } else {
                if let topMood = mostCommonMood {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(topMood.color.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: topMood.icon)
                                .foregroundColor(topMood.color)
                                .font(.system(size: 20))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Most Common")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey(topMood.rawValue))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(topMood.color)
                        }
                        
                        Spacer()
                        
                        Text("\(monthMoodLogs.count)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text("Days")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(topMood.color.opacity(0.1))
                    .cornerRadius(16)
                }
                
                VStack(spacing: 12) {
                    ForEach(moodCounts, id: \.mood) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.mood.icon)
                                .font(.system(size: 16))
                                .foregroundColor(item.mood.color)
                                .frame(width: 24)
                            
                            Text(LocalizedStringKey(item.mood.rawValue))
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .frame(width: 72, alignment: .leading)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(UIColor.systemGray6))
                                        .frame(height: 10)
                                    
                                    Capsule()
                                        .fill(item.mood.color.opacity(0.8))
                                        .frame(
                                            width: item.count == 0 ? 0 : max(geo.size.width * CGFloat(item.count) / CGFloat(maxCount), 8),
                                            height: 10
                                        )
                                }
                            }
                            .frame(height: 10)
                            
                            Text("\(item.count)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(30)
        .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
    }
}
