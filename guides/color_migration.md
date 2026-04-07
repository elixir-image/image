# Replacing `Image.Color` with the `Color` library

This is a working plan, not yet a finished migration. It captures what `Image.Color` currently does, what `Color` (the new dependency at `../color`) provides, where they overlap, where they don't, and the work needed to migrate. Strict backwards compatibility is **not** a goal; minimising breaking changes is.

## Status

* `{:color, path: "../color"}` is declared in `mix.exs` and the project compiles cleanly against it.
* **Phase 1 complete.** `Image.Pixel` and `Image.ICCProfile` exist with full doctest and unit-test coverage (44 tests passing). No `Image.Color` call sites have been changed yet — the two namespaces coexist and the full Image test suite still passes (the only failures are pre-existing environmental ones: minio, camera, HEIC support).
* `ChromaGreen` / `ChromaBlue` are already present upstream in `Color.CSSNames`.

## What `Image.Color` does today

`lib/image/color.ex` is a ~540 line grab-bag that mixes four unrelated concerns:

1. **Color parsing and validation** — `validate_color/1`, `rgb_color/1`, `rgb_color!/1`, `rgb_to_hex/1`, `hex_to_rgb/1`, `normalize/1`, the CSS color CSV under `priv/color/`, and the `is_color/1` defguard.

2. **Color-space conversion** — `convert/4` and `convert!/4`, supporting `:srgb`, `:hsv`, `:lab`, and a custom `:hlv` (used internally by `sort/2`/`compare_colors/3` for colour ordering).

3. **Transparency handling** — `validate_transparency/1`, `max_opacity/0`, `min_opacity/0`, `rgba_color!/2`. Accepts `:none | :transparent | :opaque | 0..255 | 0.0..1.0`.

4. **ICC profile knowledge** — `inbuilt_profiles/0`, `known_icc_profile?/1`, `is_inbuilt_profile/1`. These are about libvips, not color science.

It also exports types: `Image.Color.t/0`, `rgb_color/0`, `transparency/0`, `icc_profile/0`.

### Inventory of call sites

`Image.Color` (or its alias `Color`) is referenced in **18** files under `lib/` and **2** test files. By function:

| Function | Call sites |
|---|---|
| `validate_color/1` | `lib/image.ex` (5 sites: `if_then_else`, `replace_color`, `flatten`, `compare/2`), `lib/image/options/embed.ex` |
| `rgb_color/1` | `lib/image/options/{chroma_key,trim,join,compare,warp_perspective,meme,linear_gradient,radial_gradient,new,draw}.ex` (10 option validators) |
| `rgba_color!/2` | `lib/image/text.ex` (background fill with opacity) |
| `convert/4` and `convert!/4` | `lib/image.ex` (`dominant_color`, `k_means`, `compare_colors`) |
| `is_color/1` (guard) | `lib/image.ex` (`if_then_else`), `lib/image/options/write.ex` |
| `is_inbuilt_profile/1` (guard) | `lib/image/options/{thumbnail,write}.ex` |
| `known_icc_profile?/1` | `lib/image/options/{thumbnail,write}.ex` |
| `max_rgb/0` | `lib/image.ex` (histogram scaling, two sites) |
| `max_opacity/0` | `lib/image/draw.ex` (alpha extension helper) |
| `sort/2` | `test/color_test.exs` |

The flow at every option-validation site is the same: take a user-supplied value (atom name, hex string, list of ints, or already-validated list), normalise it to an integer `[r, g, b]` or `[r, g, b, a]`, and pass that list verbatim into a libvips operation as a `:background`, `:color`, or similar argument.

### The bug that motivates the migration

Every option validator above uses `Image.Color.rgb_color/1` (or `validate_color/1`), which returns an integer list in `0..255` regardless of the target image's interpretation. Vips does not interpret that list — it just stuffs the numbers into the operation's pixel argument. So:

* For an `:srgb` (`uchar`) image, `:red` → `[255, 0, 0]` happens to mean red. This works.
* For a `:lab` image, `:red` → `[255, 0, 0]` is **not** Lab red. Lab red is roughly `[53.24, 80.09, 67.20]`. The drawn pixel is whatever `[255, 0, 0]` decodes to in Lab (a bright pinkish near-white), not the color the user asked for.
* For a `:scrgb` (float `[0.0, 1.0]`) image, `[255, 0, 0]` blows past the working range entirely — clipped to `[1.0, 0.0, 0.0]` after the fact, but the option validator gives no signal.
* CMYK images get a 3-channel value where vips expects 4.

