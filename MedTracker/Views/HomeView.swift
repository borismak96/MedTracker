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
    @State private var bpRecordedAt = Date()
    @State private var editingBPReadingId: UUID?
    @State private var bpAlertCategory: BloodPressureCategory?
    
    @State private var showingBPChart = false
    @State private var showingMedicalCard = false
    
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
                                    bpDiastolic: $bpDiastolic,
                                    bpRecordedAt: $bpRecordedAt,
                                    editingBPReadingId: $editingBPReadingId
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
            .sheet(isPresented: $showingBPSheet, onDismiss: {
                editingBPReadingId = nil
            }) {
                if let log = todayLog {
                    bpSheetContent(for: log)
                }
            }
            .sheet(isPresented: $showingBPChart) {
                BloodPressureChartView(logs: logs)
            }
            .alert(
                bpAlertCategory?.localizedTitle ?? AppLocalization.string("Blood Pressure"),
                isPresented: Binding(
                    get: { bpAlertCategory != nil },
                    set: { if !$0 { bpAlertCategory = nil } }
                )
            ) {
                Button(AppLocalization.string("OK"), role: .cancel) {
                    bpAlertCategory = nil
                }
            } message: {
                Text(bpAlertCategory?.localizedAdvice ?? "")
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
                Text(AppBrand.displayName)
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
                        Text(AppLocalization.string("Hello, Friend!"))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    } else {
                        Text(AppLocalization.format("Hello, %@!", profile.name))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    Text(AppLocalization.string("Let's stay on track today."))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
                
                Spacer()
            }
        }
    }
    
    func skipSheetContent(for log: MedicationLog) -> some View {
        let reminderTitle = log.doseRecords.first(where: { $0.id == activeSkipReminderId })?.localizedDisplayTitle
            ?? AppLocalization.string("Missed Details")
        
        return NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        sheetHeader(
                            icon: "exclamationmark.triangle.fill",
                            title: AppLocalization.string("Missed Medication"),
                            subtitle: reminderTitle
                        )
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text(AppLocalization.string("Time"))
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Spacer()
                                DatePicker("", selection: $skippedTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(.mint)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 16)
                            
                            TextField(AppLocalization.string("Physical Reaction (Optional)"), text: $skipReaction)
                                .font(.system(.body, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 16)
                            
                            TextField(AppLocalization.string("Additional Notes (Optional)"), text: $skipNotes)
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
                            Text(AppLocalization.string("Save"))
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
                    Button(AppLocalization.string("Cancel")) {
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
        let isEditing = editingBPReadingId != nil
        
        return NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        sheetHeader(
                            icon: "heart.text.square.fill",
                            title: AppLocalization.string(isEditing ? "Edit Blood Pressure" : "Log Blood Pressure"),
                            subtitle: AppLocalization.string("Blood Pressure (mmHg)")
                        )
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.red.opacity(0.85))
                                TextField(AppLocalization.string("Systolic (High)"), text: $bpSystolic)
                                    .font(.system(.body, design: .rounded))
                                    .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 16)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.blue.opacity(0.85))
                                TextField(AppLocalization.string("Diastolic (Low)"), text: $bpDiastolic)
                                    .font(.system(.body, design: .rounded))
                                    .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 16)
                            
                            DatePicker(
                                AppLocalization.string("Time"),
                                selection: $bpRecordedAt,
                                displayedComponents: .hourAndMinute
                            )
                            .font(.system(.body, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                        
                        Button {
                            guard let sys = Int(bpSystolic), let dia = Int(bpDiastolic) else { return }
                            // Keep reading on the selected log’s calendar day.
                            let calendar = Calendar.current
                            let day = calendar.startOfDay(for: log.date)
                            let time = calendar.dateComponents([.hour, .minute], from: bpRecordedAt)
                            var parts = calendar.dateComponents([.year, .month, .day], from: day)
                            parts.hour = time.hour
                            parts.minute = time.minute
                            let recordedAt = calendar.date(from: parts) ?? Date()
                            
                            if let editId = editingBPReadingId {
                                log.updateBP(id: editId, systolic: sys, diastolic: dia, recordedAt: recordedAt)
                            } else {
                                log.addBP(systolic: sys, diastolic: dia, recordedAt: recordedAt)
                            }
                            let category = BloodPressureCategory.classify(systolic: sys, diastolic: dia)
                            editingBPReadingId = nil
                            showingBPSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                bpAlertCategory = category
                            }
                        } label: {
                            Text(AppLocalization.string("Save"))
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
                    Button(AppLocalization.string("Cancel")) {
                        editingBPReadingId = nil
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
                    Text(AppLocalization.string("Today's Medication"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(AppLocalization.string("Log each reminder time"))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                        Text(AppLocalization.format("%lld of %lld doses done", log.takenDoseCount, max(log.doseRecords.count, 1)))
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
                    Text(AppLocalization.string("How are you feeling today?"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(MoodStatus.allCases, id: \.self) { mood in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMood = mood
                                }
                            } label: {
                                MoodFaceChip(mood: mood, isSelected: selectedMood == mood)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    TextField(AppLocalization.string("Add remark (optional)"), text: $remarkText)
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
                    Text(AppLocalization.string("All reminder times taken today"))
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
                    Text(record.localizedLabel.isEmpty ? record.timeDescription : record.localizedLabel)
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
                Text(AppLocalization.string("No medicines assigned yet."))
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
                undoButton(reminderId: record.id, titleColor: titleColor, prefersLightText: prefersLightText)
            } else if record.isSkipped {
                if let reaction = record.physicalReaction, !reaction.isEmpty {
                    Text(AppLocalization.format("Reaction: %@", reaction))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(secondaryColor)
                }
                undoButton(reminderId: record.id, titleColor: titleColor, prefersLightText: prefersLightText)
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
                        Text(AppLocalization.string("Take Now"))
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
                        Text(AppLocalization.string("Skip / Missed"))
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
            title = AppLocalization.string("Taken")
            tint = .green
        } else if record.isSkipped {
            title = AppLocalization.string("Skipped")
            tint = .red
        } else {
            title = AppLocalization.string("Pending")
            tint = .orange
        }
        
        return Text(title)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(onSolid ? Color.white.opacity(0.92) : tint.opacity(0.15))
            .cornerRadius(10)
    }
    
    private func undoButton(reminderId: UUID, titleColor: Color, prefersLightText: Bool) -> some View {
        Button {
            withAnimation { log.undoDose(reminderId: reminderId) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .bold))
                Text(AppLocalization.string("Undo"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            .foregroundColor(titleColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(prefersLightText ? Color.white.opacity(0.28) : Color.white.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(titleColor.opacity(prefersLightText ? 0.45 : 0.2), lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

struct VitalsCard: View {
    @Bindable var log: MedicationLog
    @Binding var showingBPSheet: Bool
    @Binding var showingBPChart: Bool
    @Binding var bpSystolic: String
    @Binding var bpDiastolic: String
    @Binding var bpRecordedAt: Date
    @Binding var editingBPReadingId: UUID?
    
    private var readings: [BloodPressureReading] {
        log.sortedBPReadings
    }
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.string("Vitals"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(AppLocalization.string("Blood Pressure"))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if !readings.isEmpty {
                        Text(AppLocalization.format("%lld readings today", readings.count))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
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
            
            if readings.isEmpty {
                Text(AppLocalization.string("No BP recorded today."))
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(readings.reversed())) { reading in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.title3)
                                    .foregroundColor(reading.category.color)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reading.valueDescription)
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundColor(reading.category.color)
                                    Text(reading.timeDescription)
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    editingBPReadingId = reading.id
                                    bpSystolic = "\(reading.systolic)"
                                    bpDiastolic = "\(reading.diastolic)"
                                    bpRecordedAt = reading.recordedAt
                                    showingBPSheet = true
                                } label: {
                                    Text(AppLocalization.string("Edit"))
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    withAnimation {
                                        log.removeBP(id: reading.id)
                                    }
                                } label: {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            BloodPressureCategoryBadge(category: reading.category)
                        }
                        .padding(14)
                        .background(reading.category.color.opacity(0.08))
                        .cornerRadius(16)
                    }
                }
            }
            
            Button {
                editingBPReadingId = nil
                bpSystolic = ""
                bpDiastolic = ""
                bpRecordedAt = Date()
                showingBPSheet = true
            } label: {
                Text(AppLocalization.string(readings.isEmpty ? "Log Blood Pressure" : "Add Reading"))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(20)
                    .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            
            Button(action: { showingBPChart = true }) {
                Text(AppLocalization.string("View BP Trends"))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(30)
        .onAppear {
            log.ensureBPReadingsMigrated()
        }
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
                    Text(AppLocalization.string("Mood Trends"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(AppLocalization.string("This Month"))
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
                Text(AppLocalization.string("No mood data yet this month."))
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
            } else {
                if let topMood = mostCommonMood {
                    HStack(spacing: 12) {
                        MoodFaceChip(mood: topMood, isSelected: true, diameter: 44)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppLocalization.string("Most Common"))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(AppLocalization.string(topMood.rawValue))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(topMood.color)
                        }
                        
                        Spacer()
                        
                        Text("\(monthMoodLogs.count)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text(AppLocalization.string("Days"))
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
                            MoodFaceView(mood: item.mood, size: 26)
                                .frame(width: 28)
                            
                            Text(AppLocalization.string(item.mood.rawValue))
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
