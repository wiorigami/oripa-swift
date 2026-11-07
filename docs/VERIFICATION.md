# Verification report — native ORIPA Swift port

Everything below was executed on the development machine (Apple Silicon, macOS 26,
Command Line Tools only — **no full Xcode**, no simulator) on 2026-11-07, against the
committed tree. The iOS IPA itself can only be built by GitHub Actions (full Xcode);
everything that can be verified headlessly was verified with the commands shown.

## 1. Golden-logic verification (vs the executable JavaScript reference)

The reference implementation (`../oripa-port/src/js`, the source of
`wiorigami/oripaweb`) is executed in Node to emit deterministic golden JSON committed under
`Fixtures/`; the Swift port is asserted against it. CI does not need Node.

```bash
swift run ORIPATests
```

```
PASS 36 suites, 35,849 checks, 0 failures
```

| Suites | Checks | What is proven |
|---|---:|---|
| CoreModel (5) | 1,873 | Resources/colors/constants tables; geometry + GL matrix math + mirror involution; Java `HashMap/HashSet` value semantics & iteration order; `CreasePattern` add/duplicate/diagonal rejection, nearest point/line with grid snapping, `cleanStraightLines`, flat-foldability (Kawasaki/Maekawa), grid square+triangle render data; undo/redo/50-step cap/branching |
| CoreTree (7) | 65 | Generic AVL/red-black trees (in-order, heights, black-height, violation checks); `Avl/RedBlackPointTree`/`LineTree` insert/remove/range/nearest/duplicate-key behaviour; exact `JavaMap` iteration order of the red-black line facade |
| CoreTools (3) | 1,846 | All 12 state-machine classes + all 16 tool machines: direct/indirect event sequencing, batch operations, pref filters (exact Android R.id values), picked/temp state, by-value context, manager delegation/reset; 32 JS-driven scenarios / 117 operations |
| FoldIO (16) | 12,778 | OPX/OPXC/CP/SVG load + re-export byte equality; 6 certified fold-oracle cases (incl. 236-face 《福》 CP, crane base, octa base, Sierpinski L2, negative case); malformed inputs; `GLData*` render-data encodings |
| FoldModel (5) | 19,287 | Fold engine 1:1 against JS goldens: per-vertex `valueAfterFold`, 16-element face matrices, half-edge/twin wiring, draw order, component count, consistency guard (the missing-`continue` bug is regression-tested), overlap/x-ray/cut-line data |

Deterministic fixture generators live in `tools/fixtures/**` (`node tools/fixtures/core/*.js`,
`tools/fixtures/tree/gen_tree.js`, `tools/fixtures/tools/gen_tools.js`,
`tools/fixtures/foldio/gen_foldio.js`); they regenerate byte-identical JSON.

## 2. End-to-end integration (real app layer, headless)

```bash
swift run ORIPAIntegration
```

```
PASS 64 integration checks
```

Covers, driving the real `ORIPACore` + `ORIPAUI` objects:

* `ProjectStore` disk layout (`Documents/project_data`, `project_thumbs`, `import_data`,
  `temp_save_file`) and `ProjectStore.runSelfTest()` — **write → fresh store instance
  (“relaunch”) re-read → rename/copy/delete → import staging → crash-safe autosave
  recovery**, 31 checks;
* New editor → default square (4 boundary lines); two real `PaintDriver` taps →
  `StateMachineManager` → `historyManager.newBranch` → one new line; undo/redo;
* Save → OPXC written to disk + 180 px thumbnail; a **new** `ProjectStore` instance sees
  the project and `OripaIO.loadCreasePatternForce` reloads the drawn lines (no data loss);
* Autosave → `temp_save_file` + metadata → recoverable after “crash” → discard removes it;
* External `crane_base_mitani.opx` staged import → `prepareFold()` → **12 folded faces,
  1 connected component** (certified pattern), broken-pattern error path;
* CP/OPX/OPXC export → reload round-trips with identical line counts; SVG output;
* All 6 reference case files load through `readCreasePatternFile`;
* Android preference semantics (`clear()` restores defaults).

The user's hard requirement — “projects must not be lost like the web version” — is
covered by both the persistence self-test and the save→relaunch path above.

## 3. Headless UI verification (SwiftUI `ImageRenderer`)

```bash
swift run ORIPASnapshots build-snapshots
# 47 PNGs + manifest.json
```

Every screen/mode is rendered at iPad sizes (820×1180 / 1180×820 @2x):

* shell: splash, projects grid/list/landscape/empty/sort/selection, all project dialogs,
  overflow menus, snackbar, About, preview + preview overflow, settings + number picker;
