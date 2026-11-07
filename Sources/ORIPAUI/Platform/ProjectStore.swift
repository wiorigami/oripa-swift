// Persistent on-disk project storage.
//
// HARD USER REQUIREMENT: crease-pattern projects are real files on disk, in the exact
// Android/WKWebView-port layout inside the app's Documents directory:
//
//   Documents/project_data/<name>        OPXC bytes (no extension; name == srcFilenameNoExt)
//   Documents/project_thumbs/<name>      PNG thumbnail bytes (no extension)
//   Documents/import_data/<file.ext>     staging area for files picked from Files.app
//   Documents/temp_save_file             crash-safe autosave (OPXC bytes)
//   Documents/temp_save_meta.json        autosave metadata (this native port)
//
// The layout and the bundle identifier (`AppInfo.bundleIdentifier`) are identical to the
// previous WKWebView app, so projects created by that build are still listed/served after
// upgrading. Every write is atomic (`Data.write(options: .atomic)` = temp file + rename),
// so a crash can never leave a half-written project or autosave file.
//
// Port of `ORIPA.ui.projectStore` (`src/js/ui/dialogs/project_dialogs.js`), the filesystem
// part of `src/js/platform.js`, and the unique-name rules of
// `com.origamitoolbox.oripa.io.export.Exporter` (name / name-1 / … and name-copy /
// name-copy-copy / …).
import Foundation

#if canImport(Combine)
import Combine
#endif
import ORIPACore

// MARK: - ProjectInfo

/// One internal project file (`ProjectInfo` of the Android project list).
public struct ProjectInfo: Identifiable, Hashable {
    /// Internal file name without extension (== `srcFilenameNoExt`).
    public let name: String
    /// Last-modified date from the file system attributes.
    public let modifiedAt: Date
    /// File size in bytes.
    public let size: Int

    public init(name: String, modifiedAt: Date, size: Int) {
        self.name = name
        self.modifiedAt = modifiedAt
        self.size = size
    }

    public var id: String { name }

    /// `ProjectInfo.compareByModified`: newest first.
    public static func compareByModified(_ a: ProjectInfo, _ b: ProjectInfo) -> Bool {
        if a.modifiedAt != b.modifiedAt { return a.modifiedAt > b.modifiedAt }
        return compareByName(a, b)
    }

    /// `ProjectInfo.compareByName`: `compareToIgnoreCase` ascending.
    public static func compareByName(_ a: ProjectInfo, _ b: ProjectInfo) -> Bool {
        let an = a.name.lowercased()
        let bn = b.name.lowercased()
        if an != bn { return an < bn }
        return a.name < b.name
    }
}

// MARK: - Temporary autosave metadata

/// Metadata stored next to `temp_save_file` so a crash-recovered draft can be reopened
/// with the right project name / entry parameters.
public struct TempSaveMeta: Codable, Equatable {
    /// When the autosave was written.
    public var savedAt: Date
    /// Internal project name, when the draft belongs to an existing `project_data` file.
    public var projectName: String?
    /// Editor session file name without extension (the name the save dialog proposes).
    public var srcFilenameNoExt: String
    /// EditorSession `srcIsInternal` flag.
    public var srcIsInternal: Bool
    /// Currently shown fragment, e.g. "paint" / "check" / "fold" (informational).
    public var fragment: String?
    /// Whether the crease pattern was modified when autosaved.
    public var modified: Bool

    public init(savedAt: Date = Date(),
                projectName: String? = nil,
                srcFilenameNoExt: String = "",
                srcIsInternal: Bool = true,
                fragment: String? = nil,
                modified: Bool = true) {
        self.savedAt = savedAt
        self.projectName = projectName
        self.srcFilenameNoExt = srcFilenameNoExt
        self.srcIsInternal = srcIsInternal
        self.fragment = fragment
        self.modified = modified
    }
}

// MARK: - Staged import

/// A file picked by the document picker, written to `import_data/` so the editor session
/// can load it through the same path-based APIs the Android app used for external files.
public struct StagedImport {
    /// Unique staged file name, e.g. `crane.opx` or `crane-1.opx`.
    public let name: String
    /// The picked bytes.
    public let data: Data
    /// Absolute URL of the staged file.
    public let url: URL

