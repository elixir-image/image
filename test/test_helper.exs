paths = Path.wildcard("test/support/did_not_match/**/*.{png,tif,jpg,webp,gif}")
Enum.each(paths, &File.rm/1)

Application.ensure_all_started(:telemetry)
Application.ensure_all_started(:hackney)

# Gain map tests need a libvips built with libuhdr (8.18 or later). The
# precompiled libvips shipped by `vix` has it; a platform-provided one may not.
gain_map_excludes =
  if Code.ensure_loaded?(Vix.Vips.Operation) and
       function_exported?(Vix.Vips.Operation, :uhdrload, 1) do
    []
  else
    [gain_map: true]
  end

ExUnit.configure(exclude: [full: true] ++ gain_map_excludes, timeout: 120_000)
ExUnit.start()
