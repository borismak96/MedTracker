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
                    Text(AppLocalization.string("Set one or more daily reminder times. Assign medicines to each time on the Medications page."))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    
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
                            Text(AppLocalization.string("Add Reminder"))
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
        .navigationTitle(AppLocalization.string("Reminder Times"))
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
            Text(AppLocalization.string("No reminders yet."))
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
                    var next = profile.reminders
                    next[index] = updated
                    profile.reminders = next
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
                TextField(AppLocalization.string("Label (e.g. Morning)"), text: Binding(
                    get: { ReminderSlot.localizedLabel(for: binding.wrappedValue.label) },
                    set: { binding.wrappedValue.label = ReminderSlot.storageLabel(from: $0) }
                ))
                .font(.system(.headline, design: .rounded, weight: .bold))
                
                if profile.reminders.count > 1 {
                    Button {
                        withAnimation {
                            // Reassign arrays so SwiftData / SwiftUI reliably observe the change.
                            profile.reminders = profile.reminders.filter { $0.id != reminder.id }
                            profile.medications = profile.medications.map { med in
                                var updated = med
                                updated.reminderIds.removeAll { $0 == reminder.id }
                                return updated
                            }
                            try? profile.modelContext?.save()
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
                            Text(AppLocalization.string(label))
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
            
            DatePicker(AppLocalization.string("Time"), selection: timeBinding, displayedComponents: .hourAndMinute)
                .font(.system(.body, design: .rounded))
            
            Text(AppLocalization.format("%lld medicines at this time", medCount))
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
            
            profile.reminders = profile.reminders + [
                ReminderSlot(hour: next.1, minute: next.2, label: next.0)
            ]
            try? profile.modelContext?.save()
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
