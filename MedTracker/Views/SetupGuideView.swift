import SwiftUI

struct SetupGuideView: View {
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    
                    stepCard(
                        number: 1,
                        icon: "bell.badge.fill",
                        title: AppLocalization.string("Set reminder times"),
                        body: AppLocalization.string("Open Profile → Reminder Times. Add one or more daily alarms (for example Morning, Afternoon, and Night), and pick a custom time for each.")
                    )
                    
                    stepCard(
                        number: 2,
                        icon: "pills.fill",
                        title: AppLocalization.string("Add your medications"),
                        body: AppLocalization.string("Open Profile → Manage Medications. Add each medicine and dose, then choose which reminder times it should use — or keep All times.")
                    )
                    
                    stepCard(
                        number: 3,
                        icon: "bell.fill",
                        title: AppLocalization.string("Turn on notifications"),
                        body: AppLocalization.string("In Profile, enable Daily Reminders so PillPal can notify you at each scheduled time with the medicines for that slot.")
                    )
                    
                    stepCard(
                        number: 4,
                        icon: "house.fill",
                        title: AppLocalization.string("Track on Home"),
                        body: AppLocalization.string("On Home, check your day streak and this month rings, then use Take Now or Missed when you finish or skip a dose. Tap a streak colour to see that reminder’s details.")
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(AppLocalization.string("How to Set Up"))
        .navigationBarTitleDisplayMode(.inline)
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
            
            Text(AppLocalization.string("Follow these steps to schedule multiple reminder times and assign medicines to each one."))
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
    
    private func stepCard(number: Int, icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text("\(number)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.mint)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.mint)
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                
                Text(body)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
