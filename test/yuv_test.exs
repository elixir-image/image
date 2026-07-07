defmodule Image.YUVTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Opening an .YUV image, convert to RGB then back to YUV" do
    raw_yuv_file = image_path("image.yuv")
    {:ok, binary} = File.read(raw_yuv_file)

    assert {:ok, rgb_image} = Image.YUV.new_from_binary(binary, 1920, 1080, :C420, :bt601)
    assert {:ok, _yuv} = Image.YUV.to_yuv(rgb_image, :C420, :bt601)
    assert {:ok, _yuv} = Image.YUV.to_yuv(rgb_image, :C420, :bt709)
    assert {:ok, _yuv} = Image.YUV.to_yuv(rgb_image, :C422, :bt601)
    assert {:ok, _yuv} = Image.YUV.to_yuv(rgb_image, :C444, :bt709)
  end

  describe "round-trip accuracy" do
    # Regression: the encoder used studio-swing (limited range)
    # coefficients while the decoder used full-range inverses, so
    # round trips compressed colors toward grey (for example
    # [200, 30, 90] returned as [173, 24, 76]). Both directions now
    # use studio-swing coefficients.
    test "encode then decode returns close to the original color" do
      for color <- [[200, 30, 90], [10, 250, 128], [255, 255, 255], [0, 0, 0]],
          colorspace <- [:bt601, :bt709],
          encoding <- [:C444, :C420] do
        image = Image.new!(8, 8, color: color)
        {:ok, binary} = Image.YUV.write_to_binary(image, encoding, colorspace)
        {:ok, round_tripped} = Image.YUV.new_from_binary(binary, 8, 8, encoding, colorspace)
        result = Image.get_pixel!(round_tripped, 4, 4)

        for {expected, actual} <- Enum.zip(color, result) do
          assert abs(expected - actual) <= 3,
                 "#{inspect(colorspace)}/#{inspect(encoding)} " <>
                   "round trip of #{inspect(color)} returned #{inspect(result)}"
        end
      end
    end
  end
end
