import SwiftUI

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringKey("Terms_Content"))
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                    .padding()
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey("Terms & Conditions"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