    public init(name: String, data: Data, url: URL) {
        self.name = name
        self.data = data
        self.url = url
    }

    /// Extension without the dot, lower-cased (`FileUtil.getFileExt`).
    public var fileExtension: String {
        ProjectStore.fileExtension(of: name)
    }

    /// File name without extension (`FileUtil.getFilenameNoExt`).
    public var filenameNoExt: String {
        ProjectStore.filenameNoExt(name)
    }
}

// MARK: - Errors

public enum ProjectStoreError: Error, LocalizedError, Equatable {
    case invalidName(String)
    case projectNotFound(String)
    case writeFailed(String)
    case renameFailed(String)
    case copyFailed(String)
    case deleteFailed(String)
    case stagingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let name): return "Invalid project name: \(name)"
        case .projectNotFound(let name): return "Project not found: \(name)"
        case .writeFailed(let message): return "Could not save project: \(message)"
        case .renameFailed(let message): return "Could not rename project: \(message)"
        case .copyFailed(let message): return "Could not copy project: \(message)"
        case .deleteFailed(let message): return "Could not delete project: \(message)"
        case .stagingFailed(let message): return "Could not stage imported file: \(message)"
        }
    }
}

// MARK: - ProjectStore

/// Disk-backed project store with the Android internal-storage directory layout.
@MainActor
public final class ProjectStore: ObservableObject {

    // MARK: Directories

    /// Application data root (the app's `Documents` directory).
    public let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// `Documents/project_data`.
    public var projectDataURL: URL { rootURL.appendingPathComponent(AppInfo.projectDataDirectory, isDirectory: true) }
    /// `Documents/project_thumbs`.
    public var projectThumbURL: URL { rootURL.appendingPathComponent(AppInfo.projectThumbDirectory, isDirectory: true) }
    /// `Documents/import_data`.
    public var importDataURL: URL { rootURL.appendingPathComponent(AppInfo.importDataDirectory, isDirectory: true) }
    /// `Documents/temp_save_file`.
    public var tempSaveURL: URL { rootURL.appendingPathComponent(AppInfo.tempSaveFile, isDirectory: false) }
    /// `Documents/temp_save_meta.json` (native addition next to the Android temp file).
    public var tempSaveMetaURL: URL { rootURL.appendingPathComponent(AppInfo.tempSaveFile + "_meta.json", isDirectory: false) }

    // MARK: Published state

    /// Internal projects, newest modified first (screens may re-sort).
    @Published public private(set) var projects: [ProjectInfo] = []
    /// Thumbnail modification dates keyed by project name (thumbnail cache key).
    @Published public private(set) var thumbMtimes: [String: Date] = [:]

    /// Set by `AppModel` so `prepareProjectOpen()` can mirror the Android prefs clearing.
    public weak var preferences: Preferences?

    /// Pluggable OPXC→PNG thumbnail renderer, installed by the app once the CP renderer is
    /// available (keeps this store free of rendering dependencies). Returns PNG bytes.
    public static var thumbnailRenderer: ((Data) -> Data?)?

    /// Names already repaired in this session (avoid retrying broken projects on every render).
    private var thumbnailRepairAttempts: Set<String> = []

    // MARK: Init

