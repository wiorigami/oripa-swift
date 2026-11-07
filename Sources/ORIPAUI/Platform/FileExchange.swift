// System file integration: document-picker import + share-sheet / save-panel export.
//
// Replaces the WKWebView shell's `window.webkit.messageHandlers.oripa` import/export ops
// (`src/js/platform.js`, `ios/main.m` of the web port) with native Apple APIs:
//   * import: SwiftUI `.fileImporter` (UIDocumentPickerViewController on iOS,
//     NSOpenPanel on macOS) attached once by `ORIPARootView`;
//   * export: UIActivityViewController share sheet on iOS (same behaviour as the previous
//     port) and NSSavePanel on macOS (native save dialog).
// Both must work on iOS and macOS without a window-server dependency at compile time.
import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - ImportedFile

/// One file returned by the document picker (JS `{name, bytes, ext}` of `platform.importFile`).
public struct ImportedFile: Identifiable {
    public let id = UUID()
    /// Last path component, e.g. `crane.opx`.
    public let name: String
    /// Raw file bytes.
    public let bytes: Data

    public init(name: String, bytes: Data) {
        self.name = name
        self.bytes = bytes
    }

    /// `FileUtil.getFileExt` of the picked name.
    public var ext: String { ProjectStore.fileExtension(of: name) }

    /// `FileUtil.getFilenameNoExt`.
    public var filenameNoExt: String { ProjectStore.filenameNoExt(name) }
}

// MARK: - FileExchange

/// System integration facade used by every screen and dialog.
@MainActor
public final class FileExchange: ObservableObject {

    // MARK: Import

    /// Extensions accepted by the import action (`platform.importFile(["opx","opxc","cp"])`).
    nonisolated public static let importExtensions = ["opx", "opxc", "cp"]

    /// `public.item` lets the picker show every file; the extension is validated by the
    /// caller exactly like the JS port did (`projects.js` importExternalFile).
    nonisolated public static var importContentTypes: [UTType] { [.item] }

    /// Bound to the root `.fileImporter` modifier.
    @Published public var isImporting = false

    private var importContinuation: CheckedContinuation<[ImportedFile], Never>?

    /// Present the system document picker and await the picked files.
    ///
    /// Cancellation resolves to an empty array (JS `cb(null)` when the user cancels).
    public func pickImport(allowedExtensions: [String] = FileExchange.importExtensions) async -> [ImportedFile] {
        // Never stack two pickers; a pending request resolves with "cancelled".
        if importContinuation != nil {
            completeImport(.success([]))
        }
        return await withCheckedContinuation { continuation in
            importContinuation = continuation
            isImporting = true
        }
    }

    /// Called when the picker's presentation binding resets without a completion callback;
    /// resolves a pending `pickImport()` as cancelled.
    public func importDismissed() {
        guard importContinuation != nil else { return }
        completeImport(.failure(CocoaError(.userCancelled)))
    }

    /// Called by the root `.fileImporter` modifier when the picker finishes.
    public func completeImport(_ result: Result<[URL], Error>) {
        isImporting = false
        let continuation = importContinuation
        importContinuation = nil
        switch result {
        case .failure:
            continuation?.resume(returning: [])
        case .success(let urls):
            var imported: [ImportedFile] = []
            for url in urls {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { continue }
                imported.append(ImportedFile(name: url.lastPathComponent, bytes: data))
            }
            continuation?.resume(returning: imported)
        }
    }

    // MARK: Export

    /// Bound to the root `.fileExporter`/save-panel presentation (published for bindings).
    @Published public var isExporting = false

    private var exportCompletion: ((Bool) -> Void)?
    private var pendingExportURL: URL?

    /// `plain.exportFile(...)` equivalent: export binary data through the system UI.
    ///
    /// iOS: share sheet (UIActivityViewController, exactly the previous WKWebView shell).
    /// macOS: NSSavePanel. `completion(true)` only when the user actually exported the file;
    /// a cancellation is reported as `false` and must not be treated as an error.
    public func export(_ data: Data,
                       filename: String,
                       mimeType: String,
                       completion: ((Bool) -> Void)? = nil) {
        presentExport(data: data, filename: filename, mimeType: mimeType, completion: completion)
    }

    /// Text export (`platform.exportText`).
    public func exportText(_ text: String,
                           filename: String,
                           mimeType: String,
                           completion: ((Bool) -> Void)? = nil) {
        let data = Data(text.utf8)
        presentExport(data: data, filename: filename, mimeType: mimeType, completion: completion)
    }

    /// PNG image export (`platform.exportBinary` of a PNG data URL).
    public func exportImagePNG(_ data: Data,
                               filename: String,
                               completion: ((Bool) -> Void)? = nil) {
        presentExport(data: data, filename: filename, mimeType: "image/png", completion: completion)
    }

    /// Share-sheet variant; on macOS the save panel is used (there is no share popover
    /// anchor without a view, and "save to Downloads" is the native expectation).
    public func share(_ data: Data,
                      filename: String,
                      mimeType: String,
                      completion: ((Bool) -> Void)? = nil) {
        presentExport(data: data, filename: filename, mimeType: mimeType, completion: completion)
    }

    private func presentExport(data: Data,
                               filename: String,
                               mimeType: String,
                               completion: ((Bool) -> Void)?) {
        // Stage the bytes in the temporary directory; both platform UIs take a file URL so
        // the exported file keeps the requested name and extension.
        let safeFilename = filename.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeFilename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            completion?(false)
            return
        }
        if isExporting {
            completion?(false)
            return
        }
        isExporting = true
        exportCompletion = completion
        pendingExportURL = url

        #if canImport(UIKit)
        presentShareSheet(for: url)
        #elseif canImport(AppKit)
        presentSavePanel(for: url)
        #else
        finishExport(success: false)
        #endif
    }

    private func finishExport(success: Bool) {
        let completion = exportCompletion
        exportCompletion = nil
        isExporting = false
        if let url = pendingExportURL {
            try? FileManager.default.removeItem(at: url)
        }
        pendingExportURL = nil
        completion?(success)
    }

    #if canImport(UIKit)

    private func presentShareSheet(for url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let presenterView = FileExchange.topViewController() else {
                self.finishExport(success: false)
                return
            }
            let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = controller.popoverPresentationController {
                popover.sourceView = presenterView.view
                popover.sourceRect = CGRect(x: presenterView.view.bounds.midX,
                                            y: presenterView.view.bounds.maxY - 60,
                                            width: 1,
                                            height: 1)
                popover.permittedArrowDirections = []
            }
            controller.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                DispatchQueue.main.async {
                    self?.finishExport(success: completed)
                }
            }
            presenterView.present(controller, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? scenes.first?.windows.first
        guard var controller = window?.rootViewController else { return nil }
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }

    #elseif canImport(AppKit)

    private func presentSavePanel(for url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = url.lastPathComponent
            if let type = UTType(filenameExtension: url.pathExtension) {
                panel.allowedContentTypes = [type]
            }
            panel.begin { [weak self] response in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard response == .OK, let destination = panel.url else {
                        self.finishExport(success: false)
                        return
                    }
                    do {
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try FileManager.default.removeItem(at: destination)
                        }
                        // The staged URL is moved to the user-chosen location.
                        try FileManager.default.moveItem(at: url, to: destination)
                        self.finishExport(success: true)
                    } catch {
                        self.finishExport(success: false)
                    }
                }
            }
        }
    }

    #endif
}
