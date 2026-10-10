# Performance

Notes on the performance characteristics of selected `Image` operations.

## Dominant colors: `:histogram` vs `:imagequant`

`Image.dominant_color/2` supports two methods:

* `:histogram` (default) — a coarse 3D RGB histogram via `vips_hist_find_ndim`. Returns the centres of the most populated bins.

* `:imagequant` — routes through `vips_gifsave_buffer` so that libvips runs libimagequant and writes a quantised Global Color Table. The GCT is parsed back into a list of RGB tuples ordered by perceptual importance.

### `Kip_small.png` (300×328×3)

Warm timings, 20 iterations each, macOS arm64.

| `top_n` | `:histogram` | `:imagequant` | ratio |
| ------- | ------------ | ------------- | ----- |
| 1       | 0.09 ms      | 3.00 ms       | ~33×  |
| 8       | 0.16 ms      | 3.82 ms       | ~24×  |
| 16      | 0.13 ms      | 4.70 ms       | ~36×  |

Imagequant effort sweep (`top_n: 8`):

| `:effort` | time    |
| --------- | ------- |
| 1         | 2.95 ms |
| 3         | 2.95 ms |
| 5         | 3.89 ms |
| 7         | 3.98 ms |
| 10        | 4.15 ms |

Sample output (`top_n: 5`):

```
histogram : [[40, 40, 40], [56, 56, 56], [8, 8, 8], [184, 184, 184], [168, 168, 168]]
imagequant: [{195, 195, 195}, {125, 125, 125}, {91, 91, 91}, {153, 153, 153}, {176, 176, 176}]
```

### `Singapore-2016-09-5887.jpg` (1000×590×3)

Warm timings, 20 iterations each, macOS arm64.

| `top_n` | `:histogram` | `:imagequant` | ratio  |
| ------- | ------------ | ------------- | ------ |
| 1       | 0.09 ms      | 55.29 ms      | ~614×  |
| 8       | 0.13 ms      | 145.79 ms     | ~1120× |
| 16      | 0.13 ms      | 156.01 ms     | ~1200× |

Imagequant effort sweep (`top_n: 8`):

| `:effort` | time      |
| --------- | --------- |
| 1         | 29.80 ms  |
| 3         | 29.92 ms  |
| 5         | 63.39 ms  |
| 7         | 147.57 ms |
| 10        | 210.41 ms |

Sample output (`top_n: 5`):

```
histogram : [[8, 24, 40], [8, 40, 56], [24, 104, 168], [40, 104, 168], [40, 120, 184]]
imagequant: [{224, 213, 207}, {187, 154, 121}, {136, 151, 178}, {106, 98, 93}, {63, 122, 180}]
```

### Takeaways

* `:histogram` is two to three orders of magnitude faster than `:imagequant`. Its cost is dominated by a single pass over the pixels plus a small sort, and it barely scales with `:top_n`.

* `:histogram` also scales well with image size. On the 300×328 PNG and the 1000×590 JPEG the histogram time is essentially unchanged (~0.1 ms), because `hist_find_ndim` is cheap relative to libvips' per-call overhead.

* `:imagequant` has a fixed cost plus a component that scales with both pixel count and palette size. On the small PNG the fixed libvips/GIF-encode overhead (~3 ms) dominates. On the larger JPEG the quantise itself dominates: 55 ms for a 2-color palette rising to 156 ms for 16 colors.

* `:effort` is a strong lever on the quantise itself. On the Singapore image, dropping from the default `effort: 7` to `effort: 3` cuts runtime by ~5× (148 ms → 30 ms) with only a small perceived quality loss. Effort 1 and 3 are indistinguishable in timing; effort 5 is about halfway; 10 roughly doubles effort 7.

* Output quality differs in character. `:histogram` quantises to the centres of a fixed 3D grid (visible as the `[8, 24, 40]`, `[24, 104, 168]`, ... clustering), which is good enough for "what is the overall dominant color" questions. `:imagequant` returns perceptually representative colors suitable for building palettes, swatches, or UI accents from photographic input.

