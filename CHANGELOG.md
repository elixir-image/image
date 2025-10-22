# Changelog

## Image 0.62.1

This is the changelog for Image version 0.62.1 released on October 23rd, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix decoding EXIF component configuration if the value is invalid. Fixes #194. Thanks to @ethangunderson for the report.

* Fix `Image.minimize_metadata/1` when the image does not have an author or copyright field.

## Image 0.62.0

This is the changelog for Image version 0.62.0 released on August 8th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking Change

* `Image.histogram/1` previously normalized the results which meant that the pixel counts for each bucket could not be resolved. The function no longer normalises the histogram so the raw pixel counts per bucket are retained.

### Bug Fixes

* `Image.histogram/1` is fixed to *not* normalize histogram entries. Therefore the histogram now returns correct pixel counts.

* Fix `Image.Text.add_background_padding/2` when the padding is derived from a base image.

### Enhancements

* Add `Image.to_list/1` to return an image as a nested list.

* Added an example for `Image.histogram/1` to illustrate what data is returned and how to interpret it.

## Image 0.61.1

This is the changelog for Image version 0.61.1 released on July 14th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix "function get_req_message/1" compiler warning.

## Image 0.61.0

This is the changelog for Image version 0.61.0 released on July 2nd, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.from_req_stream/2`. This function returns a `Vix.Vips.Image.t/0` from streaming a `Req` request using the `Req.get/2` option `into: :self`,

## Image 0.60.0

This is the changelog for Image version 0.60.0 released on June 27th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking Changes

* `Image.Math.maxpos/2` is renamed to `Image.Math.top_n/2` to better reflect its intent. The keyword options argument is also replaced with a simple integer argument `n`.

* `Image.Math.minpos/2` is renamed to `Image.Math.bottom_n/2` to better reflect its intent. The keyword options argument is also replaced with a simple integer argument `n`.

* The return value from `Image.Math.top_n/2` and `Image.Math.bottom_n/2` have changed. They will now return the form `{max, max_x, max_y, [{x_max_1, y_max_1}, {x_max_2, y_max_2}, ...]}`.

### Bug Fixes

* Improve the error messages for `Image.crop/5` when the crop bounding box is invalid. Closes #190.

### Enhancements

* Add `Image.band_and/1`, `Image.band_or/1` and `Image.band_xor/1` to apply the appropriate boolean operation across the bands of an image.

* Add new (and different) `Image.Math.maxpos/2` and `Image.Math.minpos/2` which return only coordinates whose values match the image maximum or minimum.

## Image 0.59.3

This is the changelog for Image version 0.59.3 released on April 27th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `:compression` option handling for `Image.write/2` when the image type is `.heic` or `:avif`. Thanks to @olivermt for the report. Closes #189.

## Image 0.59.2

This is the changelog for Image version 0.59.2 released on April 21st, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes `Image.rounded/1` and `Image.squircle/1` when the image has an alpha band. Thanks to @Neophen for the report. Closes #182.

## Image 0.59.1

This is the changelog for Image version 0.59.1 released on April 21st, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Deprecation

* The option `:fontfile` to `Image.Text.text/2` is deprecated in favour of `:font_file` to be compatible with other functions that use the same option name.

### Bug Fixes

* Remove pattern matching on `Stream.t` in `Image.open/2`. Thanks to @dcrck for the PR. Closes #187.

* Fix `Image.Text.text/2` when `:height` is specified but not `:width`. In this case an error is returned since `:height` can only be specified if `:width` is also specified. Thanks to @Neophen for the report. Closes #185.

* Fix `Image.Text.text/2` when the option `:font_weight` is specified. The options `:font_weight` and `:letter_spacing` are implemented by wrapping the text in a [Pango markup](https://docs.gtk.org/Pango/pango_markup.html) `span` tag. If the `string` parameter starts with `<span` then these two options are ignored since this implies the user is taking full control of the markup. Closes #183.

* Add option documentation for `:font_file` to `Image.Text.text/2` and note the requirement to also specify `:font` if `:font_file` is specified.

* Clarify that `Image.Text.text/2` option `:font_file` is not supported on MacOS. On that platform, only FontBook fonts are supported. It is known to work on Linux. The status on Windows is currently unknown by the author - feedback would be welcome.

## Image 0.59.0

This is the changelog for Image version 0.59.0 released on March 14th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking Change

* `Image.radial_distortion_correction/5` and `Image.vignette_correction/4` have moved to a new library [image_lens_correction](https://github.com/elixir-image/image_lens_correction).

### Enhancements

* Tolerate non-compliant null-terminated datatime strings in Exif. Thanks to @hansihe for the PR. Closes #181.

* Add `Image.Math.max/1`, `Image.Math.min/1`, `Image.Math.max!/1`, `Image.Math.min!/1` and `Image.Complex.polar/1`.

## Image 0.58.0

This is the changelog for Image version 0.58.0 released on March 11th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Add `Image.barrel_correction/5` to correct barrel distortion in an image.

* Add `Image.Math.abs/1`.

## Image 0.57.0

This is the changelog for Image version 0.57.0 released on March 11th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes `Image.from_kino!/2` to accept `format: :png` images.

### Enhancements

* Adds `Image.distort/2` to perform a freeform image distortion using [Shepard's algorithm](https://legacy.imagemagick.org/Usage/distorts/#shepards)

## Image 0.56.1

This is the changelog for Image version 0.56.1 released on March 11th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Support `:png` image types in `Image.from_kino/2`. Although the option is called `:png` in Kino, it actually allows any image format as long as it can be opened with `Image.open/2`.

## Image 0.56.0

This is the changelog for Image version 0.56.0 released on January 28th, 2025.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.find_trim/2` and `Image.find_trim!/2` to return the bounding box of the non-background area of an image.

## Image 0.55.2

This is the changelog for Image version 0.55.2 released on December 8th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Update the version number only so that there is no retired version as the latest on hex.

## Image 0.55.1

This is the changelog for Image version 0.55.1 released on December 8th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Deprecated and retired.

## Image 0.55.0

This is the changelog for Image version 0.55.0 released on December 8th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes `Image.mutate/4` to correctly interpret the return results of mutation functions in `Image.Draw`. Thanks to @ramyma for the issue and the PR.  Closes #173, closes #174.

* Fix spec for `Image.crop!/4`. Thanks to @BobbyMcWho for the PR. Closes #171.

### Enhancements

* Support the `:pyramid` option for saving `.tiff` files. Thanks to @dersmon for the suggestion. Closes #172.

## Image 0.54.4

