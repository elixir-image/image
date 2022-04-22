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

* [ ] Streaming images
* [ ] Thumbnail an image
* [x] Resize
* [x] Crop
* [ ] Create avatar from image
* [ ] Remove metadata from image
* [ ] Add minimal metadata to image (artist, title, description, copyright, keywords)
* [ ] Bidirectional integration with [Nx](https://hex.pm/packages/nx) to integrate ML and GPU processing with image transformation

### GLib Debug Output

At the bottom of the stack, `libvips` is a `C` library that actually performs the image manipulation and thats what provides the speed, memory efficiency and functionality. `libvips` used the [GLib](https://docs.gtk.org/glib/) library which has configurable debug output. This output depends on the setting of the environment variable `G_DEBUG`.  The initial value will depend on the installation method of `libvips` for a given system. It can be changed by setting the `G_DEBUG` environment variable to one of the following:

fatal-warnings
  Causes GLib to abort the program at the first call to g_warning() or g_critical().

fatal-criticals
  Causes GLib to abort the program at the first call to g_critical().

gc-friendly
  Newly allocated memory that isn't directly initialized, as well as
  memory being freed will be reset to 0. The point here is to allow memory
  checkers and similar programs that use Boehm GC alike algorithms to produce
  more accurate results.

resident-modules
  All modules loaded by GModule will be made resident. This can be
  useful for tracking memory leaks in modules which are later unloaded;
  but it can also hide bugs where code is accessed after the module would
  have normally been unloaded.

bind-now-modules
  All modules loaded by GModule will bind their symbols at load time,
  even when the code uses %G_MODULE_BIND_LAZY.

For example, to produce debug output for only the most critical issues, set `G_DEBUG` as follows (in bash and compatible shells):

```bash
export G_DEBUG=fatal-criticals
````

### Memory Leak Detection

The environment variable `VIPS_LEAK` determines whether `libvips` reports possible memory leaks. To enable leak detection (on `bash` compatible systems):
```bash
export VIPS_LEAK=true
```
To stop leak detection:
```bash
unset VIPS_LEAK
````

### Concurrency

`Image` (because of `Vix` and `libvips`) will execute concurrent image operations using a number of system native threads (not BEAM processes). The number of threads available for concurrent image operations is configurable by either setting the environment variable `VIPS_CONCURRENCY` or through a call to `Image.put_concurrency/1`.  The current number of configured threads is returned from `Image.get_concurrency/0`.

The default number of threads is equal to the number of cores detected on the running system. This may create CPU contention with other workloads given that image processing is CPU intensive.  Therefore it may be prudent to reduce the number of threads if overall system throughput is being affected.

### Caching

## Installation

When [available in Hex](https://hex.pm/packages/image), `Image` can be installed
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