The user wants this fixed: every color argument or option must be converted to **match the colorspace and band layout of the image being processed**, not blindly assumed to be 8-bit sRGB.

## What the `Color` library provides

`Color` is a struct-based color science library with one entry per space (`Color.SRGB`, `Color.Lab`, `Color.LCHab`, `Color.Oklab`, `Color.XYZ`, `Color.HSLuv`, `Color.JzAzBz`, `Color.ICtCp`, `Color.YCbCr`, `Color.CMYK`, `Color.AdobeRGB`, `Color.RGB` (linear, any working space), …).

The relevant API:

* `Color.new(input, space \\ :srgb)` — accepts a struct, a list of 3/4/5 numbers, a hex string (`"#ff0000"`, `"#f80"`, `"#ff000080"`), an unprefixed hex (`"ff0000"`), a CSS named color string (`"rebeccapurple"`), or an atom (`:misty_rose`). Returns `{:ok, struct}` or `{:error, reason}`. List validation is strict for display spaces (uniform int-or-float, range-checked) and permissive for CIE/perceptual/HDR spaces.

* `Color.convert(color, target, options)` and `Color.convert(color, Color.RGB, working_space)` — converts to the target space via the XYZ hub. Supports `:intent` (`:relative_colorimetric`, `:absolute_colorimetric`, `:perceptual`, `:saturation`), `:bpc`, `:adaptation` (`:bradford`, `:cat02`, …). Bradford chromatic adaptation between reference whites is automatic; gamut mapping (via Oklch binary search) is opt-in via `intent: :perceptual`.

* `Color.SRGB.parse/1` — the CSS hex/named-color parser (used internally by `Color.new/2` for binary input).

* `Color.CSSNames.lookup/1` — full set of CSS Color Module Level 4 named colors. Image's `priv/color/css_colors.csv` is a subset of this.

* `Color.premultiply/1` / `Color.unpremultiply/1` — alpha straightening, only meaningful for RGB-like spaces.

* `Color.Gamut.in_gamut?/2` and `Color.Gamut.to_gamut/3` — gamut checking and mapping (perceptual intent uses this internally).

### Gaps in `Color` that `Image.Color` covers

These are the only things `Image.Color` does that `Color` does not, and that we will need to keep somewhere on the `Image` side:

1. **ICC profile awareness.** `:srgb`, `:cmyk`, `:p3`, and arbitrary file paths are libvips concerns, not color-science concerns. They will live in a new `Image.ICCProfile` module (or stay as private helpers in `lib/image/options/{thumbnail,write}.ex`).

2. **Transparency aliases.** `:none`, `:transparent`, `:opaque`, integer `0..255`, and float `0.0..1.0` are an `Image` convention. `Color` only knows about a single `:alpha` field on each struct in the range `[0.0, 1.0]`. We need a small adapter.

3. **`additional_colors.csv`.** `ChromaGreen` and `ChromaBlue` are not in CSS. Two options: either add them to `Color.CSSNames` upstream, or carry a tiny extension list in `Image`. The other entries in that file (`Transparent` → `#FFFFFF`, `Opaque` → `#000000`) are misleading — they're hex stand-ins for behavior, not color names. They should be deleted.

4. **`is_color/1` defguard.** `Color.new/2` is a function, not a guard. We need a small Image-side guard that matches lists of length 3..5, atoms in the CSS-name set, hex strings, and `Color.*` structs.

5. **The integer-only `[r, g, b]` return shape.** Many call sites and `dominant_color`/`average`/`get_pixel`/k-means return integer triples. We will keep returning lists for back-compat at the boundary, but internally pass `Color.SRGB` (or whatever) structs around.

## Target architecture

Three new things need to exist before `Image.Color` can be retired:

### `Image.Pixel` (working name) — the bridge between `Color` and libvips

A small new module whose job is to convert any user-supplied color into a list of doubles in **the exact band layout and pixel range that the target image's interpretation expects**. This is the function the bug fix hinges on.

Sketch:

