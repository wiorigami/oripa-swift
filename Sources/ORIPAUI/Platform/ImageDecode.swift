// Small cross-platform image decoding/encoding helpers.
//
// The project thumbnails are raw PNG bytes in `project_thumbs/<name>` (no extension), so
// they are decoded directly from data instead of the bundled asset loader. The headless
// snapshot/thumbnail renderer produces a `CGImage` via SwiftUI `ImageRenderer`, which is
// encoded back to PNG bytes here with ImageIO (works on both macOS and iOS).
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum OripaImage {
    /// Decode PNG/JPEG bytes into a SwiftUI image (nil when the data is not a valid image).
    public static func image(data: Data) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }

    /// Pixel size of encoded image data, when available (thumbnail aspect handling).
    public static func pixelSize(data: Data) -> CGSize? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return image.size
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return image.size
        #else
        return nil
        #endif
    }

    /// Encode a `CGImage` as PNG data (used by the snapshot/thumbnail renderers).
    public static func pngData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
