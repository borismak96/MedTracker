import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @AppStorage(ActiveProfileStore.idKey, store: AppLocalization.sharedDefaults) private var activeProfileID = ""
    
        var body: some View {
            NavigationView {
                ZStack {
                    AppBackground()
                    
                    VStack(spacing: 0) {
                        let _ = activeProfileID
                        HStack {
                            Text(AppLocalization.string("Profile"))
                                .font(.system(.title, design: .rounded, weight: .heavy))
                                .foregroundColor(.primary)
                            Spacer()
                            if let active = ActiveProfileStore.resolve(from: profiles), profiles.count > 1 {
                                ProfileSwitcher(profiles: profiles, active: active, compact: true)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        
                        if let profile = ActiveProfileStore.resolve(from: profiles) {
                            ProfileForm(profile: profile, allProfiles: profiles)
                                .id(profile.id)
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
    var allProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MedicationLog.date, order: .reverse) private var allLogs: [MedicationLog]
    @AppStorage("appLanguage", store: AppLocalization.sharedDefaults) private var appLanguage = "system"
    @AppStorage("isNotificationEnabled", store: AppLocalization.sharedDefaults) private var isNotificationEnabled = false
    @AppStorage("isNotificationSoundEnabled", store: AppLocalization.sharedDefaults) private var isNotificationSoundEnabled = true
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showSaveButton = true
    @State private var showingAddPerson = false
    @State private var newPersonName = ""
    @State private var profilePendingDelete: UserProfile?
    @State private var showExportConfirm = false
    @State private var showingMedicalCard = false
    @AppStorage(ElderMode.enabledKey, store: AppLocalization.sharedDefaults) private var elderMode = false
    
    private var logs: [MedicationLog] {
        HouseholdData.logs(for: profile, in: allLogs)
    }
    
    var body: some View {
        Form {
            Section {
                householdSection
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            
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
                                Text(AppLocalization.string("Remove"))
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
            
            Section(header: Text(AppLocalization.string("Personal Info"))) {
                TextField(AppLocalization.string("Name"), text: $profile.name)
                
                Picker(AppLocalization.string("Age Range"), selection: $profile.ageRange) {
                    Text(AppLocalization.string("Select age range"))
                        .tag("")
                    ForEach(AgeRange.allCases) { range in
                        Text(range.localizedName)
                            .tag(range.rawValue)
                    }
                }
            }
            
            Section(header: Text(AppLocalization.string("Medical Card"))) {
                TextField(AppLocalization.string("Allergies (e.g. penicillin)"), text: $profile.allergies, axis: .vertical)
                    .lineLimit(2...4)
                TextField(AppLocalization.string("ICE Name"), text: $profile.emergencyContactName)
                TextField(AppLocalization.string("Relationship"), text: $profile.emergencyContactRelation)
                TextField(AppLocalization.string("ICE Phone"), text: $profile.emergencyContactPhone)
                    .keyboardType(.phonePad)
                Text(AppLocalization.string("Not an official medical ID"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                
                Button {
                    showingMedicalCard = true
                } label: {
                    Label(AppLocalization.string("View Medical Card"), systemImage: "person.text.rectangle.fill")
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
            
            Section(header: Text(AppLocalization.string("Medications"))) {
                NavigationLink(destination: MedicationsSettingsView(profile: profile)) {
                    HStack {
                        Image(systemName: "pills.fill")
                            .foregroundColor(.mint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppLocalization.string("Manage Medications"))
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
            
            Section(header: Text(AppLocalization.string("Reminder Times"))) {
                NavigationLink(destination: RemindersSettingsView(profile: profile)) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.mint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppLocalization.string("Manage Reminders"))
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
            
            Section(header: Text(AppLocalization.string("App Settings"))) {
                Picker(AppLocalization.string("Language"), selection: $appLanguage) {
                    Text(AppLocalization.string("System")).tag("system")
                    Text(AppLocalization.string("English")).tag("en")
                    Text("繁體中文").tag("zh-Hant")
                }
                
                Toggle(isOn: $elderMode) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLocalization.string("樂齡 Mode"))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        Text(AppLocalization.string("Larger text and high-contrast buttons for easier tapping."))
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.mint)
            }
            
            Section(header: Text(AppLocalization.string("Reminders"))) {
                Toggle(isOn: $isNotificationEnabled) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.mint)
                        Text(AppLocalization.string("Enable Daily Reminders"))
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
                
                Text(AppLocalization.string("Reminders include Taken and Snooze actions."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                
                if isNotificationEnabled {
                    Toggle(isOn: $isNotificationSoundEnabled) {
                        HStack {
                            Image(systemName: isNotificationSoundEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                                .foregroundColor(isNotificationSoundEnabled ? .mint : .secondary)
                                .frame(width: 24)
                            Text(AppLocalization.string("Notification Sound"))
                        }
                    }
                    .onChange(of: isNotificationSoundEnabled) { _, _ in
                        scheduleCurrentNotification()
                    }
                }
            }
            
            Section(header: Text(AppLocalization.string("My Data"))) {
                HStack {
                    Text(AppLocalization.string("Age Range"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(localizedAgeRangeLabel)
                        .fontWeight(.semibold)
                }
                
                NavigationLink(destination: VisitPackView(profile: profile, logs: logs)) {
                    Label(AppLocalization.string("Clinic Visit Pack"), systemImage: "doc.text.fill")
                }
                
                Button(action: { showExportConfirm = true }) {
                    Label(AppLocalization.string("Export Data"), systemImage: "square.and.arrow.up")
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
            
            Section(header: Text(AppLocalization.string("About"))) {
                NavigationLink(destination: SetupGuideView()) {
                    Label(AppLocalization.string("How to Set Up"), systemImage: "lightbulb.fill")
                }
                NavigationLink(destination: AboutUsView()) {
                    Label(AppLocalization.string("About Us"), systemImage: "info.circle")
                }
                NavigationLink(destination: TermsView()) {
                    Label(AppLocalization.string("Terms & Conditions"), systemImage: "doc.text")
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
                        Text(AppLocalization.string("Save Settings"))
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
        .onChange(of: profile.allergies) { _, _ in revealSaveButton() }
        .onChange(of: profile.emergencyContactName) { _, _ in revealSaveButton() }
        .onChange(of: profile.emergencyContactPhone) { _, _ in revealSaveButton() }
        .onChange(of: profile.emergencyContactRelation) { _, _ in revealSaveButton() }
        .onChange(of: appLanguage) { _, _ in revealSaveButton() }
        .onChange(of: isNotificationEnabled) { _, _ in revealSaveButton() }
        .sheet(isPresented: $showingMedicalCard) {
            ZStack {
                Color.black.opacity(0.25).ignoresSafeArea()
                MedicalCardView(profile: profile, isShowing: $showingMedicalCard)
            }
            .background(Color.clear)
        }
        .alert(
            AppLocalization.format("Delete \"%@\"?", profilePendingDelete?.displayName ?? ""),
            isPresented: Binding(
                get: { profilePendingDelete != nil },
                set: { if !$0 { profilePendingDelete = nil } }
            )
        ) {
            Button(AppLocalization.string("Cancel"), role: .cancel) {
                profilePendingDelete = nil
            }
            Button(AppLocalization.string("Delete Profile"), role: .destructive) {
                if let pending = profilePendingDelete {
                    HouseholdData.deleteProfile(pending, logs: allLogs, remaining: allProfiles, context: modelContext)
                    NotificationManager.shared.rescheduleFromStore()
                }
                profilePendingDelete = nil
            }
        } message: {
            Text(AppLocalization.string("All data for this person will be removed from this device."))
        }
        .alert(
            AppLocalization.string("Export Data"),
            isPresented: $showExportConfirm
        ) {
            Button(AppLocalization.string("Cancel"), role: .cancel) { }
            Button(AppLocalization.string("Export Data")) {
                exportUserData()
            }
        } message: {
            Text(AppLocalization.string("This export includes your health records. Only share it with people you trust."))
        }
        .sheet(isPresented: $showingAddPerson) {
            addPersonSheet
        }
    }
    
    private var householdSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("Household"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(AppLocalization.string("Profiles stay on this iPhone. No account needed."))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(allProfiles.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { member in
                        Button {
                            ActiveProfileStore.select(member)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    householdAvatar(member)
                                    if member.id == profile.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.mint)
                                            .background(Circle().fill(Color.white))
                                            .offset(x: 4, y: -4)
                                    }
                                }
                                Text(member.displayName)
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if allProfiles.count > 1 {
                                Button(role: .destructive) {
                                    profilePendingDelete = member
                                } label: {
                                    Label(AppLocalization.string("Delete Profile"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                    if allProfiles.count < HouseholdData.maxProfiles {
                        Button {
                            newPersonName = ""
                            showingAddPerson = true
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(Color.mint, style: StrokeStyle(lineWidth: 2, dash: [5]))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.mint)
                                }
                                Text(AppLocalization.string("Add Person"))
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundColor(.mint)
                                    .lineLimit(1)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if allProfiles.count > 1 {
                Button(role: .destructive) {
                    profilePendingDelete = profile
                } label: {
                    Text(AppLocalization.string("Delete Profile"))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private func householdAvatar(_ member: UserProfile) -> some View {
        Group {
            if let data = member.profileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.white, Color.mint)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }
    
    private var addPersonSheet: some View {
        NavigationView {
            ZStack {
                AppBackground()
                VStack(spacing: 20) {
                    Text(AppLocalization.string("Who is this for?"))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(AppLocalization.string("Add a family member to keep medicines, reminders, and history separate — all on this device."))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    TextField(AppLocalization.string("Family member"), text: $newPersonName)
                        .font(.system(.body, design: .rounded))
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(14)
                    
                    Button {
                        _ = HouseholdData.addProfile(name: newPersonName, among: allProfiles, context: modelContext)
                        showingAddPerson = false
                        NotificationManager.shared.rescheduleFromStore()
                    } label: {
                        Text(AppLocalization.string("Add Person"))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.mint)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("Cancel")) {
                        showingAddPerson = false
                    }
                    .foregroundColor(.mint)
                }
            }
        }
    }
    
    private func revealSaveButton() {
        guard !showSaveButton else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            showSaveButton = true
        }
    }
    
    private var localizedAgeRangeLabel: String {
        if profile.ageRange.isEmpty {
            return AppLocalization.string("Not selected")
        }
        if let range = AgeRange(rawValue: profile.ageRange) {
            return range.localizedName
        }
        return profile.ageRange
    }
    
    private var medicationsSummary: String {
        let names = profile.medications.map(\.name).filter { !$0.isEmpty }
        if names.isEmpty {
            return AppLocalization.string("No medications added.")
        }
        if names.count == 1 {
            return names[0]
        }
        return AppLocalization.format("%lld medications", names.count)
    }
    
    private func exportUserData() {
        guard let url = MedTrackerExportDocument.makePDF(profile: profile, logs: logs) else {
            print("Export failed: could not create PDF")
            return
        }
        SharePresenter.present(items: [url])
    }
    
    private func updateNotificationIfNeeded() {
        if isNotificationEnabled {
            scheduleCurrentNotification()
        }
    }
    
    private func scheduleCurrentNotification() {
        profile.ensureRemindersMigrated()
        NotificationManager.shared.rescheduleFromStore()
    }
}
