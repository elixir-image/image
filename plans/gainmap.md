# Gain map support

**Status:** in progress, 2026-11-01

UltraHDR JPEGs carry a gain map: a second, usually half-resolution image that records how much brighter each region should be on an HDR display. An image opened with `Image.open/2` already keeps its gain map and `Image.write/3` already writes it back, but almost every geometric operation leaves the gain map describing the *original* frame. The file that comes out is a valid JPEG whose HDR rendition is misaligned, stretched or mirrored. This plan makes the gain map follow the image through every `Image` operation, with as little change to the public API as possible.

## What libvips provides

UltraHDR support arrived in libvips 8.18.0 through the optional `libuhdr` dependency. The precompiled libvips that `vix` 0.42.0 ships is 8.18.7 built with libultrahdr 2.0.2, so every user on the default `PRECOMPILED_NIF_AND_LIBVIPS` mode already has it. `Vix.Vips.Operation` exposes `uhdrload`, `uhdrload_buffer`, `uhdrsave`, `uhdrsave_buffer` and `uhdr2scrgb`.

* **Loading** — libvips picks `uhdrload` automatically for an UltraHDR JPEG, so `Image.open/2` needs no change.

* **Representation** — the gain map is held as metadata, never as image bands. `gainmap-data` is the compressed gain map as a JPEG blob; `gainmap` is an optional *decoded* gain map image that takes precedence over `gainmap-data` when saving. The parameters are `gainmap-scale-factor`, `gainmap-min-content-boost`, `gainmap-max-content-boost`, `gainmap-gamma`, `gainmap-offset-sdr`, `gainmap-offset-hdr`, `gainmap-hdr-capacity-min`, `gainmap-hdr-capacity-max` and `gainmap-use-base-cg`.

* **Saving** — `jpegsave` hands off to `uhdrsave` whenever `gainmap-data` is present, so `Image.write/3` to a JPEG target writes an UltraHDR file. Every other format drops the gain map. `VIPS_FOREIGN_KEEP_GAINMAP` controls whether the `gainmap*` fields survive a save's `keep` filter.

* **Transforms** — only `thumbnail` (and `dzsave`) update the gain map. libvips merged automatic handling for crop and resize in PR #4709 and then reverted it before release as "adding too much complexity", leaving the job to higher-level libraries. The scale relationship is never stored: callers derive it from the dimensions (`gainmap.width / image.width`) each time.

* **Rendering** — `uhdr2scrgb` applies the gain map at full boost and returns a float scRGB HDR image. It has no headroom or weight parameter.

* **Formats** — only UltraHDR JPEG today. AVIF gain maps, and possibly JXL, are planned for libvips 8.20 through libultrahdr 2; 8.20 has no announced date, and 8.19 entered feature freeze on 2026-10-27 without them. Apple and Adobe Camera Raw 16.1 gain maps are not recognised by libultrahdr.

## What sharp does

sharp 0.35.0 (June 2026) added two experimental, mutually exclusive output methods. The default is to **drop** the gain map.

* **`keepGainMap()`** decodes the gain map once and replays every geometric operation on it at its own resolution, dividing offsets and sizes by `gainmap-scale-factor` with truncating integer division. It covers resize, extract and gravity crop, 90° rotation, flip, flop, EXIF auto-orientation and extend. Any other rotation angle, `trim`, `affine` and smart crop throw. Blur and negate are applied to the gain map; most colour operations leave it unchanged, and composite, modulate and similar throw. Only JPEG output keeps it.

* **`withGainMap()`** applies the gain map with `uhdr2scRGB`, discards it and lets libultrahdr compute a new one on JPEG output.

