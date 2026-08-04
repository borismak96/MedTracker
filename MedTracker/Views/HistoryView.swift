import SwiftUI
import SwiftData

struct DateWrapper: Identifiable {
    let id = UUID()
    let date: Date
}

struct HistoryView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \MedicationLog.date, order: .reverse) private var logs: [MedicationLog]
    
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var editingDateWrapper: DateWrapper? = nil
    
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var profile: UserProfile? { profiles.first }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                VStack(spacing: 0) {
                    HStack {
                        Text(AppLocalization.string("History"))
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            VStack(spacing: 20) {
                                monthHeader
                                weekdayHeader
                                calendarGrid
                            }
                            .padding(24)
                            .background(Color.white)
                            .cornerRadius(30)
                            .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
                            
                            selectedDateSummary
                                .padding(24)
                                .background(Color.white)
                                .cornerRadius(30)
                                .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $editingDateWrapper) { dateWrapper in
                if let profile = profile {
                    DailyRecordSheet(date: dateWrapper.date, profile: profile)
                }
            }
            .onAppear {
                syncSelectedDateDoseRecords()
            }
            .onChange(of: selectedDate) { _, _ in
                syncSelectedDateDoseRecords()
            }
            .onChange(of: logs.count) { _, _ in
                syncSelectedDateDoseRecords()
            }
        }
    }
    
    private func syncSelectedDateDoseRecords() {
        guard let profile, let log = logForDate(selectedDate) else { return }
        // Only auto-create reminder slots for today. Past empty days should stay "Not Recorded"
        // so new users don't see Pending on days they never tracked.
        guard Calendar.current.isDateInToday(selectedDate) else { return }
        log.syncDoseRecords(with: profile)
        try? log.modelContext?.save()
    }
    
    var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(currentMonth, format: Date.FormatStyle().year().month().locale(AppLocalization.locale))
                .font(.system(.title3, design: .rounded, weight: .bold))
            
            Spacer()
            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(Circle())
            }
        }
    }
    
    var weekdayHeader: some View {
        HStack {
            ForEach(weekdays, id: \.self) { day in
                Text(AppLocalization.string(day))
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    var calendarGrid: some View {
        let days = currentMonth.daysInMonth
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<days.count, id: \.self) { index in
                if let date = days[index] {
                    let log = logForDate(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    DayCell(date: date, log: log, isSelected: isSelected)
                        .onTapGesture {
                            selectedDate = date
                        }
                } else {
                    Color.clear
                        .frame(height: 50)
                }
            }
        }
    }
    
    var selectedDateSummary: some View {
        let log = logForDate(selectedDate)
        let doseRecords = historyDoseRecords(for: log)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedDate, format: Date.FormatStyle().month().day().weekday(.wide).locale(AppLocalization.locale))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Button(action: {
                    editingDateWrapper = DateWrapper(date: selectedDate)
                }) {
                    Text(AppLocalization.string("Edit"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Text(AppLocalization.string("Reminder History"))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)
            
            if doseRecords.isEmpty {
                Text(AppLocalization.string("Not Recorded"))
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 10) {
                    ForEach(doseRecords) { record in
                        let slot = ReminderSlot(
                            id: record.id,
                            hour: record.hour,
                            minute: record.minute,
                            label: record.label
                        )
                        historyDoseCard(
                            record: record,
                            color: StatsRingPalette.color(for: slot),
                            prefersLightText: StatsRingPalette.prefersLightText(for: slot)
                        )
                    }
                }
                
                Text(AppLocalization.format("%lld taken · %lld skipped · %lld pending", doseRecords.filter(\.isTaken).count,
                              doseRecords.filter(\.isSkipped).count,
                              doseRecords.filter(\.isPending).count))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            if let log = log {
                let readings = log.sortedBPReadings
                if !readings.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(.red)
                            Text(AppLocalization.string("Blood Pressure"))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.red)
                            Spacer()
                            Text(AppLocalization.format("%lld readings", readings.count))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        ForEach(Array(readings.reversed())) { reading in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(reading.timeDescription)
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(reading.valueDescription)
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundColor(reading.category.color)
                                }
                                BloodPressureCategoryBadge(category: reading.category, compact: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
            }
            
            if let log = log, let moodStr = log.mood, let mood = MoodStatus.from(string: moodStr) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        MoodFaceChip(mood: mood, isSelected: true, diameter: 36)
                        Text(AppLocalization.string("Mood: "))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(mood.color)
                        Text(AppLocalization.string(mood.rawValue))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(mood.color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(mood.color.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func historyDoseRecords(for log: MedicationLog?) -> [ReminderDoseRecord] {
        let isToday = Calendar.current.isDateInToday(selectedDate)
        
        // Prefer persisted per-reminder records (same source as Home).
        if let log, !log.doseRecords.isEmpty {
            let records = log.sortedDoseRecords
            if isToday {
                return records
            }
            // Past days: only show doses the user actually took or skipped.
            return records.filter { $0.isTaken || $0.isSkipped }
        }
        
        guard let profile else { return [] }
        profile.ensureRemindersMigrated()
        
        // Past days with no real activity → empty ("Not Recorded"), never Pending placeholders.
        if !isToday {
            guard let log else { return [] }
            if log.isTaken {
                return profile.sortedReminders.map { reminder in
                    ReminderDoseRecord(
                        id: reminder.id,
                        label: reminder.label,
                        hour: reminder.hour,
                        minute: reminder.minute,
                        status: DoseRecordStatus.taken.rawValue,
                        notes: log.notes,
                        medicineName: log.medicineName,
                        dose: log.dose,
                        mood: log.mood
                    )
                }
            }
            if log.skippedTime != nil {
                return profile.sortedReminders.enumerated().map { index, reminder in
                    let skipped = index == 0
                    return ReminderDoseRecord(
                        id: reminder.id,
                        label: reminder.label,
                        hour: reminder.hour,
                        minute: reminder.minute,
                        status: skipped ? DoseRecordStatus.skipped.rawValue : DoseRecordStatus.pending.rawValue,
                        skippedTime: skipped ? log.skippedTime : nil,
                        physicalReaction: skipped ? log.physicalReaction : nil,
                        notes: skipped ? log.notes : nil
                    )
                }.filter { $0.isTaken || $0.isSkipped }
            }
            return []
        }
        
        // Today with no day log yet — show reminder slots as pending placeholders.
        guard let log else {
            return profile.sortedReminders.map {
                ReminderDoseRecord(id: $0.id, label: $0.label, hour: $0.hour, minute: $0.minute)
            }
        }
        
        // Today: legacy day-level log without doseRecords yet.
        return profile.sortedReminders.map { reminder in
            if log.isTaken {
                return ReminderDoseRecord(
                    id: reminder.id,
                    label: reminder.label,
                    hour: reminder.hour,
                    minute: reminder.minute,
                    status: DoseRecordStatus.taken.rawValue,
                    notes: log.notes,
                    medicineName: log.medicineName,
                    dose: log.dose,
                    mood: log.mood
                )
            } else if log.skippedTime != nil {
                return ReminderDoseRecord(
                    id: reminder.id,
                    label: reminder.label,
                    hour: reminder.hour,
                    minute: reminder.minute,
                    status: DoseRecordStatus.skipped.rawValue,
                    skippedTime: log.skippedTime,
                    physicalReaction: log.physicalReaction,
                    notes: log.notes
                )
            } else {
                return ReminderDoseRecord(
                    id: reminder.id,
                    label: reminder.label,
                    hour: reminder.hour,
                    minute: reminder.minute
                )
            }
        }
    }
    
    private func historyDoseCard(record: ReminderDoseRecord, color: Color, prefersLightText: Bool) -> some View {
        let statusTitle: String
        let statusColor: Color
        let statusIcon: String
        let slot = ReminderSlot(id: record.id, hour: record.hour, minute: record.minute, label: record.label)
        let titleColor = StatsRingPalette.primaryText(for: slot)
        let secondaryColor = StatsRingPalette.secondaryText(for: slot)
        
        if record.isTaken {
            statusTitle = AppLocalization.string("Taken")
            statusColor = .green
            statusIcon = "checkmark.circle.fill"
        } else if record.isSkipped {
            statusTitle = AppLocalization.string("Skipped")
            statusColor = .red
            statusIcon = "xmark.circle.fill"
        } else {
            statusTitle = AppLocalization.string("Pending")
            statusColor = .orange
            statusIcon = "clock.fill"
        }
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(prefersLightText ? Color.white : Color(white: 0.15))
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.localizedLabel.isEmpty ? record.timeDescription : record.localizedLabel)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(titleColor)
                    Text(record.timeDescription)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(secondaryColor)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                    Text(statusTitle)
                }
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.92))
                .cornerRadius(10)
            }
            
            if let medName = record.medicineName, !medName.isEmpty {
                let names = medName.components(separatedBy: "\n")
                let doses = record.dose?.components(separatedBy: "\n") ?? []
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<names.count, id: \.self) { index in
                        HStack {
                            Text(names[index])
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundColor(secondaryColor)
                            Spacer()
                            if index < doses.count, !doses[index].isEmpty {
                                Text(doses[index])
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundColor(titleColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.35))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            
            if record.isSkipped, let skipped = record.skippedTime {
                Text(AppLocalization.format("Missed at %@", skipped.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLocalization.locale))))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(secondaryColor)
            }
            
            if let reaction = record.physicalReaction, !reaction.isEmpty {
                Text(AppLocalization.format("Reaction: %@", reaction))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(secondaryColor)
            }
            
            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(secondaryColor)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color)
        .cornerRadius(16)
        .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
    }
    
    func logForDate(_ date: Date) -> MedicationLog? {
        logs.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

struct DayCell: View {
    let date: Date
    let log: MedicationLog?
    let isSelected: Bool
    
    var body: some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let dots = doseDotColors
        
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(isSelected ? .white : (isToday ? .mint : .primary))
                .bold(isToday || isSelected)
            
            if dots.isEmpty {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<dots.count, id: \.self) { index in
                        Circle()
                            .fill(dots[index])
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.mint : (isToday ? Color.mint.opacity(0.1) : Color.clear))
        )
        .contentShape(Rectangle())
    }
    
    private var doseDotColors: [Color] {
        guard let log = log else { return [] }
        if !log.doseRecords.isEmpty {
            let hasActivity = log.doseRecords.contains { $0.isTaken || $0.isSkipped }
            // Don't treat pending-only past days as activity on the calendar.
            if !hasActivity && !Calendar.current.isDateInToday(date) {
                return []
            }
            return log.sortedDoseRecords.prefix(3).map { record in
                if record.isTaken { return .green }
                if record.isSkipped { return .red }
                return .orange.opacity(0.35)
            }
        }
        if log.isTaken { return [.green] }
        if log.skippedTime != nil { return [.red] }
        return []
    }
}

