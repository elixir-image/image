# Image

An Image processing library for Elixir. Based upon the fabulous [vix](https://hex.pm/packages/vix) library that provides a [libvips](https://www.libvips.org) wrapper for Elixir.

The library is in very early development but is intended to bring the power of `libvips` with an idiomatic Elixir interface to developers. `libvips`'s high performance, pipeline architecture and low memory footprint makes it a very solid foundation for image processing in Elixir.

In a very simple image resizing benchmark, `Image` is approximately 2 to 3 times faster than `Mogrify` and uses about 5 times less memory. More thorough benchmarking will be done later in the development cycle. See the `bench` directory.

Currently `Image` supports:

### Currently supported

* [*] Math operators (`+`, `-`, `/`, `*`, `**`) and functions (`cos`, `sin`) for images and scalars/integers
* [*] Flip
* [*] Rotate
* [*] Ripple filter
* [*] Circular crop filter
* [*] Rounded corners filter
* [*] Extract [exif](https://en.wikipedia.org/wiki/Exif) and [XMP](https://www.adobe.com/products/xmp.html) (limited) into a map
* [*] Linear gradient filter (one direction only)

### Roadmap

It is the intention of `Image` to bring the power of `libvips` to Elixir developers in an idiomatic API that can support:

* [ ] Streaming image support
* [ ] Thumbnail an image
* [x] Resize
* [ ] Crop
* [ ] Create avatar from image
* [ ] Remove metadata from image
* [ ] Add minimal metadata to image (artist, title, description, copyright, keywords)
* [ ] Bidirectional integration with [Nx](https://hex.pm/packages/nx) to integrate ML and GPU processing with image transformation

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `image` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:image, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/image](https://hexdocs.pm/image).

