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