struct DailyRecordSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let profile: UserProfile
    
    @Query private var allLogs: [MedicationLog]
    
    var log: MedicationLog? {
        allLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
    }
    
    enum SlotStatus: String, CaseIterable, Identifiable {
        case pending
        case taken
        case missed
        
        var id: String { rawValue }
        
        var localizedLabel: String {
            switch self {
            case .pending: return AppLocalization.string("Pending")
            case .taken: return AppLocalization.string("Taken")
            case .missed: return AppLocalization.string("Missed")
            }
        }
    }
    
    @State private var doseDrafts: [ReminderDoseRecord] = []
    @State private var bpDrafts: [BloodPressureReading] = []
    @State private var newSystolic = ""
    @State private var newDiastolic = ""
    @State private var newBPTime = Date()
    @State private var mood: MoodStatus? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 16) {
                        Text(AppLocalization.string("Edit each reminder time for this day."))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach($doseDrafts) { $draft in
                            doseEditCard(draft: $draft)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppLocalization.string("Vitals (Optional)"))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                            
                            if bpDrafts.isEmpty {
                                Text(AppLocalization.string("No BP recorded for this day."))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(bpDrafts) { reading in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(reading.valueDescription)
                                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                    .foregroundColor(reading.category.color)
                                                Text(reading.timeDescription)
                                                    .font(.system(.caption, design: .rounded))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Button {
                                                bpDrafts.removeAll { $0.id == reading.id }
                                            } label: {
                                                Image(systemName: "trash.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(.red.opacity(0.8))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        BloodPressureCategoryBadge(category: reading.category, compact: true)
                                    }
                                    .padding(10)
                                    .background(reading.category.color.opacity(0.08))
                                    .cornerRadius(12)
                                }
                            }
                            
                            Text(AppLocalization.string("Add Reading"))
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            TextField(AppLocalization.string("Systolic (High) BP"), text: $newSystolic)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            
                            TextField(AppLocalization.string("Diastolic (Low) BP"), text: $newDiastolic)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            
                            DatePicker(
                                AppLocalization.string("Time"),
                                selection: $newBPTime,
                                displayedComponents: .hourAndMinute
                            )
                            
                            Button {
                                guard let sys = Int(newSystolic), let dia = Int(newDiastolic) else { return }
                                let calendar = Calendar.current
                                let day = calendar.startOfDay(for: date)
                                let time = calendar.dateComponents([.hour, .minute], from: newBPTime)
                                var parts = calendar.dateComponents([.year, .month, .day], from: day)
                                parts.hour = time.hour
                                parts.minute = time.minute
                                let recordedAt = calendar.date(from: parts) ?? date
                                bpDrafts.append(
                                    BloodPressureReading(recordedAt: recordedAt, systolic: sys, diastolic: dia)
                                )
                                bpDrafts.sort { $0.recordedAt < $1.recordedAt }
                                newSystolic = ""
                                newDiastolic = ""
                                newBPTime = date
                            } label: {
                                Text(AppLocalization.string("Add Reading"))
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppLocalization.string("Mood (Optional)"))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                            
                            HStack(spacing: 12) {
                                ForEach(MoodStatus.allCases, id: \.self) { m in
                                    Button {
                                        withAnimation { mood = mood == m ? nil : m }
                                    } label: {
                                        MoodFaceChip(mood: m, isSelected: mood == m)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                        
                        Button(action: saveRecord) {
                            Text(AppLocalization.string("Save Record"))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.mint)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(Text(date, format: .dateTime.month().day().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("Cancel")) { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.mint)
                }
            }
            .onAppear { loadData() }
        }
    }
    
    private func doseEditCard(draft: Binding<ReminderDoseRecord>) -> some View {
        let statusBinding = Binding<SlotStatus>(
            get: {
                switch draft.wrappedValue.doseStatus {
                case .taken: return .taken
                case .skipped: return .missed
                case .pending: return .pending
                }
            },
            set: { newValue in
                switch newValue {
                case .pending:
                    draft.wrappedValue.status = DoseRecordStatus.pending.rawValue
                    draft.wrappedValue.takenAt = nil
                    draft.wrappedValue.skippedTime = nil
                case .taken:
                    draft.wrappedValue.status = DoseRecordStatus.taken.rawValue
                    draft.wrappedValue.takenAt = draft.wrappedValue.takenAt ?? date
                    draft.wrappedValue.skippedTime = nil
                    draft.wrappedValue.physicalReaction = nil
                case .missed:
                    draft.wrappedValue.status = DoseRecordStatus.skipped.rawValue
                    draft.wrappedValue.takenAt = nil
                    draft.wrappedValue.skippedTime = draft.wrappedValue.skippedTime ?? date
                }
            }
        )
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(draft.wrappedValue.localizedDisplayTitle)
                .font(.system(.headline, design: .rounded, weight: .bold))
            
            Picker(AppLocalization.string("Status"), selection: statusBinding) {
                    ForEach(SlotStatus.allCases) { status in
                        Text(status.localizedLabel).tag(status)
                    }
                }
            .pickerStyle(.segmented)
            
            if draft.wrappedValue.isTaken {
                TextField(AppLocalization.string("Add remark (optional)"), text: Binding(
                    get: { draft.wrappedValue.notes ?? "" },
                    set: { draft.wrappedValue.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            } else if draft.wrappedValue.isSkipped {
                DatePicker(AppLocalization.string("Time"),
                    selection: Binding(
                        get: { draft.wrappedValue.skippedTime ?? date },
                        set: { draft.wrappedValue.skippedTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                
                TextField(AppLocalization.string("Physical Reaction (Optional)"), text: Binding(
                    get: { draft.wrappedValue.physicalReaction ?? "" },
                    set: { draft.wrappedValue.physicalReaction = $0.isEmpty ? nil : $0 }
                ))
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                
                TextField(AppLocalization.string("Additional Notes (Optional)"), text: Binding(
                    get: { draft.wrappedValue.notes ?? "" },
                    set: { draft.wrappedValue.notes = $0.isEmpty ? nil : $0 }
                ))
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    func loadData() {
        profile.ensureRemindersMigrated()
        newBPTime = date
        
        if let existing = log {
            existing.syncDoseRecords(with: profile)
            existing.ensureBPReadingsMigrated()
            doseDrafts = existing.sortedDoseRecords
            bpDrafts = existing.sortedBPReadings
            mood = MoodStatus.from(string: existing.mood)
        } else {
            doseDrafts = profile.sortedReminders.map { reminder in
                let meds = profile.medications(for: reminder)
                return ReminderDoseRecord(
                    id: reminder.id,
                    label: reminder.label,
                    hour: reminder.hour,
                    minute: reminder.minute,
                    medicineName: meds.map(\.name).filter { !$0.isEmpty }.joined(separator: "\n"),
                    dose: meds.map(\.dose).filter { !$0.isEmpty }.joined(separator: "\n")
                )
            }
            bpDrafts = []
            mood = nil
        }
    }
    
    func saveRecord() {
        let targetLog = log ?? MedicationLog(date: date)
        let hasVitals = !bpDrafts.isEmpty || (!newSystolic.isEmpty && !newDiastolic.isEmpty)
        let hasDoseActivity = doseDrafts.contains { !$0.isPending }
        
        if log == nil && (hasDoseActivity || hasVitals || mood != nil) {
            modelContext.insert(targetLog)
        }
        
        // Refresh medicine lists for taken slots from current profile assignment.
        var updated = doseDrafts
        for i in updated.indices {
            if let reminder = profile.sortedReminders.first(where: { $0.id == updated[i].id }) {
                let meds = profile.medications(for: reminder)
                if updated[i].isTaken || updated[i].isPending {
                    updated[i].medicineName = meds.map(\.name).filter { !$0.isEmpty }.joined(separator: "\n")
                    updated[i].dose = meds.map(\.dose).filter { !$0.isEmpty }.joined(separator: "\n")
                }
            }
        }
        
        // Include an in-progress BP form value if user typed but didn't tap Add.
        var readings = bpDrafts
        if let sys = Int(newSystolic), let dia = Int(newDiastolic) {
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: date)
            let time = calendar.dateComponents([.hour, .minute], from: newBPTime)
            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            parts.hour = time.hour
            parts.minute = time.minute
            let recordedAt = calendar.date(from: parts) ?? date
            readings.append(BloodPressureReading(recordedAt: recordedAt, systolic: sys, diastolic: dia))
        }
        
        targetLog.doseRecords = updated.sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
        targetLog.refreshAggregateFlags()
        targetLog.bpReadings = readings.sorted { $0.recordedAt < $1.recordedAt }
        targetLog.syncLegacyBPFields()
        targetLog.mood = mood?.rawValue
        
        try? modelContext.save()
        dismiss()
    }
}

// Calendar Date Helper
extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }
    
    var daysInMonth: [Date?] {
        let calendar = Calendar.current
        let start = startOfMonth
        let daysCount = calendar.range(of: .day, in: .month, for: start)!.count
        let firstWeekday = calendar.component(.weekday, from: start)
        
        var result: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for i in 0..<daysCount {
            result.append(calendar.date(byAdding: .day, value: i, to: start))
        }
        
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }
}
