paths = Path.wildcard("test/support/did_not_match/**/*.{png,tif,jpg,webp,gif}")
Enum.each(paths, &File.rm/1)

Application.ensure_all_started(:telemetry)

# Tests that compare rendered text with reference images need the same fonts
# on every machine: fontconfig, configured by test/support/fonts/fonts.conf to
# see only the fonts in test/support/fonts and priv/fonts. Both variables are
# read by C libraries when they initialise, which System.put_env/2 does not
# reach, so they must be set before the VM starts. CI sets them; elsewhere
# these tests are excluded unless they are set:
#
#   PANGOCAIRO_BACKEND=fc FONTCONFIG_FILE=$PWD/test/support/fonts/fonts.conf mix test
fonts_conf = Path.expand("support/fonts/fonts.conf", __DIR__)

text_excludes =
  if System.get_env("FONTCONFIG_FILE") == fonts_conf and
       System.get_env("PANGOCAIRO_BACKEND") == "fc" do
    []
  else
    IO.puts(
      "Excluding the text rendering tests: set PANGOCAIRO_BACKEND=fc and " <>
        "FONTCONFIG_FILE=#{fonts_conf} to include them."
    )

    [text: true, text_avatar: true]
  end

# Gain map tests need a libvips built with libuhdr (8.18 or later). The
# precompiled libvips shipped by `vix` has it; a platform-provided one may not.
gain_map_excludes =
  if Code.ensure_loaded?(Vix.Vips.Operation) and
       function_exported?(Vix.Vips.Operation, :uhdrload, 1) do
    []
  else
    [gain_map: true]
  end

ExUnit.configure(exclude: text_excludes ++ gain_map_excludes, timeout: 120_000)
ExUnit.start()