* editor: paint canvas with typed creases/vertices/grid, Action menu, by-value column,
  selection rectangle + picked lines, hide-menus, landscape, AddSegment tap-drawn line,
  check view (pink faces, red error vertices), export-CP / PNG-options / help /
  save-changes / angle dialogs, real route integration, canvas preview;
* fold: X-Ray, X-Ray wireframe, Overlap (+shadow, +flip, blank-when-disabled),
  Cut Line split view portrait+landscape, mode menu, x-ray/overlap/cross settings dialogs,
  export dialog, PNG options, HSV colour picker.

Visual comparison against the reference screenshots (`oripa-port/tools/ui_harness/
screenshots`, `oripa-port/docs/screenshots`, Play Store `ref/screen*.png`): layouts,
texts, icons and dialog structure match; fold screens were pixel-diffed by the fold
workstream (mean |Δ| 0.17 – 0.95 / 255 vs the web-port captures, differences limited to
chrome text/anti-aliasing). Remaining known snapshot-only gap: the Projects *preview*
content depends on `onAppear`, which `ImageRenderer` does not run; its renderer itself is
proven by `33-canvas-preview` and `EditorSelfCheck`.

Additionally, `EditorSelfCheck.run(app:)` (headless, real compiled module) reports
**55/55 checks**: tap-draw, undo/redo, save/thumbnail/clean-exit, internal + `.cp`/`.opxc`
imports, back-stack semantics, fold hand-off, check/preview render data, PNG dimensions.

## 4. iOS compilation (the CI-critical part)

No Xcode locally, so the iOS build is CI-only; however the shared code was type-checked
for the iOS triple locally with an iPhoneOS SDK matching the CLT toolchain:

```bash
IOS_SDK=/path/to/iPhoneOS.sdk bash tools/ios_typecheck.sh
# iOS typecheck OK — 0 errors
```

This compiles `ORIPACore` + `ORIPAUI` for `arm64-apple-ios16.0`, including the
`#if canImport(UIKit)` raw-touch gesture adapter and every iOS-availability check, plus
`iOSApp/ORIPAApp.swift`. It removed the biggest CI risk (iOS-SDK compilation of the shared
code). `xcodegen generate` regenerates `ORIPA.xcodeproj` byte-identically.

Still only verifiable in GitHub Actions: Xcode's resolution of the local `path: "."`
package, asset-catalog compilation (`actool`), SwiftPM resource-bundle lookup on iOS,
`xcodebuild` device build + unsigned IPA packaging.

## 5. macOS app

```bash
bash scripts/build_mac.sh
```

* `build/macos/ORIPA.app` (7.6 MB) assembled from `swift build -c release` output,
  ad-hoc signed, **`codesign --verify --deep --strict` OK**;
* launches and stays running (verified; no crash);
* `build/macos/ORIPA-macOS.zip` (2.6 MB) produced with `ditto`.
* Project storage on macOS lives in `~/Library/Application Support/ORIPA` (not the user's
  Documents), with a one-time migration from the old WKWebView Documents layout; iOS keeps
  the app Documents container for Files.app + upgrade compatibility.

## 6. Packaging scripts

* `scripts/build_ipa.sh` was exercised with a fake `xcodebuild` harness: success path
  (Payload/`ORIPA.app` → zip, plist/version/Files.app/iPad-orientation assertions,
  `lipo arm64`, `LC_BUILD_VERSION`), failure path, `ADHOC_SIGN` path and a platform
  assertion rejecting a macOS-only binary. A real run needs Xcode (CI).
* `scripts/build_mac.sh`, `scripts/run_tests.sh`, `scripts/package_all.sh` run end-to-end
  locally.
* `.github/workflows/ci.yml` builds three independent jobs: tests (+snapshots), unsigned
  iOS IPA, macOS app — no secrets/certificates.

## 7. Known limitations / follow-ups

1. **iOS runtime devices**: iOS-only branches compile (typecheck) but real touch gestures,
   document picker and share sheet need a device run (no device/simulator here).
2. **First GitHub Actions run** validates Xcode-specific packaging (IPA layout/signing
   toggles) — no Xcode locally.
3. Snapshot-tool limitations: `ImageRenderer` does not run `onAppear`/`async task`s and
   renders `ScrollView`/`Lazy*` empty; the app opts into eager layouts in snapshot mode
   only. Projects-preview content uses the stored thumbnail/preview factory; its live
   loading path is verified at runtime, not in the PNG.
4. Multi-touch gesture *feel* (inertia, two-finger rotation signs on trackpad) needs a
   real device/trackpad; the gesture math itself is ported 1:1 and unit-checked.
5. Ported Android quirks intentionally kept (e.g. drawing preferences cleared when a
   project is closed); documented in `docs/DECISIONS.md`.