* **Lessons** — extract did not crop the gain map until 0.35.5 (#4606), the sharp maintainer intends to make keeping the default once libvips has CICP support, and colour space conversion leaves the gain map's channel gains wrong (#4612, open).

## What `Image` does today

Measured on libvips 8.18.7 by opening a generated UltraHDR JPEG (1000×542 base, 500×271 gain map), applying each function, writing with `Image.write/3` and reloading with `uhdrload`.

| Call | Result |
|---|---|
| `open` then `write` | Correct |
| `thumbnail/3` (path or image) | Correct, because libvips handles it |
| `resize/3` | Wrong at most scales; 0.5 only works because it happens to match the gain map |
| `crop/5`, `center_crop/3` | Corrupt — aspect ratio mismatch, gain map covers the original frame |
| `rotate/3` by 90 | Corrupt — gain map left in the old orientation |
| `embed/4` | Corrupt — gain map stretched over the new canvas |
| `flip/2` | Silently corrupt — dimensions look right but the gain map is not mirrored |
| `write/3` with `strip_metadata: true` | Gain map dropped; `minimize_file_size: true` does the same for JPEG |

The fix is proven: transforming the decoded gain map in its own coordinate space and setting it as the `gainmap` field with `Vix.Vips.Image.mutate/2` and `MutableImage.set(m, "gainmap", :VipsImage, gain_map)` makes an unchanged `Image.write/3` produce a correct file (crop: 300×200 base with 150×100 gain map; rotate: 542×1000 with 271×500). No change to `vix` is needed.

## Design

### Principles

* **Correct or absent, never stale.** Every `Image` function either transforms the gain map correctly or removes it. A removed gain map yields a valid SDR image; a stale one yields a broken HDR image that looks fine on an SDR screen, so the defect goes unnoticed.

* **Keep by default.** Unlike sharp, `Image` keeps the gain map by default, because `Image.open/2` followed by `Image.write/3` already preserves it and switching to drop would change today's correct output. Users who never touch HDR files see no change.

* **No new arguments on existing functions.** The gain map travels as metadata on the `Vimage`, so `resize/3`, `crop/5` and the rest keep their signatures. Control lives in one `Image.open/2` option and one new module.

* **Derive the scale, never store it.** Each operation computes horizontal and vertical ratios from the gain map and base dimensions, as libvips' own `thumbnail` does, so successive operations cannot accumulate drift.

* **Degrade on old libvips.** An image only has `gainmap*` fields on libvips 8.18 and later, so detection by field presence is a no-op elsewhere. Functions that need `uhdr2scrgb` check that it exists and return `{:error, %Image.Error{}}` when it does not.

### Public API

* **`Image.GainMap`** — a new module for the few things a caller needs to do explicitly:

  * `gain_map?/1` — whether the image carries a gain map.

  * `gain_map/1` — the decoded gain map as `{:ok, Vimage.t()}`, `{:ok, nil}` when absent, or `{:error, reason}`. This mirrors `vips_image_get_gainmap/1`, which `vix` does not bind.

  * `info/1` — the gain map parameters as a struct with Elixir field names.

  * `remove/1` — returns the image without its gain map, so it saves as plain SDR.

  * `apply/1` — renders the HDR image with `uhdr2scrgb`, returning float scRGB and discarding the gain map. This is sharp's `withGainMap`.

* **`Image.open/2` option `:gain_map`** — `:keep` (default) carries it, `:drop` removes it on open, and `:apply` returns the rendered HDR image.

* **`Image.write/3`** — unchanged for JPEG. Writing to a format that cannot carry a gain map drops it, as today.

### Per-operation mapping

Each geometric function gets the same treatment: if the input has a gain map, apply the equivalent operation to the decoded gain map at its own scale and set the result as the `gainmap` field on the output. One internal helper does the decode, scale computation and `mutate`, so each function adds a few lines.

| Function | Gain map treatment | Phase |
|---|---|---|
| `thumbnail/3` | Handled by libvips; add tests only | 1 |
| `resize/3` | Same horizontal and vertical scale, linear kernel as libvips uses | 1 |
| `crop/5`, `center_crop/3`, `crop/2` | `extract_area` at scaled coordinates; `crop/2` only accepts rectangles and delegates to `crop/5` | 1 |
| `trim/2` | Free once `crop/5` is aware, since it crops a found box | 1 |
| `rotate/3` by multiples of 90 | Same `rot` | 1 |
| `flip/2` | Same flip | 1 |
| `autorotate/1` | Same orientation correction | 1 |
| `embed/4` | Embed at scaled offsets with the "no boost" encoded value as background | 1 |
| `rotate/3` by other angles | Removed now; same angle at the gain map's scale in phase 3 | 3 |
| `affine/3`, `translate/4`, `shear/4` | Same linear part, translation scaled | 3 |
| `warp_perspective/4`, `straighten_perspective/3`, `distort/4`, `map/3`, `ripple/2`, polar transforms | Remove the gain map | 2 |
| `join/2`, `compose/3`, `extract_pages/1` | Remove the gain map | 2 |
| Colour and tone operations | Keep unchanged, since HDR is SDR × gain | 2 |
| Colour space conversion away from the gain map's gamut | Remove, per sharp #4612 | 2 |

Rounding: scale offsets with `floor` and far edges with `ceil`, then clamp to the gain map bounds, so a crop never loses the last gain map row or column. sharp truncates both and can lose one.

The "no boost" background for `embed/4` is the encoded value whose decoded gain is 1.0, which depends on `gainmap-min-content-boost`, `gainmap-max-content-boost`, `gainmap-gamma` and the offsets. It is 0 only when the minimum boost is 1.0, so it must be computed, not assumed.

## Tasks

* [x] **Fixture** — commit a small UltraHDR JPEG generated from an existing test image with `uhdrsave` (scRGB with highlights above 1.0), so it is licence-clean. Tag gain map tests so they skip when `uhdrload` is unavailable.

* [x] **`Image.GainMap` core** — `gain_map?/1`, `gain_map/1`, `info/1`, `remove/1` and the internal transform helper, with the derived per-axis scale and the rounding rule above.

* [x] **Phase 1 operations** — the eight rows marked 1. Each test asserts both dimensions and spatial alignment, using a gain map with a known marked region, because a dimension check alone misses the `flip/2` case.

* [x] **Phase 2 safety net** — every other geometric function removes the gain map; colour space conversion out of the gain map's gamut removes it. After this, no `Image` function can write a stale gain map.

* [x] **`apply/1` and the `:gain_map` open option**, guarded for libvips without `uhdr2scrgb`.

* [x] **Write path** — `strip_metadata` and `minimize_file_size` keep the gain map with `VIPS_FOREIGN_KEEP_GAINMAP`; on libvips 8.18 the UltraHDR saver ignores the size-reducing JPEG options, which is documented.

* [x] **Streams and buffers** — opening from a binary or stream, `Image.stream!/2`, and writing to a stream or `Plug.Conn` all keep the gain map with no change to `Image`; regression tests cover each route.

* [x] **Documentation** — the `guides/hdr_and_gain_maps.md` guide, and a note in the docs of each function that transforms or removes the gain map.

* [ ] **Phase 3 operations** — arbitrary-angle rotation and the affine family.

### Deferred

* [ ] **AVIF and JXL gain maps** — wait for libvips 8.20 (no date announced) and a `vix` release that ships it. The metadata-based design should carry over unchanged.

* [ ] **`image_plug`** — once `Image` is gain-map-aware its JPEG output becomes correct with no change, but format negotiation to WebP or AVIF drops the gain map. Decide whether to prefer JPEG for gainmapped sources.

## Decisions needed

* **Default** — keep (recommended, matches today and avoids changing correct output) or drop (sharp's choice).

* **Unsupported operations** — remove the gain map silently (recommended), log at debug level, or return an error. Removing keeps the API unchanged and the output valid.

* **`strip_metadata: true` and `minimize_file_size: true`** — keep the gain map (recommended: it is image data, not metadata, and dropping it silently loses the HDR rendition) or drop it as now.

* **Composites** — `compose/3` onto a gainmapped base: remove the gain map (recommended), or keep it and accept that the overlay inherits the base's boost.

* **Names** — `Image.GainMap` and `:gain_map` follow the ISO 21496-1 term; `Image.UltraHDR` would follow the file format.

## Requirements

* libvips 8.18.0 or later built with libuhdr; 8.18.7 or later is preferred because earlier versions truncate `gainmap-scale-factor`. The precompiled libvips in `vix` 0.42.0 qualifies. The first `vix` release to ship it has not been checked.

## Sources

* libvips: [What's new in 8.18](https://www.libvips.org/2025/12/04/What's-new-in-8.18.html), [UltraHDR chapter](https://www.libvips.org/API/8.18/uhdr.html), [design discussion #3799](https://github.com/libvips/libvips/issues/3799), [PR #4709](https://github.com/libvips/libvips/pull/4709), [HEIF/AVIF plan #5238](https://github.com/libvips/libvips/issues/5238).

* sharp: [`keepGainMap` docs](https://github.com/lovell/sharp/blob/main/docs/src/content/docs/api-output.md#keepgainmap), [tracking issue #4314](https://github.com/lovell/sharp/issues/4314), [extract fix #4606](https://github.com/lovell/sharp/issues/4606), [colour space issue #4612](https://github.com/lovell/sharp/issues/4612), [pipeline source](https://github.com/lovell/sharp/blob/1ea0375ef20c94e0dc94f790bf1375bb8872642f/src/pipeline.cc).
