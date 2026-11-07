# ORIPA — native Apple port (Swift / SwiftUI)

Native **iOS/iPadOS + macOS** port of **ORIPA for Android 0.2.3.3** — the crease-pattern
(折痕図) editor from [ORIPA](https://github.com/oripaweb) / ORIPA S, as shipped in the
[oripaweb](https://github.com/wiorigami/oripaweb) iPad build.

> Status: port in progress. Build locally with `swift build`, `swift test`,
> `swift run ORIPASnapshots`. iOS IPA is built by GitHub Actions
> (`.github/workflows/ci.yml`) — see [docs/BUILD.md](docs/BUILD.md).

* Same workflow, tools, file formats (OPX/OPXC/CP/SVG/PNG), foldability check and
  folded-model views (X-Ray / Overlap / Cut Line) as the ported app.
* Native system integration: Files.app-backed project storage, document picker import,
  share-sheet export, multi-touch, pointer/keyboard, dark mode.
* Local-first: projects are stored on disk and survive restarts; crash-safe autosave.
* No network, no third-party dependencies.

**Credits:** ORIPA © 2005–2009 Jun Mitani · ORIPA S © 2012 Ouchi Koji ·
ORIPA for Android © 2016–2018 Michelle Fung. GPL-3.0 (see [LICENSE](LICENSE)).