This is the changelog for Image version 0.54.4 released on October 3rd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Raises minimum Elixir version to 1.14 since that is the minimum requriement now for [Nx](https://hex.pm/packages/nx).

* Add Elixir 1.14 to the CI matrix. Thanks very much to @@leandrocp for the PR. Closes #164.

* Fix some EXIF tag decoding. Thanks to @hansihe for the PR. Closes #169.

## Image 0.54.3

This is the changelog for Image version 0.54.3 released on September 6th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix parsing invalid date time in Exif data. When invalid, the raw underlying string is returned.

* Trim strings in Exif data. As a result, empty strings will be returned now as `nil` rather than `""`.

* Replace a `<<0, ....>>` sequence in an Exif string value with `nil`.

* Decode additional tags:

  * Exif tag `0xA005`, Interop Offset. The value is in internal file pointer so has no meaningful interpretation in `image`.

  * TIFF tag `0xC4A5`, Print Image Matching. According to [this source](https://www.loc.gov/preservation/digital/formats/content/tiff_tags.shtml) the field has no standardised values so the raw value is returned.

## Image 0.54.2

This is the changelog for Image version 0.54.2 released on September 1st, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Return the updated `t:Plug.Conn.t/0` when calling `Image.write/2` with the destination being a plug. Thanks to @lostkobrakai for the issue. Closes #159.

* Fixes `Image.Application` to use `Image.bumblebee_configured?/0`. Thanks to @mat-hek for the PR. Closes #160.

* Fix the spec for `Image.Video.with_video/2`. Thanks to @nikitosing for the report. Closes #162.

## Image 0.54.1

This is the changelog for Image version 0.54.1 released on August 20th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Adjust `Image.Math.-/1` (unary minus) syntax to be compatible on more elixir versions. Should be ok back to Elixir 1.12 depending on vix version support requirement on OTP.

## Image 0.54.0

This is the changelog for Image version 0.54.0 released on August 18th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix typespecs in `Image.Draw`, improve tests and clarify docs. In particular, document that the function passed to `Image.mutate/2` *must* return either `:ok` or `{:ok, term}`.

* Fix `Image.get_pixel/3` to ensure only integer values are returned when the image band format is integer. This is required because the underlying `Vix.Vips.Operation.getpoint/3` always returns floats.

* Fix using `Image.open/2` with binary HEIC files. HEIC magic numbers are now used to identify if a binary is an HEIC image (as is already done for other image types).

* Return an error if opening a video stream returns a `Evision.VideoCapture.t` struct but the `isOpened` field is `false`.

### Enhancements

* Adds `Image.vibrance/3` and `Image.vibrance!/3` following the [libvips discussion](https://github.com/libvips/libvips/discussions/4039).

* Add documentation to `Image.Video.open/2` illustrating how to open RTSP video streams.

## Image 0.53.0

This is the changelog for Image version 0.53.0 released on July 14th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.join_bands/1` and `Image.join_bands!/1`. Thanks to @Solido for the suggestion. Closes #146.

## Image 0.52.3

This is the changelog for Image version 0.52.3 released on July 13th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `Image.Color.sort/2`. Thanks to @Solido for the report. Closes #145.

## Image 0.52.2

This is the changelog for Image version 0.52.2 released on July 9th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix the return from `Image.contrast/2`. Thanks to @RyoWakabayashi for the report and the PR. Closes #144.

## Image 0.52.1

This is the changelog for Image version 0.52.1 released on July 3rd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix including `Image.Nx` only if `Nx` is configured.  Closes #143.

## Image 0.52.0

This is the changelog for Image version 0.52.0 released on July 3rd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `:background_color` option to `Image.flatten/2`.

* Add `Image.Nx` to host some `Nx` convenience functions.

### Bug Fixes

* Fix `Image.delta_e/2` to return a float (not an integer)

* Fix `Image.k_means/2` to work with images in color spaces other than sRGB.

## Image 0.51.0

This is the changelog for Image version 0.51.0 released on June 29th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds Image.to_kino/1 to convert an image to a Kino image struct. Only available if [Kino](https://hex.pm/packages/kino) is configured.

* Adds `Image.delta_e!/2`

* Adds `Image.reduce_colors!/2`

## Image 0.50.0

This is the changelog for Image version 0.50.0 released on June 28th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.reduce_colors/2` to reduce the number of colors in an image. `Scholar.Cluster.KMeans.fit/2` is used to cluster the colors. The clusters are then used to recolor the image.

## Image 0.49.0

This is the changelog for Image version 0.49.0 released on June 28th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Updates `Image.dominant_color/2` to take an optional `:top_n` which indicates how many of the most dominant colors to return. The default is `1`. In addition, the implementation of `Image.dominant_color/2` has been simplified following the advice at https://github.com/libvips/libvips/discussions/4016

* Adds `Image.delta_e/3` to calculate a difference between two colors using one of the CIE color difference algorithms.

* Adds `Image.k_means/2` to cluster image colors into a color palette. This function is only available if [scholar](https://hex.pm/packages/scholar) is configured. As for any [Nx](https://hex.pm/packages/nx) installation, performance is affected by configuration options. It is likely that setting the following in `config.exs` will be a good idea:

```elixir
config :nx,
  default_backend: EXLA.Backend

config :nx, :default_defn_options,
  compiler: EXLA
```

* Adds `Image.Color.sort/2` to sort colors perceptually.

* Adds `Image.Color.convert/3` to convert a color from one color space to another. Currently only supports `srgb_to_hsv`.

## Image 0.48.1

This is the changelog for Image version 0.48.1 released on June 6th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Relax `evision` dependency to allow the `0.2` chain as well as the `0.1` chain. Thanks to @davydog187 for the report. Closes #140.

* Fix `Evision.resize/3` parameter to be `:interpolation` rather than `:interpolate`.

## Image 0.48.0

This is the changelog for Image version 0.48.0 released on May 30th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Add `:model_options` and `:featurizer_options` configuration keys for `Image.Classifier`. These options are expected to be the options passed to `Bumblebee.load_model/2` and `Bumblebee.load_featurizer/2` respectively.

* Add `:batch_size` as a configuration option. The value is passed to `Bumblebee.Vision.image_classification/4`. The default value is `10`.

## Image 0.47.0

This is the changelog for Image version 0.47.0 released on May 14th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix warnings for Elixir 1.17

### Enhancements

* Add `Image.from_nx!/2`

## Image 0.46.0

This is the changelog for Image version 0.46.0 released on May 11th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `:dpi` as an option to `Image.Text.text/2` and `Image.Text.simple_text/2`.

## Image 0.45.0

This is the changelog for Image version 0.45.0 released on May 6th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking changes

The implementations of `Image.text/2` and `Image.simple_text/2` have been simplified to use only the built-in Pango renderer. A bug in font sizing using the Pango renderer has also been fixed. As a result, there may be some small visual differences between text images generated by Image 0.45.0 compared to previous releases.

* `Image.text/2` now uses only the built-in [Pango](https://docs.gtk.org/Pango/pango_markup.html) renderer for all use cases. SVG is not nhow used for any rendering in `Image.text/2` or `Image.simple_text/2`. This gives a more consistent output and less ambiguity. However as a result, a small number of options are no longer available since they cannot be honoured by Pango:

  * `:text_stroke_color`

  * `:text_stroke_width`

* The `:autofit` option to `Image.text/2` is also removed. The autofit capability is now controlled by whether the `:width` and/or `:height` options are provided.

* Some other options are now treated differently in `Image.text/2`:

  * `:width` and `:height` are now truly optional. If ommitted, the renderer will calculate the required image size based upon the other options. It is acceptable to specify `:width` and omit `:height` in which case the maximum width is fixed and the height is variable.

### Bug Fixes

* Fix warnings on upcoming Elixir 1.17.

* A bug resulting in incorrect font sizing with using the Pango renderer has been fixed. Font sizing is now very similar to the sizing of the previously used SVG renderer.

## Image 0.44.0

This is the changelog for Image version 0.44.0 released on April 9th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.Blurhash.encode/2` and `Image.Blurhash.decode/1` to encode and decode [blurhashes](https://blurha.sh). Based upon a fork of [rinpatch_blurhash](https://github.com/rinpatch/blurhash). Thanks to @stiang for the suggestion. Thanks very much to @rinpatch for the implementation.

## Image 0.43.2

This is the changelog for Image version 0.43.2 released on April 2nd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix typo in exif `:subsec_time_original`.

* Remove spurious leading space from exif tag description " Standard Output Sensitivity and Recommended Exposure Index"

* Fix decoding exif tags that have an empty string as a value.

Thanks to Cam Cook for the issues.

## Image 0.43.1

This is the changelog for Image version 0.43.1 released on March 22nd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* `Image.from_kino/2` and `Image.from_kino!/2` now use the `:file_ref` field in the Kino input structure to identify the required image. This changed was added in [Kino 0.11](https://github.com/livebook-dev/kino/blob/main/CHANGELOG.md#v0110-2023-10-06) which is therefore now a minimum version requirement. Thanks to @kevinschweikert for the PR. Closes #133.

* Improve the thumbnailing guide. Thanks to @nathanl for the PR. Closes #132.

## Image 0.43.0

This is the changelog for Image version 0.43.0 released on February 27th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking Changes

* `Image.erode/2` and `Image.dilate/2` now take a `radius` parameter rather than a `pixels` parameter. Both functions have been refactored to allow a radius in the range `1..5` with a default of `1`. The radius represents the dimension of the matrix used in the `Vix.Vips.Operations.range/4` function that underpins dilation and erosion. As such they represent the *approximate* number of pixels eroded or dilated.  In addition, this function now results in a single `libvips` operation. The previous implementation created `n` operations (where `n` was the value of the `pixels` param) that could result in a slow imaging pipeline and in some cases a [segfault of the entire VM due to stack space exhaustion in libvips](https://github.com/elixir-image/image/issues/125).

* The signature for `Image.linear_gradient/{1..3}` has changed.  The function now takes:
  * An image and an optional keyword list of options
  * A width and height as numbers and a keyword list of options

* `Image.dominant_color/2` now returns an `{:ok, rgb_color}` tuple rather than a `[r, g, b]` list. Use `Image.dominant_color!/2` if only the color value return is required.

* `Image.map_pages/2` is deprecated in favour of `Image.map_join_pages/2` to better reflect the intent of the function.

### Enhancements

* `Image.linear_gradient/{1..3}` now takes an `:angle` option which determines the angle of the gradient in degrees. Thanks to @severian1778 for considerable patience. Closes #67.

* Improve options handling and documentation for `Image.radial_gradient/3`.

* Add `Image.radial_gradient!/3` to mirror `Image.radial_gradient/3`.

* Add `Image.dominant_color!/2` to mirror `Image.dominant_color/2`.

* Add `Image.extract_pages/1` which will extract the pages of a multi-page into a list of separate images.

## Image 0.42.0

This is the changelog for Image version 0.42.0 released on January 23rd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Deprecations

* `Image.interpretation/0` deprecated in favour of `Image.colorspace/0`. This is more orthogonal to the `Image.to_colorspace/2` call and more in line with common image lexicons.

* `Image.convert_to_mask/1` is deprecated in favour of `Image.covert_alpha_to_mask/1` which is more descriptive of the functions purpose.

* `Image.type/1` is deprecated in favour of `Image.band_format/1`. This function name expresses clearer intent.

### Bug Fixes

* Fix `:rbg` colorspace to be the correct name of `:rgb`.

### Enhancements

* Documentation updates for `Image.dilate/2` and `Image.erode/2`.

* Add `Image.cast!/2` to mirror `Image.cast/2`.

* Add `Image.invert/1` and `Image.invert!/2` to invert an image.

* Add livebook tutorial for edge masking. [![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fraw.githubusercontent.com%2Felixir-image%2Fimage%2Fmain%2Flivebook%2Fimage_edge_masking.livemd)

## Image 0.41.0

This is the changelog for Image version 0.41.0 released on January 18th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.YUV` module that provides functions to convert between YUV and RGB image data. Thanks very much to @mat-hek for the collaboration. This module makes it easier to work with video image data which is typically in YUV encoded. The module supports [4:4:4, 4:2:2 and 4:2:0](https://en.wikipedia.org/wiki/Chroma_subsampling) encoding in either of the [BT601](https://en.wikipedia.org/wiki/Rec._601) or [BT709](https://en.wikipedia.org/wiki/Rec._709) colorspaces.

## Image 0.40.0

This is the changelog for Image version 0.40.0 released on January 6th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fix

* Fix docs for `Image.new/1` (the docs for `Image.new/{2, 3}` are correct).

### Enhancements

* Adds `Image.join/2` which takes a list of images and joins them into a grid.

## Image 0.39.3

This is the changelog for Image version 0.39.3 released on January 4th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fix

* Fix typespec of `Image.write!/3` to include `:memory` as a valid destination.  Thanks to @LostKobrakai for the PR. Closes #124.

## Image 0.39.2

This is the changelog for Image version 0.39.2 released on January 2nd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fix

* Fix `Image.avatar/2` to correctly resize and maintain aspect ratio. Thanks to @samullen for the report and patience. Closes #123.

## Image 0.39.1

This is the changelog for Image version 0.39.1 released on December 28th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fix

* Adds support for `phoenix_html` ~4.0 in addition to ~3.2 and ~2.1. Thanks to @tapickell for the PR.

* Don't include `priv/models` in the hex package.

## Image 0.39.0

This is the changelog for Image version 0.39.0 released on December 15th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking change

* `Image.open/2` no longer supports the `:autorotate` option. Instead, call `Image.autorotate/1` after opening the image. There reasons are:
  * `:autorotate` is only supported by `libvips` for a few image types, *not* including `png` images. Hence the option cannot be used in a generalised way.
  * No signalling is done to indicate whether the image was actually rotated whereas `Image.autorotate/1` does return this information.
  * Using `autorotate: true` does not appear to remove the `orientation` EXIF tag and therefore calling `Image.autorotate/1` would result in a second rotation.

### Bug Fixes

* Fix finding the dominant color for images with an alpha band. Thansk to @mayel for the report. Closes #114.

## Image 0.38.5

This is the changelog for Image version 0.38.5 released on December 7th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking change

* The `Image.embed/4` option `:background` is renamed to `:background_color` to better align with other functions.

### Bug Fixes

* Fix `Image.Text.add_background_padding/2` when the base image doesn't already have an alpha band. Thanks to @tielur for the report. Closes #120.

* Fix `Image.embed/4` to default to `x: :center, y: :center` as stated in the documentation.

* Fix `Image.embed/4` to set `extend_mode: :background` if `:background_color` is specified.

## Image 0.38.4

This is the changelog for Image version 0.38.4 released on November 9th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes `Image.dhash/2`. Thanks to @jhonathas for the report. Closes #118.

* Fixes compiler warnings for Elixir 1.16.

## Image 0.38.3

This is the changelog for Image version 0.38.3 released on October 17th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Due to [the fix](https://github.com/akash-akya/vix/pull/129) for [this issue](https://github.com/akash-akya/vix/issues/126) in [vix](https://github.com/akash-akya/vix), a fix is applied in `Image.nx/2` to ensure correct operation. There should be no change to user code other than the requirement for the versions of `image` and `vix` to correctly match.  This release of `image` requires `vix` version `0.23` to ensure compatibility.

## Image 0.38.2

This is the changelog for Image version 0.38.2 released on September 27th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `Image.dominant_color/2` for images with an alpha band.  Thanks to @mayel for the report. Closes #114.

## Image 0.38.1

This is the changelog for Image version 0.38.1 released on September 23rd, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `t:Image.Options.Avatar.avatar_options/0`. Thanks to @jarrodmoldrich. Closes #113.

* Improves `Image.avatar/2` documentation and brings the docs into line with the implementation.

## Image 0.38.0

This is the changelog for Image version 0.38.0 released on September 11th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `extend_mode: :black` color handling for images with an alpha band. Also fixes when the image is a single band image.  Thanks to @icefoxen for reporting the issue. Closes #108.

### Enhancements

* Adds a [squircle](https://en.wikipedia.org/wiki/Squircle) mask function and a squircle avatar shape option. Thanks to @gf3 for the PR.

* Adds `Image.map_pages/2` to execute a function for each page in a `.webp` or `.gif` image then reassemble the pages into a new image. This can be used to crop all the frames of an animated image.  Thanks to @Mefgalm for the prompt to get this done. Eventually this function will be used by default for `Image.crop/5` and `Image.thumnail/3`.

* Adds `Image.pages/1` to return the number of pages in an image. For normal images the result will be `1`. For animated images it will be the number of frames in the animation.

* Adds support for cropping multi-page images (like animated `.webp` and `.gif` images) in `Image.crop/5`.

* Adds `Image.Shape.circle/2`, `Image.Shape.ellipse/3` and `Image.Shape.line/5` as well as their `!` counterparts.

* Allow `pages: :all` as a synonym for `pages: -1` when opening an image.

## Image 0.37.0

This is the changelog for Image version 0.37.0 released on August 17th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `background: :alpha` as an option to `Image.trim/2`. When set, the image is trimmed to the bounds of the mask in the alpha band of an image.

## Image 0.36.2

This is the changelog for Image version 0.36.2 released on July 24th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `Image.from_nx/1` by respecting the axis name order in the tensor. Thanks to @gBillal for the PR. Closes #101.

## Image 0.36.1

This is the changelog for Image version 0.36.1 released on July 23rd, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Support negative offsets `:x` and `:y` for `Image.compose/3`.

## Image 0.36.0

This is the changelog for Image version 0.36.0 released on July 16th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.Histogram.as_svg/2` and `Image.Histogram.as_image/2` to return the histogram of an image as either an SVG format suitable to adding to an HTML page or as an `t:Vix.Vips.Image.t/0`.

## Image 0.35.0

This is the changelog for Image version 0.35.0 released on July 4th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking change

* Removes `Image.autolevel/1` which is replaced by `Image.equalize(image, :each)`.

* Removes `Image.normalize/1` which is replaced by `Image.equalize(image, :luminance)`.

### Enhancements

* Adds `Image.equalize/2` which expands an image to fill the tone range. Equalization can be performed on all bands, on each band or only on the luminance band. This function replaces `Image.normalize/1` and `Image.autolevel/1`.

* Adds `Image.contrast/2` to apply simple contrast adjustments to an image. The contrast parameter is provided as a float >= 0.0 with contrast less than 1.0 meaning reduce contrast and greater than 1.0 meaning increase contrast.

* Adds `Image.apply_tone_curve/2` which applies a [tone curve](https://en.wikipedia.org/wiki/Curve_(tonality)) to an image. This is typically used to affect overall image contrast.

* Adds `Image.local_contrast/2` which applies a [Constrast Limited Adaptive histogram equalization (CLAHE)](https://en.wikipedia.org/wiki/Adaptive_histogram_equalization#Contrast_Limited_AHE) to improve local contrast in images.

* Adds `Image.sharpen/2` to apply sharpening to an image.

* Adds `Image.modulate/2` to adjust an image using brightness, saturation, hue rotation and lightness in a single call.

* Adds `Image.band_format/1` to return the band format of an image in `Nx` notation.

* Adds `Image.with_band_format/3` to cast an image to a new band format, execute a function on the cast image and then re-cast the image back to its original band format if the function returns successfully.

* Adds `Image.range/1` that returns the possible range of values for a pixel as a tuple in the form `{min_value, max_value}`.

* Adds `Image.reduce_noise/2` and `Image.reduce_noise!/2` that applies a median filter to reduce salt and pepper noise in an image.

## Image 0.34.0

This is the changelog for Image version 0.34.0 released on June 24th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Corrects generating text images with `Image.Text.text/2` whent the `text_stroke_color` and `text_fill_color` are black. Closes #87 (again).

* Fixes using a combination of atom and numeric arguments to `Image.compose/3`. Thanks to @sodapopcan for the PR. Closes #97.

* Removes a warning when testing without minio being installed. Thanks to @sodapopcan for the PR. Closes #95.

### Enhancements

* Adds `Image.compare/3` to compare two images for similarity using a given metric (default is `:ae` or absolute error). The three metrics implemented in this release are `:ae` (absolute error which returns a value between 0.0 and 1.0), `:mse` (mean squared error) and `:rmse` (root mean squared error which returns a value between 0.0 and 1.0).

* Adds `Image.brightness/2` and `Image.saturation/2` to adjust the image brightness and saturation by a percentage amount between `0.0` and `1.0`. Also adds `Image.brightness!/2` and `Image.saturation!/2`.

* Adds `hash_size` as an argument to `Image.hamming_distance/3`. This is the size in bits of the returned hash. The default is 64. The size of the returned hash is only guaranteed to be this size if the `:math.sqrt(hash_size)` is an integer.

* Adds `:letter_spacing` as an option to `Image.Text.text/2`. Thanks to @sodapopcan for the PR. Closes #97.

## Image 0.33.0

This is the changelog for Image version 0.33.0 released on June 2nd, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking Changes

* `Image.dhash/1` now returns a 64-bit hash (by default) rather than a 512-bit hash. The original algorithm is intended to return a 64-bit hash so this is both a breaking change and bug fix.

* Fix generation of images from text when `autofit: false` (the default). In these cases the text image is generated from SVG. The original implementation operated on the basis that the image would be generated with a height and width necessary to contain the text of a given font size. The result is not consistent and is influenced by whether the text has ascenders or desenders.  The new implementation creates an SVG container of a size large enough to contain the text at the given font-size and then trims away the background to produce the final result. Thanks to @ilesar for the report. Closes #86. **As a result of this fix, existing text-generated images may not now be the same as previous releases.**

## Image 0.32.0

This is the changelog for Image version 0.32.0 released on May 24th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `Image.Text.text/2` when the text fill color is black (within a tolerance). When the text image is created, `Vix.Vips.Operation.find_trim/2` is called to trim the image assuming a black background. Since the fill color is also black, the resulting trim is 0 pixels wide and 0 pixels high. When then cropping the image, the crop fails because the crop size is invalid.  The fix is to not crop if there is no trim detected. Thanks to @tielur for the report. Closes #84.

* Fix specification for `Image.compose/3` to remove dialyzer error (and include test case). Thanks to @tielur for the report. Closes #85.

* Fix `Image.add_alpha/2` when providing a "color". In fact the value should be an integer in the range 0..255 representing the level of transparency of the alpha band. The function spec, documentation and implementation are now changed to accept only an integer (or the atoms :opaque and :transparent).

### Enhancements

* Adds `Image.from_svg/2` and `Image.from_svg!/2` to provide a more discoverable means of creating an image from an SVG string.

## Image 0.31.1

This is the changelog for Image version 0.31.1 released on May 10th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix spec for `Image.replace_color/2` and `Image.replace_color!/2`. Thanks to @tielur. Closes #79.

## Image 0.31.0

This is the changelog for Image version 0.31.0 released on May 7th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix resolution of the image returned from `Image.replace_color/2`. Thanks to @tielur for the report. Closes #78.

### Enhancements

* Add `:blend` option to `Image.if_then_else/4`. When set to true with smoothly blend between the `then` and `else`  images. The default is `false`.

## Image 0.30.0

This is the changelog for Image version 0.30.0 released on April 20th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Add documentation for `Image.with_colorspace/3`.

* Fix `Image.trim/2` reflecting the updated `vix` return data structure.

* Fix `Image.if_then_else/3` to validate color options correctly.

### Enhancements

* Adds `Image.cast/2` to convert the band format of an image to a different numeric type.

* Adds `Image.replace_color/2` and `Image.replace_color!/2`.

* Adds `Image.if_then_else!/3`.

## Image 0.29.0

This is the changelog for Image version 0.29.0 released on April 14th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Supports [vix version 0.17.0](https://hex.pm/packages.vix/0.17.0).

## Image 0.28.2

This is the changelog for Image version 0.28.2 released on April 13th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* `Image.Classification.serving/2` was applying the option `top_k: 1` which means not all predictions were being returned. This option is now removed. Thanks to @tmariaz for raising the issue.

## Image 0.28.1

This is the changelog for Image version 0.28.1 released on April 7th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes `Image.add_alpha/2`. Thanks to @kwando for the PR. Closes #71.

* Fixes `:threshold` option in `Image.Options.ChromaKey` to allow a value of `0`.

* Fixes `Image.warp_perspective/4` to correctly flatten an image with an alpha band before the transform. Closes #70.

## Image 0.28.0

This is the changelog for Image version 0.28.0 released on April 6th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes resizing images with alpha bands. Resizing images with alpha bands requires premultiplying the alpha band into the image and reversing that after resizing.

### Enhancements

* Adds `Image.warp_perspective/4` to apply a warp transformation to an image. Thanks very much to @sodapopcan for the PR and collaboration.

* Adds `Image.straighten_perspective/3` to apply a warp perspective that straighens the image. It is basically `Image.warp_perspective/4` with algorithmically derived `destination` parameter.

* Adds `Image.map/2` which applies a transformation matrix (not a convolution kernel) to an image. A transformation matrix can be returned from `Image.transform_matrix/3`. These two functions underpin `Image.warp_perspective/4`.

* Adds `Image.crop/2` which is a variation of `Image.crop/5` that takes the same format of bounding box as that applied to `Image.warp_perspective/4` making it easy to apply a warp transform and then crop to the transformed area. Note that cropping requires that the bounding box be a rectangle, not an arbitrary quadrilateral.

## Image 0.27.1

This is the changelog for Image version 0.27.1 released on March 20th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Behaviour Change

* Changes the default position for an image embedded via `Image.embed/2` to be `[0, 0]` not `[:center, :center]`.

## Image 0.27.0

This is the changelog for Image version 0.27.0 released on March 20th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Image packaging future

In a future release, Image will be split into several packages

* `:image` which will retain all the core components of image transformation based upon `vix` and `libvips`.
* `:image_nx` which will provide `:nx` interoperability (and will depend on `:image`)
* `:image_exif` which will provide metadata support (and will depend on `:image`)
* `:image_classification` which will provide image classification (and will depend on `:image` and `:bumblebee`)
* `:image_generation` which will provide image generation (and will depend on `:image` and `:bumblebee`)
* `:image_detection` which will provide object detection (and will depend on `:image`, `:axon`, `:axon_onnx`)
* `:image_qrcode` which will provide QRcode scanning and production (and will depend on`:image` and `:evision`)
* `:image_video` which will provide video frame extraction (and will depend on`:image` and `:evision`)

### Enhancements

* Add `Image.from_kino/2` and `Image.from_kino!/2` to simplify create an image from a [Kino](https://hex.pm/packages/kino) image in [Livebook](https://livebook.dev).

* Add `Image.average/1` and `Image.average!/1` to calulate the average color of an image.

* Add `Image.center_crop/3` and `Image.center_crop!/3`

* Add `Image.embed/4` and `Image.embed!/4` to embed an image in a larger canvas, generating additional border pixels as required.

* Add `Image.Shape.rect/3` to draw a rectangle image.

## Image 0.26.0

This is the changelog for Image version 0.26.0 released on March 12th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking change

* `Image.avatar/3` is now `Image.avatar/2`. The `size` parameter is now the `:size` option. The default value of 180 pixels remains.

### Enhancements

* `Image.avatar/2` takes a `:shape` option that is either `:circle` (the default) or `:square`. This allows the generation of either circular or square avatars.

### Bug Fixes

* Fix `Image.open/2` for SVG binaries and add note to show that SVG images can be opened.

* Fix `Image.avatar/2` to square the image after thumbnailing but before applying any mask. This ensures a circular mask is centred on the thumbnailed image.

* Fix `Image.avatar/2` for image path parameters which no correctly flattens the image.

* Fix `Image.avatar!/2` to accept either an image or an image path.

## Image 0.25.1

This is the changelog for Image version 0.25.1 released on March 1st, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `is_webp/1` guard and downcase all suffixes before validation. Thanks to @quentin-bettoum for the report and fix. Closes #64.

* Fix `Image.avatar/3` to flatten the source image before compositing with the mask. Thanks to @jarrodmoldrich for the report. Closes #63.

* Fix `Image.flatten/1` to only flatten if there is an alpha band.

## Image 0.25.0

This is the changelog for Image version 0.25.0 released on February March 1st, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Behavior Change

* The default access mode for `Image.open/2` is now `access: :random` in line with `libvips` native default. Although `access: :sequential` optimizes for many cases (especially with regard to memory) it resulted in poor developer experience since the error messages when trying to re-use a `access: :sequential` image are difficult to understand and very difficult to re-interpret in `image`.

### Bug Fixes

* Adds `:heic` and `:avif` suffixes to the list of valid suffixes for `heif` file formats.  Thanks to @quentin-bettoum for the PR. Closes #50.

* Allows specifying the option `padding: 0` for `Image.Text.text/2`. Previously this only supported positive integers.

* Fix `Image.write/3` documentation. Thanks to @jeregrine for the PR. Closes #62.

### Enhancements

* Update `README.md` to include updated documentation for installing `libvips` with `Vix`.

* Adds `:x` and `:y` options to `Image.Text.text/2` which allows placing the text on its background in the specified location.  `:x` can be specified as a non-negative integer or one of `:left`, `:right` or `:center` with the default being `:center`. `:y` can be specified as a non-negative integer or one of `:top`, `:bottom` or `:middle` with the default being `:middle`. Thanks to @severian1778 for the issue and collaboration. Closes #44.

* Adds an option `:effort` to `Image.write/3` for `:png`, `:heif`, `:heic`, `:avif` and `:webp` images that determines the amount of CPU effort permitted when compressing the image data.  Thanks to @quentin-bettoum for the PR. Closes #45.

## Image 0.24.1

This is the changelog for Image version 0.24.1 released on February 14th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes `:weight` option handling in `Image.meme/3` to include `:ultralight`. Thanks to @quentin-bettoum. Closes #42.

* Fixes `:intent` option handling in `Image.thumbnail/3`. Thanks to @quentin-bettoum. Closes #43.

## Image 0.24.0

This is the changelog for Image version 0.24.0 released on February 6th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.Draw.flood!/4` to align with `Image.Draw.flood/4`.

* Adds `Image.add_alpha/2` and `Image.add_alpha!/2`.

* Adds `:stroke_width` to `Image.Draw.rect/6` and `Image.Draw.circle/5`. Thanks to @RyoWakabayashi for the suggestion and sample code.

## Image 0.23.2

This is the changelog for Image version 0.23.2 released on January 31st, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* `Image.Kino.show/2` returns the type `t:Kino.Image.t/0` which as a side effect does not show a duplicate image and plays nicely with `Kino.Layout.grid/2`.  Thanks to @RyoWakabayashi. Closes #37.

## Image 0.23.1

This is the changelog for Image version 0.23.1 released on January 30th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* `Kino.show/2` returns the image instead of `:ok` so that it works correctly in a grid. Thanks to @RyoWakabayashi for the [suggestion](https://github.com/elixir-image/image/discussions/1#discussioncomment-4826961).

## Image 0.23.0

This is the changelog for Image version 0.23.0 released on January 29th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix specs for `Image.Options.Write`. Thanks to @jarrodmoldrich. Closes #36.

* Fix spec for `Image.exif/1`. Thanks to @ntodd for the PR. Closes #35.

### Enhancements

* Adds `Image.normalize/1` which normalizes an image by expanding the luminance of an image to cover the full dynamic range.

* Adds `Image.autolevel/1` which scales each band of an image to fit the full dynamic range. Unlike `Image.normalize/1`, each band is scaled separately.

* Adds `Image.erode/2` which erodes pixels from the edge of an image mask. This can be useful to remove a small amount of colour fringing around the edge of an image.

* Adds `Image.dilate/2` which dilates pixels from the edge of an image mask.

* Adds `Image.trim/2` which trims an image to the bounding box of the non-background area.

* Adds `Image.flatten/1` which flattens an alpha layer out of an image

* `Image.Options.Write.validate_options/2` now validates options appropriate to each image type in order to make validation more robust.

* Adds `:minimize_file_size` option to `Image.write/2` for JPEG and PNG files which if `true` will apply a range of techniques to minimize the size of the image file at the expense of time to save the image and potentially image quality.

## Image 0.22.1

This is the changelog for Image version 0.22.1 released on January 9th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Don't compile `Image.Options.Video` unless Evision is configured and compiled.

## Image 0.22.0

This is the changelog for Image version 0.22.0 released on January 9th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.Video.stream!/2` that returns an enumerable stream of frames as images.

* Adds `Image.Video.scrub/2` that scubs the video head forward a number of frames.

## Image 0.21.0

This is the changelog for Image version 0.21.0 released on January 8th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking change

* `Image.Video.image_at_millisecond/2` and `Image.Video.image_from_frame/2` are removed and replaced by `Image.Video.image_from_video/2`.

### Enhancements

* Adds `Image.Video.image_from_video/2` with support for `:frame` and `:millisecond` seek options. Seek options are only supported for video files, not video streams.

* Adds `Image.Video.seek/2` to seek the extraction point to the requested frame or millisecond. Seeking is supported for video files only, not video streams.

* Adds support for capturing images from video streams (not only video files). For example, `Image.Video.open(:default_camera)`. See the updated documentation for `Image.Video.open/1`.  An image stream does not support seeking.

## Image 0.20.0

This is the changelog for Image version 0.20.0 released on January 8th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `Image.from_evision/1` to correctly orient the dimensions as `{width, height, bands}`

### Enhancements

* Add support for extracting frames from video as images using `eVision`.  See `Image.Video`.

* Supports `vix` upcoming prebuilt `libvips`.  The prebuilt `libvips` may not include the FFT dependency so `Image.skew_angle/1` and `Image.fft/1` are only included if `Vix.Vips.Operation.fft!/1` is available.

## Image 0.19.0

This is the changelog for Image version 0.19.0 released on December 24th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.Generation.text_to_image/2` the uses [Stable Diffusion](https://en.wikipedia.org/wiki/Stable_Diffusion) support in [Bumblebee](https://hex.pm/packages/bumblebee) to generate an image from a text description of scene.

## Image 0.18.1

This is the changelog for Image version 0.18.1 released on December 21st, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `Image.Application.start/2`. Previously it would return `nil` if Bumblebee was not configured and `nil` is not a valid return from an application start function. Thanks to @haste for the report and PR.  Closes #34.

## Image 0.18.0

This is the changelog for Image version 0.18.0 released on December 20th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.Classification.classify/2` and `Image.Classification.labels/2` to execute image classification models over an image using [Bumblebee](https://hex.pm/packages/bumblebee).

* Adds an option `:max_height` to `Image.Kino.show/2`. Thanks to @kwando for the PR.  Closes #33.

## Image 0.17.0

This is the changelog for Image version 0.17.0 released on December 19, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking change

* Rename `Image.orientation/1` to be `Image.aspect/1` to better reflect its purpose. Orientation has a more specific meaning in image metadata and in `Vips.Vix.Image.orientation/1`.

### Bug Fixes

* Fix `Image.aspect/1` for exactly square images.

* Draw functions now default to opaque if the base image has an alpha band (previously they would be transparent). Thanks for @kwando for the collaboration. Closes #32.

### Enhancements

* Adds a `:fit` option to `Image.thumbnail/3` that uses the same terminology as the CSS [object-fit](https://www.w3schools.com/css/css3_object-fit.asp) property. This option sets overwrites the options `:crop` and `:resize` to produce the specified outcome.

* Add `Image.Draw.point!/4`, `Image.Draw.rect!/6`, `Image.Draw.circle!/5` and `Image.Draw.line!/6`.

## Image 0.16.0

This is the changelog for Image version 0.16.0 released on Decmber 18th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Allow percentages to be specified as `Image.crop/5` parameters for left, top, width and height.  Percentages are expressed as floats in the range -1.0 to 1.0 (for left and top) and greater than 0.0 and less than or equal to 1.0 (for width and height). Thanks to @tmjoen for the suggestion.

## Image 0.15.1

This is the changelog for Image version 0.15.1 released on Decmber 13th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes interpretation of color encoded as `#xxxxxx`. Closes #26. Thanks to @a8t for the report.

## Image 0.15.0

This is the changelog for Image version 0.15.0 released on Decmber 4th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `Image.minimize_metadata/1` which was previously creating malformed exif data.

### Enhancements

* Add `:autofit` option to `Image.Text.text/2`. When set to `true`, text is rendered with `Vix.Vips.Operation.text/2`. The default, `false`, uses SVG rendering. There are pros and cons to both strategies. The main difference is that `autofit: true` will automatically size the text and perform line wrapping to fit the specified `:width` and `:height`.  Thanks to @dmitriid for the suggestion!

## Image 0.14.4

This is the changelog for Image version 0.14.4 released on November 14th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix the return type for `Image.write/3` for `Plug.Conn`. Thanks to @andreyuhai for the PR.

* Fix type specs for `Image.write/3` when the destination is `:memory`. Thanks to @georgfaust for raising the issue.

* Fixes the rbga color model for integer alpha values *again* (which are automatically cast to the appropriate float value). Thanks to @andreyuhai for your patience and collaboration while this was sorted out.

## Image 0.14.3

This is the changelog for Image version 0.14.3 released on November 14th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes the rbga color model for integer alpha values (which are automatically cast to the appropriate float value). Thanks to @andreyuhai for your patience and collaboration while this was sorted out.

* Casts the color to the correct number of bands in `Image.Draw` functions. This will either add or remove an alpha band to the color of the shape being drawn to match the underlying image.  Thanks to @andreyuhai for the PR. Closes #22.

## Image 0.14.2

This is the changelog for Image version 0.14.2 released on November 13th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix `Image.split_bands/1`

* Fix `Image.split_alpha/1`

## Image 0.14.1

This is the changelog for Image version 0.14.1 released on November 11th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fix streaming image writes. Previously the stream chunks were being written in reverse order. Closes #19. Thanks to @loics2 for the report.

## Image 0.14.0

This is the changelog for Image version 0.14.0 released on November 11th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Fixes extracting exif data when there is an exif blob but no exif tags. Closes #21.  Thanks to @feld for the report.

### Enhancements

* Add `Image.pixelate/2` and `Image.pixelate!/2`

* Add `Image.resize!/3`

## Image 0.13.1

This is the changelog for Image version 0.13.1 released on October 23rd, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug fixes

* Since a font named `Impact` isn't available on all systems, default meme generator can produce unexpected results for the rendered text.  The `Impact` font is now included in `Image` and will be used if the font name is `Impact`.

## Image 0.13.0

This is the changelog for Image version 0.13.0 released on October 23rd, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Breaking change

* `Image.resize/3` renamed to `Image.thumbnail/3`

### Bug fixes

* Fix `Image.open/2` when opening JPEG images from a binary. Seems JPEG files agree on the `<<0xff, 0xd8, 0xff>>` header for the first three bytes. But not completely consistent with the following bytes.

* Fix options for `Image.Draw` functions which are expected to be a map after validation (but were a keyword list).

### Enhancements

* Add `Image.chroma_key/2` and `Image.chroma_mask/2`.

* Add `Image.meme/3` and `Image.meme!/3`.

* Add `Image.QRcode.encode/1` and `Image.QRcode.decode/1`.

* Add `Image.blur/2`.

* Add `Image.feather/2`.

* Add `Image.new/2` that creates a new image of the same shape as the provided image.

* Add `Image.resize/3`.

* Add `Image.split_bands/1`.

* Add `Image.if_then_else/3`.

* Add `Image.preview/1` (and `Image.p/1` that delegates to it) to preview an image inline in an iTerm2 terminal windows.

* Add `Image.split_bands/1` to return a list single band images, one for each band in the original image.

## Image 0.12.0

This is the changelog for Image version 0.12.0 released on October 14th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Updates to support [eVision 0.1.11](https://hex.pm/packages/evision/0.1.11) which has API breaking changes. There is no change to the `Image.QRcode.decode/1` function which uses `eVision`.

## Image 0.11.0

This is the changelog for Image version 0.11.0 released on October 8th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Now uses `eVision` version `0.1` or later from [hex.pm](https://hex.pm/packages/evision)

## Image 0.10.0

This is the changelog for Image version 0.10.0 released on October 5th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug Fixes

* Since the mix build process does a `File.cwd!/1` to the directory of each dependency we can't use the dirname of the dependency to decide whether to configure `:evision` or not. The strategy is now changed to configure `:evision` only if the environment `CONFIGURE_EVISION` is set.  Note this is only relevant when developing `:image` itself.  Consumers of the library should add `:evision` as a dependency manually in their application `mix.exs` as described in the `readme`.  Thanks to @martosaur for the report.  Closes #13.

## Image 0.9.0

This is the changelog for Image version 0.9.0 released on October 1st, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* `Image.open/2` supports opening `.gif` and `.tif` images from raw binary data in addition to the previous `.jpeg`, `.png` and `.webp`.

* Add `Image.shape/1`

* Add `Image.interpretation/1`

* Add `Image.type/1`

* Add initial support for [eVision](https://github.com/cocoa-xu/evision). In this release the function `Image.QRcode.decode/1` is provided to decode images that contain a QRcode. See the `eVision` repository for installation instructions since this library is not yet on `hex.pm`.

* Removed most dialyzer warnings. The remaining warnings require an update to `Vix` (a PR has been submitted).

## Image 0.8.0

This is the changelog for Image version 0.8.0 released on September 30, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* `Image.open/2` now accepts raw image data for the image types `.jpeg`, `.png`, `.webp`

## Image 0.7.0

This is the changelog for Image version 0.7.0 released on September 30, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Set the environment variable `VIPS_BLOCK_UNTRUSTED` at application start if it is not already set. As of [libvips 8.13](https://www.libvips.org/2022/05/28/What's-new-in-8.13.html) this environment variable will cause `libvips` to not use any image loaders that are "unfuzzed".

* Add mutable draw operations. These operations mutate an image directly and hence special care is taken to avoid race conditions. All mutuable operations are serialized via a `GenServer`. See the `Image.Draw` module.  These functions are experimental for now pending additional testing.

* Add `Image.from_binary/2` to support creating an image from a raw binary.

* Thanks to @timothyvanderaerden for the PR to support getting dialyzer under control.  Work will continue on this over the next several releases.

## Image 0.6.0

This is the changelog for Image version 0.6.0 released on July 19th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Bug fixes

* Don't attempt to compile code that refers to `Plug.t` if `Plug` is not configured. Thanks to @kwando. Closes #7.

### Enhancements

* Adds `Image.dshash/1` to return a 512-bit image hash.

* Adds `Image.hamming_distance/2` to compare the similarity of two images or two image hashes.

* Adds `Image.radial_gradient/3` to great a radial gradient image. This could be used to composite over another image to add a vignette.

* Adds `Image.Math` logical functions `boolean_and/2`, `boolean_or/2`, `boolean_xor/2`, `boolean_lshift/2` and `boolean_rshift/2`. Also includes the `!` versions.

* Add operator `use Image.Math` overloads for image `&&&` (`and`), `|||` (`or`), `<<<` (`lshift`) and `>>>` (`rshift`).

## Image 0.5.0

This is the changelog for Image version 0.5.0 released on June 24th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.to_nx/1` to convert an image to an Nx tensor.

* Adds `Image.from_nx/1` to convert an Nx tensor into an image.

## Image 0.4.0

This is the changelog for Image version 0.4.0 released on June 23rd, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds support for opening streaming images. This allows images to be streamed from `File.stream!/3` or from any `t:Stream.t/0` including those created from [ExAws.S3](https://hexdocs.pm/ex_aws_s3/ExAws.S3.html) by [ExAws.stream!/2](https://hexdocs.pm/ex_aws/ExAws.html#stream!/2).

* Adds support writing streaming images. This allows images to be streamed as an enumerable which can then be consumed by `Plug.Conn.chunk/2`, by `ExAws.S3.upload/3`, `File.stream/3` or any other function that processes stream resources. See the `test/stream_image_test.exs` for examples.

* Adds a `:memory` option to `Image.write/3`. Instead of a path name or stream, use `:memory` if you'd like to return a `binary` form of an image in its formatted type. Note that this will run the image transformation pipeline resulting in the entire final image being loaded into memory. Therefore this option should be used sparingly since most use cases do not require this option. It is primarily added to facilitate passing images to other libraries in the Elixir ecosystem.

## Image 0.3.0

This is the changelog for Image version 0.3.0 released on June 4th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Add `Image.dominant_color/2` to return the dominant color of an image

* Add `Image.histogram/1` to return a histogram of an image

* Add `Image.get_pixel` to get the pixel value at a given `x` and `y` offset into an image.

## Image 0.2.0

This is the changelog for Image version 0.2.0 released on May 18th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Adds `Image.Text` to support generating an image from a string. See `Image.Text.text/2`.

* Adds `Image.Shape` to support generating images from shapes. In this release there is a generalised support for polygons and stars.  See `Image.Shape.polygon/2` and `Image.Shape.star/2`.

* Improves `Image.compose/3` to support composing with image lists, relative image placement and more.

## Image 0.1.0

This is the changelog for Image version 0.1.0 released on May 4th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-image/image/tags)

### Enhancements

* Initial release
