// Port of `com.origamitoolbox.oripa.resource.ProjectKey` (oripa-port src/js/core/resource/ProjectKey.js).
//
// Java enum used as Intent/Bundle keys between the project screens. `getKey()` builds the exact
// Android key string `com.origamitoolbox.oripa.ProjectKey.<NAME>`.
import Foundation

public enum ProjectKey: String, CaseIterable, Sendable {
    case SRC_ADAPTER_POSITION
    case SRC_FILENAME_NO_EXT
    case SRC_FILENAME_WITH_EXT
    case SRC_PROJECT_DIR_PATH
    case SRC_THUMB_DIR_PATH
    case SRC_PROJECT_FILE_PATH
    case SRC_THUMB_FILE_PATH
    case SRC_IS_INTERNAL
    case RESULT_CODE
    case RESULT_FILENAME_NO_EXT

    /// Java `name()`.
    public var name: String { rawValue }

    /// Java `ordinal()`.
    public var ordinal: Int { ProjectKey.allCases.firstIndex(of: self) ?? 0 }

    public func toString() -> String { name }

    /// Java `getKey()`.
    public func getKey() -> String { "com.origamitoolbox.oripa.ProjectKey." + name }

    public var key: String { getKey() }

    /// Java `values()`.
    public static func values() -> [ProjectKey] { allCases }

    /// Java `valueOf(String)`.
    public static func valueOf(_ name: String) -> ProjectKey? {
        ProjectKey(rawValue: name)
    }
}
