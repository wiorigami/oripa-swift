// Asset loader + Material icon view.
//
// Every icon is a PNG rasterised from the APK's vector drawables (the same assets the
// web port inlined as SVG). They live in ORIPAUI/Resources/Icons/<name>.png and keep
// the original SVG basename, e.g. `ic_undo_dark_24dp`, `ic_oripa_line_v3`.
//
// A `tint` renders the PNG as a template image (alpha mask) in that colour; without a
// tint the multi-colour drawables keep their original colours.
//
// The APK drawables for the "dark" variants bake a 54 %-black fill (alpha 138/255) into
// the raster. Treating that alpha as a mask and multiplying it by an already translucent
// tint (rgba(0,0,0,.54) for `iconActive`) produced a double-faded icon (71 % grey instead
// of 54 %, i.e. noticeably lighter than the reference). When a tint is supplied we
// therefore normalise the asset alpha to full coverage first, so only the tint carries
// the opacity. The same normalisation keeps `iconInactive` / white icons exact.
//
// Consumed by every UI workstream — keep this API stable, extend only additively.
//
// Resources are resolved through `ORIPAUIResources` (not `Bundle.module`) so the same
// loader works for `swift run`, the packaged macOS .app (Contents/Resources) and the iOS
// app bundle with a valid code signature.
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum AssetLoader {
    /// PNG bytes for an icon (original colours), or nil when the asset is missing.
    public static func pngData(_ name: String) -> Data? {
        guard let url = ORIPAUIResources.url(forResource: name, withExtension: "png") else { return nil }
        return try? Data(contentsOf: url)
    }

    public static func image(_ name: String) -> Image? {
        guard let url = ORIPAUIResources.url(forResource: name, withExtension: "png") else { return nil }
        #if canImport(UIKit)
        guard let ui = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: ui)
        #elseif canImport(AppKit)
        guard let ns = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: ns)
        #else
        return nil
        #endif
    }

    /// Platform bitmap for an icon (used for alpha normalisation), or nil.
    static func cgImage(_ name: String) -> CGImage? {
        #if canImport(UIKit)
        guard let url = ORIPAUIResources.url(forResource: name, withExtension: "png"),
              let ui = UIImage(contentsOfFile: url.path) else { return nil }
        return ui.cgImage
        #elseif canImport(AppKit)
        guard let url = ORIPAUIResources.url(forResource: name, withExtension: "png"),
              let ns = NSImage(contentsOf: url) else { return nil }
        var rect = CGRect(origin: .zero, size: ns.size)
        return ns.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
}

// MARK: - Tint mask normalisation

/// Cache of alpha-normalised template icons (the mask is independent of the tint colour).
private enum OrIconMaskCache {
    static var images: [String: Image] = [:]
}

/// The icon shape with its baked-in fill opacity removed, so the supplied tint alpha is
/// the only opacity applied when SwiftUI renders it as a template.
private func orTemplateImage(_ name: String) -> Image? {
    if let cached = OrIconMaskCache.images[name] { return cached }
    guard let source = AssetLoader.cgImage(name) else { return nil }
    let width = source.width
    let height = source.height
    guard width > 0, height > 0 else { return nil }

    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    var normalized: CGImage?
    bytes.withUnsafeMutableBytes { buffer in
        guard let ctx = CGContext(data: buffer.baseAddress,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return
        }
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        let raw = buffer.bindMemory(to: UInt8.self)
        var maxAlpha: UInt8 = 0
        for i in stride(from: 3, to: raw.count, by: 4) {
            if raw[i] > maxAlpha { maxAlpha = raw[i] }
        }
        // Fully opaque rasters (the "light" / custom icons) need no normalisation.
        guard maxAlpha > 0, maxAlpha < 250 else {
            normalized = source
            return
        }
        let scale = 255.0 / Double(maxAlpha)
        for i in stride(from: 0, to: raw.count, by: 4) {
            let alpha = UInt8(min(255.0, (Double(raw[i + 3]) * scale).rounded()))
            raw[i] = alpha
            raw[i + 1] = alpha
            raw[i + 2] = alpha
            raw[i + 3] = alpha
        }
        normalized = ctx.makeImage()
    }

    guard let cg = normalized else { return nil }
    let image = Image(decorative: cg, scale: 1)
    OrIconMaskCache.images[name] = image
    return image
}

/// A Material-style icon from the bundled APK drawables.
public struct MaterialIcon: View {
    public let name: String
    public var size: CGFloat
    public var tint: Color?

    public init(_ name: String, size: CGFloat = 24, tint: Color? = nil) {
        self.name = name
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        if let tint {
            // `orTemplateImage` strips the drawable's baked 54 %/38 % fill so the tint
            // alpha is applied exactly once (see the file header).
            if let mask = orTemplateImage(name) {
                mask
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundStyle(tint)
            } else if let image = AssetLoader.image(name) {
                image
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundStyle(tint)
            } else {
                missingAsset
            }
        } else if let image = AssetLoader.image(name) {
            image
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            missingAsset
        }
    }

    private var missingAsset: some View {
        // Missing assets are loud on purpose during development.
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.red.opacity(0.25))
            .frame(width: size, height: size)
    }
}

/// The ORIPA raster logos (1024 px sources).
public struct OripaLogo: View {
    public enum Variant {
        case mark       // oripa_logo_v3_raster
        case wordmark   // oripa_logo_text_v2_raster
    }

    public let variant: Variant
    public var height: CGFloat

    public init(_ variant: Variant, height: CGFloat = 72) {
        self.variant = variant
        self.height = height
    }

    public var body: some View {
        let name = variant == .mark ? "oripa_logo_v3_raster" : "oripa_logo_text_v2_raster"
        if let image = AssetLoader.image(name) {
            image.resizable().interpolation(.high).scaledToFit().frame(height: height)
        } else {
            Text("ORIPA").font(.largeTitle.bold())
        }
    }
}
