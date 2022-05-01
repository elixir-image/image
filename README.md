# Image

`Image` is an image processing library for Elixir. It is based upon the fabulous [vix](https://hex.pm/packages/vix) library that provides a [libvips](https://www.libvips.org) wrapper for Elixir.

`Image` is intended to provide well-documented common image processing functions in an idiomatic Elixir functional style as a layer above the very comprehensive set of functions in `Vix`.

In a very simple image resizing benchmark, `Image` is approximately 2 to 3 times faster than `Mogrify` and uses about 5 times less memory. 

## Installation

`Image` can be installed by adding `image` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:image, "~> 0.1.0"}
  ]
end
```

The documentation can be found at [https://hexdocs.pm/image](https://hexdocs.pm/image).

### Installation Dependencies

Installing `Vix` requires `libvips` with development headers. Installation is platform dependent however the common platform installations are:

macOS: Install using [homebrew](https://brew.sh) with `brew install libvips`
Linux: Install with `apt install libvips-dev`

For more details see https://www.libvips.org/install.html

In addition the following will be required (and would normally be installed in the steps above):

* pkg-config
* A `c` compiler

### Configurration

#### Vix NIF Error Logging

`Vix` NIF code writes logs to stderr on certain errors. This is disabled by default. To enable logging set `VIX_LOG_ERROR` environment variable to `true`.

#### GLib Debug Output

The platform upon which `Image` and `Vix` stand is [libvips](https://www.libvips.org), a `C` library that actually performs the image manipulation. Its `libvips` that delivers the speed, memory efficiency and functionality.

`libvips` uses the [GLib](https://docs.gtk.org/glib/) library which has configurable debug output. This output depends on the setting of the environment variable `G_DEBUG`.  The initial value will depend on the installation method of `libvips` for a given system. It can be changed by setting the `G_DEBUG` environment variable to one of the following:

* **fatal-warnings** which causes GLib to abort the operation at the first call to g_warning() or g_critical().

* **fatal-criticals** causes GLib to abort the operation at the first call to g_critical().

* **gc-friendly** causes newly allocated memory that isn't directly initialized, as well as memory being freed to be reset to 0. The point here is to allow memory checkers and similar programs that use Boehm GC alike algorithms to produce more accurate results.

* **resident-modules** causes all modules loaded by GModule will be made resident. This can be useful for tracking memory leaks in modules which are later unloaded; but it can also hide bugs where code is accessed after the module would have normally been unloaded.

* **bind-now-modules** causes all modules loaded by GModule to bind their symbols at load time, even when the code uses %G_MODULE_BIND_LAZY.

To produce debug output for only the most critical issues, set `G_DEBUG` as follows (in bash and compatible shells):

```bash
export G_DEBUG=fatal-criticals
```

#### Memory Leak Detection

The environment variable `VIPS_LEAK` determines whether `libvips` reports possible memory leaks. To enable leak detection (on `bash` compatible systems):
```bash
export VIPS_LEAK=true
```

To stop leak detection:
```bash
unset VIPS_LEAK
```

#### Concurrency

`Image` (because of `Vix` and `libvips`) will execute concurrent image operations using a number of system native threads (not BEAM processes). The number of threads available for concurrent image operations is configurable by either setting the environment variable `VIPS_CONCURRENCY` or through a call to `Image.put_concurrency/1`.  The current number of configured threads is returned from `Image.get_concurrency/0`.

The default number of threads is equal to the number of cores detected on the running system. This may create CPU contention with other workloads given that image processing is CPU intensive.  Therefore it may be prudent to reduce the number of threads if overall system throughput is being affected.

#### Caching

### Security Cosiderations

* There are [638](https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=imagemagick) CVEs reporting for Imagemagick and only [8](https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=libvips) CVE's reported for `libvips`



