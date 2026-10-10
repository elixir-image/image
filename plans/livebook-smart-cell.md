# Livebook smart cell

**Status:** in progress, 2026-10-10

Addresses [#31](https://github.com/elixir-image/image/issues/31), which asks for an imaging playground in Livebook for experimenting with transformations, citing eVision's smart cells as the precedent.

## The shape of it

A single smart cell, `Image.SmartCell.Transform`, that composes a pipeline. The user picks a source image, adds operations to a list, adjusts their parameters, and sees both a live preview and the `Image` code that produces it. Converting the cell to a plain Elixir cell leaves working, readable source behind.

One cell rather than one per operation. eVision ships a cell per ML algorithm because each is a separate task; here the point is chaining, so a single composing cell is the useful shape.

## The central design decision

**The operation catalogue lives in Elixir and the JavaScript renders it generically.** The Elixir side holds a specification for each operation — its label, its parameters, each parameter's type, range and default — and sends that catalogue to the client on `handle_connect/1`. The client has no knowledge of any particular operation; it renders whatever specification it is given.

```elixir
%{
  name: :blur,
  label: "Blur",
  doc: "Gaussian blur",
  params: [
    %{key: :sigma, label: "Sigma", type: :range, min: 0.1, max: 20.0, step: 0.1, default: 1.5}
  ]
}
```

The payoff is that adding, removing or re-tuning an operation afterwards is an Elixir-only change. Nobody has to touch JavaScript to extend the cell, which matters for long-term maintenance by someone who would rather not.

Parameter types needed by the first operation set: `:range`, `:number`, `:select`, `:text`, `:colour`, `:boolean`. Each maps to one widget in the client, and that mapping is the only operation-aware code in the JavaScript.

## The kino requirement

No change is needed. `mix.exs` already declares `{:kino, "~> 0.13", optional: true}`, and eVision — a working smart cell implementation — declares only `~> 0.11` for the same API surface. kino's changelog shows one `SmartCell` breaking change since, in v0.13.0, and it concerns the cell *editor*, which this design does not use. `scan_binding/3` is not a recent addition either.

The dependency stays optional, since it serves only Livebook.

## Structure

Following eVision, which is the closest precedent and sits in the dependency tree to read:

```elixir
use Kino.JS, assets_path: "lib/assets"
use Kino.JS.Live
use Kino.SmartCell, name: "Image: transform"
```

The callbacks are `init/2`, `handle_connect/1`, `handle_event/3`, `to_attrs/1` and `to_source/1`.

* **Registration** goes in `Image.Application.start/2`, guarded by `Code.ensure_loaded?(Kino.SmartCell)`, as eVision does from its own application module.

* **Compiling without kino** follows eVision's pattern of wrapping the module in `if !Code.ensure_loaded?(Kino.SmartCell) do ... else ... end`, so the module name resolves but is empty.

* **Assets** live in `lib/assets/` and ship without a change to `mix.exs`, because `package.files` already includes `"lib"`.

* **State** is canonical in Elixir. The client pushes an intent, the server updates `ctx.assigns`, then broadcasts the new state back; the client never holds authoritative state. That keeps the generated source and the preview in step with what the form shows.

## Source generation

`to_source/1` builds the pipeline with `quote` and renders it with `Kino.SmartCell.quoted_to_string/1`, the same way eVision's cells do. The target is code a person would recognise as their own:

```elixir
image
|> Image.thumbnail!(400, crop: :attention)
|> Image.blur!(sigma: 2.5)
|> Image.rounded!()
```

Generated code uses the `!` variants, because a pipeline of them is what reads well and what the guides show. That is in tension with the library's own convention that fallible code returns tuples, so this is explicitly playground output; worth revisiting if people start pasting it into production.

A test should assert the generated string for a known set of attributes, since that string is the cell's real contract.

## Source image

Three ways in, offered as a selector:

* **A variable already in the notebook** — `scan_binding/3` discovers variables bound to a `t:Vix.Vips.Image.t/0` and offers them by name.

* **A path** — a text input, resolved at evaluation.

* **An upload** — `Kino.Input.image/2` exists, but a smart cell cannot embed a `Kino.Input`, so this needs a file field in the cell's own UI and the bytes handed over as an attribute. Lowest priority of the three.

## Operations for a first version

Visual, few parameters, and already well covered by tests:

| Operation | Parameters |
|---|---|
| `thumbnail` | length, `:crop`, `:fit` |
| `resize` | scale |
| `crop` | left, top, width, height |
| `rotate`, `flip`, `flop` | angle for rotate |
| `blur`, `sharpen` | sigma |
| `brightness`, `saturation`, `gamma`, `sepia` | one factor each |
| `to_colorspace` | target interpretation |
| `rounded`, `squircle`, `avatar` | radius or size |
| `drop_shadow` | sigma, opacity, colour |
| `Image.Text.text` | string, font size, colour |

## Preview

`Image.Kino.show/2` already renders an image and takes `:max_height`, so it covers the rendering. The risk is responsiveness: every parameter change re-evaluates the whole pipeline over the full-size source.

Mitigation is to thumbnail the source once, cache it, and preview against that, evaluating the real pipeline only when the cell is evaluated. The preview then becomes an approximation, which needs saying in the UI for operations whose result depends on resolution.

An operation returning `{:error, reason}` renders the reason in place of the image rather than raising, so a bad parameter does not kill the cell.

## Open questions

* **Reordering.** Drag and drop is nicer and more work; up and down buttons are simpler, keyboard accessible, and enough to be useful. Start with buttons.

* **Should the operation catalogue be public?** If `Image.SmartCell` exposes it, other tooling could drive the same specifications. Speculative until something wants it.

## Tasks

### In progress

* [ ] **Try it in a Livebook** — the client has not been run. Everything on the Elixir side is tested, but `lib/assets/main.js` needs a notebook to exercise, and that is the one thing a test here cannot do.

* [ ] **Preview caching** — thumbnail the source once and preview against it, with a note in the UI where the approximation matters.

* [ ] **A livebook demonstrating it** — added to `extras` alongside the existing two, so the feature is discoverable from the documentation.

### Done

* [x] **Confirm the kino floor** — no change required; `~> 0.13, optional: true` already covers the API and stays optional. 2026-10-10.

* [x] **Operation catalogue** — `Image.SmartCell.Operations` with sixteen operations, parameter specifications, client value casting and call generation. Every entry's defaults are executed against a real image by `test/smart_cell_operations_test.exs`. 2026-10-10.

* [x] **Cell skeleton end to end** — `Image.SmartCell.Transform` with all five callbacks plus `scan_binding/3`, registered from `Image.Application.start/2`. Generated source is asserted exactly, including hand-edited attributes, in `test/smart_cell_transform_test.exs`. 2026-10-10.

* [x] **Generic client renderer** — `lib/assets/main.js` and `main.css`, driven entirely by the catalogue, with add, remove and reorder. Built alongside the skeleton rather than after it, since building the client twice would have been wasted. 2026-10-10.

* [x] **The remaining operations** — all sixteen were in the catalogue from the start, so no second pass was needed. 2026-10-10.
