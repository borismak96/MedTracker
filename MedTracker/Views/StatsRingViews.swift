import SwiftUI

/// Soft pastel palette for reminder time cards (Day Streak, Today, History).
enum StatsRingPalette {
    /// Morning — #FFDF3E
    static let yellow = Color(red: 255/255, green: 223/255, blue: 62/255)
    /// Afternoon — #FC7D1B
    static let orange = Color(red: 252/255, green: 125/255, blue: 27/255)
    /// Night — #B771F4
    static let purple = Color(red: 183/255, green: 113/255, blue: 244/255)
    
    /// Deeper accents for ring progress / filled buttons.
    static let yellowAccent = Color(red: 0.45, green: 0.34, blue: 0.02)
    static let orangeAccent = Color(red: 0.48, green: 0.20, blue: 0.04)
    static let purpleAccent = Color(red: 0.42, green: 0.18, blue: 0.68)
    
    static let green = Color(red: 0.72, green: 0.91, blue: 0.78)
    static let pink = Color(red: 0.98, green: 0.78, blue: 0.84)
    static let blue = Color(red: 0.75, green: 0.86, blue: 0.96)
    static let cream = Color(red: 0.99, green: 0.98, blue: 0.95)
    
    static let accentColors: [Color] = [yellow, orange, purple, blue]
    
    /// Morning = #FFDF3E, Afternoon = #FC7D1B, Night = #B771F4.
    static func color(for reminder: ReminderSlot) -> Color {
        switch period(for: reminder) {
        case .morning: return yellow
        case .afternoon: return orange
        case .night: return purple
        }
    }
    
    static func accent(for reminder: ReminderSlot) -> Color {
        switch period(for: reminder) {
        case .morning: return yellowAccent
        case .afternoon: return orangeAccent
        case .night: return purpleAccent
        }
    }
    
    /// Yellow/orange use dark text; purple uses white text for contrast.
    static func prefersLightText(for reminder: ReminderSlot) -> Bool {
        period(for: reminder) == .night
    }
    
    static func primaryText(for reminder: ReminderSlot) -> Color {
        prefersLightText(for: reminder) ? .white : Color(white: 0.10)
    }
    
    static func secondaryText(for reminder: ReminderSlot) -> Color {
        prefersLightText(for: reminder) ? Color.white.opacity(0.92) : Color(white: 0.18)
    }
    
    private enum Period { case morning, afternoon, night }
    
    private static func period(for reminder: ReminderSlot) -> Period {
        let label = reminder.label.lowercased()
        if label.contains("morning") || label.contains("早上") { return .morning }
        if label.contains("afternoon") || label.contains("下午") { return .afternoon }
        if label.contains("night") || label.contains("evening") || label.contains("晚上") { return .night }
        
        switch reminder.hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        default: return .night
        }
    }
}

struct RingSegmentModel: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let detailLines: [String]
    let color: Color
    let icon: String
    let startDegrees: Double
    let endDegrees: Double
    
    var midDegrees: Double {
        (startDegrees + endDegrees) / 2
    }
}

struct SegmentedStatsRing: View {
    let segments: [RingSegmentModel]
    let centerValue: String
    let centerLabel: String
    var lineWidth: CGFloat = 26
    var onSelect: (RingSegmentModel) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - lineWidth / 2 - 4
            
            ZStack {
                Circle()
                    .fill(StatsRingPalette.cream.opacity(0.55))
                    .frame(width: size * 0.72, height: size * 0.72)
                
                ForEach(segments) { segment in
                    CapsuleArc(
                        startDegrees: segment.startDegrees,
                        endDegrees: segment.endDegrees
                    )
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size - 8, height: size - 8)
                    .contentShape(
                        CapsuleArc(
                            startDegrees: segment.startDegrees,
                            endDegrees: segment.endDegrees
                        )
                        .stroke(style: StrokeStyle(lineWidth: lineWidth + 16, lineCap: .round))
                    )
                    .onTapGesture {
                        onSelect(segment)
                    }
                    
                    segmentIcon(segment, radius: radius, size: size)
                }
                
