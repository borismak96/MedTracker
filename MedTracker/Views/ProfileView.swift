import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    
        var body: some View {
            NavigationView {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text("Profile")
                                .font(.system(.title, design: .rounded, weight: .heavy))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        
                        if let profile = profiles.first {
                            ProfileForm(profile: profile)
                        } else {
                            ProgressView()
                                .frame(maxHeight: .infinity)
                        }
                    }
                }
                .navigationBarHidden(true)
            }
        }
}

struct ProfileForm: View {
    @Bindable var profile: UserProfile
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    var body: some View {
        let timeBinding = Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = profile.targetTimeHour
                components.minute = profile.targetTimeMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                profile.targetTimeHour = components.hour ?? 10
                profile.targetTimeMinute = components.minute ?? 0
                updateNotificationIfNeeded()
            }
        )
        
        Form {
            Section {
                VStack(spacing: 16) {
                    if let data = profile.profileImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.mint)
                            .background(Circle().fill(Color.mint.opacity(0.2)))
                    }
                    
                    HStack(spacing: 20) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            Text(profile.profileImageData == nil ? "Add Photo" : "Change Photo")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.mint)
                                .cornerRadius(12)
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    profile.profileImageData = data
                                }
                            }
                        }
                        
                        if profile.profileImageData != nil {
                            Button(action: {
                                withAnimation {
                                    profile.profileImageData = nil
                                }
                            }) {
                                Text("Remove")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .listRowBackground(Color.clear)
            
            Section(header: Text("Personal Info")) {
                TextField("Name", text: $profile.name)
            }
            
            Section(header: Text("Medications")) {
                List {
                    ForEach($profile.medications) { $med in
                        HStack(spacing: 12) {
                            TextField("Medication Name", text: $med.name)
                            
                            Divider()
                                .frame(height: 20)
                            
                            TextField("Dose (e.g., 1 pill)", text: $med.dose)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indices in
                        profile.medications.remove(atOffsets: indices)
                    }
                    
                    Button(action: {
                        withAnimation {
                            profile.medications.append(MedicationItem())
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Medication")
                        }
                        .foregroundColor(.mint)
                    }
                }
            }
            .onChange(of: profile.medications) { _, _ in updateNotificationIfNeeded() }
            
            Section(header: Text("Reminder Time")) {
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
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
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.mint)
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
            
            Section {
                Button(action: {
                    updateNotificationIfNeeded()
                    // Manually trigger a save to ensure SwiftData persists immediately,
                    // although it usually auto-saves on changes.
                    try? profile.modelContext?.save()
                }) {
                    Text("Save Settings")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
                .listRowBackground(Color.mint)
            }
        }
        .font(.system(.body, design: .rounded))
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarHidden(true)
    }
    
    private func updateNotificationIfNeeded() {
        if isNotificationEnabled {
            scheduleCurrentNotification()
        }
    }
    
    private func scheduleCurrentNotification() {
        let medNames = profile.medications.map { $0.name }.filter { !$0.isEmpty }
        let medName = medNames.isEmpty ? String(localized: "your medication") : medNames.joined(separator: ", ")
        
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
