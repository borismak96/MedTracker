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
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
    
    var body: some View {
        Form {
            Section(header: Text("Personal Info")) {
                TextField("Name", text: $profile.name)
            }
            
            Section(header: Text("Medication Details")) {
                TextField("Medication Name", text: $profile.medicationName)
                    .onChange(of: profile.medicationName) { _, _ in updateNotificationIfNeeded() }
                
                Picker("Target Hour", selection: $profile.targetTimeHour) {
                    ForEach(0..<24) { hour in
                        Text("\(hour):00").tag(hour)
                    }
                }
                .onChange(of: profile.targetTimeHour) { _, _ in updateNotificationIfNeeded() }
                
                Picker("Target Minute", selection: $profile.targetTimeMinute) {
                    ForEach(0..<60) { minute in
                        if minute % 5 == 0 {
                            Text("\(minute) min").tag(minute)
                        }
                    }
                }
                .onChange(of: profile.targetTimeMinute) { _, _ in updateNotificationIfNeeded() }
            }
            
            Section(header: Text("App Settings")) {
                Picker("Language", selection: $appLanguage) {
                    Text("System").tag("system")
                    Text("English").tag("en")
                    Text("繁體中文").tag("zh-Hant")
                }
            }
            
            Section(header: Text("Reminders")) {
                Toggle(isOn: $isNotificationEnabled) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Enable Daily Reminders")
                    }
                }
                .onChange(of: isNotificationEnabled) { _, newValue in
                    if newValue {
                        NotificationManager.shared.requestPermission { granted in
                            if granted {
                                scheduleCurrentNotification()
                            } else {
                                isNotificationEnabled = false
                            }
                        }
                    } else {
                        NotificationManager.shared.cancelNotifications()
                    }
                }
            }
        }
        .navigationTitle("Profile")
    }
    
    private func updateNotificationIfNeeded() {
        if isNotificationEnabled {
            scheduleCurrentNotification()
        }
    }
    
    private func scheduleCurrentNotification() {
        let medName = profile.medicationName.isEmpty ? String(localized: "your medication") : profile.medicationName
        
        let title = String(localized: "Medication Reminder")
        // Using String format manually or localized string interpolation
        let body = String(format: String(localized: "It's time to take %@"), medName)
        
        NotificationManager.shared.scheduleNotification(
            hour: profile.targetTimeHour,
            minute: profile.targetTimeMinute,
            title: title,
            body: body
        )
    }
}
