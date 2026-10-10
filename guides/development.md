# Developing Image

This guide is for contributors working on `Image` itself. Using the library in your own project needs none of it — `libvips` ships prebuilt with `vix` and the optional dependencies are genuinely optional there.

## What you need

* **A C toolchain** — `cc` and `make`. Xcode command line tools on macOS, `build-essential` on Debian and Ubuntu.

* **Memory headroom** — the optional `exla` dependency is by far the heaviest thing in the tree and has been known to exhaust memory during compilation. See "Compiling exla runs out of memory" below.

* **ffmpeg** — only to work on `Image.Video`. The `xav` dependency binds to it, so a mismatch between the installed ffmpeg and the version `xav` expects shows up as a compilation failure.

* **minio** — only to run the streaming tests. See "The streaming tests need minio" below.

`libvips` itself is bundled by `vix`, so there is nothing to install for it. If you want to build against your own libvips, set `VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS` before fetching dependencies.

## Getting started

```bash
git clone https://github.com/elixir-image/image.git
cd image
mix deps.get
git config core.hooksPath .githooks
mix test
```

The `core.hooksPath` line is worth doing first. It enables `.githooks/pre-commit`, which runs `mix format` over staged Elixir files so that CI's formatting check has nothing to flag. Git does not enable committed hooks on clone, so each contributor sets this once per checkout.

## Optional dependencies are not optional here

Every dependency marked `optional: true` in `mix.exs` is still fetched and compiled in this repository's own `dev` and `test` environments. `optional: true` only means a *consumer* of the published package may leave it out — the test suite here exercises all of them.

That matters because large parts of the library are compiled conditionally. A module whose dependency is missing is not merely untested, it does not exist, and tests referring to it fail with `UndefinedFunctionError` rather than being skipped.

| Dependency | What it enables |
|---|---|
| `nx` | `Image.to_nx/2`, `Image.from_nx/1`, parts of `Image.Color` and `Image.BandFormat` |
| `nx`, `exla`, `scholar`, `nx_image` | `Image.Scholar`, `Image.k_means/2`, `Image.reduce_colors/2`, `Image.Palette` |
| `evision` | `Image.to_evision/1` and `Image.from_evision/1` |
| `xav` | `Image.Video` |
| `kino` | `Image.Kino` |
| `plug` | `Image.write/3` to a `Plug.Conn`, and the streaming tests |
| `req` | `Image.from_req_stream/2` |
| libvips built with FFTW | `Image.fft`, `Image.fft!` and `Image.skew_angle` |

The last row is not a mix dependency. Those three functions exist only when the libvips in use was built with FFTW, which the bundled build may not have been, so they can be undefined on your machine and defined in CI. They are written without an arity above for that reason — a documentation reference to a function that does not exist on the machine building the documentation fails the build.

## Running the tests

```bash
mix test
```

`test/test_helper.exs` excludes the `:full` tag by default, since those tests are slow. Everything else runs.

CI additionally excludes four tags that depend on fonts or codecs that are awkward to install:

```bash
mix test --exclude text --exclude text_avatar --exclude video --exclude circular_gradient
```

Run that form if a font or codec you do not have is failing tests unrelated to your change.

### The streaming tests need minio

