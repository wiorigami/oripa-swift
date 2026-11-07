// Android SharedPreferences equivalent.
//
// Port of the `prefs` object of `src/js/platform.js` (which was itself the bridge to the
// previous WKWebView shell's `NSUserDefaults` storage). Compatibility notes:
//   * the previous native shell stored every preference as a **String** under
//     `oripa.pref.<key>` in `UserDefaults.standard`; the same keys/storage are used here,
//     so preferences survive an upgrade from the WKWebView build;
//   * `clear()` removes every `oripa.pref.*` entry (Android `SharedPreferences.clear()`),
//     keeping the Android quirk that opening a project/editor clears the settings
//     (`ProjectsActivity`/`PreviewCreasePatternActivity` call it before starting the editor).
import Foundation

#if canImport(Combine)
import Combine
#endif

/// Persisted preference store with Android `SharedPreferences` semantics.
@MainActor
public final class Preferences: ObservableObject {

    /// UserDefaults key prefix used by the WKWebView port (keep for data compatibility).
    nonisolated public static let keyPrefix = "oripa.pref."

    private let defaults: UserDefaults
    private let prefix: String

    /// Incremented on every mutation so SwiftUI screens that read prefs can re-render.
    @Published public private(set) var revision: Int = 0

    public init(defaults: UserDefaults = .standard, prefix: String = Preferences.keyPrefix) {
        self.defaults = defaults
        self.prefix = prefix
    }

    // MARK: - Reading

    /// Raw string value, like `prefs.get(key)`; `nil` when unset (JS `null`).
    public func value(_ key: String) -> String? {
        if let string = defaults.string(forKey: prefix + key) {
            return string
        }
        // The previous shell always wrote strings, but be tolerant of typed legacy values.
        if let number = defaults.object(forKey: prefix + key) as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    /// `prefs.getBool`: only "true"/"false" strings count, otherwise the default.
    public func bool(_ key: String, default defaultValue: Bool) -> Bool {
        guard let value = value(key) else { return defaultValue }
        switch value.lowercased() {
        case "true": return true
        case "false": return false
        default: return defaultValue
        }
    }

    /// `prefs.getInt`: `parseInt(value, 10)`, fall back to the default when unparsable.
    public func int(_ key: String, default defaultValue: Int) -> Int {
        guard let value = value(key) else { return defaultValue }
        return Preferences.parseInt(value) ?? defaultValue
    }

    /// `prefs.get` for non-numeric preferences (e.g. grid type "0"/"1").
    public func string(_ key: String, default defaultValue: String) -> String {
        value(key) ?? defaultValue
    }

    // MARK: - Writing (all values are stored as strings, exactly like the JS port)

    public func setBool(_ value: Bool, for key: String) {
        setString(value ? "true" : "false", for: key)
    }

    public func setInt(_ value: Int, for key: String) {
        setString(String(value), for: key)
    }

    public func setString(_ value: String, for key: String) {
        defaults.set(value, forKey: prefix + key)
        bump()
    }

    /// `prefs.remove(key)`.
    public func remove(_ key: String) {
        defaults.removeObject(forKey: prefix + key)
        bump()
    }

    /// Android `SharedPreferences.clear()` — drops every ORIPA preference.
    ///
    /// Quirk kept on purpose: `ProjectsActivity` / `PreviewCreasePatternActivity` clear the
    /// default preferences right before opening the editor, and `EditorActivity.cleanAndExit()`
    /// clears them again on exit, so settings are reset with every project open/close
    /// (matching ORIPA for Android 0.2.3.3).
    public func clear() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        bump()
    }

    /// Snapshot of every ORIPA preference with the prefix stripped (JS native bridge payload).
    public func snapshot() -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            out[String(key.dropFirst(prefix.count))] = value
        }
        return out
    }

    /// True when the key has never been written.
    public func contains(_ key: String) -> Bool {
        defaults.object(forKey: prefix + key) != nil
    }

    // MARK: - Defaults for the paint/settings preferences
    //
    // Values transcribed from `res/xml/pref_paint_cp_settings.xml` + `res/values/integers.xml`
    // and mirrored by `src/js/ui/screens/settings.js` and `editor.js`.

    public enum Key {
        public static let showGrid = "paint_pref_show_grid"
        public static let gridDivisions = "paint_pref_grid_divisions"
        public static let gridType = "paint_pref_grid_type"
        public static let showMvbLines = "paint_pref_show_mvb_lines"
        public static let showFlatLines = "paint_pref_show_flat_lines"
        public static let showVertices = "paint_pref_show_vertices"
        public static let useDashedLines = "paint_pref_use_dashed_lines"
        public static let directSelection = "paint_pref_direct_selection"
        public static let foldOverlap = "paint_pref_fold_overlap"
        public static let foldOverlapShadow = "paint_pref_fold_overlap_shadow"
    }

    public enum Default {
        public static let gridDivisions = 4
        public static let gridMin = 2
        public static let gridMax = 256
    }

    // MARK: - Helpers

    /// JavaScript `parseInt(value, 10)` (leading whitespace/sign/digits, ignores the rest).
    public static func parseInt(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        var sign = 1
        var digits = ""
        for (index, character) in trimmed.enumerated() {
            if index == 0 && (character == "-" || character == "+") {
                sign = character == "-" ? -1 : 1
                continue
            }
            if character.isNumber {
                digits.append(character)
            } else {
                break
            }
        }
        guard !digits.isEmpty, let magnitude = Int(digits) else { return nil }
        return sign * magnitude
    }

    private func bump() {
        revision &+= 1
    }
}
