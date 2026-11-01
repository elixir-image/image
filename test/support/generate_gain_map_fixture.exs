# Generates test/support/images/gain_map.jpg, the UltraHDR fixture used by the
# gain map tests. Run from the project root with:
#
#     mix run --no-start test/support/generate_gain_map_fixture.exs
#
# It needs a libvips built with libuhdr (8.18 or later), which the precompiled
# libvips shipped by `vix` provides.
#
# The base is a repository image, so the fixture is licence-clean. Only a marker
# rectangle in the top-left quadrant is lifted above SDR white, so the gain map
# libultrahdr computes is high inside the marker and flat everywhere else. The
# marker is asymmetric on both axes, which lets a test check that a flip, rotate
# or crop moved the gain map with the image, not just that its dimensions fit.

alias Vix.Vips.Image, as: Vimage
alias Vix.Vips.Operation

source = "test/support/images/Kamchatka-2019-8754.jpg"
destination = "test/support/images/gain_map.jpg"

# The marker in base image pixels: left, top, width, height.
{marker_left, marker_top, marker_width, marker_height} = {48, 40, 120, 80}

# HDR value of the marker, in scRGB where 1.0 is SDR white.
marker_value = 4.0

{:ok, base} = Vimage.new_from_file(source)
{:ok, base} = Operation.resize(base, 480 / Vimage.width(base))
{:ok, scrgb} = Operation.colourspace(base, :VIPS_INTERPRETATION_scRGB)

{:ok, region} = Operation.extract_area(scrgb, marker_left, marker_top, marker_width, marker_height)
{:ok, marker} = Operation.linear(region, [0.0], [marker_value])
{:ok, hdr} = Operation.insert(scrgb, marker, marker_left, marker_top)

{:ok, jpeg} = Operation.uhdrsave_buffer(hdr, Q: 85)
File.write!(destination, jpeg)

IO.puts(
  "Wrote #{destination} (#{byte_size(jpeg)} bytes), base #{Vimage.width(hdr)}x#{Vimage.height(hdr)}"
)
