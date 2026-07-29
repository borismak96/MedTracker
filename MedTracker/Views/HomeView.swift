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
            ScrollView {
                VStack(spacing: 24) {
                    if let profile = profile {
                        headerSection(profile: profile)
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
                        statsSection
                    } else {
                        Text("Loading...")
                    }
                }
                .padding()
            }
            .navigationTitle("MedTracker")
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
        HStack {
            VStack(alignment: .leading) {
                if profile.name.isEmpty {
                    Text("Hello!")
                        .font(.title2)
                        .bold()
                } else {
                    Text("Hello, \(profile.name)!")
                        .font(.title2)
                        .bold()
                }
                Text("Let's stay on track today.")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    var statsSection: some View {
        HStack {
            VStack {
                Text("\(streakCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                Text("Day Streak")
                    .font(.subheadline)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(16)
            
            VStack {
                let takenCount = logs.prefix(30).filter { $0.isTaken }.count
                Text("\(takenCount)/30")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                Text("Last 30 Days")
                    .font(.subheadline)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(16)
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
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Medication")
                        .font(.headline)
                    if profile.medicationName.isEmpty {
                        Text("Your Medication")
                            .font(.title)
                            .bold()
                            .foregroundColor(.blue)
                    } else {
                        Text(profile.medicationName)
                            .font(.title)
                            .bold()
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                        Text("Scheduled for \(profile.targetTimeDescription)")
                    }
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                }
                Spacer()
                Image(systemName: "pills.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue.opacity(0.8))
            }
            
            if log.isTaken {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Taken Today")
                            .bold()
                    }
                    
                    if let medName = log.medicineName, !medName.isEmpty {
                        Text("Medicine: \(medName)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    if let dose = log.dose, !dose.isEmpty {
                        Text("Dose: \(dose)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                Button(action: {
                    log.isTaken = false
                    log.medicineName = nil
                    log.dose = nil
                }) {
                    Text("Undo")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else if log.skippedTime != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Skipped Today")
                            .bold()
                    }
                    
                    if let reaction = log.physicalReaction, !reaction.isEmpty {
                        Text("Reaction: \(reaction)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                
                Button(action: {
                    log.skippedTime = nil
                    log.physicalReaction = nil
                    log.notes = nil
                }) {
                    Text("Undo")
                        .font(.footnote)
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
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showingSkipSheet = true
                    }) {
                        Text("Skip / Missed")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}
