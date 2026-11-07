// App identity constants (ported from ORIPA for Android 0.2.3.3).
//
// The bundle identifier intentionally matches the Android/iPad port so that a native
// build installed over the previous WKWebView build keeps the same app container and
// therefore the user's existing `Documents/project_data` crease-pattern files.
import Foundation

public enum AppInfo {
    /// Marketing version — must stay "0.2.3.3" for parity with the ported app.
    public static let version = "0.2.3.3"
    /// Monotonic build number (1 = the original ported app).
    public static let build = "2"
    /// Bundle identifier used by the iOS target and the macOS app bundle.
    public static let bundleIdentifier = "com.origamitoolbox.oripa"
    /// App name shown on the home screen.
    public static let displayName = "ORIPA"
    /// Documents sub-directories of the Android internal storage layout.
    public static let projectDataDirectory = "project_data"
    public static let projectThumbDirectory = "project_thumbs"
    public static let importDataDirectory = "import_data"
    public static let tempSaveFile = "temp_save_file"
}