```elixir
defmodule Image.Pixel do
  @moduledoc """
  Bridges the `Color` library and libvips pixel arguments.

  Every libvips operation that takes a color (background, fill, draw,
  flatten, embed, …) ultimately wants a list of doubles in the
  interpretation and band count of the image it is operating on.
  This module owns that conversion.
  """

  alias Vix.Vips.Image, as: Vimage

  @doc """
  Converts any color input into a list of doubles matching the
  interpretation and band layout of `image`.

  ### Arguments

  * `image` is the target image. Its interpretation and band count
    determine the output shape and value range.

  * `color` is anything `Color.new/2` accepts: a struct, a list of
    3/4/5 numbers, a hex string, a CSS named color, or one of Image's
    transparency aliases (`:none`, `:transparent`, `:opaque`).

  * `options` is a keyword list:

    * `:alpha` — if the target image has an alpha band, force this
      transparency value (uses `Image.Pixel.transparency/1`). If
      unset, the color's own alpha is used (or full opacity).

    * `:intent` — passed through to `Color.convert/3`. Defaults to
      `:relative_colorimetric`.

  ### Returns

  * `{:ok, [double, ...]}` ready to hand to a Vix operation.

  * `{:error, reason}`.

  ### Notes

  * The output is **always floats** when the image's interpretation
    is float-valued (`:scrgb`, `:xyz`, `:lab`, `:hsv`, …). For
    8-bit interpretations (`:srgb`, `:rgb`, `:bw`) the output is the
    natural 0..255 range. For 16-bit (`:rgb16`, `:grey16`) it is
    0..65535.

  * The output band count matches `Vix.Vips.Image.bands/1` exactly,
    appending or stripping alpha as needed.
  """
  def to_pixel(%Vimage{} = image, color, options \\ [])
end
```

Internally, `to_pixel/3` is just:

1. `{:ok, struct} = resolve(color)` — `Color.new/2`, plus the small set of `Image`-specific aliases (`:none`, `:transparent`, `:opaque`, the `:auto`/`:average` sentinels handled by their callers).
2. Pick the target `Color` module from `Image.colorspace(image)` via a fixed lookup table (`:srgb` → `Color.SRGB`, `:lab` → `Color.Lab`, `:hsv` → `Color.Hsv`, `:cmyk` → `Color.CMYK`, `:scrgb` → `Color.SRGB` then scale, `:rgb16` → `Color.SRGB` then scale to 0..65535, `:bw`/`:grey16` → average, etc).
3. `{:ok, converted} = Color.convert(struct, target_module, intent: ...)`.
4. Extract the channel values, multiply by the per-interpretation scale, append/strip alpha to match `Vix.Vips.Image.bands/1`.

### `Image.Pixel.transparency/1` — the small alpha helper

```elixir
def transparency(:none),        do: {:ok, 0}
def transparency(:transparent), do: {:ok, 0}
def transparency(:opaque),      do: {:ok, 255}
def transparency(int)   when int in 0..255,           do: {:ok, int}
def transparency(float) when is_float(float),         do: {:ok, round(255 * float)}
def transparency(other), do: {:error, "Invalid transparency: #{inspect(other)}"}
```

This is `Image.Color.validate_transparency/1` with no other dependencies. It belongs next to `to_pixel/3`.

### `Image.ICCProfile` — extracted from `Image.Color`

The four ICC-related functions move into their own module (`is_inbuilt_profile/1`, `inbuilt_profiles/0`, `known_icc_profile?/1`, plus the `icc_profile/0` type). This is a one-line rename per call site (`Image.Color.known_icc_profile?` → `Image.ICCProfile.known?`).

## Migration plan

Five phases. Each phase compiles, runs the test suite, and is releasable on its own. Public API changes are concentrated in phases 4 and 5.

### Phase 1 — Build the bridge

Files added:

* `lib/image/pixel.ex` — `Image.Pixel.to_pixel/3`, `Image.Pixel.transparency/1`, `Image.Pixel.is_pixel/1` (defguard, replaces `Image.Color.is_color/1`).
* `lib/image/icc_profile.ex` — `Image.ICCProfile.known?/1`, `Image.ICCProfile.inbuilt/0`, `Image.ICCProfile.is_inbuilt/1`, type `t/0`.
* Tests for both, including round-trips through `:srgb`, `:lab`, `:scrgb`, `:cmyk`, `:bw`, `:rgb16`.

No call sites change. `Image.Color` still works exactly as before. Risk is low — purely additive.

### Phase 2 — Route option validators through `Image.Pixel`

Files changed (10 option validators plus the two with embedded ICC handling):

