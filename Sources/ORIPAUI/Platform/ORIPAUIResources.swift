// Resource bundle resolver for the ORIPAUI assets (icons + logos).
//
// SwiftPM's generated `Bundle.module` accessor only looks for
// `<Bundle.main.bundleURL>/ORIPA_ORIPAUI.bundle` when running from an executable product on
// macOS. In a hand-assembled `ORIPA.app` bundle that would have to live at the bundle ROOT,
// which makes codesign report "unsealed contents present in the bundle root". The resolver
// below checks the standard `Contents/Resources` location first (macOS .app), then the
// `swift run` build directory, then the class/framework bundle (iOS frameworks), so the
// same asset loader works in every packaging form while keeping a valid code signature.
import Foundation

/// Locates the `ORIPA_ORIPAUI.bundle` produced by SwiftPM's resource processing.
public enum ORIPAUIResources {
    private final class BundleFinder {}

    /// The resource bundle, when it can be found in one of the known locations.
    public static let bundle: Bundle? = {
        let name = "ORIPA_ORIPAUI"
        let candidates: [URL?] = [
            Bundle.main.resourceURL,                                    // .app/Contents/Resources (macOS), iOS .app
            Bundle.main.bundleURL,                                      // `swift run`: .build/<config>
            Bundle(for: BundleFinder.self).resourceURL,                 // framework/static-link resources
            Bundle(for: BundleFinder.self).bundleURL,
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true),
        ]
        for candidate in candidates {
            guard let candidate else { continue }
            let url = candidate.appendingPathComponent(name + ".bundle", isDirectory: true)
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()

    /// URL of a bundled PNG resource (icon basenames have no extension).
    public static func url(forResource name: String, withExtension ext: String) -> URL? {
        if let url = bundle?.url(forResource: name, withExtension: ext) {
            return url
        }
        // Last-resort fallbacks for hosts where the bundle is embedded directly.
        return Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle(for: BundleFinder.self).url(forResource: name, withExtension: ext)
    }
}
