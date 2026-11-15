# TODO

Work tracking for `Image`. Design documents live under [plans/](plans/), and anything longer than a short paragraph belongs there rather than here.

## Open

* [ ] **Finish the Rule 2 sweep** — `Image.compare/3` guards its options with `is_list/1` and three functions guard a callback with `is_function(fun, 1)`, so all four raise `FunctionClauseError` rather than returning an error. Both were left deliberately: #220 made non-keyword options raise on purpose, and a wrong-arity callback is a programmer error where a loud failure beats a hidden one. Decide whether that still stands.

* [ ] **`Image.Social.image_usages/1` and `default_image_usage/1` raise for an unknown platform** — they return bare values rather than tuples, so converting them changes their contract shape rather than just their error path.

* [ ] **`Image.compare/3`'s "Invalid metric" error uses a string `:reason`** — every other error path uses an atom after #231. Changing it is breaking.

* [ ] **Doc bullet punctuation** — around 480 documentation bullet items do not end in terminal punctuation, against the house rule. Roughly half of those legitimately end in "or", being the `X or` / `Y.` return pattern, so a blanket fix would corrupt them.

## In progress

* [ ] **Privacy scan** — a function that reports tracking and identifying data in an image (Facebook's `FBMD` IPTC identifier, device serials, GPS, XMP document IDs, hidden trailers), paired with metadata removal. Stages 1 and 2 are on `main` as `Image.Privacy.scan/1`; the guide section remains. C2PA is deliberately not scanned. Plan in [plans/privacy-scan.md](plans/privacy-scan.md).

* [ ] **Livebook smart cell** — a cell that composes an `Image` pipeline from a form, previews it and writes the equivalent source into the notebook. On `main` since `81980d1` for 0.74.0, awaiting live testing in a notebook before release. Design in [plans/livebook-smart-cell.md](plans/livebook-smart-cell.md), issue [#31](https://github.com/elixir-image/image/issues/31).

## Deferred

* [ ] **`Image.compare/3` returns sRGB for `:lab`, `:lch` and `:cmyk`** — `composite2/3` composites outside the sRGB family in 8-bit sRGB and returns its result there, so the composed difference cannot stay in those interpretations. Fixing it means hand-rolling the OVER blend with `Image.Math` instead of calling libvips.

## Done

* [x] **`Image.exif/1` returns `:thumbnail`** — `Image.Exif` reads IFD1, in either order relative to IFD0; the broken, unused `Image.Exif.Thumbnail.to_image/2` was removed. 2026-11-15, v0.74.0.

* [x] **Gain map support** — UltraHDR gain maps stay aligned through every geometric operation, or are removed where they cannot be; `Image.GainMap` and the HDR and gain maps guide. 2026-11-01, v0.74.0.

* [x] **Dead CI exclusion** — `.github/workflows/ci.yml` no longer excludes the `heic_compression` tag, which no test used. 2026-10-10.