    public init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? ProjectStore.defaultRootURL(fileManager: fileManager)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder
        if rootURL == nil {
            ProjectStore.migrateLegacyDocumentsIfNeeded(into: self.rootURL, fileManager: fileManager)
        }
        createDirectories()
        reload()
    }

    /// macOS only: copy the old WKWebView-port `Documents/{project_data,project_thumbs}` over
    /// when Application Support is still empty (best effort, never overwrites).
    private static func migrateLegacyDocumentsIfNeeded(into destination: URL, fileManager: FileManager) {
        #if os(macOS)
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let legacyProjectData = documents.appendingPathComponent(AppInfo.projectDataDirectory, isDirectory: true)
        let newProjectData = destination.appendingPathComponent(AppInfo.projectDataDirectory, isDirectory: true)
        let newContents = (try? fileManager.contentsOfDirectory(atPath: newProjectData.path)) ?? []
        guard newContents.isEmpty,
              let legacyContents = try? fileManager.contentsOfDirectory(atPath: legacyProjectData.path),
              !legacyContents.isEmpty else {
            return
        }
        try? fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for directory in [AppInfo.projectDataDirectory, AppInfo.projectThumbDirectory] {
            let from = documents.appendingPathComponent(directory, isDirectory: true)
            let to = destination.appendingPathComponent(directory, isDirectory: true)
            guard fileManager.fileExists(atPath: from.path),
                  !fileManager.fileExists(atPath: to.path) else { continue }
            try? fileManager.copyItem(at: from, to: to)
        }
        #endif
    }

    /// Default application data root.
    ///
    /// * iOS/iPadOS: the app's `Documents` directory — the same container the previous
    ///   WKWebView port used, so existing user projects survive the upgrade and are visible
    ///   in Files.app (`UIFileSharingEnabled`).
    /// * macOS: `~/Library/Application Support/ORIPA` so running the development app does
    ///   not write into the user's Documents folder. A one-time migration copies the old
    ///   WKWebView-port `Documents` layout over when it is the only existing data.
    nonisolated public static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        #if os(macOS)
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        return base.appendingPathComponent(AppInfo.displayName, isDirectory: true)
        #else
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documents
        }
        // Fallback for exotic hosts (headless snapshot runs): current directory.
        return URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        #endif
    }

    private func createDirectories() {
        for directory in [projectDataURL, projectThumbURL, importDataURL] {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Listing

    /// Re-scan `project_data` (and thumbnail mtimes) from disk.
    public func reload() {
        createDirectories()
        var infos: [ProjectInfo] = []
        let contents = (try? fileManager.contentsOfDirectory(
            at: projectDataURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == false { continue }
            let name = url.lastPathComponent
            if name.isEmpty || name.hasPrefix(".") { continue }
            let modified = values?.contentModificationDate
                ?? (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
                ?? Date.distantPast
            let size = values?.fileSize ?? 0
            infos.append(ProjectInfo(name: name, modifiedAt: modified, size: size))
        }
        infos.sort(by: ProjectInfo.compareByModified)
        projects = infos
        reloadThumbMtimes()
    }

    private func reloadThumbMtimes() {
        var mtimes: [String: Date] = [:]
        let contents = (try? fileManager.contentsOfDirectory(
            at: projectThumbURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            mtimes[url.lastPathComponent] = values?.contentModificationDate ?? Date.distantPast
        }
        thumbMtimes = mtimes
    }

    public func projectInfo(name: String) -> ProjectInfo? {
        projects.first { $0.name == name }
    }

    public func projectExists(name: String) -> Bool {
        fileManager.fileExists(atPath: projectPath(name).path)
    }

    public func hasThumb(name: String) -> Bool {
        fileManager.fileExists(atPath: thumbPath(name).path)
    }

    // MARK: - Paths

    public func projectPath(_ name: String) -> URL {
        projectDataURL.appendingPathComponent(name, isDirectory: false)
    }

    public func thumbPath(_ name: String) -> URL {
        projectThumbURL.appendingPathComponent(name, isDirectory: false)
    }

    // MARK: - Fixed formatting helpers (FileUtil port)

    /// `FileUtil.getFileExt`: substring after the last dot, lower-cased ("" when none).
    nonisolated public static func fileExtension(of filename: String) -> String {
        guard let dot = filename.lastIndex(of: ".") else { return "" }
        let ext = String(filename[filename.index(after: dot)...]).lowercased()
        return ext == filename.lowercased() ? "" : ext
    }

    /// `FileUtil.getFilenameNoExt`.
    nonisolated public static func filenameNoExt(_ filename: String) -> String {
        guard let dot = filename.lastIndex(of: ".") else { return filename }
        return String(filename[..<dot])
    }

    /// `FileUtil.getFilenameWithExt`.
    nonisolated public static func filenameWithExt(_ baseName: String, fileType: FileType) -> String {
        "\(baseName).\(fileType.getExtension())"
    }

    /// `FileUtil.getMimeType` table of the port (nil for unknown extensions).
    nonisolated public static func mimeType(forExtension ext: String) -> String? {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "svg": return "image/svg+xml"
        case "opx", "opxc": return "text/xml"
        case "cp": return "text/plain"
        default: return nil
        }
    }

    /// `FileUtil.getLastModifiedText`: date + time with seconds, locale-aware.
    ///
    /// The JS port used `Date.toLocaleString()` (`dateStyle: "short"`, `timeStyle: "medium"`),
    /// which renders e.g. "2026/10/31 18:22:42" (24 h) on the reference machine. A localized
    /// template is used instead of `dateStyle/timeStyle` so the 24-hour clock matches that
    /// reference output (Foundation's `.medium` time style uses AM/PM in some locales).
    nonisolated public static func lastModifiedText(_ date: Date) -> String {
        format(date, template: "yMdHms")
    }

    /// `FileUtil.getLastModifiedTextShort`: SHORT date + SHORT time (grid captions).
    nonisolated public static func lastModifiedTextShort(_ date: Date) -> String {
        format(date, template: "yMdHm")
    }

    /// Locale-aware `DateFormatter` template formatting (`yMdHms` / `yMdHm`).
    nonisolated private static func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template,
                                                       options: 0,
                                                       locale: Locale.current)
        return formatter.string(from: date)
    }

    /// `ProjectAdapter` list-mode date: "Modified: %s" (`project_list_item_text_modified`).
    nonisolated public static func modifiedText(_ date: Date) -> String {
        "Modified: " + lastModifiedText(date)
    }

    /// `ProjectAdapter` grid-mode short date.
    nonisolated public static func modifiedTextShort(_ date: Date) -> String {
        lastModifiedTextShort(date)
    }

    // MARK: - Unique-name rules (Exporter)

    /// `Exporter.getNewUniqueFile`: `base`, `base-1`, `base-2`, …
    public func uniqueName(base: String) -> String {
        var candidate = base
        var index = 0
        while projectExists(name: candidate) {
            index += 1
            candidate = "\(base)-\(index)"
        }
        return candidate
    }

    /// `Exporter.getNewCopyFile`: `base-copy`, `base-copy-copy`, …
    public func copyName(base: String) -> String {
        var candidate = "\(base)-copy"
        while projectExists(name: candidate) {
            candidate += "-copy"
        }
        return candidate
    }

    /// `exporter.getNewUniqueInternalFile("project_data", base)` used by the editor for a
    /// new "untitled" project.
    public func uniqueInternalName(base: String) -> String {
        uniqueName(base: base)
    }

    // MARK: - Reading / writing project files

    /// Read the OPXC bytes of an internal project (nil when the file is missing/unreadable).
    public func readProject(name: String) -> Data? {
        guard isValidProjectName(name) else { return nil }
        return try? Data(contentsOf: projectPath(name))
    }

    /// Read the PNG thumbnail bytes of an internal project (nil when missing).
    public func readThumb(name: String) -> Data? {
        guard isValidProjectName(name) else { return nil }
        return try? Data(contentsOf: thumbPath(name))
    }

    /// Atomic project write (`EditorActivity.saveChanges`): OPXC bytes + optional PNG thumb.
    public func write(name: String, opxc: Data, thumbPNG: Data?) throws {
        guard isValidProjectName(name) else { throw ProjectStoreError.invalidName(name) }
        do {
            try writeAtomically(opxc, to: projectPath(name))
            if let thumbPNG, !thumbPNG.isEmpty {
                try? writeAtomically(thumbPNG, to: thumbPath(name))
            }
        } catch {
            throw ProjectStoreError.writeFailed(error.localizedDescription)
        }
        thumbnailRepairAttempts.remove(name)
        reload()
    }

    /// Convenience alias used by the editor save flow.
    public func writeProject(name: String, data: Data, thumbnail: Data?) throws {
        try write(name: name, opxc: data, thumbPNG: thumbnail)
    }

    /// Write only the thumbnail of an existing project.
    public func writeThumb(name: String, png: Data) throws {
        guard isValidProjectName(name) else { throw ProjectStoreError.invalidName(name) }
        do {
            try writeAtomically(png, to: thumbPath(name))
        } catch {
            throw ProjectStoreError.writeFailed(error.localizedDescription)
        }
        reloadThumbMtimes()
    }

    /// Rename a project (and its thumbnail). Returns the final unique name.
    ///
    /// Mirrors `ProjectRenameDialogFragment` + `Exporter.getNewUniqueFile`: the entered name
    /// is uniquified (`name`, `name-1`, …) and the thumbnail is renamed with the project; a
    /// failed thumbnail rename rolls the project rename back.
    @discardableResult
    public func rename(oldName: String, to enteredName: String) throws -> String {
        guard isValidProjectName(oldName) else { throw ProjectStoreError.invalidName(oldName) }
        let trimmed = enteredName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProjectStoreError.invalidName(enteredName) }
        guard isValidProjectName(trimmed) else { throw ProjectStoreError.invalidName(enteredName) }
        if trimmed == oldName { return oldName }
        guard projectExists(name: oldName) else { throw ProjectStoreError.projectNotFound(oldName) }
        let target = uniqueName(base: trimmed)
        if target == oldName { return oldName }
        do {
            try fileManager.moveItem(at: projectPath(oldName), to: projectPath(target))
        } catch {
            throw ProjectStoreError.renameFailed(error.localizedDescription)
        }
        if hasThumb(name: oldName) {
            do {
                try fileManager.moveItem(at: thumbPath(oldName), to: thumbPath(target))
            } catch {
                // Roll back the project rename, like the JS port does.
                try? fileManager.moveItem(at: projectPath(target), to: projectPath(oldName))
                throw ProjectStoreError.renameFailed(error.localizedDescription)
            }
        }
        reload()
        return target
    }

    /// Copy a project (and its thumbnail). Returns the generated `name-copy…` name.
    @discardableResult
    public func copy(name: String) throws -> String {
        guard isValidProjectName(name) else { throw ProjectStoreError.invalidName(name) }
        guard projectExists(name: name) else { throw ProjectStoreError.projectNotFound(name) }
        let target = copyName(base: name)
        do {
            try fileManager.copyItem(at: projectPath(name), to: projectPath(target))
        } catch {
            throw ProjectStoreError.copyFailed(error.localizedDescription)
        }
        if hasThumb(name: name) {
            try? fileManager.copyItem(at: thumbPath(name), to: thumbPath(target))
        }
        reload()
        return target
    }

    /// Delete a project and its thumbnail (`ProjectDeleteDialogFragment`).
    public func delete(name: String) throws {
        guard isValidProjectName(name) else { throw ProjectStoreError.invalidName(name) }
        guard projectExists(name: name) else { throw ProjectStoreError.projectNotFound(name) }
        do {
            try fileManager.removeItem(at: projectPath(name))
        } catch {
            throw ProjectStoreError.deleteFailed(error.localizedDescription)
        }
        try? fileManager.removeItem(at: thumbPath(name))
        thumbnailRepairAttempts.remove(name)
        reload()
    }

    /// Delete several projects (`ProjectDeleteMultipleDialogFragment`); returns failures.
    @discardableResult
    public func delete(names: [String]) -> [String] {
        var failures: [String] = []
        for name in names {
            do {
                try delete(name: name)
            } catch {
                failures.append(name)
            }
        }
        return failures
    }

    // MARK: - Thumbnails

    /// Regenerate a missing thumbnail from the OPXC bytes (`ProjectAdapter`/ImageLoader
    /// repair addition of the web port). Returns the written PNG bytes when it worked.
    public func regenerateThumb(name: String) -> Data? {
        if thumbnailRepairAttempts.contains(name) { return nil }
        thumbnailRepairAttempts.insert(name)
        guard let renderer = ProjectStore.thumbnailRenderer,
              let opxc = readProject(name: name),
              let png = renderer(opxc),
              !png.isEmpty else {
            return nil
        }
        try? writeAtomically(png, to: thumbPath(name))
        reloadThumbMtimes()
        return png
    }

    // MARK: - Import staging (`import_data/`)

    /// Write picked bytes into `import_data/<unique name>` for the editor session to read.
    public func createImportStaging(data: Data, filename: String) throws -> StagedImport {
        createDirectories()
        let safeFilename = filename.isEmpty ? "untitled.opxc" : filename
        let base = ProjectStore.filenameNoExt(safeFilename)
        let ext = ProjectStore.fileExtension(of: safeFilename)
        var candidate = safeFilename
        var index = 0
        while fileManager.fileExists(atPath: importDataURL.appendingPathComponent(candidate).path) {
            index += 1
            candidate = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
        }
        let url = importDataURL.appendingPathComponent(candidate)
        do {
            try writeAtomically(data, to: url)
        } catch {
            throw ProjectStoreError.stagingFailed(error.localizedDescription)
        }
        return StagedImport(name: candidate, data: data, url: url)
    }

    /// Read a staged file (editor session external-file path).
    public func readStaging(name: String) -> Data? {
        let url = importDataURL.appendingPathComponent(name)
        guard url.standardizedFileURL.path.hasPrefix(importDataURL.standardizedFileURL.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Remove every staged import (`ProjectsActivity` cleanup after the editor session read it).
    public func cleanupStaging() {
        let contents = (try? fileManager.contentsOfDirectory(
            at: importDataURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }

    public func stagingFiles() -> [String] {
        ((try? fileManager.contentsOfDirectory(atPath: importDataURL.path)) ?? []).sorted()
    }

    // MARK: - Crash-safe autosave (`temp_save_file` + metadata)

    /// Write the crash-safe autosave (`EditorActivity.onStop`); data first, metadata second.
    public func writeTempSave(_ data: Data, meta: TempSaveMeta) {
        createDirectories()
        try? writeAtomically(data, to: tempSaveURL)
        if let encoded = try? encoder.encode(meta) {
            try? writeAtomically(encoded, to: tempSaveMetaURL)
        }
    }

    /// Read a pending autosave + its metadata. Legacy autosaves (WKWebView port: bytes only,
    /// no metadata) are still recoverable with synthesized metadata.
    public func readTempSave() -> (Data, TempSaveMeta)? {
        guard let data = try? Data(contentsOf: tempSaveURL), !data.isEmpty else { return nil }
        if let metaData = try? Data(contentsOf: tempSaveMetaURL),
           let meta = try? decoder.decode(TempSaveMeta.self, from: metaData) {
            return (data, meta)
        }
        let attributes = try? fileManager.attributesOfItem(atPath: tempSaveURL.path)
        let savedAt = (attributes?[.modificationDate] as? Date) ?? Date()
        let legacyName = ProjectStore.filenameNoExt(AppInfo.tempSaveFile)
        return (data, TempSaveMeta(savedAt: savedAt,
                                   projectName: nil,
                                   srcFilenameNoExt: legacyName,
                                   srcIsInternal: true,
                                   fragment: nil,
                                   modified: true))
    }

    /// Metadata of a recoverable draft, if any (used by the launch recovery prompt).
    public func recoverableDraft() -> TempSaveMeta? {
        readTempSave()?.1
    }

    public func deleteTempSave() {
        try? fileManager.removeItem(at: tempSaveURL)
        try? fileManager.removeItem(at: tempSaveMetaURL)
    }

    /// Android `ProjectsActivity`/`PreviewCreasePatternActivity` + `EditorActivity.cleanAndExit`
    /// preparation: clear the default preferences and delete the temporary autosave.
    public func prepareProjectOpen() {
        preferences?.clear()
        deleteTempSave()
    }

    // MARK: - Validation

    /// The Android `FilenameInputFilter` only allows letters/digits/`_`/`-`; names coming
    /// from older builds may additionally contain spaces, so path separators & dot-dot are
    /// the hard requirement here (never escape the project_data directory).
    public func isValidProjectName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 255 else { return false }
        if name == "." || name == ".." { return false }
        if name.contains("/") || name.contains("\\") { return false }
        if name.contains(":") { return false }
        return true
    }

    /// `FilenameInputFilter`: letters, digits, `_` and `-` only (rename dialog input).
    nonisolated public static func sanitizeFilename(_ value: String) -> String {
        var result = ""
        for character in value.unicodeScalars {
            let scalar = character
            if CharacterSet.alphanumerics.contains(scalar)
                || scalar == "_" || scalar == "-" {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    // MARK: - Atomic write helper

    private func writeAtomically(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        // Data.write(.atomic) writes a temporary file in the same directory and renames it
        // over the destination — crash-safe on both iOS and macOS.
        try data.write(to: url, options: .atomic)
    }
}
