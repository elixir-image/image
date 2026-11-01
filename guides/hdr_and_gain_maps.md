# HDR and gain maps

An UltraHDR JPEG is an ordinary JPEG with a second, smaller image hidden inside it: a gain map recording how much brighter each region should be shown on a high dynamic range (HDR) display. A viewer without HDR support shows the standard dynamic range (SDR) base image and ignores the gain map, so the file works everywhere. Recent Android phones, Google's Pixel among them, take photos as UltraHDR JPEGs. This guide explains how `Image` handles them and what to do when you need control.

The short version: open, transform and write UltraHDR images as you would any other image. `Image` keeps the gain map aligned with the base image, removes it when an operation cannot keep it aligned, and writes it back when saving a JPEG.

## Requirements

Gain map support needs libvips 8.18 or later built with libuhdr. The precompiled libvips that `vix` ships qualifies, so nothing needs installing on the default setup. On a libvips without it, an UltraHDR JPEG opens as a plain JPEG with no gain map and every function in this guide behaves as it does for an SDR image.

## Opening an UltraHDR image

`Image.open/2` recognises an UltraHDR JPEG from its content, whether it is given a path, a binary or a stream. `Image.GainMap.gain_map?/1` says whether an image has a gain map, and `Image.GainMap.gain_map/1` returns it decoded. The examples use the 480×260 UltraHDR fixture in this repository.

```elixir
iex> image = Image.open!("test/support/images/gain_map.jpg")
iex> Image.GainMap.gain_map?(image)
true
iex> {:ok, gain_map} = Image.GainMap.gain_map(image)
iex> Image.shape(gain_map)
{240, 130, 1}
```

The gain map is usually smaller than the base image, often by half, and may have one band or three. An image without a gain map returns `{:ok, nil}`.

The `:gain_map` option of `Image.open/2` decides what happens to the gain map on load:

* **`:keep`** — the default. The gain map is carried with the image.

* **`:drop`** — the gain map is removed, so the image behaves and saves as plain SDR.

