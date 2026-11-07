# ORIPA Swift port — team contract

**Read this fully before writing any code.** It is the single source of truth for the port's
architecture, ownership, conventions, boundary APIs and definition of done. The Lead owns this
file; if it is wrong or incomplete, message the Lead — do not silently deviate.

---

## 1. Mission

Port **ORIPA for Android 0.2.3.3** (the app behind `https://github.com/wiorigami/oripaweb`) to a
**native Apple Swift/SwiftUI application** that runs on iPad/iPhone (iOS 16+) and macOS (13+).

Primary deliverable: a native **unsigned iOS/iPadOS IPA** built by GitHub Actions, plus a native
macOS `.app`. Same workflow, features, algorithms, file formats, texts and icons as the web port —
but implemented in Swift/SwiftUI with **native platform integrations** (document picker, share
sheet, Files.app document storage, multi-touch, pointer support, dark mode, keyboard).

### Source of truth

| What | Where |
|---|---|
| **Reference implementation to port (JavaScript)** | `/Users/william/Desktop/hns/apps/oripa-port/src/js/**` |
| Reference CSS (layout/visuals) | `oripa-port/src/css/**` |
| Reference web HTML shell | `oripa-port/src/index.template.html` |
| Decompiled Android Java (original app) | `oripa-port/rev/jadx/sources/com/origamitoolbox/oripa/**` |
| Decoded Android resources: layouts, menus, **strings**, colors, dimens, drawables | `oripa-port/rev/apktool/res/**` (strings: `values/strings.xml`) |
| Workstream reports (detailed inventories, API notes, quirks) | `oripa-port/docs/reports/*.md`, `oripa-port/docs/{ARCHITECTURE,FEATURES,PORTING_NOTES,render-api}.md` |
| Reference screenshots (web port + Play Store) | `oripa-port/tools/ui_harness/screenshots/**`, `oripa-port/docs/screenshots/**`, `oripa-port/ref/screen0..3.png` |
| Icons (SVG converted from APK vectors) / logos | `oripa-port/src/assets/icons/*.svg`, `oripa-port/src/assets/img/*.png` |
| `oripaweb` repo (built bundle only) | https://github.com/wiorigami/oripaweb — no source, do not port from it |
| Golden fixtures for tests | `oripa-port/tools/tests/*.js`, `oripa-port/tools/fold_oracle/cases/**` |

**This repo:** `/Users/william/Desktop/hns/apps/oripa-swift` (new GitHub repo `wiorigami/oripa-swift`).

### User requirements beyond parity

1. **Local persistence is a hard requirement** (user complaint about the web version: work is lost).
   - Crease-pattern projects must be stored as real files on disk (`Documents/project_data/<name>`
     OPXC + `Documents/project_thumbs/<name>` PNG), written atomically, surviving app termination,
     relaunch and device reboot.
   - Same bundle id (`com.origamitoolbox.oripa`) and same directory layout as the previous
     WKWebView port so existing user projects are still visible after upgrading.
   - Crash-safe autosave (`temp_save_file` + metadata) with a recovery prompt; never silently
     discard unsaved work.
   - Files.app access (`UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`) and system
     document picker import / share-sheet export. No network, no cloud.
2. **Native adaptations** replace Android/WKWebView plumbing: `fileImporter`/document picker,
   share sheet, multi-touch pinch/pan/rotate, Apple Pencil/pointer, dark-mode-capable chrome,
   keyboard shortcuts, native iPad/iPhone layouts. Never regress the workflow.

---

## 2. Repository layout

```
Package.swift                  # Lead — SwiftPM: ORIPACore, ORIPAUI, ORIPAMac, ORIPASnapshots, tests
Sources/
  ORIPACore/                   # pure Foundation logic, no SwiftUI/UIKit — testable with `swift run ORIPATests`
    Resources/ Geometry/ Collections/ Tree/ Model/{CreasePattern,History,StateMachine,Tool}
    Model/FoldedModel/ IO/ RenderData/ Version.swift
  ORIPAUI/                     # SwiftUI, cross-platform (iOS 16 / macOS 13)
    App/ DesignSystem/ Platform/ Screens/{Splash,Projects,Preview,Editor,Settings,Fold}
    Dialogs/ Canvas/ Resources/{Icons,Logos}
  ORIPAMac/                    # macOS @main wrapper (SwiftPM executable)
  ORIPASnapshots/              # headless ImageRenderer QA tool
Tests/ORIPATests/              # hermetic test runner (no XCTest): Support/ (Lead), CoreModel/, FoldIO/
Fixtures/                      # committed golden JSON + real .opx/.opxc/.cp case files
tools/                         # Node fixture generators, asset conversion, packaging scripts
iOSApp/                        # iOS app entry, Info.plist, Assets.xcassets (AppIcon/Launch)
project.yml + ORIPA.xcodeproj  # XcodeGen spec + committed generated project (iOS build)
.github/workflows/ci.yml       # tests + unsigned IPA + macOS app artifacts
scripts/                       # build/test/package scripts
docs/                          # this contract, build/install/token guides
```

