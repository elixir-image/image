# Image

An Image processing library for Elixir. Based upon the fabulous [vix](https://hex.pm/packages/vix) library that provides a [libvips](https://www.libvips.org) wrapper for Elixir.

The library is in very early development but is intended to bring the power of `libvips` with an idiomatic Elixir interface to developers. `libvips` pipeline architecture and low memory footprint makes it a very solid foundation for image processing in Elixir.

Currently `Image` supports:

* Opening image files in the local file system
* Math operators (`+`, `-`, `/`, `*`, `**`) and functions (`cos`) for images and scalars/integers
* Circular crop of an impage
* Rounded corner crop of an image
* Linear gradience overlay of an image
* Extraction of [exif](https://en.wikipedia.org/wiki/Exif) data to an Elixir map
* Extraction of limited [XMP](https://www.adobe.com/products/xmp.html) data

### Roadmap

It is the intention of `Image` to bring the power of `libvips` to Elixir developers in an idiomatic API that can support:

* Image transformation (flip, resize, ...)
* Image convolution (sharpen, ...)
* Image metadata access and update
* Image optimization for web and other application usage
* Bidirectional integration with [Nx](https://hex.pm/packages/nx) to integrate ML and GPU processing with image transformation

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

