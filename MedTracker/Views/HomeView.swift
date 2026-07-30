import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \MedicationLog.date, order: .reverse) private var logs: [MedicationLog]
    
    @State private var showingSkipSheet = false
    @State private var skipNotes = ""
    @State private var skipReaction = ""
    @State private var skippedTime = Date()
    
    @State private var showingTakeSheet = false
    @State private var takeMedicineName = ""
    @State private var takeDose = ""
    
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
                                    skipNotes: $skipNotes,
                                    showingTakeSheet: $showingTakeSheet,
                                    takeMedicineName: $takeMedicineName,
                                    takeDose: $takeDose
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
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSkipSheet) {
                if let log = todayLog {
                    skipSheetContent(for: log)
                }
            }
            .sheet(isPresented: $showingTakeSheet) {
                if let log = todayLog {
                    takeSheetContent(for: log)
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
                    // Profile or Settings Action
                }) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.mint)
                        .padding(12)
                        .background(Circle().fill(Color.white))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            }
            
            // Greeting and Avatar
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.mint)
                    .background(Circle().fill(Color.mint.opacity(0.2)))
                
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
    
    func takeSheetContent(for log: MedicationLog) -> some View {
        NavigationView {
            Form {
                Section(header: Text("Medication Details")) {
                    TextField("Medication Name", text: $takeMedicineName)
                    
                    TextField("Dose (e.g., 1 pill)", text: $takeDose)
                }
                
                Button(action: {
                    log.isTaken = true
                    log.medicineName = takeMedicineName.isEmpty ? nil : takeMedicineName
                    log.dose = takeDose.isEmpty ? nil : takeDose
                    
                    // Clear skip details if they existed
                    log.skippedTime = nil
                    log.physicalReaction = nil
                    log.notes = nil
                    
                    showingTakeSheet = false
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .bold()
                }
            }
            .navigationTitle("Take Medication")
            .navigationBarItems(trailing: Button("Cancel") {
                showingTakeSheet = false
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
    
    @Binding var showingTakeSheet: Bool
    @Binding var takeMedicineName: String
    @Binding var takeDose: String
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Medication")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if profile.medicationName.isEmpty {
                        Text("Your Medication")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                    } else {
                        Text(profile.medicationName)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
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
                    }
                    
                    if let medName = log.medicineName, !medName.isEmpty {
                        Text("Medicine: \(medName)")
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
                .cornerRadius(16)
                
                Button(action: {
                    log.isTaken = false
                    log.medicineName = nil
                    log.dose = nil
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
                }) {
                    Text("Undo")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 16) {
                    Button(action: {
                        takeMedicineName = profile.medicationName
                        takeDose = ""
                        showingTakeSheet = true
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
