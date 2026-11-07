# Building ORIPA (Apple port)

Native **iOS/iPadOS 16+** and **macOS 13+** port of ORIPA for Android 0.2.3.3.
The SwiftUI UI/logic lives in one SwiftPM package (`ORIPACore`, `ORIPAUI`) and is shared
by three products:

| Product | What it is | Where it runs |
|---|---|---|
| `ORIPAMac` | native macOS app (SwiftPM executable, bundled by `scripts/build_mac.sh`) | macOS 13+ |
| `ORIPASnapshots` | headless screenshot/QA tool (SwiftUI `ImageRenderer`) | macOS 13+ |
| `ORIPATests` | hermetic unit/golden-test runner (no XCTest, see below) | macOS 13+ |
| `ORIPAIntegration` | headless end-to-end checks over the real app layer (storage, editor, autosave, imports, folding, exports) | macOS 13+ |
| iOS app `ORIPA` | thin `@main` wrapper around `ORIPAUI` (`iOSApp/`), built from `ORIPA.xcodeproj` | iPhone/iPad, iOS 16+ |

---

## 1. Requirements

### Local development (this Mac: Apple Silicon, macOS 26, **Command Line Tools only**)

| Tool | Needed for | Install |
|---|---|---|
| Swift 5.9+ toolchain (CLT) | `swift build`, `swift run ORIPATests`, `swift run ORIPASnapshots`, macOS app | `xcode-select --install` (already present) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+ | generating `ORIPA.xcodeproj` | `brew install xcodegen` (installed at `/opt/homebrew/bin/xcodegen`) |
| ImageMagick 7 (`magick`) | **only** when regenerating icon PNGs from the APK SVGs | `brew install imagemagick` |
| Python 3 | SVG normaliser used by the icon regeneration | macOS system Python 3 |
| Xcode 16+ (full Xcode) | building the **iOS** app / IPA locally | App Store; not installed on this Mac |

> **No XCTest locally.** The Command Line Tools toolchain ships no `XCTest` module, so
> `swift test` does **not** work here. Tests are plain executable targets:
> `swift run ORIPATests` (unit/golden tests) and `swift run ORIPAIntegration` (headless
> end-to-end checks over the real app layer). Both exit non-zero on failure and CI runs
> the same commands, so local and CI verification are identical.
>
> **iOS builds are CI-only on this machine.** `xcodebuild` requires a full Xcode
> installation; the IPA is produced by GitHub Actions (`macos-15` runners have Xcode).
> Everything else is verified locally with `swift build` / `swift run`.

### CI

GitHub Actions `macos-15` runners (Xcode 16.x, Swift 6 toolchain in Swift 5 language
mode, Homebrew). No signing certificates, provisioning profiles, secrets or third-party
Swift dependencies are used.

---

## 2. Quick start

```bash
cd /Users/william/Desktop/hns/apps/oripa-swift

# Build everything type-checkable on this Mac (debug).
swift build

# Run the hermetic test suite (replaces `swift test` on this toolchain).
swift run ORIPATests

# Headless end-to-end integration checks (real app layer).
swift run ORIPAIntegration

# Render the SwiftUI screens headlessly to PNG for visual QA.
swift run ORIPASnapshots build-snapshots
#   -> build-snapshots/*.png + build-snapshots/manifest.json

# Generate the committed Xcode project from project.yml (iOS target).
/opt/homebrew/bin/xcodegen generate

# One-shot local verification (build + tests + snapshots).
bash scripts/run_tests.sh
#   SKIP_SNAPSHOTS=1 bash scripts/run_tests.sh   # faster, skips ImageRenderer
```

`swift run ORIPASnapshots --help` lists the options (`-l/--list`, `-s/--scenario`,
`-o/--out`, `--scale 1...4`).

### Optional: local iOS typecheck (no Xcode needed)

CI is the authoritative iOS build, but the shared Swift/SwiftUI code can also be
type-checked for `arm64-apple-ios16.0` on this Mac, using the Command Line Tools
toolchain plus an iPhoneOS SDK that matches that toolchain's Swift version:

```bash
# with a full Xcode installation:
IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)" bash tools/ios_typecheck.sh
# or point IOS_SDK at any locally available iPhoneOS SDK:
IOS_SDK=/path/to/iPhoneOS.sdk bash tools/ios_typecheck.sh
```

It emits the `ORIPACore`/`ORIPAUI` modules for the iOS triple, typechecks every
`#if canImport(UIKit)` branch (e.g. the raw-touch gesture adapter), and typechecks
`iOSApp/ORIPAApp.swift`. This catches iOS-only compile errors that the macOS build cannot
see. A full Xcode is still required to actually build/package the IPA
(`scripts/build_ipa.sh`).

---

## 3. macOS app