* **`:apply`** — the gain map is applied and the HDR image is returned in the `:scrgb` colorspace; see [rendering the HDR image](#rendering-the-hdr-image).

```elixir
iex> image = Image.open!("test/support/images/gain_map.jpg", gain_map: :drop)
iex> Image.GainMap.gain_map?(image)
false
```

## Inspecting the gain map

`Image.GainMap.info/1` returns the parameters that say how the gain map's values translate into brightness. The per-channel parameters are lists of three floats, even for a one-band gain map.

```elixir
iex> image = Image.open!("test/support/images/gain_map.jpg")
iex> {:ok, info} = Image.GainMap.info(image)
iex> info.scale_factor
2
iex> info.min_content_boost
[1.0, 1.0, 1.0]
iex> info.hdr_capacity_max
49.26108169555664
```

`:max_content_boost` is the most any region is brightened, and `:hdr_capacity_min` and `:hdr_capacity_max` are the display headroom range over which the gain map is applied.

## How operations treat the gain map

libvips stores the gain map as metadata and does not transform it, so a crop or a rotation would otherwise leave the gain map describing the original frame. The HDR rendition would then be misaligned while the SDR image looked fine, so the fault would go unnoticed. `Image` applies each geometric operation to the gain map at the gain map's own scale.

```elixir
iex> image = Image.open!("test/support/images/gain_map.jpg")
iex> {:ok, cropped} = Image.crop(image, 0, 0, 200, 100)
iex> {:ok, gain_map} = Image.GainMap.gain_map(cropped)
iex> Image.shape(gain_map)
{100, 50, 1}
iex> {:ok, rotated} = Image.rotate(image, 90)
iex> {:ok, gain_map} = Image.GainMap.gain_map(rotated)
iex> Image.shape(gain_map)
{130, 240, 1}
```

An operation that cannot yet transform the gain map removes it, so the result is a valid SDR image rather than a broken HDR one.

| Operation | Gain map |
|---|---|
| `Image.thumbnail/3`, `Image.resize/3` | Resized with the image |
| `Image.crop/5`, `Image.center_crop/3`, `Image.trim/2` | Cropped with the image |
| `Image.flip/2`, `Image.autorotate/1` | Flipped or reoriented with the image |
| `Image.rotate/3` by a multiple of 90° | Rotated with the image |
| `Image.embed/4` | Embedded with a background that adds no boost |
| `Image.feather/2`, blurs, colour and tone adjustments | Kept unchanged |
| `Image.rotate/3` by any other angle | Removed |
| `Image.affine/3`, `Image.translate/4`, `Image.shear/4` | Removed |
| `Image.warp_perspective/4`, `Image.distort/4`, `Image.map/3`, `Image.ripple/2` | Removed |
| `Image.to_polar_coordinates/2`, `Image.to_rectangular_coordinates/2` | Removed |
| `Image.compose/3`, `Image.join/2` | Removed |
| `Image.to_colorspace/2` to another colorspace | Removed |

Colour and tone adjustments keep the gain map because the HDR rendition is the SDR image multiplied by the gain, so an adjustment to the base image carries through. Converting to another colorspace removes it, because the gain map's channel gains are defined in the base image's colour space. Converting to the image's own colorspace keeps it.

To remove the gain map yourself, use `Image.GainMap.remove/1`:

```elixir
iex> image = Image.open!("test/support/images/gain_map.jpg")
iex> {:ok, sdr} = Image.GainMap.remove(image)
iex> Image.GainMap.gain_map?(sdr)
false
```

## Writing an UltraHDR image

`Image.write/3` writes an image with a gain map as UltraHDR whenever the output is a JPEG, whether to a file, to memory, to a stream or to a `Plug.Conn`. Every other format drops the gain map and writes the SDR base image, because none of them can carry one yet.

The gain map is image data rather than metadata, so `strip_metadata: true` keeps it while removing the EXIF (including GPS location), XMP and IPTC data. The colour profile is replaced with an sRGB profile written by the UltraHDR encoder.

`minimize_file_size: true` also keeps the gain map, but with libvips 8.18 the UltraHDR encoder does not support the size-reducing JPEG options that it normally sets, so the file is larger than an SDR JPEG minimised the same way. For the smallest file, remove the gain map first:

```elixir
iex> image = Image.open!("test/support/images/gain_map.jpg")
iex> {:ok, sdr} = Image.GainMap.remove(image)
iex> {:ok, jpeg} = Image.write(sdr, :memory, suffix: ".jpg", minimize_file_size: true)
iex> {:ok, reloaded} = Image.from_binary(jpeg)
iex> Image.GainMap.gain_map?(reloaded)
false
```

## Rendering the HDR image

`Image.GainMap.apply/1` applies the gain map at full boost and returns the HDR image as 32-bit float scRGB, where 1.0 is SDR white and brighter regions go above it. The result has no gain map; an image that had none is simply converted to scRGB. Writing it to a JPEG lets the UltraHDR encoder compute a new gain map, which is the way to produce an UltraHDR image after an operation that would otherwise have removed the gain map.

```elixir
iex> image = Image.open!("test/support/images/gain_map.jpg")
iex> {:ok, hdr} = Image.GainMap.apply(image)
iex> Image.colorspace(hdr)
:scrgb
iex> Image.band_format(hdr)
{:f, 32}
iex> Image.GainMap.gain_map?(hdr)
false
```

## Limitations

* **Formats** — only UltraHDR JPEG is supported. AVIF and JPEG XL gain maps are planned for libvips 8.20, and Apple and Adobe gain maps are not recognised by libultrahdr.

* **Arbitrary transforms** — rotation by an angle that is not a multiple of 90°, the affine family and the coordinate-remapping functions remove the gain map rather than transform it.

* **File size** — with libvips 8.18, `minimize_file_size: true` cannot apply its JPEG encoder options to an UltraHDR image.

* **Rendering** — `Image.GainMap.apply/1` always applies the full boost; there is no option to render for a display with less headroom.