`test/stream_image_test.exs` reads and writes through an S3-compatible endpoint, which is expected to be [minio](https://min.io) running locally. The Elixir side is `ex_aws_s3` and `hackney`, both declared `only: [:dev, :test]` in `mix.exs`, so nothing extra needs adding. The endpoint is configured in `config/test.exs`: host `127.0.0.1`, port `9000`, bucket `images`, region `local`, with credentials read from the environment.

minio ships as a single binary; see [min.io's download page](https://min.io/download) for your platform. Run it against any empty directory, and set the two credential variables first — minio uses them for its root credentials and `config/test.exs` reads the same two names, so exporting them once serves both:

```bash
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=minioadmin
minio server ~/.minio-image-dev --console-address :9001
```

Then create the bucket and seed the one object the tests read. The tests download `Hong-Kong-2015-07-1998.jpg` from the bucket, so that file has to be in it, and the copy in the repository is the one to upload. This uses the project's own `ex_aws_s3` dependency, so it needs no additional tooling:

```bash
MIX_ENV=test iex -S mix
```

```elixir
ExAws.S3.put_bucket("images", "local") |> ExAws.request()

"test/support/images/Hong-Kong-2015-07-1998.jpg"
|> ExAws.S3.Upload.stream_file()
|> ExAws.S3.upload("images", "Hong-Kong-2015-07-1998.jpg")
|> ExAws.request()
```

Doing it from `iex` avoids a trap: minio's own command line client is called `mc`, which is also the name of Midnight Commander. If you have the file manager installed, `mc` commands from minio's documentation will fail in confusing ways.

Without a running minio, the credentials exported and that object uploaded, six tests in `StreamImage.Test` fail with `Required key: :secret_access_key is nil in config!` or a connection error. Nothing else in the suite depends on them, so it is reasonable to leave them failing while you work on something unrelated — just do not read them as a regression you introduced.

## Test images

Every image the tests need is committed, so a clone is all you need and there is nothing to download.

* **`test/support/images`** — the source images tests read, around 24MB across 39 files.

* **`test/support/validate`** — the reference images that output is compared against, 88 files.

A test that compares output against a reference calls `assert_images_equal/3`, which scores the difference rather than demanding an exact match. When the score is outside tolerance it writes the image it actually produced, plus a comparison image, into `test/support/did_not_match`. That directory is gitignored, so expect files to appear there when a visual test fails and do not commit them — open them to see what changed.

Adding a fixture is fine when an existing image cannot show the behaviour. Keep it as small as the test allows, since these files live in the repository forever, and make sure its licence permits redistribution. `test/support/images/bitonal.jpg` is an example: a single band JPEG contributed by the reporter of a greyscale bug, derived from a public domain painting.

## Before opening a pull request

These are the same checks CI runs, in the order they fail fastest:

```bash
mix format
mix credo --strict
mix test
mix dialyzer
```

Documentation is also checked, and a broken reference fails the build:

```bash
MIX_ENV=release mix docs --warnings-as-errors
```

`mix docs` writes both HTML and Markdown, the latter so that coding agents and other tooling can read the documentation. Both must build cleanly.

CI runs the suite against every Elixir from 1.17 to 1.20 on each OTP release it supports. One row — the most recent Elixir on the most recent OTP — additionally runs the formatter check, Credo, Dialyzer and the documentation build. The whole matrix must pass.

## Conventions

* **Public functions document their arguments, options, returns and examples** — under `### Arguments`, `### Options`, `### Returns` and `### Examples` headings, in that order. Examples are doctests wherever the function can be called without external state.

* **A function that can fail returns `{:ok, result}` or `{:error, reason}`** — never an exception. The `!` variant raises `Image.Error`. A guard that rejects bad input without a matching fall-through clause turns invalid input into a `FunctionClauseError`, which is a defect.

* **Errors are an `Image.Error` with an atom `:reason`** — so callers can match on the reason rather than scraping the message. Anything parameterising the error goes in `:value`. A binary `:reason` means a libvips message with no structured form yet.

* **Changelog entries are at most two sentences** — naming the function, what changed and the migration, with the detail left to the documentation and the diff.

## Troubleshooting

### Compiling exla runs out of memory

A `Killed` or `zsh: killed` message while `exla` compiles is the operating system's out-of-memory killer, not a build error. The prebuilt XLA archive is downloaded rather than compiled, so the memory goes on `exla`'s own Elixir compilation.

Compiling it alone, rather than alongside everything else, reduces the peak:

```bash
mix deps.compile exla
mix deps.compile
```

`exla` is needed for the full suite because `config/test.exs` sets `EXLA.Backend` as the default `Nx` backend. If it will not build on your machine you can still work on anything unrelated to the machine-learning features by running a subset of the suite, but `mix test` as a whole will not pass.

### xav fails to compile

`xav` binds to the ffmpeg installed on your machine, and ffmpeg removes and renames symbols between major versions. A failure naming an undeclared identifier, such as `FF_PROFILE_UNKNOWN`, means the installed ffmpeg is newer than the `xav` version in `mix.lock` expects.

`xav` is optional and only `Image.Video` needs it, so `mix compile --no-deps-check` will get you a working build while it is broken. Updating `xav` is the real fix.

### A function is undefined that the documentation describes

The dependency that gates it is missing, or the bundled libvips lacks a feature it needs. Check the table above, then `mix deps.get`.
