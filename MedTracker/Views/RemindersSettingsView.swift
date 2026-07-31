import SwiftUI
import SwiftData

struct RemindersSettingsView: View {
    @Bindable var profile: UserProfile
    @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
    
    private let suggestedLabels = ["Morning", "Afternoon", "Night", "Custom"]
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 16) {
                    Text(LocalizedStringKey("Set one or more daily reminder times. Assign medicines to each time on the Medications page."))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    
                    if profile.sortedReminders.isEmpty {
                        emptyState
                    } else {
                        ForEach(profile.sortedReminders) { reminder in
                            reminderCard(reminder)
                        }
                    }
                    
                    Button(action: addReminder) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(LocalizedStringKey("Add Reminder"))
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
        .navigationTitle(LocalizedStringKey("Reminder Times"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            profile.ensureRemindersMigrated()
        }
        .onChange(of: profile.reminders) { _, _ in
            syncNotifications()
            try? profile.modelContext?.save()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 70, height: 70)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.mint)
            }
            Text(LocalizedStringKey("No reminders yet."))
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    private func reminderCard(_ reminder: ReminderSlot) -> some View {
        let binding = Binding(
            get: {
                profile.reminders.first(where: { $0.id == reminder.id }) ?? reminder
            },
            set: { updated in
                if let index = profile.reminders.firstIndex(where: { $0.id == reminder.id }) {
                    profile.reminders[index] = updated
                    // keep legacy fields in sync with first reminder
                    if let first = profile.sortedReminders.first {
                        profile.targetTimeHour = first.hour
                        profile.targetTimeMinute = first.minute
                    }
                }
            }
        )
        
        let timeBinding = Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = binding.wrappedValue.hour
                components.minute = binding.wrappedValue.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                binding.wrappedValue.hour = components.hour ?? 8
                binding.wrappedValue.minute = components.minute ?? 0
            }
        )
        
        let medCount = profile.medications(for: reminder).count
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField(LocalizedStringKey("Label (e.g. Morning)"), text: Binding(
                    get: { binding.wrappedValue.label },
                    set: { binding.wrappedValue.label = $0 }
                ))
                .font(.system(.headline, design: .rounded, weight: .bold))
                
                if profile.reminders.count > 1 {
                    Button {
                        withAnimation {
                            profile.reminders.removeAll { $0.id == reminder.id }
                            for i in profile.medications.indices {
                                profile.medications[i].reminderIds.removeAll { $0 == reminder.id }
                            }
                        }
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedLabels, id: \.self) { label in
                        Button {
                            binding.wrappedValue.label = label == "Custom" ? "" : label
                        } label: {
                            Text(LocalizedStringKey(label))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(binding.wrappedValue.label == label || (label == "Custom" && binding.wrappedValue.label.isEmpty) ? Color.mint.opacity(0.25) : Color(UIColor.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            DatePicker(LocalizedStringKey("Time"), selection: timeBinding, displayedComponents: .hourAndMinute)
                .font(.system(.body, design: .rounded))
            
            Text(String(format: String(localized: "%lld medicines at this time"), medCount))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private func addReminder() {
        withAnimation {
            profile.ensureRemindersMigrated()
            let defaults: [(String, Int, Int)] = [
                ("Morning", 8, 0),
                ("Afternoon", 14, 0),
                ("Night", 20, 0)
            ]
            let next = defaults.first { candidate in
                !profile.reminders.contains { $0.label == candidate.0 }
            } ?? ("Reminder", 12, 0)
            
            profile.reminders.append(ReminderSlot(hour: next.1, minute: next.2, label: next.0))
        }
    }
    
    private func syncNotifications() {
        guard isNotificationEnabled else { return }
        profile.ensureRemindersMigrated()
        NotificationManager.shared.scheduleReminders(profile.sortedReminders) { reminder in
            profile.medications(for: reminder)
        }
    }
}
