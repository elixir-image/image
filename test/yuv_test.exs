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

    test "each range round trips within itself" do
      for range <- [:limited, :full],
          color <- [[200, 30, 90], [10, 250, 128], [255, 255, 255], [0, 0, 0]],
          colorspace <- [:bt601, :bt709],
          encoding <- [:C444, :C420] do
        image = Image.new!(8, 8, color: color)
        {:ok, binary} = Image.YUV.write_to_binary(image, encoding, colorspace, range)

        {:ok, round_tripped} =
          Image.YUV.new_from_binary(binary, 8, 8, encoding, colorspace, range)

        result = Image.get_pixel!(round_tripped, 4, 4)

        for {expected, actual} <- Enum.zip(color, result) do
          assert abs(expected - actual) <= 3,
                 "#{inspect(range)}/#{inspect(colorspace)}/#{inspect(encoding)} " <>
                   "round trip of #{inspect(color)} returned #{inspect(result)}"
        end
      end
    end

    test "the range argument defaults to :limited" do
      image = Image.new!(8, 8, color: [200, 30, 90])

      {:ok, default_binary} = Image.YUV.write_to_binary(image, :C444, :bt601)
      {:ok, limited_binary} = Image.YUV.write_to_binary(image, :C444, :bt601, :limited)

      assert default_binary == limited_binary
    end

    test "full range uses the whole 0..255 luma range while limited clips to 16..235" do
      white = Image.new!(4, 4, color: [255, 255, 255])

      {:ok, <<full_y::8, _::binary>>} = Image.YUV.write_to_binary(white, :C444, :bt601, :full)
      {:ok, <<limited_y::8, _::binary>>} = Image.YUV.write_to_binary(white, :C444, :bt601, :limited)

      assert full_y == 255
      assert limited_y == 235
    end

    test "decoding with the wrong range shifts the result" do
      image = Image.new!(8, 8, color: [200, 30, 90])
      {:ok, binary} = Image.YUV.write_to_binary(image, :C444, :bt601, :full)

      # Decoding full-range data as limited-range must not round-trip cleanly.
      {:ok, mismatched} = Image.YUV.new_from_binary(binary, 8, 8, :C444, :bt601, :limited)
      [r, _g, _b] = Image.get_pixel!(mismatched, 4, 4)

      assert abs(r - 200) > 5
    end
  end
end
