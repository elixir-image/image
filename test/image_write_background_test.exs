defmodule Image.Write.Background.Test do
  use ExUnit.Case, async: true

  # A 4-band (RGBA) image that is fully transparent red. Written to a
  # format without alpha (JPEG) the transparent areas are flattened
  # onto the `:background`.
  setup do
    Temp.track()
    tmp_dir = Temp.mkdir!()
    {:ok, base} = Image.new(8, 8, color: [255, 0, 0])
    {:ok, rgba} = Image.add_alpha(base, 0)
    {:ok, %{rgba: rgba, tmp_dir: tmp_dir}}
  end

  defp roundtrip_background(tmp_dir, image, background) do
    path = Temp.path!(suffix: ".jpg", basedir: tmp_dir)
    {:ok, _} = Image.write(image, path, background: background)
    written = Image.open!(path)
    Image.get_pixel!(written, 4, 4)
  end

  # need the tolerance for jpeg saves. no other non-alpha format at hand.
  defp close_to?(actual, [r, g, b], tolerance \\ 6) do
    [ar, ag, ab] = Enum.take(actual, 3)
    abs(ar - r) <= tolerance and abs(ag - g) <= tolerance and abs(ab - b) <= tolerance
  end

  describe "Image.write/3 :background color resolution" do
    # just test that it goes through `Image.Pixel.to_pixel/2`
    test "accepts a CSS named color as a string", %{rgba: rgba, tmp_dir: tmp_dir} do
      pixel = roundtrip_background(tmp_dir, rgba, "lime")
      assert close_to?(pixel, [0, 255, 0])
    end

    test "accepts a numeric list", %{rgba: rgba, tmp_dir: tmp_dir} do
      pixel = roundtrip_background(tmp_dir, rgba, [0, 255, 0])
      assert close_to?(pixel, [0, 255, 0])
    end

    test "accepts :average and flattens onto the image average", %{rgba: rgba, tmp_dir: tmp_dir} do
      # The image is solid red under the transparency, so the
      # average is red and the flattened background is red.
      pixel = roundtrip_background(tmp_dir, rgba, :average)
      assert close_to?(pixel, [255, 0, 0])
    end

    test "returns an error for an unknown color", %{rgba: rgba, tmp_dir: tmp_dir} do
      path = Temp.path!(suffix: ".jpg", basedir: tmp_dir)
      assert {:error, _reason} = Image.write(rgba, path, background: :not_a_real_color)
    end
  end
end
