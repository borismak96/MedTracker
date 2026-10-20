import SwiftUI
import SwiftData

struct MedicalCardView: View {
    @Bindable var profile: UserProfile
    @Binding var isShowing: Bool
    
    @State private var showingEditor = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(ElderMode.enabledKey, store: AppLocalization.sharedDefaults) private var elderMode = false
    
    private var stackedLayout: Bool {
        elderMode || dynamicTypeSize.prefersStackedLayout
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(AppLocalization.string("Medical Card"))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(minWidth: ElderMode.minTap, minHeight: ElderMode.minTap)
                }
                .accessibilityLabel(AppLocalization.string("Edit Medical Card"))
                
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(minWidth: ElderMode.minTap, minHeight: ElderMode.minTap)
                }
                .accessibilityLabel(AppLocalization.string("Close Medical Card"))
            }
            .padding()
            .background(Color.mint)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        if let data = profile.profileImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.mint, lineWidth: 3))
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 72, height: 72)
                                .foregroundStyle(.white, Color.mint)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                            if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(AppLocalization.string("Add a name in Profile"))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    
                    disclaimerBanner
                    
                    cardSection(title: AppLocalization.string("Allergies"), icon: "exclamationmark.triangle.fill", tint: .orange) {
                        if profile.hasAllergies {
                            Text(profile.trimmedAllergies)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        } else {
                            emptyPrompt(AppLocalization.string("No allergies recorded. Add them so this card is ready in an emergency."))
                        }
                    }
                    
                    cardSection(title: AppLocalization.string("Emergency Contact"), icon: "phone.fill", tint: .red) {
                        if profile.hasEmergencyContact {
                            VStack(alignment: .leading, spacing: 4) {
                                if !profile.trimmedICEName.isEmpty {
                                    Text(profile.trimmedICEName)
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                }
                                if !profile.trimmedICERelation.isEmpty {
                                    Text(profile.trimmedICERelation)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                if !profile.trimmedICEPhone.isEmpty {
                                    Text(profile.trimmedICEPhone)
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                        .foregroundColor(.mint)
                                }
                            }
                        } else {
                            emptyPrompt(AppLocalization.string("No emergency contact yet. Add a name and phone number."))
                        }
                    }
                    
                    cardSection(title: AppLocalization.string("Current Medications"), icon: "pills.fill", tint: .mint) {
                        let activeMeds = profile.activeMedications
                        if activeMeds.isEmpty {
                            emptyPrompt(AppLocalization.string("No medications added."))
                        } else {
                            VStack(spacing: 10) {
                                ForEach(activeMeds) { med in
                                    HStack(alignment: .top, spacing: 12) {
                                        MedicationPhotoView(data: med.photoData, size: stackedLayout ? 56 : 40)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(med.name)
                                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                .fixedSize(horizontal: false, vertical: true)
                                            if !med.dose.isEmpty {
                                                Text(med.dose)
                                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                            if elderMode, !med.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                SpeakMedicationButton(name: med.name, dose: med.dose, large: true)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(10)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .accessibilityElement(children: .contain)
                                }
                            }
                        }
                    }
                    
                    Button {
                        showingEditor = true
                    } label: {
                        Text(AppLocalization.string("Fill in details"))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.mint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.mint.opacity(0.12))
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        .padding(16)
        .onDisappear {
            MedicationSpeech.shared.stop()
        }
        .sheet(isPresented: $showingEditor) {
            NavigationView {
                MedicalCardEditor(profile: profile)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(AppLocalization.string("Done")) {
                                try? profile.modelContext?.save()
                                showingEditor = false
                            }
                            .font(.system(.body, design: .rounded, weight: .bold))
                        }
                    }
            }
        }
    }
    
    private var disclaimerBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundColor(.secondary)
            Text(AppLocalization.string("Not an official medical ID"))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }
    
    private func cardSection<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
    
    private func emptyPrompt(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
    }
}

struct MedicalCardEditor: View {
    @Bindable var profile: UserProfile
    
    var body: some View {
        ZStack {
            AppBackground()
            Form {
                Section {
                    Text(AppLocalization.string("Not an official medical ID"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text(AppLocalization.string("Personal Info"))) {
                    TextField(AppLocalization.string("Name"), text: $profile.name)
                }
                
                Section(header: Text(AppLocalization.string("Allergies"))) {
                    TextField(AppLocalization.string("Allergies (e.g. penicillin)"), text: $profile.allergies, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text(AppLocalization.string("Emergency Contact"))) {
                    TextField(AppLocalization.string("ICE Name"), text: $profile.emergencyContactName)
                    TextField(AppLocalization.string("Relationship"), text: $profile.emergencyContactRelation)
                    TextField(AppLocalization.string("ICE Phone"), text: $profile.emergencyContactPhone)
                        .keyboardType(.phonePad)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(AppLocalization.string("Edit Medical Card"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