* `lib/image/options/{chroma_key,trim,join,compare,warp_perspective,meme,linear_gradient,radial_gradient,new,draw,embed}.ex`
* `lib/image/options/{thumbnail,write}.ex` (ICC profile handling only)
* `lib/image/draw.ex` (the `maybe_add_alpha` helper)
* `lib/image/text.ex` (the `rgba_color!` background-fill site)

The option validators currently look like this:

```elixir
defp validate_option({:color, color}, options) do
  case Color.rgb_color(color) do
    {:ok, color} ->
      rgb = if Keyword.keyword?(color), do: Keyword.fetch!(color, :rgb), else: color
      {:cont, Keyword.put(options, :color, rgb)}

    {:error, reason} ->
      {:halt, {:error, reason}}
  end
end
```

After phase 2 they look like this:

```elixir
defp validate_option({:color, color}, image, options) do
  case Image.Pixel.to_pixel(image, color) do
    {:ok, pixel} -> {:cont, Keyword.put(options, :color, pixel)}
    {:error, reason} -> {:halt, {:error, reason}}
  end
end
```

The validator now needs the target image (it didn't before), so the validator entry-point signature widens by one argument. Most validators already take the image as their first argument; the few that don't (`Image.Options.New`, `Image.Options.{Linear,Radial}Gradient`) get it added. **This is the largest mechanical change in the migration.** Where there is no image yet (a fresh canvas in `Image.new/3`), `Color.new/2` is called instead and the result is materialised when the canvas is created.

The bug fix lands here: every option validator now produces pixel values in the right interpretation. Existing tests against sRGB images will not change behavior; tests against Lab / scRGB / CMYK images will now produce the colors the user actually asked for.

`Image.Color.rgb_color/1` and `Image.Color.validate_color/1` are deprecated with `@deprecated`, but they keep working as thin wrappers around `Color.new/2 + Color.convert(_, Color.SRGB)`.

### Phase 3 — Replace internal conversions

Files changed:

* `lib/image.ex` — the four `Color.validate_color/1` call sites (`if_then_else`, `replace_color`, `flatten`, `compare/2`), the `Color.convert!` site in `k_means`, the `Color.convert!` site in `compare_colors`, and the `dominant_color` paths if they need to round-trip through Lab.
* `lib/image/color.ex` — `convert/4`, `convert!/4`, `convert/2 (image)`, `sort/2`, `compare_colors/3` are reimplemented as wrappers over `Color.convert/2,3` and marked `@deprecated`. The custom `:hlv` ordering moves into a private helper inside `Image` (it is image-specific).

The CSV-driven `@color_map`/`@css_color`/`@greyscale_color_map` module attributes go away. `priv/color/css_colors.csv` is deleted (its content is in `Color.CSSNames`). `priv/color/additional_colors.csv` is reduced to `ChromaGreen, ChromaBlue` only — and, ideally, those move into `Color.CSSNames` upstream so the file disappears entirely. The `Transparent`/`Opaque` "color" entries are deleted (they were only ever transparency aliases mis-modelled as colors).

`Image.Color.max_rgb/0` is inlined as a constant in `image.ex` where it is used. `Image.Color.max_opacity/0` and `min_opacity/0` are deleted; the two callers use `Image.Pixel.transparency(:opaque)` / `transparency(:transparent)`.

### Phase 4 — Type and documentation cleanup

Type aliases:

| Old | New | Notes |
|---|---|---|
| `Image.Color.t/0` | `Image.Pixel.t/0` | union of: a `Color.*` struct, an integer/float list (3..5), a hex string, a CSS atom |
| `Image.Color.rgb_color/0` | `Image.Pixel.rgb_color/0` or `[number()]` | most call sites can drop this entirely |
| `Image.Color.transparency/0` | `Image.Pixel.transparency/0` | unchanged shape |
| `Image.Color.icc_profile/0` | `Image.ICCProfile.t/0` | unchanged shape |

A handful of `@spec` lines change. Where the old type was used inside `lib/image/options/*.ex` typespecs, they switch to `Image.Pixel.t()`.

Documentation: every "see `Image.Color.color_map/0` and `Image.Color.rgb_color/1`" reference (~30 sites) is rewritten to "any value accepted by `Color.new/2`". This is a big diff but mechanical.

The Color section in `mix.exs` `groups_for_modules/0` adds `Image.Pixel` and `Image.ICCProfile` and removes `Image.Color`.

### Phase 5 — Removal

In the next minor release after the deprecation cycle:

* Delete `lib/image/color.ex`.
* Delete `priv/color/`.
* Delete `test/color_test.exs` (or rewrite the one assertion against `Image.Pixel`).
* Drop the deprecated wrappers.

## Impact summary

| Area | Impact | Severity |
|---|---|---|
| `Image.Color` module | deprecated in phase 2, deleted in phase 5 | Breaking — but `@deprecated` warns first |
| Color in non-sRGB images | **bug fixed** — color args are converted to the image's interpretation | Behavior change, almost certainly the change a user would want |
| Public typespec `Image.Color.t/0` | renamed to `Image.Pixel.t/0` | Breaking for downstream typespecs |
| Public typespec `Image.Color.icc_profile/0` | renamed to `Image.ICCProfile.t/0` | Breaking for downstream typespecs |
| `Image.Color.color_map/0`, `rgb_color/1`, `validate_color/1`, `rgb_to_hex/1`, `hex_to_rgb/1`, `convert/4`, `sort/2` | deprecated wrappers for one release, then removed | Breaking after phase 5 |
| `Image.dominant_color/2` return shape | unchanged on the integer-list path; the `:imagequant` path still returns `{r, g, b}` tuples | None |
| Hex/named color parsing | now via `Color.SRGB.parse/1` — supports `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, named colors. The current parser is `#RRGGBB` only | **Improvement**, no break |
| ICC profile helpers | move from `Image.Color` to `Image.ICCProfile` | Breaking, mechanical rename |
| `priv/color/` CSVs | deleted (CSS) and reduced to a tiny extension list (or upstream into `Color.CSSNames`) | Internal |
| `additional_colors.csv` `Transparent`/`Opaque` entries | deleted — they were transparency aliases, not colors | Breaking only if user code wrote `:transparent` expecting a *color* (they were almost certainly using it as transparency) |
| `lib/image/text.ex` background fill via `rgba_color!/2` | reimplemented over `Image.Pixel.to_pixel/3` with `alpha:` | Behavior preserved |

## Open questions

1. ~~Where should `ChromaGreen` / `ChromaBlue` live?~~ **Resolved.** They already live in `Color.CSSNames` (`color/lib/color/css_names.ex` lines 161–162), tagged with a comment noting drop-in compatibility with `Image.Color`'s `additional_colors.csv`. `priv/color/additional_colors.csv` can be deleted entirely in phase 3.

2. **What rendering intent should the default be when converting a user color into an image's interpretation?** `:relative_colorimetric` (the `Color.convert/3` default) is right for most cases. For drawing-into-CMYK, `:perceptual` may be more forgiving (gamut mapping). **Recommendation:** default to `:relative_colorimetric` and accept an `:intent` option on every call site that wants a different one.

3. **Should `Image.Pixel.to_pixel/3` clip out-of-gamut input, or pass it through?** libvips will silently clip later. If we set the default intent to `:perceptual` we get gamut mapping for free; otherwise the user gets vips' clipping. **Recommendation:** pass through and document.

4. **Float vs integer outputs.** Vix accepts both, but some operations are happier with one. **Recommendation:** always emit floats for non-`:srgb` interpretations and integers for `:srgb` (matching today's behavior on the only common path).

5. **Should `Image.Color` be kept as a permanent thin wrapper, never deleted?** This would eliminate the breaking change in phase 5 entirely. The cost is one file of `@deprecated` redirects forever. **Recommendation:** keep it — the surface is small and the back-compat win is large.

## Estimated scope

* New code: ~250 lines in `lib/image/pixel.ex`, ~50 in `lib/image/icc_profile.ex`, ~150 lines of tests.
* Touched files in phase 2: 13 option validators + `lib/image/draw.ex` + `lib/image/text.ex`. Each is a 5–10 line change.
* Touched files in phase 3: `lib/image.ex` (8 sites), `lib/image/color.ex` (rewritten as deprecated wrappers).
* Documentation rewrites in phase 4: ~30 docstring sites.
* Net deletions: `priv/color/css_colors.csv` (138 lines), most of `lib/image/color.ex` (~400 lines) once phase 5 lands.

Total work is manageable. The two risks worth flagging are:

* **Phase 2 widens a lot of validator signatures.** Worth doing in one PR per file group rather than one massive PR.
* **The bug fix is a behavior change.** Users who happened to be passing `[255, 0, 0]` to `Image.embed/4` against a Lab image and expecting today's broken output (a near-white pinkish pixel) will get a different pixel after phase 2. This is the right answer but it should be called out clearly in the changelog when phase 2 ships.
