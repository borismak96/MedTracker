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
    
    @State private var showingBPSheet = false
    @State private var bpSystolic = ""
    @State private var bpDiastolic = ""
    
    @State private var showingBPChart = false
    @State private var showingMedicalCard = false
    
    var profile: UserProfile? { profiles.first }
    
    var todayLog: MedicationLog? {
        let today = Calendar.current.startOfDay(for: Date())
        return logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
    }
    
    var streakCount: Int {
        var streak = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for i in 0..<31 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today),
               let log = logs.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                if log.isTaken {
                    streak += 1
                } else if i > 0 {
                    break
                }
            }
        }
        return streak
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
                            
                            statsSection
                            
                            if let log = todayLog {
                                TodayCard(
                                    log: log,
                                    profile: profile,
                                    showingSkipSheet: $showingSkipSheet,
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
    
    var statsSection: some View {
        HStack(spacing: 16) {
            let streakColor = Color(red: 255/255, green: 193/255, blue: 36/255) // #FFC124
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(streakColor)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(Circle())
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(streakCount)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Text("Day Streak")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(streakColor)
            .cornerRadius(24)
            .shadow(color: streakColor.opacity(0.3), radius: 10, x: 0, y: 4)
            
            let last30Color = Color(red: 56/255, green: 240/255, blue: 151/255) // #38F097
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(last30Color)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(Circle())
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    let calendar = Calendar.current
                    let today = Date()
                    let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
                    let takenThisMonthCount = logs.filter { 
                        calendar.isDate($0.date, equalTo: today, toGranularity: .month) && $0.isTaken 
                    }.count
                    
                    Text("\(takenThisMonthCount)/\(daysInMonth)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Text("This Month")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(last30Color)
            .cornerRadius(24)
            .shadow(color: last30Color.opacity(0.3), radius: 10, x: 0, y: 4)
        }
    }
    
    func skipSheetContent(for log: MedicationLog) -> some View {
        NavigationView {
            Form {
                Section(header: Text("Missed Details")) {
                    DatePicker("Time", selection: $skippedTime, displayedComponents: .hourAndMinute)
                    
                    TextField("Physical Reaction (Optional)", text: $skipReaction)
                    
                    TextField("Additional Notes (Optional)", text: $skipNotes)
                }
                
                Button(action: {
                    log.skippedTime = skippedTime
                    log.physicalReaction = skipReaction
                    log.notes = skipNotes
                    showingSkipSheet = false
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .bold()
                }
            }
            .navigationTitle("Missed Medication")
            .navigationBarItems(trailing: Button("Cancel") {
                showingSkipSheet = false
            })
        }
    }
    
    func bpSheetContent(for log: MedicationLog) -> some View {
        NavigationView {
            Form {
                Section(header: Text("Blood Pressure (mmHg)")) {
                    TextField("Systolic (High)", text: $bpSystolic)
                        .keyboardType(.numberPad)
                    
                    TextField("Diastolic (Low)", text: $bpDiastolic)
                        .keyboardType(.numberPad)
                }
                
                Button(action: {
                    if let sys = Int(bpSystolic), let dia = Int(bpDiastolic) {
                        log.systolic = sys
                        log.diastolic = dia
                    }
                    showingBPSheet = false
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .bold()
                }
            }
            .navigationTitle("Log Blood Pressure")
            .navigationBarItems(trailing: Button("Cancel") {
                showingBPSheet = false
            })
        }
    }
}

struct TodayCard: View {
    @Bindable var log: MedicationLog
    var profile: UserProfile
    @Binding var showingSkipSheet: Bool
    @Binding var skippedTime: Date
    @Binding var skipReaction: String
    @Binding var skipNotes: String
    
    @State private var selectedMood: MoodStatus? = nil
    @State private var remarkText: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Medication")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if profile.medications.isEmpty {
                        Text("Your Medication")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                    } else {
                        let namedMeds = profile.medications.filter { !$0.name.isEmpty }
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(namedMeds) { med in
                                    Text("\(med.name)\(med.dose.isEmpty ? "" : " - \(med.dose)")")
                                        .font(.system(.title3, design: .rounded, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(height: min(CGFloat(max(namedMeds.count, 1)) * 28, 96))
                    }
                    
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("Scheduled for \(profile.targetTimeDescription)")
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
            
            if log.isTaken {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        Text("Taken Today")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        
                        if let moodStr = log.mood, let mood = MoodStatus.from(string: moodStr) {
                            Spacer()
                            ZStack {
                                Circle().fill(mood.color.opacity(0.2)).frame(width: 40, height: 40)
                                Image(systemName: mood.icon)
                                    .foregroundColor(mood.color)
                                    .font(.system(size: 20))
                            }
                        }
                    }
                    
                    if let medName = log.medicineName, !medName.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Medications:")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                            
                            let names = medName.components(separatedBy: "\n")
                            let doses = log.dose?.components(separatedBy: "\n") ?? []
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(0..<names.count, id: \.self) { index in
                                        HStack {
                                            Text(names[index])
                                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            if index < doses.count, !doses[index].isEmpty {
                                                Text(doses[index])
                                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                    .foregroundColor(.primary.opacity(0.8))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.mint.opacity(0.2))
                                                    .cornerRadius(6)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(height: min(CGFloat(max(names.count, 1)) * 30, 90))
                        }
                    }
                    
                    if let notes = log.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Remark:")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                            Text(notes)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(16)
                
                Button(action: {
                    log.isTaken = false
                    log.medicineName = nil
                    log.dose = nil
                    log.mood = nil
                    log.notes = nil
                    remarkText = ""
                }) {
                    Text("Undo")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                }
            } else if log.skippedTime != nil {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        Text("Skipped Today")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                    
                    if let reaction = log.physicalReaction, !reaction.isEmpty {
                        Text("Reaction: \(reaction)")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(16)
                
                Button(action: {
                    log.skippedTime = nil
                    log.physicalReaction = nil
                    log.notes = nil
                    log.mood = nil
                }) {
                    Text("Undo")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How are you feeling today?")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 15) {
                        ForEach(MoodStatus.allCases, id: \.self) { mood in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMood = mood
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedMood == mood ? mood.color.opacity(0.2) : Color(UIColor.systemGray6))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: mood.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedMood == mood ? mood.color : .gray)
                                }
                                .scaleEffect(selectedMood == mood ? 1.1 : 1.0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    TextField(LocalizedStringKey("Add remark (optional)"), text: $remarkText)
                        .font(.system(.body, design: .rounded))
                        .padding(12)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.vertical, 8)
                
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation {
                            log.isTaken = true
                            
                            let medNames = profile.medications.map { $0.name }.filter { !$0.isEmpty }
                            let medDoses = profile.medications.map { $0.dose }.filter { !$0.isEmpty }
                            
                            log.medicineName = medNames.isEmpty ? nil : medNames.joined(separator: "\n")
                            log.dose = medDoses.isEmpty ? nil : medDoses.joined(separator: "\n")
                            log.mood = selectedMood?.rawValue
                            
                            log.skippedTime = nil
                            log.physicalReaction = nil
                            log.notes = remarkText.isEmpty ? nil : remarkText
                        }
                    }) {
                        Text("Take Now")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.mint)
                            .cornerRadius(20)
                            .shadow(color: Color.mint.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        showingSkipSheet = true
                    }) {
                        Text("Skip / Missed")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(20)
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
