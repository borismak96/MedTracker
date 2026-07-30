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
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Text("History")
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
        }
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
            
            Text(currentMonth, format: .dateTime.year().month())
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
                Text(LocalizedStringKey(day))
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedDate, format: .dateTime.month().day().weekday(.wide))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Button(action: {
                    editingDateWrapper = DateWrapper(date: selectedDate)
                }) {
                    Text("Edit")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            let log = logForDate(selectedDate)
            if let log = log {
                if log.isTaken {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Taken")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                        }
                        if let med = log.medicineName, !med.isEmpty {
                            Text("Medicine: \(med)")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        if let dose = log.dose, !dose.isEmpty {
                            Text("Dose: \(dose)")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else if log.skippedTime != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Missed at \(log.skippedTime ?? selectedDate, format: .dateTime.hour().minute())")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                        }
                        if let reaction = log.physicalReaction, !reaction.isEmpty {
                            Text("Reaction: \(reaction)")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        if let notes = log.notes, !notes.isEmpty {
                            Text("Notes: \(notes)")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Text("Not Recorded")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
            } else {
                Text("Not Recorded")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
            
            if let log = log, let sys = log.systolic, let dia = log.diastolic {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.red)
                        Text("Blood Pressure: \(sys) / \(dia) mmHg")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
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
        
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(isSelected ? .white : (isToday ? .mint : .primary))
                .bold(isToday || isSelected)
            
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.mint : (isToday ? Color.mint.opacity(0.1) : Color.clear))
        )
        .contentShape(Rectangle())
    }
    
    var statusColor: Color {
        guard let log = log else { return .clear }
        if log.isTaken { return .green }
        if log.skippedTime != nil { return .red }
        return .clear
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
    
    enum RecordStatus { case none, taken, missed }
    @State private var status: RecordStatus = .none
    
    @State private var medicineName = ""
    @State private var dose = ""
    
    @State private var skippedTime = Date()
    @State private var skipReaction = ""
    @State private var skipNotes = ""
    
    @State private var systolic = ""
    @State private var diastolic = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Status")) {
                    Picker("Status", selection: $status) {
                        Text("Not Recorded").tag(RecordStatus.none)
                        Text("Taken").tag(RecordStatus.taken)
                        Text("Missed").tag(RecordStatus.missed)
                    }
                    .pickerStyle(.segmented)
                }
                
                if status == .taken {
                    Section(header: Text("Medication Details")) {
                        TextField("Medication Name", text: $medicineName)
                        TextField("Dose (e.g., 1 pill)", text: $dose)
                    }
                } else if status == .missed {
                    Section(header: Text("Missed Details")) {
                        DatePicker("Time", selection: $skippedTime, displayedComponents: .hourAndMinute)
                        TextField("Physical Reaction (Optional)", text: $skipReaction)
                        TextField("Additional Notes (Optional)", text: $skipNotes)
                    }
                }
                
                Section(header: Text("Vitals (Optional)")) {
                    TextField("Systolic (High) BP", text: $systolic)
                        .keyboardType(.numberPad)
                    TextField("Diastolic (Low) BP", text: $diastolic)
                        .keyboardType(.numberPad)
                }
                
                Button(action: saveRecord) {
                    Text("Save Record")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .bold()
                }
            }
            .navigationTitle(Text(date, format: .dateTime.month().day().year()))
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .onAppear {
                loadData()
            }
        }
    }
    
    func loadData() {
        if let log = log {
            if log.isTaken {
                status = .taken
                medicineName = log.medicineName ?? profile.medicationName
                dose = log.dose ?? ""
            } else if log.skippedTime != nil {
                status = .missed
                skippedTime = log.skippedTime ?? date
                skipReaction = log.physicalReaction ?? ""
                skipNotes = log.notes ?? ""
            } else {
                status = .none
            }
            systolic = log.systolic.map { "\($0)" } ?? ""
            diastolic = log.diastolic.map { "\($0)" } ?? ""
        } else {
            status = .none
            medicineName = profile.medicationName
            systolic = ""
            diastolic = ""
        }
    }
    
    func saveRecord() {
        let targetLog = log ?? MedicationLog(date: date)
        let hasVitals = !systolic.isEmpty && !diastolic.isEmpty
        
        if log == nil && (status != .none || hasVitals) {
            modelContext.insert(targetLog)
        }
        
        switch status {
        case .none:
            targetLog.isTaken = false
            targetLog.skippedTime = nil
            targetLog.medicineName = nil
            targetLog.dose = nil
            targetLog.physicalReaction = nil
            targetLog.notes = nil
        case .taken:
            targetLog.isTaken = true
            targetLog.skippedTime = nil
            targetLog.medicineName = medicineName.isEmpty ? nil : medicineName
            targetLog.dose = dose.isEmpty ? nil : dose
            targetLog.physicalReaction = nil
            targetLog.notes = nil
        case .missed:
            targetLog.isTaken = false
            targetLog.skippedTime = skippedTime
            targetLog.medicineName = nil
            targetLog.dose = nil
            targetLog.physicalReaction = skipReaction.isEmpty ? nil : skipReaction
            targetLog.notes = skipNotes.isEmpty ? nil : skipNotes
        }
        
        targetLog.systolic = Int(systolic)
        targetLog.diastolic = Int(diastolic)
        
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
