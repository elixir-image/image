# Changelog

## Image 0.6.0

This is the changelog for Image version 0.6.0 released on June 5th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/image/tags)

### Enhancements

* Adds `Image.dshash/1` to return a 512-bit image hash.

* Adds `Image.hamming_distance/2` to compare the similarity of two images or two image hashes.

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
