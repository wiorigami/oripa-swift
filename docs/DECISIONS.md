# Architecture decisions & parity log

This file records decisions taken during the native Swift port and the intentional
differences from the reference (Android 0.2.3.3 → JavaScript web port). Each deviation
names the reason; anything not listed here should behave exactly like the reference.

## AD-1 — Port target: native SwiftUI app, not a WKWebView shell

The reference (`oripa-port` / `oripaweb`) renders the rebuilt port inside a WKWebView.
This project is a **native** Swift/SwiftUI application:

- `ORIPACore` — Foundation-only 1:1 Swift port of the ported Java logic (model, geometry,
  trees, history, tool state machines, fold engine, OPX/OPXC/CP/SVG file IO).
- `ORIPAUI` — native SwiftUI rebuild of the Material UI (Canvas/Core Graphics rendering
  instead of Canvas-2D-in-WebKit), plus native file/gesture integration.
- The JavaScript reference is **not** executed at runtime; it is used only to generate
  golden test fixtures.

Reason: user requirement ("native Apple Swift project"). Consequence: much better native
behaviour, performance and persistence; the pixel-exact Android Material look is
re-created approximately with native SwiftUI equivalents, keeping the exact texts,
icons, layout structure and interaction flow.

## AD-2 — One codebase, two Apple platforms

`ORIPACore`/`ORIPAUI` are shared; `ORIPAMac` (SwiftPM executable → `ORIPA.app`) and the
iOS target in `ORIPA.xcodeproj` are thin wrappers. macOS is the local verification vehicle
(no Xcode on the development machine); the iOS app is the primary deliverable.

## AD-3 — Persistence: files on disk, crash-safe autosave (new, user-required)

The user explicitly asked that crease-pattern files must not be lost like in the web
version (which kept everything in memory/localStorage and lost files on reload).

- Projects are stored as real files in the app Documents container:
  - `Documents/project_data/<name>` — OPXC bytes (same encoding as the reference)
  - `Documents/project_thumbs/<name>` — PNG thumbnail
  - `Documents/import_data/<name>` — staging directory for external imports
  - `Documents/temp_save_file` + `temp_save_meta.json` — draft for crash recovery
- All writes are atomic (`Data.write(options: .atomic)` / write-to-temp + rename).
- Bundle id `com.origamitoolbox.oripa` and the directory layout are unchanged from the
  previous WKWebView port, so users who installed that build keep their existing projects.
- **Deviation from Android parity:** Android 0.2.3.3 writes `temp_save_file` but never
  restores it; the native port additionally offers recovery of that draft on launch
  (prompt with the source project name + timestamp). This is an intentional safety
  improvement on top of parity — data loss was the user's explicit complaint.
- `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`: the app's Documents
  folder is visible in Files.app ("On My iPad → ORIPA"), so project files can be copied
  in/out for backup.

## AD-4 — Native system integration replaces Android/WKWebView plumbing

| Reference (Android/WebKit) | Native port |
|---|---|
| SAF import dialog / HTML `<input type=file>` | `.fileImporter` (UTType opx/opxc/cp + any data) |
| `DownloadManager` / share sheet bridge | ShareLink / `UIActivityViewController` (iOS), NSSavePanel (macOS) |
| OpenGL ES / Canvas-2D | SwiftUI `Canvas` + Core Graphics paths |
| External-store permission handling | Security-scoped URLs + app Documents copies |
| Hardware back key / browser history | Android-style retained navigation stack + edge-swipe/back |
| Pinch/pan via synthetic pointer events | Native SwiftUI/`UIGestureRecognizer` gestures (pinch, pan, rotate, pencil) |
| SharedPreferences `clear()` quirk | Kept: drawing/fold preferences are cleared when a project is closed (parity) |

## AD-5 — Rendering

- Crease pattern / fold views use SwiftUI `Canvas` with `GraphicsContext` (Core Graphics
  under the hood), one path per face where the reference relies on per-face alpha
  accumulation (X-Ray), and the same camera/view-transform math (Y-down object space,
  S(0.5) initial transform) as `ViewTransform.js` / `Camera.js`.
- PNG export and project thumbnails render offscreen with `ImageRenderer`-style CG
  bitmaps, replacing `PngExport.js`'s browser canvas; the reference line widths are
  scaled by output size like the reference (no more Android fixed-pixel widths).
- SVG/OPX/OPXC/CP export remains byte-compatible text/binary formats produced by
  `ORIPACore` (ported `Exporter*` classes), so desktop ORIPA can open the files.

## AD-6 — Verification strategy (no Xcode/simulator locally)

1. `swift build` + `swift test` locally (macOS target) — full typecheck of shared code.
2. Golden fixtures generated from the executable JavaScript reference and committed as
   JSON; Swift tests assert equality (1e-9 tolerance). This is the "perfect port" proof
   for core logic, fold engine and file formats.
3. Headless SwiftUI snapshots (`swift run ORIPASnapshots`) rendered with ImageRenderer
   and compared by eye against the web reference screenshots (`oripa-port/tools/ui_harness/
   screenshots`, `oripa-port/ref/screen*.png`).
4. GitHub Actions builds the unsigned iOS IPA and the macOS app on a macOS runner with a
   full Xcode — the only place iOS-specific code is compiled.

## AD-7 — Signing / distribution

No Apple Developer certificate is available. GitHub Actions produces:

- `ORIPA-unsigned.ipa` (arm64, iOS 16+) — needs re-signing with a free Apple ID
  (Sideloadly/i4Tools) or can be installed directly on TrollStore-compatible devices.
- `ORIPA-macOS.zip` — ad-hoc signed `.app` for local use on this Mac.

No secrets are used in CI; the workflow requires no signing certificates.

## AD-8 — Bundle/version identity

- iOS bundle id: `com.origamitoolbox.oripa` (unchanged → upgrades the old port in place).
- macOS bundle id: `com.origamitoolbox.oripa.mac`.
- Version: `0.2.3.3` (marketing, parity), build `2` (monotonic; old port was build 1).

## AD-9 — No third-party dependencies

Only Apple SDKs (SwiftUI, Foundation, UniformTypeIdentifiers, CoreGraphics). No packages,
no network access, no analytics. Keeps the app auditable and the CI build hermetic.

## AD-10 — Scope of the port

Feature parity follows `oripa-port/docs/FEATURES.md` (90 rows) and the workstream reports.
Android-only plumbing with no iOS equivalent (external-storage `DownloadManager`, runtime
WRITE permission, hardware back key) is replaced by the native equivalents in AD-4; the
workflow, menus, dialog texts, icons and algorithms are preserved.