```bash
bash scripts/build_mac.sh
```

* Runs `swift build -c release --product ORIPAMac` (works with CLT only).
* Assembles `build/macos/ORIPA.app`:
  * `Contents/MacOS/ORIPA` — the SwiftPM executable;
  * `Contents/Resources/ORIPA_ORIPAUI.bundle` — the SwiftPM resource bundle
    (icons/logos). ORIPAUI resolves it through a `BundleFinder`-style candidate list
    (`Bundle.main.resourceURL`, `Bundle.main.bundleURL`, `Bundle(for:)`), which works
    both for `swift run` (no app bundle) and for the assembled `.app`. Do **not** copy
    the bundle to the app root: that makes `codesign` report unsealed contents and
    Gatekeeper blocks downloaded copies;
  * `Contents/Info.plist` — bundle id `com.origamitoolbox.oripa.mac`
    (deliberately different from iOS so both apps can coexist),
    `LSMinimumSystemVersion 13.0`, `NSHighResolutionCapable`, version read from
    `Sources/ORIPACore/Version.swift`;
  * `Contents/Resources/AppIcon.icns` — derived from the committed iOS 1024 px icon.
* Ad-hoc signs the bundle (`codesign --force --deep --sign -`), strict-verifies the
  signature (`codesign --verify --deep --strict`) — enough to launch locally,
  **not notarised** (Gatekeeper: right-click → Open, see `docs/INSTALL.md`).
* Zips it with `ditto` to `build/macos/ORIPA-macOS.zip`.

Open it with `open build/macos/ORIPA.app`.

---

## 4. iOS app and unsigned IPA

`project.yml` (XcodeGen) defines the iOS app target:

* target `ORIPA`, bundle id `com.origamitoolbox.oripa` (same as the previous WKWebView
  port so upgrades keep the Documents container), `MARKETING_VERSION 0.2.3.3`,
  `CURRENT_PROJECT_VERSION 2`, deployment target **iOS 16.0**, `TARGETED_DEVICE_FAMILY
  1,2` (iPhone + iPad), all orientations (plus upside-down on iPad);
* `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` (Files.app access — hard
  user requirement), status bar style default, Info.plist `UILaunchScreen` with the
  ORIPA wordmark, `Assets.xcassets` AppIcon set;
* depends on the local Swift package (`.`): products `ORIPACore` + `ORIPAUI`;
* one shared scheme `ORIPA` so `xcodebuild -scheme ORIPA ...` works.

The generated `ORIPA.xcodeproj` is **committed** (CI regenerates it, contributors can
open it immediately). Never hand-edit it — edit `project.yml` and run:

```bash
xcodegen generate
git diff ORIPA.xcodeproj   # review the regenerated project
```

### Building the IPA locally (requires full Xcode)

```bash
xcodegen generate
bash scripts/build_ipa.sh                 # unsigned build + Payload/ORIPA.app -> ZIP
ADHOC_SIGN=1 bash scripts/build_ipa.sh    # also ad-hoc sign the .app (optional)
```

Output:

```
build/ios/ORIPA-unsigned.ipa      # artifact to sideload (docs/INSTALL.md)
build/ios/xcodebuild-ios.log      # full xcodebuild log
build/ios/Payload/ORIPA.app        # the built .app (inspectable)
```

Equivalent xcodebuild invocation (what the script runs):

