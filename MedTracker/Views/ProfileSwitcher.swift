import SwiftUI
import SwiftData

struct ProfileSwitcher: View {
    let profiles: [UserProfile]
    let active: UserProfile
    var compact: Bool = false
    
    private var ordered: [UserProfile] {
        profiles.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }
    
    var body: some View {
        Menu {
            ForEach(ordered, id: \.id) { profile in
                Button {
                    ActiveProfileStore.select(profile)
                } label: {
                    Label(
                        profile.displayName,
                        systemImage: profile.id == active.id ? "checkmark.circle.fill" : "person.crop.circle"
                    )
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: compact ? 12 : 13, weight: .bold))
                Text(active.displayName)
                    .font(.system(compact ? .caption : .subheadline, design: .rounded, weight: .bold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.mint)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 6 : 8)
            .background(Color.mint.opacity(0.12))
            .clipShape(Capsule())
        }
        .accessibilityLabel(AppLocalization.string("Switch Profile"))
    }
}
