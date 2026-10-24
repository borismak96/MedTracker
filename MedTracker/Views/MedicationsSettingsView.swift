import SwiftUI
import SwiftData
import PhotosUI

struct MedicationsSettingsView: View {
    @Bindable var profile: UserProfile
    @Query private var allLogs: [MedicationLog]
    @AppStorage("isNotificationEnabled", store: AppLocalization.sharedDefaults) private var isNotificationEnabled = false
    @AppStorage("isNotificationSoundEnabled", store: AppLocalization.sharedDefaults) private var isNotificationSoundEnabled = true
    @AppStorage(ElderMode.enabledKey, store: AppLocalization.sharedDefaults) private var elderMode = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 16) {
                    NavigationLink(destination: SetupGuideView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.mint)
                            Text(AppLocalization.string("How to set reminders & medications"))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    
                    if profile.medications.isEmpty {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.mint.opacity(0.15))
                                    .frame(width: 70, height: 70)
                                Image(systemName: "pills.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.mint)
                            }
                            
                            Text(AppLocalization.string("No medications added."))
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
                    } else {
                        ForEach($profile.medications) { $med in
                            MedicationEditorCard(
                                med: $med,
                                elderMode: elderMode,
                                onDelete: {
                                    withAnimation {
                                        if let index = profile.medications.firstIndex(where: { $0.id == med.id }) {
                                            profile.medications.remove(at: index)
                                        }
                                    }
                                },
                                onPhotoChange: { data in
                                    applyPhoto(medID: med.id, data: data)
                                }
                            )
                        }
                    }
                    
                    Button(action: {
                        withAnimation {
                            profile.medications.append(MedicationItem())
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(AppLocalization.string("Add Medication"))
                                .fontWeight(.bold)
                        }
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: ElderMode.buttonHeight)
                        .padding(.vertical, 16)
                        .background(Color.mint)
                        .cornerRadius(20)
                        .shadow(color: Color.mint.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(AppLocalization.string("Medications"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            profile.ensureRemindersMigrated()
        }
        .onChange(of: profile.medications) { _, _ in
            profile.pruneRemovedMedications(from: allLogs.filter { $0.belongs(to: profile) })
            updateNotificationIfNeeded()
            try? profile.modelContext?.save()
        }
    }
    
    private func applyPhoto(medID: UUID, data: Data?) {
        var meds = profile.medications
        guard let index = meds.firstIndex(where: { $0.id == medID }) else { return }
        meds[index].photoData = data
        profile.medications = meds
        try? profile.modelContext?.save()
    }
    
    private func updateNotificationIfNeeded() {
        guard isNotificationEnabled else { return }
        profile.ensureRemindersMigrated()
        NotificationManager.shared.rescheduleFromStore()
    }
}

private struct MedicationEditorCard: View {
    @Binding var med: MedicationItem
    var elderMode: Bool
    var onDelete: () -> Void
    var onPhotoChange: (Data?) -> Void
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingCamera = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                MedicationPhotoView(data: med.photoData, size: elderMode ? 72 : 56)
                    .accessibilityLabel(med.hasPhoto
                        ? AppLocalization.format("Photo of %@", med.name.isEmpty ? AppLocalization.string("Medication Name") : med.name)
                        : AppLocalization.string("Add medication photo"))
                
                VStack(alignment: .leading, spacing: 8) {
                    photoActions
                    Text(AppLocalization.string("Medication photo stays on this iPhone."))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            HStack(spacing: 12) {
                TextField(AppLocalization.string("Medication Name"), text: $med.name)
                    .font(.system(.body, design: .rounded, weight: .medium))
                
                Divider()
                    .frame(height: 24)
                
                Picker(AppLocalization.string("Dose"), selection: $med.dose) {
                    ForEach(1...20, id: \.self) { num in
                        Text("\(num)").tag("\(num)")
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 60)
                .accessibilityLabel(AppLocalization.string("Dose"))
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(minWidth: ElderMode.minTap, minHeight: ElderMode.minTap)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalization.string("Remove"))
            }
            
            TextField(AppLocalization.string("Remark (optional)"), text: $med.remark, axis: .vertical)
                .font(.system(.subheadline, design: .rounded))
                .lineLimit(2...4)
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem,
                      let raw = try? await newItem.loadTransferable(type: Data.self),
                      let jpeg = MedicationPhoto.jpegData(from: raw) else { return }
                onPhotoChange(jpeg)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                if let jpeg = MedicationPhoto.jpegData(from: image) {
                    onPhotoChange(jpeg)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    private var photoActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if elderMode {
                VStack(alignment: .leading, spacing: 8) {
                    photoLibraryButton
                    cameraButton
                }
            } else {
                HStack(spacing: 8) {
                    photoLibraryButton
                    cameraButton
                }
            }
            
            if med.hasPhoto {
                Button(role: .destructive) {
                    onPhotoChange(nil)
                    selectedPhotoItem = nil
                } label: {
                    Text(AppLocalization.string("Remove photo"))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.red)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var photoLibraryButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
            actionChip(
                title: AppLocalization.string(med.hasPhoto ? "Change medication photo" : "Choose from Photos"),
                systemImage: "photo.on.rectangle"
            )
        }
        .accessibilityLabel(AppLocalization.string(med.hasPhoto ? "Change medication photo" : "Choose from Photos"))
    }
    
    @ViewBuilder
    private var cameraButton: some View {
        if CameraPicker.isAvailable {
            Button {
                showingCamera = true
            } label: {
                actionChip(title: AppLocalization.string("Take photo"), systemImage: "camera.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppLocalization.string("Take photo"))
        }
    }
    
    private func actionChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .font(.system(.caption, design: .rounded, weight: .bold))
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .frame(minHeight: elderMode ? ElderMode.buttonHeight : 36)
        .background(Color.mint)
        .cornerRadius(12)
    }
}
