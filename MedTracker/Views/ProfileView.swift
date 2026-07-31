import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    
        var body: some View {
            NavigationView {
                ZStack {
                    AppBackground()
                    
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
    @Query(sort: \MedicationLog.date, order: .reverse) private var logs: [MedicationLog]
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showSaveButton = true
    
    var body: some View {
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
                            .foregroundStyle(.white, Color.mint)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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
                
                Picker(LocalizedStringKey("Age Range"), selection: $profile.ageRange) {
                    Text(LocalizedStringKey("Select age range"))
                        .tag("")
                    ForEach(AgeRange.allCases) { range in
                        Text(LocalizedStringKey(range.rawValue))
                            .tag(range.rawValue)
                    }
                }
            }
            
            Section(header: Text("Medications")) {
                NavigationLink(destination: MedicationsSettingsView(profile: profile)) {
                    HStack {
                        Image(systemName: "pills.fill")
                            .foregroundColor(.mint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Manage Medications"))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Text(medicationsSummary)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section(header: Text(LocalizedStringKey("Reminder Times"))) {
                NavigationLink(destination: RemindersSettingsView(profile: profile)) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.mint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Manage Reminders"))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Text(profile.targetTimeDescription)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
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
            
            Section(header: Text(LocalizedStringKey("My Data"))) {
                HStack {
                    Text(LocalizedStringKey("Age Range"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(profile.ageRange.isEmpty
                         ? String(localized: "Not selected")
                         : String(localized: String.LocalizationValue(profile.ageRange)))
                        .fontWeight(.semibold)
                }
                
                Button(action: exportUserData) {
                    Label(LocalizedStringKey("Export Data"), systemImage: "square.and.arrow.up")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                        .background(Color.mint)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            
            Section(header: Text(LocalizedStringKey("About"))) {
                NavigationLink(destination: AboutUsView()) {
                    Label(LocalizedStringKey("About Us"), systemImage: "info.circle")
                }
                NavigationLink(destination: TermsView()) {
                    Label(LocalizedStringKey("Terms & Conditions"), systemImage: "doc.text")
                }
            }
            
            if showSaveButton {
                Section {
                    Button(action: {
                        updateNotificationIfNeeded()
                        try? profile.modelContext?.save()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSaveButton = false
                        }
                    }) {
                        Text("Save Settings")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 14)
                            .background(Color.mint)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
        }
        .font(.system(.body, design: .rounded))
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationBarHidden(true)
        .onAppear {
            profile.ensureRemindersMigrated()
        }
        .onChange(of: profile.name) { _, _ in revealSaveButton() }
        .onChange(of: profile.ageRange) { _, _ in revealSaveButton() }
        .onChange(of: profile.medications) { _, _ in revealSaveButton() }
        .onChange(of: profile.reminders) { _, _ in revealSaveButton() }
        .onChange(of: profile.profileImageData) { _, _ in revealSaveButton() }
        .onChange(of: appLanguage) { _, _ in revealSaveButton() }
        .onChange(of: isNotificationEnabled) { _, _ in revealSaveButton() }
    }
    
    private func revealSaveButton() {
        guard !showSaveButton else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            showSaveButton = true
        }
    }
    
    private var medicationsSummary: String {
        let names = profile.medications.map(\.name).filter { !$0.isEmpty }
        if names.isEmpty {
            return String(localized: "No medications added.")
        }
        if names.count == 1 {
            return names[0]
        }
        return String(format: String(localized: "%lld medications"), names.count)
    }
    
    private func exportUserData() {
        guard let url = MedTrackerExportDocument.makePDF(profile: profile, logs: logs) else {
            print("Export failed: could not create PDF")
            return
        }
        
        // Present the system share sheet directly (avoids a blank SwiftUI sheet).
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene.windows.first?.rootViewController else {
            return
        }
        
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        presenter.present(activityVC, animated: true)
    }
    
    private func updateNotificationIfNeeded() {
        if isNotificationEnabled {
            scheduleCurrentNotification()
        }
    }
    
    private func scheduleCurrentNotification() {
        profile.ensureRemindersMigrated()
        NotificationManager.shared.scheduleReminders(profile.sortedReminders) { reminder in
            profile.medications(for: reminder)
        }
    }
}
