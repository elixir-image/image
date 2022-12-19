# Changelog

## Image 0.18.0

This is the changelog for Image version 0.18.0 released on ______, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Adds `Image.Classification.classify/2` and `Image.Classification.labels/2` to execute image classification models over an image using [Bumblebee](https://hex.pm/packages/bumblebee).

## Image 0.17.0

This is the changelog for Image version 0.17.0 released on December 19, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Breaking change

* Rename `Image.orientation/1` to be `Image.aspect/1` to better reflect its purpose. Orientation has a more specific meaning in image metadata and in `Vips.Vix.Image.orientation/1`.

### Bug Fixes

* Fix `Image.aspect/1` for exactly square images.

* Draw functions now default to opaque if the base image has an alpha band (previously they would be transparent). Thanks for @kwando for the collaboration. Closes #32.

### Enhancements

* Adds a `:fit` option to `Image.thumbnail/3` that uses the same terminology as the CSS [object-fit](https://www.w3schools.com/css/css3_object-fit.asp) property. This option sets overwrites the options `:crop` and `:resize` to produce the specified outcome.

* Add `Image.Draw.point!/4`, `Image.Draw.rect!/6`, `Image.Draw.circle!/5` and `Image.Draw.line!/6`.

## Image 0.16.0

This is the changelog for Image version 0.16.0 released on Decmber 18th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Allow percentages to be specified as `Image.crop/5` parameters for left, top, width and height.  Percentages are expressed as floats in the range -1.0 to 1.0 (for left and top) and greater than 0.0 and less than or equal to 1.0 (for width and height). Thanks to @tmjoen for the suggestion.

## Image 0.15.1

This is the changelog for Image version 0.15.1 released on Decmber 13th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug Fixes

* Fixes interpretation of color encoded as `#xxxxxx`. Closes #26. Thanks to @a8t for the report.

## Image 0.15.0

This is the changelog for Image version 0.15.0 released on Decmber 4th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug Fixes

* Fix `Image.minimize_metadata/1` which was previously creating malformed exif data.

### Enhancements

* Add `:autofit` option to `Image.Text.text/2`. When set to `true`, text is rendered with `Vix.Vips.Operation.text/2`. The default, `false`, uses SVG rendering. There are pros and cons to both strategies. The main difference is that `autofit: true` will automatically size the text and perform line wrapping to fit the specified `:width` and `:height`.  Thanks to @dmitriid for the suggestion!

## Image 0.14.4

This is the changelog for Image version 0.14.4 released on November 14th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug Fixes

* Fix the return type for `Image.write/3` for `Plug.Conn`. Thanks to @andreyuhai for the PR.

* Fix type specs for `Image.write/3` when the destination is `:memory`. Thanks to @georgfaust for raising the issue.

* Fixes the rbga color model for integer alpha values *again* (which are automatically cast to the appropriate float value). Thanks to @andreyuhai for your patience and collaboration while this was sorted out.

## Image 0.14.3

This is the changelog for Image version 0.14.3 released on November 14th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug Fixes

* Fixes the rbga color model for integer alpha values (which are automatically cast to the appropriate float value). Thanks to @andreyuhai for your patience and collaboration while this was sorted out.

* Casts the color to the correct number of bands in `Image.Draw` functions. This will either add or remove an alpha band to the color of the shape being drawn to match the underlying image.  Thanks to @andreyuhai for the PR. Closes #22.

## Image 0.14.2

This is the changelog for Image version 0.14.2 released on November 13th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug Fixes

* Fix `Image.split_bands/1`

* Fix `Image.split_alpha/1`

## Image 0.14.1

This is the changelog for Image version 0.14.1 released on November 11th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug Fixes

* Fix streaming image writes. Previously the stream chunks were being written in reverse order. Closes #19. Thanks to @loics2 for the report.

## Image 0.14.0

This is the changelog for Image version 0.14.0 released on November 11th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug Fixes

* Fixes extracting exif data when there is an exif blob but no exif tags. Closes #21.  Thanks to @feld for the report.

### Enhancements

* Add `Image.pixelate/2` and `Image.pixelate!/2`

* Add `Image.resize!/3`

## Image 0.13.1

This is the changelog for Image version 0.13.1 released on October 23rd, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug fixes

* Since a font named `Impact` isn't available on all systems, default meme generator can produce unexpected results for the rendered text.  The `Impact` font is now included in `Image` and will be used if the font name is `Impact`.

## Image 0.13.0

This is the changelog for Image version 0.13.0 released on October 23rd, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

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

This is the changelog for Image version 0.12.0 released on October 14th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Updates to support [eVision 0.1.11](https://hex.pm/packages/evision/0.1.11) which has API breaking changes. There is no change to the `Image.QRcode.decode/1` function which uses `eVision`.

## Image 0.11.0

This is the changelog for Image version 0.11.0 released on October 8th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Now uses `eVision` version `0.1` or later from [hex.pm](https://hex.pm/packages/evision)

## Image 0.10.0

This is the changelog for Image version 0.10.0 released on October 5th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug Fixes

* Since the mix build process does a `File.cwd!/1` to the directory of each dependency we can't use the dirname of the dependency to decide whether to configure `:evision` or not. The strategy is now changed to configure `:evision` only if the environment `CONFIGURE_EVISION` is set.  Note this is only relevant when developing `:image` itself.  Consumers of the library should add `:evision` as a dependency manually in their application `mix.exs` as described in the `readme`.  Thanks to @martosaur for the report.  Closes #13.

## Image 0.9.0

This is the changelog for Image version 0.9.0 released on October 1st, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* `Image.open/2` supports opening `.gif` and `.tif` images from raw binary data in addition to the previous `.jpeg`, `.png` and `.webp`.

* Add `Image.shape/1`

* Add `Image.interpretation/1`

* Add `Image.type/1`

* Add initial support for [eVision](https://github.com/cocoa-xu/evision). In this release the function `Image.QRcode.decode/1` is provided to decode images that contain a QRcode. See the `eVision` repository for installation instructions since this library is not yet on `hex.pm`.

* Removed most dialyzer warnings. The remaining warnings require an update to `Vix` (a PR has been submitted).

## Image 0.8.0

This is the changelog for Image version 0.8.0 released on September 30, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* `Image.open/2` now accepts raw image data for the image types `.jpeg`, `.png`, `.webp`

## Image 0.7.0

This is the changelog for Image version 0.7.0 released on September 30, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Set the environment variable `VIPS_BLOCK_UNTRUSTED` at application start if it is not already set. As of [libvips 8.13](https://www.libvips.org/2022/05/28/What's-new-in-8.13.html) this environment variable will cause `libvips` to not use any image loaders that are "unfuzzed".

* Add mutable draw operations. These operations mutate an image directly and hence special care is taken to avoid race conditions. All mutuable operations are serialized via a `GenServer`. See the `Image.Draw` module.  These functions are experimental for now pending additional testing.

* Add `Image.from_binary/2` to support creating an image from a raw binary.

* Thanks to @timothyvanderaerden for the PR to support getting dialyzer under control.  Work will continue on this over the next several releases.

## Image 0.6.0

This is the changelog for Image version 0.6.0 released on July 19th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Bug fixes

* Don't attempt to compile code that refers to `Plug.t` if `Plug` is not configured. Thanks to @kwando. Closes #7.

### Enhancements

* Adds `Image.dshash/1` to return a 512-bit image hash.

* Adds `Image.hamming_distance/2` to compare the similarity of two images or two image hashes.

* Adds `Image.radial_gradient/3` to great a radial gradient image. This could be used to composite over another image to add a vignette.

* Adds `Image.Math` logical functions `boolean_and/2`, `boolean_or/2`, `boolean_xor/2`, `boolean_lshift/2` and `boolean_rshift/2`. Also includes the `!` versions.

* Add operator `use Image.Math` overloads for image `&&&` (`and`), `|||` (`or`), `<<<` (`lshift`) and `>>>` (`rshift`).

## Image 0.5.0

This is the changelog for Image version 0.5.0 released on June 24th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Adds `Image.to_nx/1` to convert an image to an Nx tensor.

* Adds `Image.from_nx/1` to convert an Nx tensor into an image.

## Image 0.4.0

This is the changelog for Image version 0.4.0 released on June 23rd, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Adds support for opening streaming images. This allows images to be streamed from `File.stream!/3` or from any `t:Stream.t/0` including those created from [ExAws.S3](https://hexdocs.pm/ex_aws_s3/ExAws.S3.html) by [ExAws.stream!/2](https://hexdocs.pm/ex_aws/ExAws.html#stream!/2).

* Adds support writing streaming images. This allows images to be streamed as an enumerable which can then be consumed by `Plug.Conn.chunk/2`, by `ExAws.S3.upload/3`, `File.stream/3` or any other function that processes stream resources. See the `test/stream_image_test.exs` for examples.

* Adds a `:memory` option to `Image.write/3`. Instead of a path name or stream, use `:memory` if you'd like to return a `binary` form of an image in its formatted type. Note that this will run the image transformation pipeline resulting in the entire final image being loaded into memory. Therefore this option should be used sparingly since most use cases do not require this option. It is primarily added to facilitate passing images to other libraries in the Elixir ecosystem.

## Image 0.3.0

This is the changelog for Image version 0.3.0 released on June 4th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Add `Image.dominant_color/2` to return the dominant color of an image

* Add `Image.histogram/1` to return a histogram of an image

* Add `Image.get_pixel` to get the pixel value at a given `x` and `y` offset into an image.

## Image 0.2.0

This is the changelog for Image version 0.2.0 released on May 18th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Adds `Image.Text` to support generating an image from a string. See `Image.Text.text/2`.

* Adds `Image.Shape` to support generating images from shapes. In this release there is a generalised support for polygons and stars.  See `Image.Shape.polygon/2` and `Image.Shape.star/2`.

* Improves `Image.compose/3` to support composing with image lists, relative image placement and more.

## Image 0.1.0

This is the changelog for Image version 0.1.0 released on May 4th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Initial release
