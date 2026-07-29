import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    
    var body: some View {
        NavigationView {
            if let profile = profiles.first {
                ProfileForm(profile: profile)
            } else {
                Text("Loading profile...")
            }
        }
    }
}

struct ProfileForm: View {
    @Bindable var profile: UserProfile
    
    var body: some View {
        Form {
            Section(header: Text("Personal Info")) {
                TextField("Name", text: $profile.name)
            }
            
            Section(header: Text("Medication Details")) {
                TextField("Medication Name", text: $profile.medicationName)
                
                Picker("Target Hour", selection: $profile.targetTimeHour) {
                    ForEach(0..<24) { hour in
                        Text("\(hour):00").tag(hour)
                    }
                }
                
                Picker("Target Minute", selection: $profile.targetTimeMinute) {
                    ForEach(0..<60) { minute in
                        if minute % 5 == 0 {
                            Text("\(minute) min").tag(minute)
                        }
                    }
                }
            }
            
            Section {
                Button(action: {
                    // In a real app, this would schedule local notifications
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Enable Daily Reminders")
                    }
                }
            }
        }
        .navigationTitle("Profile")
    }
}
