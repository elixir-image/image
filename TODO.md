# TODO

Work tracking for `Image`. Design documents live under [plans/](plans/), and anything longer than a short paragraph belongs there rather than here.

## Open

* [ ] **Livebook smart cell** — a cell that composes an `Image` pipeline from a form, previews it and writes the equivalent source into the notebook. Design in [plans/livebook-smart-cell.md](plans/livebook-smart-cell.md), issue [#31](https://github.com/elixir-image/image/issues/31).

* [ ] **Finish the Rule 2 sweep** — `Image.compare/3` guards its options with `is_list/1` and three functions guard a callback with `is_function(fun, 1)`, so all four raise `FunctionClauseError` rather than returning an error. Both were left deliberately: #220 made non-keyword options raise on purpose, and a wrong-arity callback is a programmer error where a loud failure beats a hidden one. Decide whether that still stands.

* [ ] **`Image.Social.image_usages/1` and `default_image_usage/1` raise for an unknown platform** — they return bare values rather than tuples, so converting them changes their contract shape rather than just their error path.

* [ ] **`Image.compare/3`'s "Invalid metric" error uses a string `:reason`** — every other error path uses an atom after #231. Changing it is breaking.

* [ ] **Doc bullet punctuation** — around 480 documentation bullet items do not end in terminal punctuation, against the house rule. Roughly half of those legitimately end in "or", being the `X or` / `Y.` return pattern, so a blanket fix would corrupt them.

* [ ] **Dead CI exclusion** — `.github/workflows/ci.yml` excludes a `heic_compression` tag that no test uses.

## Deferred

* [ ] **`Image.compare/3` returns sRGB for `:lab`, `:lch` and `:cmyk`** — `composite2/3` composites outside the sRGB family in 8-bit sRGB and returns its result there, so the composed difference cannot stay in those interpretations. Fixing it means hand-rolling the OVER blend with `Image.Math` instead of calling libvips.