```bash
xcodebuild -project ORIPA.xcodeproj -scheme ORIPA -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

`build_ipa.sh` also validates the result: `plutil -lint` the Info.plist, asserts
`CFBundleIdentifier == com.origamitoolbox.oripa`, prints `lipo -info` and the
`LC_BUILD_VERSION` load command (platform `IOS`, arch `arm64`), and prints the IPA size
and SHA-256.

---

## 5. Asset pipeline (icons, app icon, launch logo)

The PNGs under `Sources/ORIPAUI/Resources/**` and `iOSApp/Assets.xcassets/**` are
**committed**; regeneration is only needed when the upstream APK SVGs or the ORIPA logos
change. Requires a sibling checkout of the reference port at `../oripa-port`.

```bash
# APK vector drawables (SVG) -> 105 icons + 4 logos + iOS AppIcon set + LaunchLogo:
bash tools/assets/convert_icons.sh [/path/to/oripa-port]

# AppIcon/LaunchLogo only (no oripa-port checkout needed):
bash tools/assets/make_app_icons.sh
```

`tools/assets/convert_icons.sh` normalises each SVG first with
`tools/assets/normalize_svg.py`, which fixes three things that otherwise produce blank
icons:

1. Android ARGB hex colours (`#AARRGGBB`) → `rgba()` (ImageMagick drops invalid fills);
2. `transform` attributes on groups are baked into path coordinates (ImageMagick's SVG
   renderer ignores `rotate(...)` — this is what used to make the two
   `*_arrow_drop_right_*` icons fully transparent);
3. `@string/...` path-data references (e.g. `design_ic_visibility`,
   `$avd_hide_password__0`) are resolved from the decoded
   `rev/apktool/res/values/strings.xml`.

Every generated PNG is checked for non-zero alpha; the script fails if any icon is
blank. Output is byte-identical across runs (`-strip`, no date/time chunks), so
regeneration leaves a clean diff.

The iOS AppIcon is the ORIPA mark composited on white at all legacy sizes
(20/29/40/60/76/83.5/1024, iPhone+iPad+marketing) — visually identical to the previous
port's icon, but without an alpha channel (App Store requirement) and with a proper
`Assets.xcassets` AppIcon set. `build_mac.sh` derives the macOS `.icns` from the 1024 px
PNG, so there is a single source of truth.

---

## 6. CI (GitHub Actions)

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).
Triggers: push to `main`, pull requests, manual **Run workflow**.

| Job | Runner | Steps | Artifact (14 days) |
|---|---|---|---|
| `test` | `macos-15` | `swift build`, `swift run ORIPATests`, `swift run ORIPAIntegration`, `swift run ORIPASnapshots build-snapshots` | `oripa-ui-snapshots` (PNG + manifest) |
| `ios` | `macos-15` | `xcodegen generate`, `scripts/build_ipa.sh` | `ORIPA-unsigned.ipa`; `ios-build-log` on failure |
| `macos` | `macos-15` | `scripts/build_mac.sh` | `ORIPA-macOS` (zip) |

The jobs are independent: a failing test or iOS build never prevents the other
artifacts. No secrets/signing credentials are used (`CODE_SIGNING_ALLOWED=NO`).
Download instructions: `docs/PUBLISH.md`.

---

## 7. Versioning and bundle identifiers

Keep these in sync (all live in the repo; CI does not check them, review them in PRs):

| Value | Source of truth | Also used by |
|---|---|---|
| `0.2.3.3` (marketing version) | `Sources/ORIPACore/Version.swift` (`AppInfo.version`) | `project.yml` (`MARKETING_VERSION`), macOS Info.plist (generated by `build_mac.sh`) |
| build `2` | `Sources/ORIPACore/Version.swift` (`AppInfo.build`) | `project.yml` (`CURRENT_PROJECT_VERSION`), macOS Info.plist |
| iOS bundle id `com.origamitoolbox.oripa` | `AppInfo.bundleIdentifier` | `project.yml`, `iOSApp/Info.plist` (`$(PRODUCT_BUNDLE_IDENTIFIER)`) |
| macOS bundle id `com.origamitoolbox.oripa.mac` | `scripts/build_mac.sh` | — |

The iOS bundle id must **never** change: it is what makes the user's existing
`Documents/project_data` and `project_thumbs` files survive an upgrade from the old
WKWebView port.

---

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `xcodebuild: error: tool 'xcodebuild' requires Xcode` | Full Xcode not installed (CLT only). Build the iOS app on CI, or install Xcode and `sudo xcode-select -s /Applications/Xcode.app`. |
| `xcodegen: command not found` | `brew install xcodegen` (XcodeGen 2.46+; `/opt/homebrew/bin/xcodegen`). |
| `swift test` fails: no such module 'XCTest' | Expected on the CLT-only toolchain. Use `swift run ORIPATests` / `swift run ORIPAIntegration`. |
| `error: could not load resource bundle: ... ORIPA_ORIPAUI.bundle` | The SwiftPM resource bundle was not copied next to the executable (macOS) / into the app. `scripts/build_mac.sh` handles this; for a bare `.app` copy `ORIPA_ORIPAUI.bundle` to both the app root and `Contents/Resources`. |
| Blank/missing Material icons | Re-run `bash tools/assets/convert_icons.sh` (needs the `oripa-port` checkout + ImageMagick) and check its non-blank-alpha validation. |
| `swift build` errors in files you did not change | Another workstream is mid-edit (shared working tree). Pull/refresh, or wait; never edit files outside your scope. |
| Stale/corrupt SwiftPM build | `rm -rf .build` and rebuild. |
| CI iOS job fails but locally `swift build` is green | iOS compiles the shared code with the iOS SDK + Xcode; check the `ios-build-log` artifact. `#if os(iOS)`-only APIs must be guarded per the port contract. |
| macOS app shows "is damaged and can't be opened" | Unsigned/not-notarised download was quarantined: right-click → Open once, or `xattr -dr com.apple.quarantine ORIPA.app`. |
| CI artifact download buttons missing | The job is still running or failed; artifacts only appear after the job finishes (see `docs/PUBLISH.md`). |
