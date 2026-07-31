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
                            HStack(spacing: 12) {
                                TextField("Medication Name", text: $med.name)
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                
                                Divider()
                                    .frame(height: 24)
                                
                                Picker("Dose", selection: $med.dose) {
                                    ForEach(1...20, id: \.self) { num in
                                        Text("\(num)").tag("\(num)")
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 60)
                                
                                Button(role: .destructive) {
                                    withAnimation {
                                        if let index = profile.medications.firstIndex(where: { $0.id == med.id }) {
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
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
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
        .onChange(of: profile.medications) { _, _ in
            updateNotificationIfNeeded()
            try? profile.modelContext?.save()
        }
    }
    
    private func updateNotificationIfNeeded() {
        guard isNotificationEnabled else { return }
        
        let medNames = profile.medications.map { $0.name }.filter { !$0.isEmpty }
        let medName = medNames.isEmpty ? String(localized: "your medication") : medNames.joined(separator: ", ")
        
        NotificationManager.shared.scheduleNotification(
            hour: profile.targetTimeHour,
            minute: profile.targetTimeMinute,
            title: String(localized: "Medication Reminder"),
            body: String(format: String(localized: "It's time to take %@"), medName)
        )
    }
}
