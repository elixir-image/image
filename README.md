# Image

`Image` is a fast, memory-efficient image processing library for
Elixir. It is a high-level wrapper around
[Vix](https://hex.pm/packages/vix), the Elixir bindings for the
[libvips](https://www.libvips.org) C library, and provides an
idiomatic functional API for image manipulation, drawing, text
rendering, EXIF/XMP metadata, classification (via Bumblebee),
video frame extraction (via Xav/FFmpeg), QR code encoding and decoding (via eVision),
video frame extraction, blurhash, perceptual hashing, and many
other image-related operations.

In a simple resize benchmark, `Image` is approximately 2 to 3 times
faster than [Mogrify](https://hex.pm/packages/mogrify) and uses
about 5 times less memory.

Documentation can be found at <https://hexdocs.pm/image>.

## Features

* **Image processing** — open, write, resize, thumbnail, crop, embed,
  rotate, flip, flatten, trim, replace colour, chroma key, warp
  perspective, distort, blur (Gaussian, box, bilateral), sharpen,
  modulate, vibrance, tone map, local contrast, equalize, blend,
  composite, mask, dilate / erode, edge detect.

* **Drawing** — `Image.Draw` provides points, rectangles, circles,
  lines, masks, flood fill, image overlay, smudge.

* **Text rendering** — `Image.Text` produces antialiased text overlays
  with full Pango markup support, font selection, alignment,
  background fills, stroke, and per-character control.

* **Colour management** — colour arguments accept atoms, hex strings,
  CSS named colours, hex shorthand, `#RRGGBBAA`, `Color.*` structs,
  CSS Color 4 / 5 functions (`rgb()`, `hsl()`, `lab()`, `oklch()`,
  `color-mix()`, relative colour syntax via `from`, `none` keyword,
  `calc()`), and are converted to the **target image's interpretation**
  via `Image.Pixel.to_pixel/3`. The same colour string draws correctly
  on sRGB, Lab, scRGB, CMYK, 16-bit, and greyscale images.

* **Colour spaces** — `Image.colorspace/1`, `Image.to_colorspace/2`,
  and full conversion between sRGB / scRGB / Lab / LCh / CMYK / HSV /
  XYZ / B&W / 16-bit RGB.

* **Dominant colour and palette extraction** — `Image.dominant_color/2`
  with two methods: a fast 3D-histogram (default) and an
  imagequant-backed perceptual quantiser. See
  [`guides/performance.md`](guides/performance.md) for benchmarks.

* **K-means clustering** — `Image.k_means/2` (when `:scholar` is
  available) returns the dominant colour palette extracted by
  unsupervised clustering.

* **Histogram operations** — `Image.histogram/1`, `Image.equalize/2`,
  per-band statistics, percentile, mean, median.

* **Metadata** — `Image.exif/1` for EXIF, `Image.Xmp.extract_xmp/1` for
  XMP, plus `Image.minimize_metadata/1` to strip metadata while
  retaining the artist and copyright fields.

* **ICC colour profiles** — `Image.ICCProfile` for libvips' built-in
  profiles (`:srgb`, `:cmyk`, `:p3`) and arbitrary `.icc` files.

* **Image streaming** — open and write directly from `File.Stream`s,
  Plug `Conn`s, in-memory binaries, and S3 sources.

* **Optional ML integrations** —
  * `Image.Video` (frame extraction, seek, webcam) via
    [Xav](https://hex.pm/packages/xav), an Elixir wrapper around
    FFmpeg. Requires FFmpeg ≥ 6.0 on the system.
  * `Image.QRcode` (encode + decode) via
    [eVision](https://hex.pm/packages/evision).
  * `Image.k_means` via [Scholar](https://hex.pm/packages/scholar).
  * `Image.to_nx/2` / `Image.from_nx/1` via [Nx](https://hex.pm/packages/nx).
  * **Object detection, image classification, and image
    generation** live in the separate
    [`:image_detection`](https://hex.pm/packages/image_detection)
    package. Add it alongside `:image` in your `mix.exs` to get
    `Image.Detection`, `Image.Classification`, and
    `Image.Generation` (which depend on `:axon_onnx` and
    [Bumblebee](https://hex.pm/packages/bumblebee) respectively).

* **Hashing** — perceptual difference hash (`Image.dhash/2`),
  blurhash encode/decode (`Image.Blurhash`), Hamming distance.

* **YUV interop** — `Image.YUV` for raw YUV file/binary I/O in
  C420/C422/C444 chroma subsampling and BT.601/BT.709 colour spaces.

* **Kino integration** — `Image.Kino` renders images in
  [Livebook](https://livebook.dev) without manual conversion.

* **Social media presets** — `Image.Social` with the standard image
  sizes for Twitter, Facebook, Instagram, LinkedIn, Pinterest, YouTube,
  Snapchat, and TikTok.

* **Bundled fonts** — ships the Impact font for meme rendering so
  `Image.meme/3` works out of the box.

* **Structured errors** — every fallible function returns
  `{:ok, value}` or `{:error, %Image.Error{}}`. The error struct
  carries `:reason` (atom or `{atom, value}`), `:operation`, `:path`,
  `:value`, and a derived `:message`. Bang variants raise the same
  struct.

## Supported Elixir and OTP releases

`Image` is tested on the following matrix:

| Elixir | OTP |
|---|---|
| 1.17 | 26, 27 |
| 1.18 | 26, 27 |
| 1.19 | 26, 27, 28 |
| 1.20-rc | 27, 28 |

The minimum supported version is **Elixir 1.17 / OTP 26**. The CI
matrix runs `mix format --check-formatted`, `mix compile
--warnings-as-errors`, the full test suite, and `mix dialyzer` (lint
cell only) on every cell.

## Quick start

Add `:image` to your dependencies:

```elixir
def deps do
  [
    {:image, "~> 0.64"}
  ]
end
```

`libvips` is bundled by default via `:vix`, so you don't need to
install it system-wide. See the "Installing Libvips" section below
if you want to bring your own libvips for additional format
support.

### Open, transform, write

```elixir
{:ok, image} = Image.open("photo.jpg")
{:ok, thumb} = Image.thumbnail(image, 256)
:ok = Image.write(thumb, "thumb.jpg", quality: 85)
```

### Resize, crop, rotate

```elixir
image
|> Image.resize!(scale: 0.5)
|> Image.crop!(0, 0, 400, 400)
|> Image.rotate!(15)
|> Image.write!("derived.png")
```

### Compose and draw

```elixir
{:ok, base} = Image.new(800, 600, color: :white)
{:ok, with_circle} = Image.Draw.circle(base, 400, 300, 100, color: "#ff0000")
{:ok, with_text} = Image.Text.text("Hello world", font_size: 64)
{:ok, composed} = Image.compose(with_circle, with_text, x: :center, y: :middle)
```

### Colour-aware operations

Colour arguments work in any colour space:

```elixir
# Draws actual Lab red, not [255, 0, 0] reinterpreted as Lab
{:ok, lab_image} = Image.to_colorspace(image, :lab)
{:ok, _} = Image.Draw.rect(lab_image, 0, 0, 100, 100, color: :red)

# CSS Color 5 syntax everywhere
{:ok, _} = Image.Draw.rect(image, 0, 0, 100, 100,
  color: "color-mix(in oklch, red 40%, blue)")

# Relative colour syntax
{:ok, _} = Image.Draw.circle(image, 50, 50, 25,
  color: "oklch(from teal calc(l + 0.1) c h)")
```

### Dominant colour

```elixir
{:ok, [r, g, b]} = Image.dominant_color(image)

{:ok, palette} = Image.dominant_color(image, method: :imagequant, top_n: 8)
# => [{124, 30, 4}, {200, 88, 12}, ...]
```

### EXIF metadata

```elixir
{:ok, image} = Image.open("photo.jpg")
{:ok, exif} = Image.exif(image)
exif[:make]
# => "FUJIFILM"
```

### Streaming

```elixir
"photo.jpg"
|> File.stream!([], 64_000)
|> Image.open!()
|> Image.thumbnail!(256)
|> Image.write!(File.stream!("thumb.jpg"))
```

### QR codes

```elixir
{:ok, qrcode} = Image.QRcode.encode("Hello world", size: 256)
{:ok, "Hello world"} = Image.QRcode.decode(qrcode)
```

(Requires the optional `:evision` dependency.)

### Pattern-matching errors

```elixir
case Image.open(path) do
  {:ok, image} -> use_image(image)
  {:error, %Image.Error{reason: :enoent}} -> not_found(path)
  {:error, %Image.Error{reason: :unsupported_format}} -> wrong_format(path)
  {:error, %Image.Error{} = error} -> raise error
end
```

## Installing Libvips

Starting from `Vix` v0.16.0, `libvips` can be either bundled
(default) or platform-provided. The default uses precompiled NIF
binaries built from the [sharp-libvips](https://github.com/lovell/sharp-libvips/)
project — no system dependencies required, ideal for Livebook and
Heroku-style deploys.

For additional format support (HEIF compression options, JPEG XL,
specialised codecs) you can use the platform's libvips:

```bash
# macOS
brew install libvips

# Debian / Ubuntu
apt install libvips-dev

# Fedora / RHEL
dnf install vips-devel
```

Then set `VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS` at compile
time and at runtime. See the [Vix documentation](https://hexdocs.pm/vix)
for the full list.

## Optional dependencies

`Image` is small and self-contained at its core. The following
optional dependencies enable specific features:

| Dependency | Enables |
|---|---|
| `:nx` | `Image.to_nx/2`, `Image.from_nx/1`, tensor interop |
| `:scholar` | `Image.k_means/2` |
| `:xav` | `Image.Video` (FFmpeg-backed frame extraction) |
| `:evision` | `Image.QRcode`, `Image.to_evision/2`, `Image.from_evision/1` |
| `:image_detection` | `Image.Detection`, `Image.Classification`, `Image.Generation` (object detection, classification, image generation — pulls Bumblebee, Nx, Axon as transitive deps) |
| `:plug` | streaming via `Plug.Conn` |
| `:req` | streaming over HTTP |
| `:kino` | `Image.Kino` (Livebook integration) |
| `:exla` | EXLA backend for Nx-based features |

Each is detected at compile time; the corresponding `Image` module
is conditionally compiled. Add only the deps you actually use.

## Configuring libvips

`libvips` exposes several environment variables that control
debugging, concurrency, memory leak detection, and security. Each
has a sensible default; the most commonly tuned ones:

* `VIPS_BLOCK_UNTRUSTED=TRUE` (set automatically when the `:image`
  application starts) prevents libvips from loading untrusted format
  loaders.
* `VIPS_CONCURRENCY=N` caps the libvips thread pool. Default is
  the system core count. Lower it if image processing is competing
  with other workloads.
* `VIPS_LEAK=true` enables libvips' memory leak reporter.
* `G_DEBUG=fatal-criticals` aborts on the first GLib critical.

You can also set the concurrency programmatically with
`Image.put_concurrency/1` and read it back with
`Image.get_concurrency/0`.

## FFmpeg / Xav log noise

If you use `Image.Video` (which is backed by
[Xav](https://hex.pm/packages/xav) / FFmpeg) you may see lines like

    [swscaler @ 0x1490a0000] No accelerated colorspace conversion found from yuv420p to rgb24.

written to `stderr` during frame decoding. These are
**informational notices** from FFmpeg's `libswscale`, **not
errors**. They mean that `libswscale` does not have a
hand-optimised SIMD path for that particular pixel-format
conversion on your CPU, so it is using its generic C fallback.
Decoded frames are bit-for-bit correct either way.

The messages come from FFmpeg writing directly to `stderr` at its
default log level (`AV_LOG_INFO`). Xav does not currently expose
`av_log_set_level/1`, so the only way to silence them from
application code is to install an FFmpeg build that has the
SIMD path for your architecture (typically an FFmpeg compiled
with `--enable-runtime-cpudetect` and any of `--enable-asm`,
`--enable-x86asm`, or platform ASM flags — most distribution
packages already do this). On Apple Silicon the arm64 optimised
path for `yuv420p → rgb24` is not in FFmpeg's `swscale` as of
FFmpeg 7.x, which is why macOS users on M-series machines see
the notice most often.

If the noise is disruptive during tests or automation, you can
redirect stderr for the command in question, e.g.
`mix test 2> /dev/null`. Do not do this for production —
suppressing stderr will also hide real FFmpeg errors.

## Security considerations

* `libvips` and the underlying loaders are written in C; a malicious
  input has the potential to crash the BEAM if libvips itself crashes.
  In comparison to ImageMagick (638+ CVEs across its history),
  libvips has had a much smaller attack surface (~8 CVEs, all
  promptly fixed).

* The `:image` application sets `VIPS_BLOCK_UNTRUSTED=TRUE` on start
  unless the user has set it explicitly. This blocks libvips from
  loading the more dangerous format loaders.

* When displaying user-supplied images on a web page, sanitise
  EXIF / XMP metadata before passing it to a browser — embedded
  HTML in metadata fields is a known vector.

* Image processing is CPU-intensive and the default libvips
  concurrency equals the host core count. For multi-tenant
  workloads, lower `VIPS_CONCURRENCY` to avoid CPU starvation.

## License

Apache 2.0. See [LICENSE.md](LICENSE.md) for the full text.
