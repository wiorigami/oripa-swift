# ORIPA — native Apple port (Swift / SwiftUI)

Native **iOS/iPadOS + macOS** port of **ORIPA for Android 0.2.3.3** — the crease-pattern
(折痕図) editor from [ORIPA](https://github.com/oripaweb) / ORIPA S, as shipped in the
[oripaweb](https://github.com/wiorigami/oripaweb) iPad build.

> **Status:** port in progress. The SwiftUI shell, core model and build/packaging pipeline
> are under active development; test counts and screenshot coverage grow every day.
> Build locally with `swift build` / `swift run ORIPATests` / `swift run ORIPASnapshots`.
> iOS IPA and macOS app are built by GitHub Actions (`.github/workflows/ci.yml`).

* Same workflow, tools, file formats (OPX/OPXC/CP/SVG/PNG), foldability check and
  folded-model views (X-Ray / Overlap / Cut Line) as the ported app.
* Native system integration: Files.app-backed project storage, document picker import,
  share-sheet export, multi-touch, pointer/keyboard, dark mode.
* Local-first: projects are stored on disk and survive restarts; crash-safe autosave.
  Same bundle id (`com.origamitoolbox.oripa`) as the previous WKWebView port, so existing
  projects keep working after upgrading.
* No network, no third-party dependencies.

## Downloads

GitHub Actions builds two **unsigned/notarisation-free** artifacts on every push to `main`
(also available from the Actions tab for pull requests and manual runs):

| Artifact | Platform | How to install |
|---|---|---|
| `ORIPA-unsigned.ipa` | iPhone/iPad, iOS 16+ | Sign with Sideloadly / i4Tools / TrollStore — see [docs/INSTALL.md](docs/INSTALL.md) |
| `ORIPA-macOS` (zip) | macOS 13+ | Unzip and run `ORIPA.app` (right-click → Open) — see [docs/INSTALL.md](docs/INSTALL.md) |
| `oripa-ui-snapshots` (zip) | any | PNG renders of every screen for visual QA |

How to trigger builds and download the artifacts: [docs/PUBLISH.md](docs/PUBLISH.md).

## Building from source

Requirements and full instructions: [docs/BUILD.md](docs/BUILD.md).

```bash
cd oripa-swift

swift build                                  # SwiftPM build (macOS toolchain)
swift run ORIPATests                         # hermetic test suite (no XCTest locally)
swift run ORIPASnapshots build-snapshots     # headless SwiftUI screenshots -> build-snapshots/
xcodegen generate                            # regenerate ORIPA.xcodeproj from project.yml
bash scripts/build_mac.sh                    # macOS .app + ORIPA-macOS.zip (CLT only)
bash scripts/build_ipa.sh                    # unsigned iOS IPA (requires full Xcode)
bash scripts/run_tests.sh                    # build + tests + snapshots in one go
```

> This Mac has Command Line Tools only: `xcodebuild` needs a full Xcode, and the CLT
> toolchain ships no `XCTest` module, so `swift test` is unavailable too. Tests run
> through the `ORIPATests` executable (`swift run ORIPATests`) and the iOS IPA is produced
> in CI. The generated `ORIPA.xcodeproj` is committed.

## Repository layout

```
Package.swift                 SwiftPM: ORIPACore (Foundation logic), ORIPAUI (SwiftUI), ORIPAMac,
                              ORIPASnapshots, ORIPATests
Sources/ORIPACore/            pure Foundation port of the JS/Java core (no SwiftUI/UIKit)
Sources/ORIPAUI/              shared SwiftUI app (screens, design system, canvas, resources)
Sources/ORIPAMac/             macOS @main wrapper
Sources/ORIPASnapshots/       headless ImageRenderer QA tool
Tests/ORIPATests/             hermetic test runner + golden fixtures
iOSApp/                       iOS @main wrapper, Info.plist, Assets.xcassets (AppIcon/LaunchLogo)
project.yml + ORIPA.xcodeproj XcodeGen spec + committed generated iOS project
tools/assets/                 SVG -> PNG icon pipeline, AppIcon generator
scripts/                      build/test/package scripts
.github/workflows/ci.yml      tests + unsigned IPA + macOS app artifacts
docs/                         port contract, build/install/publishing guides
```

The port deliberately mirrors the reference implementation (class/method names, constants,
algorithms); see [docs/PORT-CONTRACT.md](docs/PORT-CONTRACT.md) for architecture, ownership
and the definition of done.

## Credits

ORIPA © 2005–2009 Jun Mitani · ORIPA S © 2012 Ouchi Koji ·
ORIPA for Android © 2016–2018 Michelle Fung. GPL-3.0 (see [LICENSE](LICENSE)).
