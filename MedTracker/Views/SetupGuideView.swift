import SwiftUI

struct SetupGuideView: View {
    private var usesChineseScreenshots: Bool {
        AppLocalization.prefersTraditionalChinese
    }
    
    private var steps: [(image: String, title: String, body: String)] {
        let suffix = usesChineseScreenshots ? "_zh" : ""
        return [
            (
                "guide_home\(suffix)",
                "Track on Home",
                "On Home, log each reminder with Take Now or Skip / Missed, and record how you feel."
            ),
            (
                "guide_profile\(suffix)",
                "Open Profile",
                "Go to Profile to manage your medications, reminder times, and daily reminder notifications."
            ),
            (
                "guide_reminders\(suffix)",
                "Set reminder times",
                "Open Profile → Reminder Times. Add one or more daily alarms (Morning, Afternoon, Night, or Custom)."
            ),
            (
                "guide_medications\(suffix)",
                "Add your medications",
                "Open Profile → Manage Medications. Add each medicine and dose, then assign it to reminder times."
            ),
            (
                "guide_notifications\(suffix)",
                "Turn on notifications",
                "In Profile, enable Daily Reminders so PillPal can notify you at each scheduled time."
            )
        ]
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepCard(
                            number: index + 1,
                            imageName: step.image,
                            title: AppLocalization.string(step.title),
                            body: AppLocalization.string(step.body)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(AppLocalization.string("How to Set Up"))
        .navigationBarTitleDisplayMode(.inline)
        // Refresh images when in-app language changes.
        .id(usesChineseScreenshots)
    }
    
    private var headerCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.mint)
            }
            
            Text(AppLocalization.string("Reminder & Medication Guide"))
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
            
            Text(AppLocalization.string("Follow these steps to schedule reminder times and assign medicines to each one."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    private func stepCard(number: Int, imageName: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.mint.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Text("\(number)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.mint)
                }
                
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                
                Spacer(minLength: 0)
            }
            
            Text(body)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
