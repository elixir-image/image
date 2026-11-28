# TODO

Work tracking for `Image`. Design documents live under [plans/](plans/), and anything longer than a short paragraph belongs there rather than here.

## Open

* [ ] **`radial_gradient/3` has no pixel radius or fade curve** — `:radius` is a unitless 1..5 scale and the fade is linear; add both without breaking the current options. Mishka gap 19.

* [ ] **Rule 2 bang sweep** — 173 calls to `!` functions remain inside non-bang functions (84 in `lib/image.ex`, 48 in `Image.Math`, mostly its operators). Each needs judging: a bang on values the library built itself is acceptable, one on caller input is not.

* [ ] **Value attributes defined between functions** — 33 module attributes such as `@max_rgb_band_value` sit after the first function definition (20 in `lib/image.ex`, the rest across nine files), against the house rule that they go in one block at the top.

* [ ] **`Image.compare/3`'s "Invalid metric" error uses a string `:reason`** — every other error path uses an atom after #231. Changing it is breaking.

* [ ] **`:font_file` has no effect on macOS** — the precompiled libvips renders text with Pango's CoreText backend, which never sees a font registered through fontconfig, so `Image.meme/3` and `Image.Text` fall back to a system font unless `PANGOCAIRO_BACKEND=fc` is set. Linux is unaffected. Belongs upstream in libvips or vix's precompiled build. The workaround is documented under "Fonts" in `Image.Text`.

## In progress

* [ ] **Livebook smart cell** — a cell that composes an `Image` pipeline from a form, previews it and writes the equivalent source into the notebook. On `main` since `81980d1` for 0.74.0, awaiting live testing in a notebook before release. Design in [plans/livebook-smart-cell.md](plans/livebook-smart-cell.md), issue [#31](https://github.com/elixir-image/image/issues/31).

## Deferred

* [ ] **Remove `Image.opacity/2` and `Image.opacity!/2`** — deprecated; removed at 1.0 and not before (user's decision, 2026-11-20).

* [ ] **Remove the `:twitter` alias from `Image.Social`** — deprecated in favour of `:x`; removed at 1.0 and not before (user's decision, 2026-11-21).

* [ ] **Maker notes in the privacy scan** — camera makers' proprietary EXIF blocks can hold body serial numbers and owner names (Canon's `OwnerName` and `InternalSerialNumber`, for example), and `Image.Privacy.scan/1` does not read them. Needs a parser per maker, starting with Canon, Nikon, Sony and Apple, and sample photos to test against. `Image.remove_metadata(image, :exif)` and `strip_metadata: true` already remove them. Detail in [plans/privacy-scan.md](plans/privacy-scan.md).

* [ ] **`Image.compare/3` returns sRGB for `:lab`, `:lch` and `:cmyk`** — `composite2/3` composites outside the sRGB family in 8-bit sRGB and returns its result there, so the composed difference cannot stay in those interpretations. Fixing it means hand-rolling the OVER blend with `Image.Math` instead of calling libvips.

## Done

* [x] **Text fitting reports what it chose** — `Image.Text.text_with_fit/2` returns the font size, the text shown and `truncated?`; `shorten_at: :sentence` cuts at whole sentences. Mishka gap 18. 2026-11-28.

* [x] **Masks no longer need SVG loading** — circle, rounded and squircle masks, `Image.fade/2` and `Image.Text` backgrounds are computed from pixels; an existing alpha is now scaled by the mask. Mishka gap 17. 2026-11-28.

* [x] **`:font_file` and `FONTCONFIG_FILE` documented** — `Image.Text` explains both and the `PANGOCAIRO_BACKEND=fc` setting macOS needs. Mishka gap 16. 2026-11-28.

* [x] **Privacy docs cover re-encoding and frame loss** — the guide and `Image.Privacy.remove/2` say saving re-encodes and drops frames without `pages: :all`. Mishka gap 15. 2026-11-28.

* [x] **`Image.Social` sizes and names reviewed** — `:twitter` renamed `:x` with an alias, sizes corrected against current platform guidance, every platform given a default usage. 2026-11-21, v0.74.0.

* [x] **Doc bullet punctuation** — every bullet in `lib` docs ends in a period or `, or`, with a blank line after it; 475 items punctuated and 93 tight items spaced. 2026-11-21, v0.74.0.

* [x] **`Image.Social` returns errors instead of raising** — `image_usages/1` and `default_image_usage/1` return tagged tuples, errors carry atom reasons, `resize/3` has no bang calls. 2026-11-21, v0.74.0.

* [x] **Every test runs in CI** — text tests render with fontconfig and fonts bundled in `test/support/fonts`, so their references match on every platform; CI sets `PANGOCAIRO_BACKEND` and `FONTCONFIG_FILE`, and locally the text tests run only when both are set. 2026-11-21.

* [x] **House-rule violations** — the smart cell no longer creates atoms from text fields, no `with` has an `else`, and no `{:ok, _} =` match remains on a runtime path. 2026-11-21, v0.74.0.

* [x] **Every public function has a `@spec`** — including the `Image.Math` operators and the options modules' `validate_options`, whose docs now follow the house template and run as doctests. 2026-11-20, v0.74.0.

* [x] **Consistent `Image.Math` operands** — invalid operands return or raise `Image.Error`, numbers and lists may be the left operand, operators fall back to `Kernel` and `Bitwise` without an image, and trigonometry is in degrees throughout. 2026-11-20, v0.74.0.

* [x] **Document `Image.Math`** — the 44 undocumented functions have docs and doctests; the module stays public for `use Image.Math`. 2026-11-20, v0.74.0.

* [x] **Options modules stop exposing helpers** — each `Image.Options.*` module shows only `validate_options`; helpers other modules need are `@doc false`, the rest private, and dead ones removed. 2026-11-20, v0.74.0.

* [x] **Bundled meme font** — `Image.meme/3` uses Anton (SIL OFL 1.1) in place of a copy of Monotype's Impact, and the three Impact files are gone from the package. 2026-11-20, v0.74.0.

* [x] **Flat-sided superellipse squircle** — `Image.squircle/2` draws superellipse corners joined by straight edges, the same shape at every size; design in [plans/squircle.md](plans/squircle.md). 2026-11-20, v0.74.0.

* [x] **XMP editing history in the privacy scan** — reported as `:document_history` and removable with `Image.Privacy.remove/2`. 2026-11-15, v0.74.0.

* [x] **Targeted removal in the privacy scan** — `Image.Privacy.remove(image, findings)` removes each EXIF field, IPTC dataset, XMP property and PNG text chunk on its own, keeping the rest. 2026-11-15, v0.74.0.

* [x] **Privacy scan** — `Image.Privacy.scan/1` reports tracking and identifying data in IPTC, EXIF, XMP and PNG text, and JPEG and PNG trailing data, with the privacy guide. C2PA deliberately not scanned; maker notes deferred. 2026-11-15, v0.74.0.

* [x] **`Image.exif/1` returns `:thumbnail`** — `Image.Exif` reads IFD1, in either order relative to IFD0; the broken, unused `Image.Exif.Thumbnail.to_image/2` was removed. 2026-11-15, v0.74.0.

* [x] **Gain map support** — UltraHDR gain maps stay aligned through every geometric operation, or are removed where they cannot be; `Image.GainMap` and the HDR and gain maps guide. 2026-11-01, v0.74.0.

* [x] **Dead CI exclusion** — `.github/workflows/ci.yml` no longer excludes the `heic_compression` tag, which no test used. 2026-10-10.
