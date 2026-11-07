// Port of `src/js/core/io/export/Exporter.js` (Java
// `com.origamitoolbox.oripa.io.export.Exporter` with the Android DownloadManager/Activity/
// Context APIs replaced).
//
// The Android class opened files in the app files dir and posted a DownloadManager
// notification. In the Swift port all filesystem access lives in the UI/platform layer
// (ProjectStore / FileExchange), so this class keeps only the Java unique-name rules:
//   getNewUniqueFile -> name, name-1, name-2 ...
//   getNewCopyFile   -> name-copy, name-copy-copy ...
// Existence checks go through the injectable `fileExists` closure (default: nothing exists,
// matching the JS behaviour without ORIPA.platform.fs).
import Foundation

public final class Exporter {
    /// Android: `context.getFilesDir()`; here a project-relative base path ("" = root).
    public let baseDir: String

    /// File-existence probe supplied by the platform layer (`ORIPA.platform.fs` in the JS port).
    public var fileExists: (String) -> Bool

    public init(baseDir: String = "", fileExists: @escaping (String) -> Bool = { _ in false }) {
        self.baseDir = baseDir
        self.fileExists = fileExists
    }

    private static func join(_ dir: String?, _ name: String) -> String {
        guard let dir, !dir.isEmpty else { return name }
        var trimmed = dir
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed + "/" + name
    }

    /// JS `ensureDirectory`: the port has no directory entries; a path is writable as long as
    /// the platform does not obviously reject it (always true here).
    private func ensureDirectory(_ path: String) -> Bool { true }

    public func getNewInternalFile(_ dirName: String, _ name: String? = nil) -> String? {
        guard let name else { return Exporter.join(baseDir, dirName) }
        let dirPath = Exporter.join(baseDir, dirName)
        if ensureDirectory(dirPath) { return Exporter.join(dirPath, name) }
        return nil
    }

    public func getNewCopyFile(_ dirPath: String, _ baseName: String) -> String? {
        if !ensureDirectory(dirPath) { return nil }
        var name = baseName + "-copy"
        var path = Exporter.join(dirPath, name)
        while fileExists(path) {
            name += "-copy"
            path = Exporter.join(dirPath, name)
        }
        return path
    }

    public func getNewCopyInternalFile(_ dirName: String, _ baseName: String) -> String? {
        getNewCopyFile(Exporter.join(baseDir, dirName), baseName)
    }

    public func getNewUniqueFile(_ dirPath: String, _ baseName: String) -> String? {
        if !ensureDirectory(dirPath) { return nil }
        var name = baseName
        var path = Exporter.join(dirPath, name)
        var i = 0
        while fileExists(path) {
            i += 1
            name = baseName + "-" + String(i)
            path = Exporter.join(dirPath, name)
        }
        return path
    }

    public func getNewUniqueInternalFile(_ dirName: String, _ baseName: String) -> String? {
        getNewUniqueFile(Exporter.join(baseDir, dirName), baseName)
    }
}
