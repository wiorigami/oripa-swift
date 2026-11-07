# fold-io golden fixtures

Golden JSON for the `ORIPACore` fold engine / file IO / render-data port, generated from the
reference JavaScript implementation in `oripa-port/src/js` (the same code the web port runs).

CI never runs Node: only the committed output under `Fixtures/foldio/*.json` and
`Fixtures/cases/**` is decoded by `Tests/ORIPATests/FoldIO/**` via the shared
`TestHarness`/`Fixtures` support.

## Regenerate

```bash
cd oripa-swift
node tools/fixtures/foldio/gen_foldio.js
```

The script uses `tools/fixtures/load_oripa.js` (auto-detects `../oripa-port/src`, or pass
`ORIPA_JS_ROOT`), copies `oripa-port/tools/fold_oracle/cases/**` into `Fixtures/cases/`, and
writes deterministic JSON (verified byte-stable across runs):

| file | contents |
|---|---|
| `roundtrip.json` | CP/OPX/OPXC/SVG export strings, load→export byte-identical re-export, `FileUtil`, `Double.toString` emulation cases, `LoaderOpxcToGL` arrays, OPX tolerance, malformed-input errors |
| `cases.json` | every oracle case in `Fixtures/cases/**`: `isFlatFoldable` verdict, `facesCheck`/`pointErrorCheck` counts + points, folded model (counts, componentCount, per-vertex `valueAfterFold`, per-face transform matrices + half-edge/twin wiring, draw orders), matrix consistency error, repeated-fold determinism, folded-model SVG (overlap/overlap-flip/xray/wireframe), xray/cut-line/overlap-split render data |
| `engine.json` | `FoldedModel` on programmatic `facesCheck` polygons (square base, single square, disconnected squares, custom half size, empty) incl. full render data, `CrossLine` numbers, `CrossLineManager` state |
| `renderdata.json` | every `GLData*` builder output for two crease patterns (`GLDataCpLinesTyped`, `GLDataCpLinesTypedWidth`, `GLDataLinesWidth`, `GLDataCpPolygons`, `GLDataCpSimple`, `GLDataCpPreview`) |

## Notes

- Folded geometry is stored with full JS-double precision; the Swift tests compare with a
  `1e-4` absolute tolerance for float32-encoded model data and exact equality for
  counts/indices/types. Folded-model SVG comparisons are structure-exact with numeric
  tolerance; overlap shadow vertex angles compare modulo 360° (V8's fdlibm vs system libm
  can differ by one last ulp before the tenth-of-a-degree truncation).
- Large models (`fu_character.cp`, 236 faces) store overlap render data as array lengths +
  first 32 values ("compact" form) to keep the committed fixtures small; the small engine
  models cover the full arrays.
