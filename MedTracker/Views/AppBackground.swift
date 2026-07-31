import SwiftUI

/// Soft mint mesh-style background matching Splash colours.
struct AppBackground: View {
    var body: some View {
        ZStack {
            // Base wash — splash mint tones, kept light for cards
            LinearGradient(
                colors: [
                    Color.mint.opacity(0.28),
                    Color.white,
                    Color.mint.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Soft bright highlight (upper-right), like the reference style
            RadialGradient(
                colors: [
                    Color.white.opacity(0.95),
                    Color.white.opacity(0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.88, y: 0.12),
                startRadius: 10,
                endRadius: 320
            )
            
            // Deeper mint glow (bottom / center-right)
            RadialGradient(
                colors: [
                    Color.mint.opacity(0.55),
                    Color.mint.opacity(0.18),
                    Color.clear
                ],
                center: UnitPoint(x: 0.75, y: 0.78),
                startRadius: 20,
                endRadius: 380
            )
            
            // Soft mint accent (top-left)
            RadialGradient(
                colors: [
                    Color.mint.opacity(0.4),
                    Color.mint.opacity(0.12),
                    Color.clear
                ],
                center: UnitPoint(x: 0.12, y: 0.22),
                startRadius: 10,
                endRadius: 300
            )
            
            // Gentle center blend
            RadialGradient(
                colors: [
                    Color.mint.opacity(0.2),
                    Color.clear
                ],
                center: UnitPoint(x: 0.45, y: 0.5),
                startRadius: 40,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}
