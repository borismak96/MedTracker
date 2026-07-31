import SwiftUI

struct AboutUsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .padding(.top, 40)
                
                Text("MedTracker")
                    .font(.system(.title, design: .rounded, weight: .bold))
                
                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(LocalizedStringKey("About_Us_Content"))
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .foregroundColor(.primary.opacity(0.8))
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey("About Us"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
