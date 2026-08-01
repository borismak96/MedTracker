import SwiftUI

/// Flat, soft face icons that match PillPal’s pastel mint UI (not system emoji).
struct MoodFaceView: View {
    let mood: MoodStatus
    var size: CGFloat = 28
    var isSelected: Bool = false
    
    private var faceFill: Color {
        switch mood {
        case .terrible: return Color(red: 0.72, green: 0.78, blue: 0.98) // soft indigo
        case .bad: return Color(red: 0.72, green: 0.88, blue: 0.98) // soft blue
        case .neutral: return Color(red: 0.90, green: 0.92, blue: 0.93) // soft gray
        case .good: return Color(red: 1.0, green: 0.90, blue: 0.78) // soft peach
        case .excellent: return Color(red: 1.0, green: 0.93, blue: 0.55) // soft yellow
        }
    }
    
    private var featureColor: Color {
        switch mood {
        case .terrible: return Color(red: 0.35, green: 0.40, blue: 0.70)
        case .bad: return Color(red: 0.30, green: 0.48, blue: 0.68)
        case .neutral: return Color(red: 0.45, green: 0.50, blue: 0.52)
        case .good: return Color(red: 0.70, green: 0.42, blue: 0.22)
        case .excellent: return Color(red: 0.62, green: 0.48, blue: 0.12)
        }
    }
    
    var body: some View {
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let inset = side * 0.06
            let rect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
            
            // Soft face disc
            context.fill(Path(ellipseIn: rect), with: .color(faceFill))
            
            // Subtle inner highlight for a soft “app icon” look
            let highlight = CGRect(
                x: rect.minX + rect.width * 0.18,
                y: rect.minY + rect.height * 0.12,
                width: rect.width * 0.38,
                height: rect.height * 0.28
            )
            context.fill(Path(ellipseIn: highlight), with: .color(.white.opacity(0.35)))
            
            let eyeY = rect.minY + rect.height * 0.40
            let leftEyeX = rect.minX + rect.width * 0.33
            let rightEyeX = rect.minX + rect.width * 0.67
            let eyeR = side * 0.055
            
            switch mood {
            case .terrible:
                drawXEye(context: context, center: CGPoint(x: leftEyeX, y: eyeY), size: side * 0.12, color: featureColor)
                drawXEye(context: context, center: CGPoint(x: rightEyeX, y: eyeY), size: side * 0.12, color: featureColor)
                drawMouth(context: context, in: rect, curve: -0.22, open: true, color: featureColor, side: side)
            case .bad:
                drawDotEye(context: context, center: CGPoint(x: leftEyeX, y: eyeY), radius: eyeR, color: featureColor)
                drawDotEye(context: context, center: CGPoint(x: rightEyeX, y: eyeY), radius: eyeR, color: featureColor)
                drawMouth(context: context, in: rect, curve: -0.16, open: false, color: featureColor, side: side)
            case .neutral:
                drawDotEye(context: context, center: CGPoint(x: leftEyeX, y: eyeY), radius: eyeR, color: featureColor)
                drawDotEye(context: context, center: CGPoint(x: rightEyeX, y: eyeY), radius: eyeR, color: featureColor)
                drawFlatMouth(context: context, in: rect, color: featureColor, side: side)
            case .good:
                drawDotEye(context: context, center: CGPoint(x: leftEyeX, y: eyeY), radius: eyeR, color: featureColor)
                drawDotEye(context: context, center: CGPoint(x: rightEyeX, y: eyeY), radius: eyeR, color: featureColor)
                drawMouth(context: context, in: rect, curve: 0.16, open: false, color: featureColor, side: side)
            case .excellent:
                drawHappyEye(context: context, center: CGPoint(x: leftEyeX, y: eyeY), size: side * 0.11, color: featureColor)
                drawHappyEye(context: context, center: CGPoint(x: rightEyeX, y: eyeY), size: side * 0.11, color: featureColor)
                drawMouth(context: context, in: rect, curve: 0.22, open: true, color: featureColor, side: side)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: mood.color.opacity(isSelected ? 0.28 : 0.12), radius: isSelected ? 4 : 2, y: 1)
    }
    
    private func drawDotEye(context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let r = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: r), with: .color(color))
    }
    
    private func drawXEye(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        var path = Path()
        let h = size * 0.45
        path.move(to: CGPoint(x: center.x - h, y: center.y - h))
        path.addLine(to: CGPoint(x: center.x + h, y: center.y + h))
        path.move(to: CGPoint(x: center.x + h, y: center.y - h))
        path.addLine(to: CGPoint(x: center.x - h, y: center.y + h))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: size * 0.22, lineCap: .round))
    }
    
    private func drawHappyEye(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: center.x - size * 0.5, y: center.y + size * 0.1))
        path.addQuadCurve(
            to: CGPoint(x: center.x + size * 0.5, y: center.y + size * 0.1),
            control: CGPoint(x: center.x, y: center.y - size * 0.55)
        )
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: size * 0.28, lineCap: .round))
    }
    
    private func drawFlatMouth(context: GraphicsContext, in rect: CGRect, color: Color, side: CGFloat) {
        let y = rect.minY + rect.height * 0.68
        let inset = rect.width * 0.28
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: y))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: side * 0.055, lineCap: .round))
    }
    
    private func drawMouth(context: GraphicsContext, in rect: CGRect, curve: CGFloat, open: Bool, color: Color, side: CGFloat) {
        let midY = rect.minY + rect.height * 0.66
        let inset = rect.width * 0.26
        let start = CGPoint(x: rect.minX + inset, y: midY)
        let end = CGPoint(x: rect.maxX - inset, y: midY)
        let control = CGPoint(x: rect.midX, y: midY + rect.height * curve)
        
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        
        if open {
            // Soft filled open mouth
            var fill = Path()
            fill.move(to: start)
            fill.addQuadCurve(to: end, control: control)
            fill.addLine(to: start)
            fill.closeSubpath()
            context.fill(fill, with: .color(color.opacity(0.22)))
        }
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: side * 0.055, lineCap: .round))
    }
}

/// Circular mood chip used in pickers.
struct MoodFaceChip: View {
    let mood: MoodStatus
    var isSelected: Bool = false
    var diameter: CGFloat = 44
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? mood.color.opacity(0.18) : Color(UIColor.systemGray6))
                .frame(width: diameter, height: diameter)
            
            MoodFaceView(mood: mood, size: diameter * 0.72, isSelected: isSelected)
        }
        .overlay(
            Circle()
                .stroke(isSelected ? Color.mint.opacity(0.75) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.08 : 1.0)
    }
}
