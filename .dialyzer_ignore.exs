[
  # `Vix.Vips.Image.header_value/2` returns `{:ok, %Vix.Vips.Image{}}` for an
  # image-valued field such as `gainmap`, but its @spec omits `t()`, so
  # dialyzer reports `Image.GainMap.gain_map/1`'s match on the decoded gain map
  # as unreachable. Remove this entry once vix widens the spec.
  {"lib/image/gain_map.ex", :pattern_match}
]
