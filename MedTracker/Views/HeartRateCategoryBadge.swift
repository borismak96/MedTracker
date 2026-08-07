import SwiftUI

/// Category label + follow-up advice for one heart-rate reading.
struct HeartRateCategoryBadge: View {
    let category: HeartRateCategory
    var compact: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(category.localizedTitle)
                .font(.system(compact ? .caption2 : .caption, design: .rounded, weight: .bold))
                .foregroundColor(category.color)
            
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: compact ? 10 : 12))
                    .foregroundColor(category.color.opacity(0.9))
                Text(category.localizedAdvice)
                    .font(.system(compact ? .caption2 : .caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 6 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(category.color.opacity(0.12))
        .cornerRadius(10)
    }
}
