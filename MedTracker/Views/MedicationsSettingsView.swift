import SwiftUI
import SwiftData

struct MedicationsSettingsView: View {
    @Bindable var profile: UserProfile
    @Query private var logs: [MedicationLog]
    @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
    @AppStorage("isNotificationSoundEnabled") private var isNotificationSoundEnabled = true
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
                            medicationCard($med)
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
            profile.pruneRemovedMedications(from: logs)
            updateNotificationIfNeeded()
            try? profile.modelContext?.save()
        }
    }
    
    private func medicationCard(_ med: Binding<MedicationItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField(AppLocalization.string("Medication Name"), text: med.name)
                    .font(.system(.body, design: .rounded, weight: .medium))
                
                Divider()
                    .frame(height: 24)
                
                Picker(AppLocalization.string("Dose"), selection: med.dose) {
                    ForEach(1...20, id: \.self) { num in
                        Text("\(num)").tag("\(num)")
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 60)
                
                Button(role: .destructive) {
                    withAnimation {
                        if let index = profile.medications.firstIndex(where: { $0.id == med.wrappedValue.id }) {
                            profile.medications.remove(at: index)
                        }
                    }
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            
            TextField(AppLocalization.string("Remark (optional)"), text: med.remark, axis: .vertical)
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
    }
    
    private func updateNotificationIfNeeded() {
        guard isNotificationEnabled else { return }
        profile.ensureRemindersMigrated()
        NotificationManager.shared.scheduleReminders(profile.sortedReminders, playSound: isNotificationSoundEnabled) { reminder in
            profile.medications(for: reminder)
        }
    }
}