                VStack(spacing: 4) {
                    Text(centerValue)
                        .font(.system(size: size * 0.18, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    Text(centerLabel)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(width: size * 0.48)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func segmentIcon(_ segment: RingSegmentModel, radius: CGFloat, size: CGFloat) -> some View {
        let angle = Angle(degrees: segment.midDegrees - 90)
        let x = cos(angle.radians) * radius
        let y = sin(angle.radians) * radius
        
        return Button {
            onSelect(segment)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                Image(systemName: segment.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .offset(x: x, y: y)
    }
}

/// Gauge inspired by the lime progress ring reference (current / goal).
struct StreakGaugeView: View {
    let current: Int
    let goal: Int
    let color: Color
    var lineWidth: CGFloat = 14
    /// Optional deeper stroke colour for progress on pastel card fills.
    var progressColor: Color? = nil
    /// When true, ring sits on a solid colored card.
    var onSolidBackground: Bool = false
    
    private var progress: CGFloat {
        guard goal > 0 else { return 0 }
        return min(1, CGFloat(current) / CGFloat(goal))
    }
    
    /// Track spans ~270° with a gap near the bottom.
    private let trackStart: CGFloat = 0.12
    private let trackLength: CGFloat = 0.76
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let centerSize = size * 0.58
            let strokeColor = progressColor ?? (onSolidBackground ? color : color)
            let trackColor = onSolidBackground ? Color.white.opacity(0.65) : Color.white.opacity(0.85)
            let plateColor = onSolidBackground ? Color.white.opacity(0.35) : color.opacity(0.14)
            
            ZStack {
                // Soft tinted plate
                Circle()
                    .fill(plateColor)
                    .frame(width: size * 0.92, height: size * 0.92)
                
                // Background track
                Circle()
                    .trim(from: trackStart, to: trackStart + trackLength)
                    .stroke(
                        trackColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: size * 0.78, height: size * 0.78)
                
                // Progress
                Circle()
                    .trim(from: trackStart, to: trackStart + trackLength * progress)
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: size * 0.78, height: size * 0.78)
                    .animation(.easeInOut(duration: 0.35), value: progress)
                
                // Center white dial
                Circle()
                    .fill(Color.white)
                    .frame(width: centerSize, height: centerSize)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                
                VStack(spacing: 5) {
                    Text("\(current)")
                        .font(.system(size: max(size * 0.22, 28), weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Rectangle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: centerSize * 0.45, height: 1.5)
                    
                    Text("\(goal)")
                        .font(.system(size: max(size * 0.13, 16), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct CapsuleArc: Shape {
    var startDegrees: Double
    var endDegrees: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees - 90),
            endAngle: .degrees(endDegrees - 90),
            clockwise: false
        )
        return path
    }
}

enum StatsRingLayout {
    /// Layout equal arcs with gaps, starting near the top.
    static func segments(
        items: [(id: UUID, title: String, subtitle: String, detailLines: [String], icon: String)],
        colors: [Color] = StatsRingPalette.accentColors
    ) -> [RingSegmentModel] {
        guard !items.isEmpty else { return [] }
        
        let count = items.count
        let gap: Double = count == 1 ? 40 : 16
        let usable = 360 - gap * Double(count)
        let span = usable / Double(count)
        var cursor = gap / 2
        
        return items.enumerated().map { index, item in
            let start = cursor
            let end = cursor + span
            cursor = end + gap
            return RingSegmentModel(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                detailLines: item.detailLines,
                color: colors[index % colors.count],
                icon: item.icon,
                startDegrees: start,
                endDegrees: end
            )
        }
    }
    
    static func icon(for reminder: ReminderSlot) -> String {
        let label = reminder.label.lowercased()
        if label.contains("morning") || label.contains("早上") { return "sun.max.fill" }
        if label.contains("afternoon") || label.contains("下午") { return "sun.haze.fill" }
        if label.contains("night") || label.contains("晚上") || label.contains("evening") { return "moon.stars.fill" }
        
        switch reminder.hour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.haze.fill"
        default: return "moon.stars.fill"
        }
    }
}

struct RingDetailSheet: View {
    let segment: RingSegmentModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(segment.color.opacity(0.35))
                                    .frame(width: 72, height: 72)
                                Image(systemName: segment.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(segment.title)
                                .font(.system(.title2, design: .rounded, weight: .heavy))
                            
                            Text(segment.subtitle)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(22)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppLocalization.string("Details"))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                            
                            if segment.detailLines.isEmpty {
                                Text(AppLocalization.string("No details available."))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(segment.detailLines, id: \.self) { line in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(segment.color)
                                            .frame(width: 8, height: 8)
                                            .padding(.top, 6)
                                        Text(line)
                                            .font(.system(.body, design: .rounded))
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("Done")) { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.mint)
                }
            }
        }
    }
}
