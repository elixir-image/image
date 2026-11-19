# Squircle

**Status:** implemented (v0.74.0), 2026-11-20

`Image.squircle/2`, and `Image.avatar/2` with `shape: :squircle`, now draw superellipse corners joined by straight edges. This document records why the old construction was replaced and why this one was chosen, measured against Raph Levien's survey [Squircles](https://linebender.org/wiki/curves/squircle/) on the Linebender wiki.

## The problem

The old mask was one cubic Bézier per quadrant, running from the midpoint of one edge to the midpoint of the next, with both control points on the box edges `:radius` pixels from the corner (default 20). It matched none of the constructions the article describes, and it had four defects:

* **The shape depended on the image size.** `:radius` was an absolute distance to the control points, not a corner radius, so the same option drew a different shape at each size. Measured by the article's *gauge* (where the outline crosses the diagonal of a unit quadrant, 0.5^(1/n) for a superellipse of exponent n), a 180-pixel avatar was close to n = 3 by coincidence, a 96-pixel one was almost a circle, and a 64-pixel one was rounder than a circle.

* **Small images were malformed.** Once the radius passed half the side (below 40 pixels at the default), the control points lay beyond the curve's own end points and the outline doubled back into a spiked diamond. The 30-pixel doctest drew exactly that.

* **There were no straight sides.** The outline touched the box only at the four edge midpoints, so the long sides of a wide image bowed outwards. The article favours flat-sided squircles because they fit any aspect ratio.

* **Errors raised.** Both the mask and `squircle/2` matched `{:ok, _}` on their results.

## Options

The article compares these constructions:

* **The Lamé superellipse** — `|x|ⁿ + |y|ⁿ = 1` over the whole shape. Smooth to order ⌈n⌉ − 1 with zero curvature where it meets the axes, but it has no straight sides, so it distorts on non-square shapes.

* **Apple's iOS 7 icon shape and Figma's corner smoothing** — three cubic Béziers per corner. Apple's matches a gauge of 0.809; Figma's middle segment is close to a circular arc and the join to it is only G1.

* **Clothoid corners** — curvature rising linearly from the straight edge. G2, but needs a numerical construction.

* **Flat-sided superellipse corners** — a superellipse quadrant scaled to a corner radius, joined by straight edges. This is what CSS `corner-shape: superellipse(k)` specifies, with k = log₂ n, and Chromium draws each corner with two cubic Béziers that are exact at the corner's midpoint. The article presents n = 3 with a radius of 46.2% of the side (`border-radius: 46.2%; corner-shape: superellipse(1.585)`) as the closest match to the Apple shape.

## Decision

Flat-sided superellipse corners, with the article's Apple-matching defaults.

* **`:radius`** is the corner radius in pixels, where the curve meets the straight edge. The default is 46.2% of the shorter side, so the default shape is the same at every size. A radius larger than half the shorter side is reduced to it.

* **`:exponent`** is the corner's superellipse exponent, default 3. An exponent of 2 is a circular arc, the same corner as `Image.rounded/2`.

* **The curve is traced, not approximated.** Chromium needs Bézier curves because it draws vectors at any scale. `Image` rasterises the mask once at the image's size, so each corner is traced as a polygon of up to one point per pixel of radius (at least 8, at most 512), which is exact well below a pixel, and librsvg anti-aliases it.

* **Invalid options return `{:error, %Image.Error{reason: :invalid_option}}`.**

A superellipse corner with n > 2 joins the straight edge with zero curvature, so the outline is G2 everywhere, the continuity the article treats as necessary for a shape to look smooth.

## Compatibility

`:radius` changed meaning, from the control-point distance to the corner radius, so a caller passing it gets a squarer shape than before at the same value. A caller that relied on the default gets nearly the same shape at 180 pixels, the default avatar size (gauge 0.81 rather than 0.79), and a correct one at every other size.

## Tasks

### Done

* [x] **Flat-sided superellipse squircle** — `Image.squircle/2` traces superellipse corners joined by straight edges, with `:radius` and `:exponent`; the measured gauge is 0.80 to 0.82 from 30 to 512 pixels, against the Apple shape's 0.809. 2026-11-20, v0.74.0.
