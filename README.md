# Image Install & Configure

`Image` is an image processing library for Elixir. It is based upon the fabulous [vix](https://hex.pm/packages/vix) library that provides a [libvips](https://www.libvips.org) wrapper for Elixir.

`Image` is intended to provide well-documented common image processing functions in an idiomatic Elixir functional style as a layer above the very comprehensive set of functions in `Vix` and `libvips`.

As of version 0.18.0, `Image` provides optional integration with [Bumblebee](https://hex.pm/packages/bumblebee) allowing machine learning models to be deployed as part of an image processing pipeline.

`Image` is also intended to be an idiomatic API layer over [eVision (OpenCV)](https://github.com/cocoa-xu/evision). As of `Image verison 0.9.0`, the `Image.QRcode.decode/1` function is provided to decode QRcodes with the functionality to do so provided by `eVision`. The `eVision` integration is optional and currently considered experimental.

In a very simple image resizing [benchmark](https://github.com/elixir-image/image/blob/main/bench/vips_v_mogrify.exs), `Image` is approximately 2 to 3 times faster than `Mogrify` and uses about 5 times less memory.

The documentation can be found at [https://hexdocs.pm/image](https://hexdocs.pm/image).

## Installation

`Image` can be installed by adding `image` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:image, "~> 0.37"}
  ]
end
```

### Installing Libvips

Starting from v0.16.0 [Vix](https://hex.pm/packages/vix) which underpins `Image` can use either pre-built binaries or platform provided binaries.

By default `Vix` provides pre-built NIF and `libvips` and uses them for operation. This makes deployment and release of your application a breeze. With this you don't have to install any compiler tools or `libvips` to use `Vix`. This is especially useful when using `Image` with [Livebook](https://livebook.dev).

However, the pre-built NIF and pre-built libvips do not include dependencies that support all image formats and operations. If you require those formats or operations then you can bring your own `libvips` by installing it manually and configure `Vix` to use that instead. `Vix` makes sure to generate relevant functions and documentation based on the dependencies you bring. For example, if you install libvips with `tiff` support, vix will generate `tiff` related bindings for you.

You can choose this using `VIX_COMPILATION_MODE` environment variable. This variable must be set both during compilation and runtime. Possible values are:

* `PRECOMPILED_NIF_AND_LIBVIPS` (Default): Uses vix provided NIF and libvips. No need to install any additional dependencies. Big thanks to sharp library maintainers, pre-compiled libvips is based on: https://github.com/lovell/sharp-libvips/.

* `PLATFORM_PROVIDED_LIBVIPS`: Uses platform provided libvips and NIF will be compiled during the compilation phase. The following build tools are required generate the `Vix` NIF:
  * Install a platform specific `libvips`. This can be compiled from source (see https://www.libvips.org/install.html) or via a platform package manager. For example:
    * macOS: `brew install libvips`
    * Linux: `apt install libvips-dev`
  * Install `pkg-config`
  * Ensure a supported C compiler is installed

### Installing Nx

[Nx](https://hex.pm/packages/nx) provides multi-dimensional arrays (tensors) and numerical definitions for Elixir. These tensors can also be used as an interchange format for binary image data. When `Nx` is installed and `Image` is compiled, the functions `Image.to_nx/2` and `Image.from_nx/1` are defined.

`Nx` is required in order to support the functions in `Image.Classification`. It is also required to support [eVision](https://hex.pm/packages/evision) and [Bumblebee](https://hex.pm/packages/bumblebee) integrations.

1. Add `Nx` to your `mix.exs`:

    ```elixir
    def deps do
      [
        # ...
        {:nx, "~> 0.4"}
      ]
    end
    ```

2. Add a default `Nx` backend to `config.exs`.

    `Nx` supports a variety of backends that provide CPU and GPU acceleration. The CPU backend that provides the widest platform compatibility is `EXLA.Backend`.

    ```elixir
    config :nx, default_backend: EXLA.Backend
    ```

3. Get dependencies:

    ```elixir
    mix deps.get
    ```

### Installing Bumblebee

[Bumblebee](https://hex.pm/packages/bumblebee) provides pre-trained and transformer Neural Network models in Axon that can be used for a variety of image classification, segmentation and detection operations. When `Bumblebee` is configured, the functions in `Image.Classification` become available.

1. Add `Bumblebee` and `exla` to your `mix.exs`.

    `exla` is required in order to provide CPU or GPU acceleration for the models so as to deliver acceptable performance. `Nx` will be installed as a transitory dependency.

    ```elixir
    def deps do
      [
        # ...
        {:bumblebee, "~> 0.1"},
        {:exla, "~> 0.4"}
      ]
    end
    ```

2. Add a default Nx backend to `config.exs`.

    `Nx` supports a variety of backends that provide CPU and GPU acceleration. The CPU backend that provides the widest platform compatibility is `EXLA.Backend`.

    ```elixir
    config :nx, default_backend: EXLA.Backend
    ```

3. Get dependencies:

    ```elixir
    mix deps.get
    ```

### Installing eVision

[eVision (OpenCV)](https://github.com/cocoa-xu/evision) provides Elixir bindings to [OpenCV](https://opencv.org), the most well-known computer vision library.

As of [Image version 0.9.0](https://hex,pm/packages/image/0.9.0), experimental support for [eVision (OpenCV)](https://github.com/cocoa-xu/evision) is provided. There is extensive documentation on how to install `eVision` and the required [OpenCV](https://opencv.org). However in most cases, the following should be enough:

1. Add `eVision` to your `mix.exs`. [exla](https://hex.pm/packages/exla) may be optionally configured too, see the `Nx` installation section above.

    ```elixir
    def deps do
      [
        # ...
        {:evision, "~> 0.1"}
      ]
    end
    ```

2. Get dependencies:

    ```elixir
    mix deps.get
    ```

Then proceed as normal. `eVision` will download a precompiled `OpenCV` for the appropriate system architecture and compile both the NIF and Elixir code.

## Configuring Libvips

`Vix` and `libvips` offer various configuration parameters that affect debug output, image caching, concurrency of imaging operations and memory leak detection. Each of these options has reasonable defaults so no action is required in order to start using the library.

### Vix NIF Error Logging

`Vix` NIF code writes logs to stderr on certain errors. This is disabled by default. To enable logging set the `VIX_LOG_ERROR` environment variable to `true`.

### GLib Debug Output

The platform upon which `Image` and `Vix` stand is [libvips](https://www.libvips.org), a `C` library that performs the image manipulation. It's `libvips` that delivers the speed, memory efficiency, and functionality.

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

### Memory Leak Detection

The environment variable `VIPS_LEAK` determines whether `libvips` reports possible memory leaks. To enable leak detection (on `bash` compatible systems):
```bash
export VIPS_LEAK=true
```

To stop leak detection:
```bash
unset VIPS_LEAK
```

### Concurrency

`Image` (because of `Vix` and `libvips`) will execute concurrent image operations using a number of system native threads (not BEAM processes). The number of threads available for concurrent image operations is configurable by either setting the environment variable `VIPS_CONCURRENCY` or through a call to `Image.put_concurrency/1`.  The current number of configured threads is returned from `Image.get_concurrency/0`.

The default number of threads is equal to the number of cores detected on the running system. This may create CPU contention with other workloads given that image processing is CPU intensive.  Therefore it may be prudent to reduce the number of threads if overall system throughput is being affected.

### Fontconfig Debug Output

Text image generation uses fonts installed and managed by [fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/). Debug information output is controlled by the [FC_DEBUG](https://www.freedesktop.org/software/fontconfig/fontconfig-user.html) environment variable.

## Library packaging future

In a future release, `:image` will be split into several packages

* `:image` which will retain all the core components of image transformation based upon `vix` and `libvips`.
* `:image_nx` which will provide `:nx` interoperability (and will depend on `:image`)
* `:image_exif` which will provide metadata support (and will depend on `:image`)
* `:image_classification` which will provide image classification (and will depend on `:image` and `:bumblebee`)
* `:image_generation` which will provide image generation (and will depend on `:image` and `:bumblebee`)
* `:image_detection` which will provide object detection (and will depend on `:image`, `:axon`, `:axon_onnx`)
* `:image_qrcode` which will provide QRcode scanning and production (and will depend on`:image` and `:evision`)
* `:image_video` which will provide video frame extraction (and will depend on`:image` and `:evision`)

## Security Considerations

There are several considerations in the use of any image processing library and any NIF-based library:

1. If a NIF crashes it will likely bring down the BEAM virtual machine. `libvips` is a robust, time-tested library however this risk cannot be eliminated.

2. Image processing is CPU intensive with its concurrent pipelining model and default concurrency level equal to the number of cores in the host machine, CPU starvation for other parts of the application is a possibility. In such cases, reducing the `libvips` concurrency is recommended.

3. Image processing by its nature operates on external data and there have been exploits based upon maliciously crafted images. The two primary vectors are:
    * An invalid image format that causes the image parser to crash and therefore crash the NIF and the BEAM
    * Executable code embedded in image metadata (such as EXIF data) that if passed un-escaped to a web browser may result in arbitrary code execution.

In comparison to `Imagemagick` that has a reported [638](https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=imagemagick) CVEs, there have been only  [8](https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=libvips) CVE's reported for `libvips`, each resolved in a very timely manner.

