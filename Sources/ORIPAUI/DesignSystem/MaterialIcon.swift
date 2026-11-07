// Asset loader + Material icon view.
//
// Every icon is a PNG rasterised from the APK's vector drawables (the same assets the
// web port inlined as SVG). They live in ORIPAUI/Resources/Icons/<name>.png and keep
// the original SVG basename, e.g. `ic_undo_dark_24dp`, `ic_oripa_line_v3`.
//
// A `tint` renders the PNG as a template image (alpha mask) in that colour; without a
// tint the multi-colour drawables keep their original colours.
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
        if let image = AssetLoader.image(name) {
            image
                .resizable()
                .renderingMode(tint == nil ? .original : .template)
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(tint ?? Color.primary)
        } else {
            // Missing assets are loud on purpose during development.
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red.opacity(0.25))
                .frame(width: size, height: size)
        }
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
