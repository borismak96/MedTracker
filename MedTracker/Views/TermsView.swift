import SwiftUI

struct TermsView: View {
    private let sections: [(icon: String, color: Color, title: LocalizedStringKey, body: LocalizedStringKey)] = [
        ("stethoscope", .mint, "Terms_Title_1", "Terms_Body_1"),
        ("lock.shield.fill", .blue, "Terms_Title_2", "Terms_Body_2"),
        ("exclamationmark.triangle.fill", .orange, "Terms_Title_3", "Terms_Body_3"),
        ("doc.badge.gearshape.fill", .purple, "Terms_Title_4", "Terms_Body_4"),
        ("info.circle.fill", .gray, "Terms_Title_5", "Terms_Body_5")
    ]
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<sections.count, id: \.self) { index in
                        let section = sections[index]
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(section.color.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: section.icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(section.color)
                                }
                                
                                Text(section.title)
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(section.body)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(LocalizedStringKey("Terms & Conditions"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
