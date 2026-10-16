import SwiftUI
import SwiftData

struct VisitPackView: View {
    var profile: UserProfile
    var logs: [MedicationLog]
    
    @State private var windowDays = 7
    @State private var previewChinese = AppLocalization.prefersTraditionalChinese
    
    private var snapshot: VisitPackSnapshot {
        VisitPackSnapshot.build(profile: profile, logs: logs, days: windowDays)
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    disclaimerCard
                    controlsCard
                    medicationsCard
                    adherenceCard
                    vitalsCard
                    moodCard
                    shareButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(AppLocalization.string("Clinic Visit Pack"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            previewChinese = AppLocalization.prefersTraditionalChinese
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.string("Clinic-ready summary"))
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(AppLocalization.format("Prepared for %@", snapshot.profileName))
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
            Text(AppLocalization.string("Uses only records already on this iPhone. Nothing is uploaded."))
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
            Text(AppLocalization.string("Visit pack disclaimer"))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(18)
    }
    
    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppLocalization.string("Period"))
                .font(.system(.headline, design: .rounded, weight: .bold))
            Picker(AppLocalization.string("Period"), selection: $windowDays) {
                Text(AppLocalization.string("Last 7 days")).tag(7)
                Text(AppLocalization.string("Last 14 days")).tag(14)
            }
            .pickerStyle(.segmented)
            
            Text(AppLocalization.string("Preview language"))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .padding(.top, 4)
            Picker(AppLocalization.string("Preview language"), selection: $previewChinese) {
                Text(AppLocalization.string("English")).tag(false)
                Text("繁體中文").tag(true)
            }
            .pickerStyle(.segmented)
            
            Text(AppLocalization.string("The shared PDF includes English and Traditional Chinese."))
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    private var medicationsCard: some View {
        sectionCard(title: loc("Current Medications")) {
            if snapshot.medications.isEmpty {
                emptyLine(loc("No medications added."))
            } else {
                ForEach(Array(snapshot.medications.enumerated()), id: \.offset) { _, med in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(med.name)
                            .font(.system(.body, design: .rounded, weight: .bold))
                        Text("\(loc("Dose")): \(med.dose.isEmpty ? "—" : med.dose)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("\(loc("Schedule")): \(previewChinese ? med.scheduleZH : med.scheduleEN)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var adherenceCard: some View {
        sectionCard(title: loc("Adherence")) {
            if !snapshot.summary.hasAdherenceHistory {
                emptyLine(loc("No adherence history in this period."))
            } else {
                HStack(spacing: 8) {
                    miniStat("\(snapshot.summary.takenDoses)", loc("Taken"), .green)
                    miniStat("\(snapshot.summary.skippedDoses)", loc("Skipped"), .orange)
                    miniStat("\(snapshot.summary.missedDoses)", loc("Missed"), .red)
                    miniStat("\(snapshot.summary.adherencePercent)%", loc("Adherence"), .mint)
                }
                
                ForEach(Array(snapshot.summary.dayRows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(mediumDate(row.date))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        Spacer()
                        if row.hasActivity {
                            Text(AppLocalization.format("%lld taken · %lld skipped · %lld missed", chinese: previewChinese, row.taken, row.skipped, row.missed))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondary)
                        } else {
                            Text(loc("Not Recorded"))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var vitalsCard: some View {
        VStack(spacing: 18) {
            sectionCard(title: loc("Blood Pressure")) {
                if snapshot.summary.bpReadings.isEmpty {
                    emptyLine(loc("No blood pressure recorded in this period."))
                } else {
                    Text(AppLocalization.format("%lld readings", chinese: previewChinese, snapshot.summary.bpReadings.count))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    if let avg = snapshot.averageBPText {
                        Text("\(loc("Average")): \(avg)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            sectionCard(title: loc("Heart Rate")) {
                if snapshot.summary.hrReadings.isEmpty {
                    emptyLine(loc("No heart rate recorded in this period."))
                } else {
                    Text(AppLocalization.format("%lld readings", chinese: previewChinese, snapshot.summary.hrReadings.count))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    if let avg = snapshot.averageHRText {
                        Text("\(loc("Average")): \(avg)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var moodCard: some View {
        sectionCard(title: loc("Mood")) {
            if snapshot.summary.moods.isEmpty {
                emptyLine(loc("No mood recorded in this period."))
            } else if let mood = snapshot.mostCommonMood {
                Text("\(loc("Most Common")): \(mood.emoji) \(loc(mood.rawValue))")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            } else {
                Text(snapshot.summary.moods.last ?? "")
                    .font(.system(.subheadline, design: .rounded))
            }
        }
    }
    
    private var shareButton: some View {
        Button {
            sharePDF()
        } label: {
            Label(AppLocalization.string("Share PDF"), systemImage: "square.and.arrow.up")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.mint)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLocalization.string("Share PDF"))
    }
    
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
    }
    
    private func miniStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundColor(color)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func loc(_ key: String) -> String {
        AppLocalization.string(key, chinese: previewChinese)
    }
    
    private func mediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = previewChinese ? Locale(identifier: "zh-Hant") : Locale(identifier: "en")
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
    
    private func sharePDF() {
        guard let url = VisitPackPDF.makePDF(snapshot: snapshot) else { return }
        SharePresenter.present(items: [url])
    }
}
