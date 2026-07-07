defmodule Image.CoverageWave3.Core.Test do
  use ExUnit.Case, async: true

  alias Image.Math
  alias Image.Draw

  defp rgb, do: Image.new!(20, 20, color: [10, 20, 30])
  defp rgba, do: Image.new!(20, 20, color: [10, 20, 30, 255])

  # An image with mismatched band count that makes most binary
  # libvips operations fail, exercising the bang raise branches.
  defp mismatched, do: Image.new!(20, 20, color: [1, 2, 3, 4, 5], bands: 5)

  describe "Image.Math bang error branches" do
    test "arithmetic bangs raise Image.Error on incompatible images" do
      for fun <- [:add!, :subtract!, :multiply!, :divide!, :pow!] do
        assert_raise Image.Error, fn ->
          apply(Math, fun, [rgb(), mismatched()])
        end
      end
    end

    test "relational bangs raise Image.Error on incompatible images" do
      for fun <- [
            :less_than!,
            :less_than_or_equal!,
            :greater_than!,
            :greater_than_or_equal!,
            :equal!,
            :not_equal!
          ] do
        assert_raise Image.Error, fn ->
          apply(Math, fun, [rgb(), mismatched()])
        end
      end
    end

    test "boolean bangs raise Image.Error on incompatible images" do
      for fun <- [
            :boolean_and!,
            :boolean_or!,
            :boolean_xor!,
            :boolean_lshift!,
            :boolean_rshift!
          ] do
        assert_raise Image.Error, fn ->
          apply(Math, fun, [rgb(), mismatched()])
        end
      end
    end

    test "top_n and bottom_n with default n" do
      assert {_value, _x, _y, positions} = Math.top_n(Image.to_colorspace!(rgb(), :bw))
      assert is_list(positions)
      assert {_value, _x, _y, positions} = Math.bottom_n(Image.to_colorspace!(rgb(), :bw))
      assert is_list(positions)
    end

    test "minpos and maxpos on a constant image flag possible overflow" do
      grey = Image.new!(10, 10, color: 128) |> Image.to_colorspace!(:bw)

      assert {_value, _coordinates, :maybe_overflow} = Math.minpos(grey)
      assert {_value, _coordinates, :maybe_overflow} = Math.maxpos(grey)
    end
  end

  describe "Image.Draw default arguments and band-adjusted map colors" do
    test "point, rect, circle, line, flood, mask with default options" do
      mask = Image.new!(5, 5, color: 255) |> Image.to_colorspace!(:bw)

      assert {:ok, _} = Draw.point(rgb(), 1, 1)
      assert {:ok, _} = Draw.rect(rgb(), 1, 1, 3, 3)
      assert {:ok, _} = Draw.circle(rgb(), 10, 10, 4)
      assert {:ok, _} = Draw.line(rgb(), 0, 0, 9, 9)
      assert {:ok, _} = Draw.flood(rgb(), 0, 0)
      assert {:ok, _} = Draw.mask(rgb(), mask, 1, 1)
    end

    test "bang variants with default options" do
      assert %Vix.Vips.Image{} = Draw.rect!(rgb(), 1, 1, 3, 3)
      assert %Vix.Vips.Image{} = Draw.circle!(rgb(), 10, 10, 4)
      assert %Vix.Vips.Image{} = Draw.line!(rgb(), 0, 0, 9, 9)
      assert %Vix.Vips.Image{} = Draw.flood!(rgb(), 0, 0)
    end

    test "a map color one band short of an alpha image gains an alpha value" do
      # Map options bypass validation, so maybe_add_alpha adjusts the
      # band count.
      assert {:ok, drawn} = Draw.point(rgba(), 1, 1, %{color: [255, 0, 0]})
      assert Image.get_pixel!(drawn, 1, 1) == [255, 0, 0, 255]
    end

    test "a map color one band over a non-alpha image loses the extra value" do
      assert {:ok, drawn} = Draw.point(rgb(), 1, 1, %{color: [255, 0, 0, 255]})
      assert Image.get_pixel!(drawn, 1, 1) == [255, 0, 0]
    end

    test "a map color on a mutable image is band-adjusted" do
      assert {:ok, _} =
               Image.mutate(rgba(), fn mutable ->
                 {:ok, _} = Draw.point(mutable, 1, 1, %{color: [255, 0, 0]})
                 :ok
               end)
    end
  end

  describe "Image.Text default arguments and background clauses" do
    test "text and simple_text with default options" do
      assert {:ok, _} = Image.Text.text("hi")
      assert %Vix.Vips.Image{} = Image.Text.text!("hi")
      assert {:ok, _} = Image.Text.simple_text("hi")
      assert %Vix.Vips.Image{} = Image.Text.simple_text!("hi")
    end

    test "add_background and friends with default options" do
      {:ok, text} = Image.Text.simple_text("hi")

      assert {:ok, _} = Image.Text.add_background(text)
      assert %Vix.Vips.Image{} = Image.Text.add_background!(text)
      assert {:ok, _} = Image.Text.add_background_padding(text)
      assert %Vix.Vips.Image{} = Image.Text.add_background_padding!(text)
      assert {:ok, _} = Image.Text.add_background_border(text)
      assert %Vix.Vips.Image{} = Image.Text.add_background_border!(text)
    end

    test "add_background with :none background is a no-op" do
      {:ok, text} = Image.Text.simple_text("hi")

      assert {:ok, ^text} =
               Image.Text.add_background(text, %{background_fill_color: :none})
    end

    test "add_background_border with :none stroke or zero padding is a no-op" do
      {:ok, text} = Image.Text.simple_text("hi")

      assert {:ok, ^text} =
               Image.Text.add_background_border(text, %{background_stroke_color: :none})

      assert {:ok, ^text} =
               Image.Text.add_background_border(text, %{
                 background_stroke_color: :blue,
                 padding: 0
               })
    end

    test "a pango span string is passed through unescaped" do
      assert {:ok, _} = Image.Text.simple_text("<span foreground=\"red\">hi</span>")
    end

    test "x and y locations :right and :bottom with canvas dimensions" do
      assert {:ok, _} =
               Image.Text.text("hi", x: :right, y: :bottom, width: 300, height: 200)
    end
  end

  describe "Image.Video gaps" do
    setup do
      {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4")
      on_exit(fn -> Image.Video.close(video) end)
      {:ok, %{video: video}}
    end

    test "image_from_video! with default options", %{video: video} do
      assert %Vix.Vips.Image{} = Image.Video.image_from_video!(video)
    end

    test "seeking beyond the end returns an error", %{video: video} do
      assert {:error, _} = Image.Video.image_from_video(video, frame: 1_000_000)
    end
  end
end
