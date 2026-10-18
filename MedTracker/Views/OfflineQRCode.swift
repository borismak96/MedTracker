import UIKit
import CoreImage.CIFilterBuiltins

enum OfflineQRCode {
    static func image(from string: String, dimension: CGFloat = 220) -> UIImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let message = Data(trimmed.utf8)
        // Prefer M for damaged prints; fall back to L if the payload needs more room.
        for level in ["M", "L"] {
            let filter = CIFilter.qrCodeGenerator()
            filter.message = message
            filter.correctionLevel = level
            guard let output = filter.outputImage, output.extent.width > 0 else { continue }
            let scale = dimension / output.extent.width
            let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let context = CIContext()
            guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { continue }
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
