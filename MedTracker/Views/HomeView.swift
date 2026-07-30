import SwiftUI
import SwiftData

struct HomeView: View {
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
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
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
                        .foregroundColor(.mint)
                        .background(Circle().fill(Color.mint.opacity(0.2)))
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
                    let takenCount = logs.prefix(30).filter { $0.isTaken }.count
                    Text("\(takenCount)/30")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Text("Last 30 Days")
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
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Medication")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if profile.medications.isEmpty {
                        Text("Your Medication")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(profile.medications) { med in
                                if !med.name.isEmpty {
                                    Text("\(med.name)\(med.dose.isEmpty ? "" : " - \(med.dose)")")
                                        .font(.system(.title3, design: .rounded, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("Scheduled for \(profile.targetTimeDescription)")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.mint)
                }
                Spacer()
                
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Medicine:")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                            Text(medName)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    if let dose = log.dose, !dose.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dose:")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                            Text(dose)
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
                            log.notes = nil
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
