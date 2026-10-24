import SwiftUI
import UIKit

/// On-device JPEG helper for medication identification photos.
enum MedicationPhoto {
    static let maxPixel: CGFloat = 720
    static let maxBytes = 400_000
    
    static func jpegData(from image: UIImage) -> Data? {
        let scaled = image.resizedToMaxDimension(Self.maxPixel)
        var quality: CGFloat = 0.72
        var data = scaled.jpegData(compressionQuality: quality)
        while let current = data, current.count > Self.maxBytes, quality > 0.28 {
            quality -= 0.12
            data = scaled.jpegData(compressionQuality: quality)
        }
        return data
    }
    
    static func jpegData(from raw: Data) -> Data? {
        guard let image = UIImage(data: raw) else { return raw.isEmpty ? nil : raw }
        return jpegData(from: image) ?? raw
    }
}

private extension UIImage {
    func resizedToMaxDimension(_ maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

struct MedicationPhotoView: View {
    var data: Data?
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 10
    
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.mint.opacity(0.14))
                    Image(systemName: "pills.fill")
                        .font(.system(size: max(14, size * 0.38), weight: .semibold))
                        .foregroundColor(.mint)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.mint.opacity(0.25), lineWidth: 1)
        )
        .accessibilityHidden(data == nil)
    }
}

/// Camera capture for medication photos. Hidden when the simulator has no camera.
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: DismissAction
        
        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }
    }
}
