// Port of `com.origamitoolbox.oripa.resource.ProjectValue` (oripa-port src/js/core/resource/ProjectValue.js).
//
// Android `Context.getFilesDir()` has no equivalent here: the path helpers return
// project-relative paths unless an explicit base directory is passed (mirrors the JS port).
public enum ProjectValue {
    public static let KEY_DIALOG = "DialogFragment.dialog"
    public static let PROJECT_SUBDIRECTORY = "project_data"
    public static let REQUEST_CODE_PREVIEW = 1
    public static let RESULT_CODE_COPY = 4
    public static let RESULT_CODE_DELETE = 5
    public static let RESULT_CODE_NO_CHANGE = -1
    public static let RESULT_CODE_RENAME = 3
    public static let THUMBNAIL_SUBDIRECTORY = "project_thumbs"
    public static let TEMP_SAVE_FILENAME = "temp_save_file"

    private static func join(_ baseDirectory: String?, _ name: String) -> String {
        guard let baseDirectory, !baseDirectory.isEmpty else { return name }
        return baseDirectory + "/" + name
    }

    /// Java `getProjectDirectory(base)`.
    public static func getProjectDirectory(_ baseDirectory: String? = nil) -> String {
        join(baseDirectory, PROJECT_SUBDIRECTORY)
    }

    /// Java `getTempSaveFile(base)`.
    public static func getTempSaveFile(_ baseDirectory: String? = nil) -> String {
        join(baseDirectory, TEMP_SAVE_FILENAME)
    }

    /// Java `getThumbDirectory(base)`.
    public static func getThumbDirectory(_ baseDirectory: String? = nil) -> String {
        join(baseDirectory, THUMBNAIL_SUBDIRECTORY)
    }
}
