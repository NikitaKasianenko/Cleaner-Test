import SwiftUI
import Photos

struct AssetImageView: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(UIColor.systemGray5))
            }
        }
        // ✅ id: asset.localIdentifier prevents stale image loading when cells reuse
        .task(id: asset.localIdentifier) {
            image = await loadImage(targetSize: CGSize(width: 250, height: 250), scale: displayScale)
        }
    }

    private func loadImage(targetSize: CGSize, scale: CGFloat) async -> UIImage? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        // ✅ highQualityFormat = one delivery, not multiple callbacks
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        let requestSize = CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )

        // ✅ withCheckedContinuation bridges callback → async safely (resumes exactly once)
        return await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: requestSize,
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }
}
