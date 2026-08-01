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
    
    private let streakGoal = 30
    
    func statsSection(profile: UserProfile) -> some View {
        let reminders = reminderSlots(for: profile)
        let colors = StatsRingPalette.accentColors
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey("Day Streak"))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Text(LocalizedStringKey("Tap a ring for details"))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Stack full-width gauges so each ring stays large and readable.
            VStack(spacing: 14) {
                ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                    streakGaugeCard(
                        reminder: reminder,
                        color: colors[index % colors.count],
                        profile: profile
                    )
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
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
        profile: UserProfile
    ) -> some View {
        let streak = streakCount(for: reminder.id)
        let meds = profile.medications(for: reminder)
        let medLines = meds.isEmpty
            ? [String(localized: "No medicines assigned yet.")]
            : meds.map { "\($0.name) · \($0.dose)" }
        let details = [
            String(format: String(localized: "Reminder time: %@"), reminder.timeDescription),
            String(format: String(localized: "Current streak: %lld days"), streak),
            String(format: String(localized: "Goal: %lld days"), streakGoal)
        ] + medLines
        
        return Button {
            selectedRingSegment = RingSegmentModel(
                id: reminder.id,
                title: reminder.label.isEmpty ? reminder.timeDescription : reminder.label,
                subtitle: reminder.displayTitle,
                detailLines: details,
                color: color,
                icon: StatsRingLayout.icon(for: reminder),
                startDegrees: 0,
                endDegrees: 0
            )
        } label: {
            HStack(spacing: 18) {
                StreakGaugeView(
                    current: streak,
                    goal: streakGoal,
                    color: color,
                    lineWidth: 18
                )
                .frame(width: 150, height: 150)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(reminder.label.isEmpty ? reminder.timeDescription : reminder.label)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(reminder.timeDescription)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(String(format: String(localized: "%lld day streak"), streak))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(color)
                        .padding(.top, 2)
                    
                    if !meds.isEmpty {
                        Text(meds.map(\.name).filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.14))
            .cornerRadius(22)
        }
        .buttonStyle(.plain)
    }
    
    /// Consecutive days this reminder dose was taken (today counts if taken).
    private func streakCount(for reminderId: UUID) -> Int {
        var streak = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for i in 0..<streakGoal {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { break }
            let log = logs.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
            
            let taken: Bool
            if let log {
                if let record = log.doseRecords.first(where: { $0.id == reminderId }) {
                    taken = record.isTaken
                } else {
                    // Legacy day-level taken counts for all reminder slots.
                    taken = log.isTaken
                }
            } else {
                taken = false
            }
            
            if taken {
                streak += 1
            } else if i > 0 {
                break
            } else {
                // Today not taken yet — keep looking from yesterday.
                continue
            }
        }
        return streak
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
    
    private let slotColors: [Color] = [
        StatsRingPalette.yellow,
        StatsRingPalette.green,
        StatsRingPalette.pink,
        StatsRingPalette.blue
    ]
    
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
                ForEach(Array(log.sortedDoseRecords.enumerated()), id: \.element.id) { index, record in
                    doseSlotCard(record: record, color: slotColors[index % slotColors.count])
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
    private func doseSlotCard(record: ReminderDoseRecord, color: Color) -> some View {
        let reminder = profile.sortedReminders.first(where: { $0.id == record.id })
        let meds = reminder.map { profile.medications(for: $0) } ?? []
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.label.isEmpty ? record.timeDescription : record.label)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(record.timeDescription)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusChip(for: record)
            }
            
            if meds.isEmpty {
                Text(LocalizedStringKey("No medicines assigned yet."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(meds) { med in
                        Text("\(med.name)\(med.dose.isEmpty ? "" : " · \(med.dose)")")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.primary.opacity(0.85))
                    }
                }
            }
            
            if record.isTaken {
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Button {
                    withAnimation { log.undoDose(reminderId: record.id) }
                } label: {
                    Text("Undo")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else if record.isSkipped {
                if let reaction = record.physicalReaction, !reaction.isEmpty {
                    Text(String(format: String(localized: "Reaction: %@"), reaction))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Button {
                    withAnimation { log.undoDose(reminderId: record.id) }
                } label: {
                    Text("Undo")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
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
                            .background(Color.mint)
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
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(color.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.45), lineWidth: 1)
        )
        .cornerRadius(18)
    }
    
    private func statusChip(for record: ReminderDoseRecord) -> some View {
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
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.15))
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
