import SwiftUI
import SwiftData

struct MedicationsSettingsView: View {
    @Bindable var profile: UserProfile
    @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 16) {
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
                            
                            Text(LocalizedStringKey("No medications added."))
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
                            Text("Add Medication")
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
        .navigationTitle(LocalizedStringKey("Medications"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            profile.ensureRemindersMigrated()
        }
        .onChange(of: profile.medications) { _, _ in
            updateNotificationIfNeeded()
            try? profile.modelContext?.save()
        }
    }
    
    private func medicationCard(_ med: Binding<MedicationItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField("Medication Name", text: med.name)
                    .font(.system(.body, design: .rounded, weight: .medium))
                
                Divider()
                    .frame(height: 24)
                
                Picker("Dose", selection: med.dose) {
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
            
            Text(LocalizedStringKey("Remind at"))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(.secondary)
            
            if profile.reminders.isEmpty {
                Text(LocalizedStringKey("Add reminder times in Reminder Times settings."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                FlowReminderChips(profile: profile, selectedIds: med.reminderIds)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private func updateNotificationIfNeeded() {
        guard isNotificationEnabled else { return }
        profile.ensureRemindersMigrated()
        NotificationManager.shared.scheduleReminders(profile.sortedReminders) { reminder in
            profile.medications(for: reminder)
        }
    }
}

/// Horizontal wrap-style chip toggles for reminder assignment.
private struct FlowReminderChips: View {
    @Bindable var profile: UserProfile
    @Binding var selectedIds: [UUID]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    selectedIds = []
                }
            } label: {
                Text(LocalizedStringKey("All times"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedIds.isEmpty ? Color.mint.opacity(0.25) : Color(UIColor.systemGray6))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            ForEach(profile.sortedReminders) { reminder in
                let isOn = selectedIds.contains(reminder.id)
                Button {
                    withAnimation {
                        if selectedIds.isEmpty {
                            // Switching from "all" to specific: select only this one
                            selectedIds = [reminder.id]
                        } else if isOn {
                            selectedIds.removeAll { $0 == reminder.id }
                        } else {
                            selectedIds.append(reminder.id)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: (selectedIds.isEmpty || isOn) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor((selectedIds.isEmpty || isOn) ? .mint : .secondary)
                        Text(reminder.displayTitle)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((selectedIds.isEmpty || isOn) ? Color.mint.opacity(0.12) : Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