## 3. Ownership (write scopes — do not write outside yours)

| Workstream | Owns |
|---|---|
| **Lead** | `Package.swift`, `README.md`, `docs/PORT-CONTRACT.md`, `docs/DECISIONS.md`, `.gitignore`, `Tests/ORIPATests/Support/**`, `tools/fixtures/load_oripa.js`, git/GitHub, final integration |
| **core-model** | `Sources/ORIPACore/{Resources,Geometry,Collections}/**`, `Sources/ORIPACore/Model/{CreasePattern,History}/**` (except CreasePattern/{line,point}/**), `Tests/ORIPATests/CoreModel/**`, `tools/fixtures/core/**`, `Fixtures/core/**` |
| **core-tree** (helper) | `Sources/ORIPACore/Tree/**`, `Sources/ORIPACore/Model/CreasePattern/{line,point}/**`, `Tests/ORIPATests/CoreTree/**` |
| **core-tools** (helper) | `Sources/ORIPACore/Model/{StateMachine,Tool}/**`, `Tests/ORIPATests/CoreTools/**`, `tools/fixtures/tools/**`, `Fixtures/tools/**` |
| **fold-io** | `Sources/ORIPACore/IO/**`, `Sources/ORIPACore/RenderData/**`, `Tests/ORIPATests/FoldIO/**` (except `FoldModelTests.swift`), `tools/fixtures/foldio/**`, `Fixtures/foldio/**`, `Fixtures/cases/**` |
| **fold-engine** (helper) | `Sources/ORIPACore/Model/FoldedModel/**`, `Tests/ORIPATests/FoldIO/FoldModelTests.swift` |
| **ui-shell** | `Sources/ORIPAUI/{App,DesignSystem,Platform}/**`, `Sources/ORIPAUI/Screens/{Splash,Projects,Preview,Settings}/**`, `Sources/ORIPAUI/Dialogs/{ProjectDialogs,AboutDialog,CommonDialogs}.swift`, `Sources/ORIPAUI/SnapshotScenarios/**` |
| **ui-canvas** | `Sources/ORIPAUI/Screens/Editor/**`, `Sources/ORIPAUI/Canvas/{ViewTransform,Camera,PaintRenderer,CheckRenderer,PreviewRenderer,CPPNGExport}.swift`, `Sources/ORIPAUI/Canvas/Gestures.swift`, `Sources/ORIPAUI/Dialogs/{ExportCPDialog,SaveDialog,HelpDialog,NumberDialog}.swift` |
| **ui-fold** | `Sources/ORIPAUI/Screens/Fold/**`, `Sources/ORIPAUI/Canvas/{FoldRenderer,FoldPNGExport}.swift`, `Sources/ORIPAUI/Dialogs/{FoldSettingsDialogs,ColorPicker}.swift` |
| **ci-release** | `project.yml`, `ORIPA.xcodeproj/**`, `iOSApp/**`, `.github/workflows/**`, `scripts/**`, `Sources/ORIPAMac/**`, `Sources/ORIPASnapshots/**`, `Sources/ORIPAUI/Resources/**`, `tools/assets/**`, `README.md` draft proposals to Lead, `docs/{BUILD,INSTALL,TOKEN-GUIDE,PUBLISH}.md` |

Rules:
- Files are shared live between agents. **Never edit a file you do not own.** Need a cross-scope
  change? Send a message to the Lead and the owner with the exact change.
- Shared abstract types that multiple scopes need (e.g. `CpContext`, `EditorSessionProtocol`,
  `Preferences`) are declared by their owner **early**, then frozen; additive changes only.
- `Package.swift` changes are Lead-only: request them.
- Generated/committed resources (`ORIPA.xcodeproj`, `Resources/**`) are owned by ci-release.

## 4. Swift porting conventions

1. **Port 1:1, do not redesign.** Keep the JS/Java class names, field names and method names
   (`getX()`, `isFlatFoldable()`, `doTransition(...)`), numeric constants (`LineType.MOUNTAIN == 2`),
   algorithms and edge-case behaviour. Read the JS file; mirror it.
2. **Module boundaries:** `ORIPACore` is Foundation-only (no SwiftUI/UIKit/AppKit, no `@MainActor`);
   all UI code lives in `ORIPAUI`. Logic must be unit-testable without a screen.
3. **Reference types for model entities.** Classes that rely on Java identity/value equality
   (`OriPoint`, `OriLine`, `OriFace`, `OriHalfEdge`, `OriVertex`, tree nodes) are `final class`
   with `func equals(_:) -> Bool` / `func hashCode() -> Int` matching the JS `equals/hashCode`.
   Value-only helper types (`PointDouble`, `Segment`, `MinMax*`) may be `struct`. Where Java
   `HashMap`/`HashSet` value semantics matter, use the core `JavaMap`/`JavaSet` (core-model owns
   `Collections/`) — plain Swift `Set` is identity-based and will silently change behaviour.
4. **Optionals:** JS `null`/`undefined` → Swift optional. Java `null` list entries stay `nil`.
5. **Numbers:** Java/JS `double` → `Double`; `float`/`float[]` → `Float`/`[Float]`; `int` → `Int`;
   Android `byte` line-type constants → `Int` raw values in `enum LineType: Int`.
6. **Strings:** UI texts are the exact English strings from the JS port (which came from
   `strings.xml`). Keep them verbatim, including punctuation/plurals. Comments and docs: English.
7. **No third-party dependencies, no network.** Only Apple SDK.
8. **Cross-platform compile is mandatory.** Everything in ORIPAUI must compile for **macOS 13 and
   iOS 16**: use `#if os(iOS)` / `#if canImport(UIKit)` guards for platform-only APIs; prefer
   cross-platform SwiftUI (`Canvas`, `fileImporter`, `ShareLink`, `ImageRenderer`).
   `swift build` on this Mac (CLT only) is the local gate — it must pass before you report.
9. Swift language mode 5 (do not enable Swift 6 strict concurrency); UI types are `@MainActor`.
10. Style: 4-space indent, `// MARK:` sectioning, one Java/JS class per Swift file whenever possible
    (mirror the reference file split), file header comment naming the ported JS/Java source.
11. No `fatalError` in shipping paths except genuinely unreachable invariants; surface user-facing
    errors as dialogs/snackbars like the reference.

## 5. Boundary APIs

These are the contracts between workstreams. Implementations may add methods, but these names /
semantics are required. If you must change one, message Lead + affected owners first.

### 5.1 Core types (owned by core-model; consumed by everyone)

- `enum LineType: Int { case flat = 0, boundary = 1, mountain = 2, valley = 3, grid = 4, picked = 5, slice = 6, undefined = 127 }`
  plus `getColor()`, `getString()`, `getAbbreviation()` helpers.
- `enum GridType: Int { case square = 0, triangle = 1, undefined = 127 }`.
- `enum FileType` (PNG, SVG, OPX, OPXC, CP) with `extension`, `mimeType`, `displayName`.
- `Color` (Android color names as `struct RGB { r,g,b: Float }` constants — mirror JS `Color.js`),
  `Constant` (all numeric constants), `ProjectKey`, `ProjectValue`, `RenderKey`.
- Geometry: `PointDouble`, `Segment`, `MinMaxDouble`, `MinMaxFloat`, `GeomUtil`, `GLUtil`,
  `ColorUtil`, `DisplayUtil` with the same static functions as JS.
- Collections: `JavaMap<T: AnyObject>` / `JavaSet<T: AnyObject>` (Java equals/hashCode semantics),
  `FixedStack`, `SimpleStack`, `Stack`, `HashList`, `NearestItem`, `BinaryIterator`.
- `CreasePattern` (class):
  props `lines: [OriLine]`, `points: [OriPoint]`, `creasePatternHalfSize: Float`, `modified: Bool`,
  `inputLineType: LineType`, `historyManager: HistoryManager`, `grid: GridManager`,
  `facesCheck: [OriPolygon]`, `pointErrorCheck: [OriPoint]`, `lineMVFB`/`pointMVFB` render-data
  (builders in ORIPACore/RenderData), `selectedLines`.
  methods `initializeDefaultSquare()`, `isFlatFoldable() -> Bool`, `findPoint(_ p: PointDouble, radius: Double) -> OriPoint?`,
  `findLine(...) -> OriLine?`, `addLineNoCheck(_:)`, `addLineCheckNoException(...) -> Bool`,
  `changeLineType(...)`, `removeLine(_:)`, `clearAll()`, `clearCheckData()`, `cleanStraightLines()`,
  and anything consumed by `src/js/ui/**` call sites (grep them).
- `HistoryManager`: `hasUndo()`, `hasRedo()`, `undo(_ cp:)`, `redo(_ cp:)`, `newBranch(...)`, `clearAll()`.
- `CpContext` protocol (`AnyObject`): the port of the JS `context` object passed to state machines.
  Core declares the minimal protocol; UI provides an adapter over `Preferences` + paint fragment.
  It must support: pref int reads used by `ChangeLineSM`/`DeleteLineSM`, and by-value callbacks used
  by `AddSegmentByValue*SM` (`getByValueButtonAngleText`, `getByValueButtonLengthText`,
  `setByValueButtonAngleText`, `setByValueButtonLengthText`, plus the finish actions).
- `StateMachineManager`: `doTransition(creasePattern:snap:pointDouble:radius:) -> Int`,
  `doLongTransition(creasePattern:z:pointDouble:radius:) -> Int`,
  `doBatchPointOperation(context:cp:start:end:)`, `doBatchLineOperation(context:cp:start:end:)`,
  `finish(context:cp:)`, `resetMachine()`, `newMachine(_:)`, `getToolType()`, `getState()`,
  `hasBatchPointOperation()`, `hasBatchLineOperation()`, `getDirectSelectionEnabled()`.
- `FoldedModel`: `foldWithoutOverlap(_ cp: CreasePattern)`, `foldWithOverlap()`, `clear()`,
  props `mFaces`, `mVertices`, `mHalfEdges`, `sortedFaces`, `sortedFacesReverse`,
  `foldedModelHalfSize: Float`, `crossLine`; plus `OriFace`/`OriHalfEdge`/`OriVertex`/
  `CrossLine`/`CrossLineManager`/`FoldOverlapParams`. `CrossLineManager.getNew(fm)`,
  `updateCrossLineRenderData(fm:angle:position:)`, `getCrossLineRenderData()`, `CrossLine.positionMaxMagnitude()`,
  `CrossLine.angleDegMaxMagnitude()`.
- IO facade (owned fold-io): 
  `enum OripaIO`:
  `loadCreasePattern(data: Data, fileType: FileType) throws -> CreasePattern`,
  `loadCreasePatternForce(data: Data) throws -> CreasePattern`,
  `readCreasePatternFile(data: Data, filename: String) throws -> CreasePattern`,
  `exportCp(_ cp:) -> Data`, `exportOpx(_ cp:) -> Data`, `exportOpxc(_ cp:) -> Data`,
  `exportSvg(_ cp:) -> String`, `exportFoldedModelSvg(...) -> String`.
  PNG export lives in ORIPAUI (`CPPNGExport` / `FoldPNGExport`) because it needs rendering.
- Render-data builders `GLData*` (owned fold-io): keep the Java/JS encodings (float arrays, byte
  arrays). Renderers consume them.

### 5.2 UI shell (owned by ui-shell; consumed by all UI workstreams)

- `@MainActor final class AppModel: ObservableObject` with `navigation: [Route]`,
  `push(_ route: Route)`, `pop()`, `replaceTop(_:)`, `popToRoot()`, and `prefs: Preferences`,
  `store: ProjectStore`, `fileExchange: FileExchange`, `toast: SnackbarCenter`.
- `enum Route: Hashable` with cases `.splash, .projects, .preview(PreviewParams), .editor(EditorParams), .settings`.
- `struct EditorParams: Hashable` = `projectName: String?`, `srcFilenameWithExt: String?`,
  `srcProjectDirPath: String?`, `srcIsInternal: Bool`.
- `@MainActor final class Preferences: ObservableObject` — Android SharedPreferences equivalent:
  `bool(_ key: String, default:)`, `int(...)`, `string(...)`, `setBool/setInt/setString`,
  `clear()`, `snapshot() -> [String: Any]`. Persisted in UserDefaults. Android quirk (prefs cleared
  on project exit) is kept; document it.
- `@MainActor final class ProjectStore: ObservableObject` — disk-backed project storage:
  `reload()`, `projects: [ProjectInfo]`, `readProject(name:) -> Data?`,
  `write(name:opxc:thumbPNG:) throws`, `rename/copy/delete`, `createImportStaging(data:filename:) -> StagedImport`,
  `writeTempSave(_ data: Data, meta: TempSaveMeta)`, `readTempSave() -> (Data, TempSaveMeta)?`,
  `deleteTempSave()`, `recoverableDraft() -> TempSaveMeta?`. Atomic writes, Documents dir.
- `FileExchange` — system integration: `pickImport() async -> [ImportedFile]`,
  `export(_ data: Data, filename: String, mimeType: String)`, `exportImagePNG(...)`, share-sheet
  presentation; must work on both iOS (document picker/share sheet) and macOS (open/save panels).
- Design system (Material look, cross-platform): `MaterialIcon` (already stable in
  `DesignSystem/MaterialIcon.swift`), `Theme` (colors/dimets from `theme.css` + Android `colors.xml`),
  `OrToolbar`, `OrDialog`/`DialogHost`, `SnackbarHost`, `OrActionBar`, `OrFAB`, `OrMenu` (cascading
  popup menus), `OrSpinner`, `OrSeekBar`, `OrSwitchRow`, `OrNumberPicker`, `OrTooltip`.
  Publish their signatures in `docs`/messages as soon as they exist; other UI workstreams consume them.
- `EditorSessionProtocol` (declared by ui-shell, implemented by ui-canvas `EditorScreen`):
  `cp: CreasePattern`, `foldedModel: FoldedModel`, `crossLineManager: CrossLineManager`,
  `prefs: Preferences`, `srcFilenameNoExt: String`, `srcIsInternal: Bool`, `modified: Bool`,
  `returnToPaint()`, `requestCloseProject()`, `runFlatFoldabilityCheck() -> Bool`,
  `prepareFold() -> Bool` (builds the folded model like `PaintCpFragment.newFoldCPIntent`).
- `EditorScreen(session params, app: AppModel)` must switch fragments `.paint / .check / .fold`
  exactly like `editor.js` (`showFragment`, retained state, back semantics).
- Snapshot QA: `SnapshotScenarios.all` (ui-shell) returns named renderable scenarios seeded with
  demo projects; `ORIPASnapshots` renders them headless (ci-release).

### 5.3 Canvas renderers (owned by ui-canvas / ui-fold; consumed by screens + PNG export)

- All renderers draw with SwiftUI `GraphicsContext` (or CGContext via `context.withCGContext` where
  useful) at a given `CGSize`; no UIKit/AppKit-only drawing. Provide:
  - `ViewTransform` (port of `render/ViewTransform.js`, exact math incl. Y-down object space).
  - `Camera` (port of `render/Camera.js`, fold views: scale/tx/ty/rotationDeg, gesture helpers).
  - `PaintRenderer`, `CheckRenderer`, `PreviewRenderer` (ui-canvas), `FoldRenderer` (ui-fold) with
    the same public behaviour as `docs/render-api.md` (`setCreasePattern`, `setViewTransform`,
    `resize`, `draw`, render-data setters, options).
  - `CPPNGExport.render(cp:width:height:options:) -> Data?` (ui-canvas) and
    `FoldPNGExport.render(fm:mode:width:height:options:) -> Data?` (ui-fold) replacing
    `PngExport.js`; used by export dialogs and project thumbnails.
- Reference visuals: `oripa-port/src/js/render/*.js`, `docs/render-api.md`,
  `oripa-port/docs/screenshots/*.png` (fold), `oripa-port/tools/ui_harness/screenshots/*.png`.

## 6. Golden-fixture verification (logic workstreams)

The JS reference is executable in Node. **Prove the Swift port against it**, do not just eyeball:

1. Node loader: `tools/fixtures/load_oripa.js` (Lead) loads `oripa-port/src/js` (via `--src` or env
   `ORIPA_JS_ROOT`) and returns the `ORIPA` namespace. Usage:
   `const O = require("../fixtures/load_oripa.js")();`
2. Each workstream writes `tools/fixtures/<area>/*.js` generators that emit deterministic JSON into
   `Fixtures/<area>/*.json` and commits it. Include: inputs, expected outputs/state snapshots.
   - core-model: trees (insert/remove/traverse/nearest), geometry functions, crease-pattern
     operations incl. undo/redo, state-machine event sequences.
   - fold-io: load/export round-trips (byte equality where deterministic), folding results for
     `oripa-port/tools/fold_oracle/cases/**` (face/vertex/edge counts, per-vertex folded positions,
     face transform matrices, error points, consistency), SVG outputs.
3. Swift tests decode the committed JSON with `Tests/ORIPATests/Support/Fixtures.swift`
   (`Fixtures.decode`) and assert with the shared harness `TestHarness` from
   `Tests/ORIPATests/Support/TestHarness.swift` (`expect`, `expectEqual`, `expectClose` —
   1e-9 tolerance for doubles). Each workstream appends its suites to `CoreModelTests.all`
   / `FoldIOTests.all`; `main.swift` runs them and exits non-zero on failure. Registries: `CoreModelTests.all`,
   `CoreToolsTests.all`, `FoldIOTests.all`, `FoldModelTestSuites.all`.
4. CI only runs `swift run ORIPATests`; it never needs Node. Regeneration is documented in `tools/fixtures/README.md`.
5. Copy the real case files (`oripa-port/tools/fold_oracle/cases/**`) into `Fixtures/cases/` via the
   generator (fold-io owns).

## 7. Build & verification commands

```bash
cd /Users/william/Desktop/hns/apps/oripa-swift

swift build                              # MUST pass (macOS 13 typecheck of all shared code)
swift run ORIPATests                     # core + fold-io golden tests (single entry point)
swift run ORIPATests CoreModel           # filter by suite-name substring (same for FoldIO)
swift run ORIPASnapshots build-snapshots # headless UI screenshots (PNG) for visual QA
xcodegen generate                        # regenerate ORIPA.xcodeproj from project.yml (ci-release)
```

- No Xcode is installed on this Mac: iOS compilation happens in GitHub Actions. Local iOS-only
  APIs must be guarded so `swift build` still passes.
- Concurrent `swift build` calls share `.build/` and serialize; that is expected.
- While another workstream's files are temporarily broken, build errors from files you do not own
  are not yours: fix your own files, message the owner if it persists.
- Syntax-only check for a single file: `swiftc -parse Sources/ORIPAUI/.../File.swift`.

## 8. Definition of done

- Your files compile in `swift build` (no errors; warnings minimised).
- Logic workstreams: golden tests pass (`swift run ORIPATests`), fixtures committed, no skipped suites.
- UI workstreams: screens render through `swift run ORIPASnapshots` in scenarios covering your
  screens; visuals compared with the reference screenshots; behaviours from the JS port reproduced
  (menus, dialogs, gestures, enabled/disabled states, exact texts).
- Persistence (ui-shell): projects save to disk, survive relaunch; autosave/recovery works.
- Report to Lead with: files, commands run + results, deviations, remaining known gaps.
- Never leave the tree in a state where `swift build` fails because of your files.

## 9. Communication

- Claim your shared task id before starting; update/complete it when done.
- Message the Lead when: API contract changes are needed, a cross-scope bug blocks you, you finish a
  milestone, or you are blocked >10 minutes.
- Keep messages short and actionable: what changed, what you need, exact file/signature.
- Do not block waiting for another workstream: code against the contract, then do a compile-fix pass
  once their files land (shared filesystem — read the real API).
- Do not run destructive git operations; the Lead owns commits/pushes.

## 10. Legal / credits

The port is derived from ORIPA (Jun Mitani, GPL-3.0), ORIPA S (Ouchi Koji, GPL-3.0) and ORIPA for
Android 0.2.3.3 (Michelle Fung, GPL-3.0). The repository is GPL-3.0 (`LICENSE`). Keep attribution in
`README.md` and About dialog. Do not redistribute the original APK or decompiled sources.