* Rule of thumb: keep `:histogram` as the default for hot paths or bulk processing. Reach for `:imagequant` when palette quality matters more than latency, and consider `effort: 3` if you want most of the quality benefit at a fraction of the CPU cost.

## Pipeline depth

`Image` functions build a libvips pipeline that is evaluated lazily, when pixels are finally needed. Evaluation walks that pipeline recursively, one stack frame or more per node, on a thread whose stack is fixed when the VM starts. A long enough chain of pending operations exhausts that stack and the whole VM dies — not an Elixir exception, a `SIGBUS` or `SIGSEGV` with no stack trace.

This is a limitation of evaluating a deep pipeline inside the BEAM rather than a defect in `Image`, `vix` or libvips. The same chain in `pyvips` survives, because a Python main thread has a far larger stack than the threads libvips is evaluated on here.

Almost no pipeline gets near it. It shows up in code that accumulates operations in a loop — compositing hundreds of tiles onto a canvas is the usual example:

```elixir
# Chains one pending composite per tile, and never evaluates until the end
Enum.reduce(tiles, canvas, fn {tile, x, y}, canvas ->
  Image.compose!(canvas, tile, x: x, y: y)
end)
```

`Image.copy_memory/1` ends the chain. It evaluates what is pending and returns a memory-resident image, so the next operation starts from a leaf rather than extending the pipeline:

```elixir
tiles
|> Enum.chunk_every(32)
|> Enum.reduce(canvas, fn chunk, canvas ->
  chunk
  |> Enum.reduce(canvas, fn {tile, x, y}, acc -> Image.compose!(acc, tile, x: x, y: y) end)
  |> Image.copy_memory!()
end)
```

### What the limit measures as

Chaining `composite2` operations over a 256x256 canvas, five runs per data point, on an M-series Mac with the bundled libvips:

| Pending operations | Runs that crashed |
|---|---|
| 100 | 0 of 5 |
| 150 | 0 of 5 |
| 200 | 4 of 5 |
| 400 and above | 5 of 5 |

Flattening a 1600-operation chain at intervals, again five runs each:

| Flattened every | Runs that crashed |
|---|---|
| 32 | 0 of 5 |
| 40 | 0 of 5 |
| 48 | 0 of 5 |
| 64 | 5 of 5 |

Two things to take from the second table. Flattening works, and the interval matters more than the depth numbers in the first table suggest — a chain of 64 is well inside the depth that survives on its own, yet flattening every 64 across 1600 operations failed every time. Repeated evaluation is harder on the stack than a single evaluation of the same depth, and the reason is not fully characterised.

The limit is also probabilistic rather than a clean cliff: 200 operations crashed four times in five, not five. Expect the exact numbers to differ with the platform, the libvips build, the operations in the chain and the image size.

### Recommendation

* **Flatten every 25 to 50 pending operations** with `Image.copy_memory/1` in any loop that accumulates them. That is comfortably inside what measured safe and leaves room for platform variation.

* **Do not flatten a pipeline that is consumed once.** Materialising an image is the one thing that defeats libvips' streaming, and it costs the full memory of the image. This is for accumulating loops, not for ordinary pipelines.

* **Treat a crash with no stack trace in image-heavy code as this first.** A `SIGBUS` or `SIGSEGV` that moves around between runs, in code that composites or chains many operations, is this rather than a corrupted image.

### Tuning the BEAM

Of the Erlang stack options, only `+sssdcpu`, the dirty CPU scheduler stack size in kilowords, makes a measurable difference — `vix` runs libvips operations on dirty CPU schedulers:

```bash
ERL_FLAGS="+sssdcpu 4096" mix run my_script.exs
```

At 200 pending operations that took the failure rate from four runs in five to zero in five. `+sssdio` and `+sss` made no difference, and neither did `VIPS_CONCURRENCY`.

It is not a substitute for flattening. Raising it further did not rescue a chain of 400 or more even at `+sssdcpu 16384`, which suggests that past some depth the recursion is happening on libvips' own worker threads, whose stacks the BEAM does not control. Use it to widen the margin, not to avoid flattening.
