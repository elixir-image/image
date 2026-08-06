defmodule Image.AnalysisCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport
  alias Vix.Vips.Image, as: Vimage

  doctest Image.Scholar

  describe "Image.delta_e/3" do
    test "identical colors have zero difference in all versions" do
      for version <- [:de00, :de76, :decmc] do
        assert {:ok, +0.0} = Image.delta_e([0, 0, 0], [0, 0, 0], version)
      end
    end

    test "black and white are completely different" do
      assert {:ok, 100.0} = Image.delta_e([0, 0, 0], [255, 255, 255])
      assert {:ok, 100.0} = Image.delta_e([0, 0, 0], [255, 255, 255], :de76)
    end

    test "different versions return different distances" do
      assert {:ok, de00} = Image.delta_e(:green, :misty_rose, :de00)
      assert {:ok, de76} = Image.delta_e(:green, :misty_rose, :de76)
      assert {:ok, decmc} = Image.delta_e(:green, :misty_rose, :decmc)

      assert de00 != de76
      assert de76 != decmc
    end

    test "colors can be expressed as names or hex strings" do
      assert {:ok, distance} = Image.delta_e(:misty_rose, "#ffe4e1")
      assert_in_delta distance, 0.0, 0.001
    end

    test "images can be used in place of colors" do
      red = Image.new!(1, 1, color: :red)
      blue = Image.new!(1, 1, color: :blue)

      assert {:ok, distance} = Image.delta_e(red, blue)
      assert distance > 0

      assert {:ok, ^distance} = Image.delta_e(red, :blue)
      assert {:ok, ^distance} = Image.delta_e(:red, blue)
    end

    test "returns an error for an invalid version" do
      assert {:error, %Image.Error{message: message}} =
               Image.delta_e([0, 0, 0], [255, 255, 255], :de99)

      assert message =~ "Invalid delta_e version :de99"
    end

    test "delta_e!/3 returns the distance" do
      assert Image.delta_e!([0, 0, 0], [255, 255, 255]) == 100.0
    end

    test "delta_e!/3 raises for an invalid version" do
      assert_raise Image.Error, fn ->
        Image.delta_e!([0, 0, 0], [255, 255, 255], :de99)
      end
    end
  end

  describe "Image.dhash/2 and Image.hamming_distance/3" do
    setup do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, %{image: image}}
    end

    test "dhash/1 returns a 64-bit hash by default", %{image: image} do
      assert {:ok, hash} = Image.dhash(image)
      assert bit_size(hash) == 64
    end

    test "dhash/2 supports other hash sizes", %{image: image} do
      assert {:ok, hash} = Image.dhash(image, 16)
      assert bit_size(hash) == 16
    end

    test "dhash/1 is deterministic", %{image: image} do
      assert {:ok, hash_1} = Image.dhash(image)
      assert {:ok, hash_2} = Image.dhash(image)
      assert hash_1 == hash_2
    end

    test "hamming_distance/2 of an image with itself is zero", %{image: image} do
      assert {:ok, 0} = Image.hamming_distance(image, image)
    end

    test "hamming_distance/2 of different images is large", %{image: image} do
      other = Image.open!(image_path("Singapore-2016-09-5887.jpg"))

      assert {:ok, distance} = Image.hamming_distance(image, other)
      assert distance > 20
    end

    test "hamming_distance/3 accepts binary hashes" do
      assert {:ok, 0} = Image.hamming_distance(<<0::64>>, <<0::64>>, 64)

      assert {:ok, 16} =
               Image.hamming_distance(<<0::64>>, <<255, 255, 0, 0, 0, 0, 0, 0>>, 64)
    end
  end

  describe "Image.histogram/1" do
    test "returns a 256x1 histogram with the same bands as the image" do
      image = Image.new!(3, 3, color: [0, 128, 0])

      assert {:ok, histogram} = Image.histogram(image)
      assert Image.shape(histogram) == {256, 1, 3}
    end

    test "counts pixels per band value" do
      image = Image.new!(3, 3, color: [0, 128, 0])
      {:ok, histogram} = Image.histogram(image)

      # All nine pixels are 0 in the red and blue bands and 128
      # in the green band.
      assert Image.get_pixel!(histogram, 0, 0) == [9, 0, 9]
      assert Image.get_pixel!(histogram, 128, 0) == [0, 9, 0]
    end
  end

  describe "Image.k_means/2 and Image.reduce_colors/2" do
    setup do
      image =
        image_path("Kip_small.jpg")
        |> Image.open!()
        |> Image.thumbnail!(32)

      {:ok, %{image: image}}
    end

    test "k_means/2 returns the requested number of clusters", %{image: image} do
      assert {:ok, colors} = Image.k_means(image, num_clusters: 4, key: Nx.Random.key(1))
      assert length(colors) == 4

      for color <- colors do
        assert [_r, _g, _b] = color
        assert Enum.all?(color, &is_integer/1)
      end
    end

    test "k_means!/2 returns a list of colors", %{image: image} do
      assert colors = Image.k_means!(image, num_clusters: 3, key: Nx.Random.key(1))
      assert length(colors) == 3
    end

    test "reduce_colors/2 returns an image of the same shape", %{image: image} do
      assert {:ok, reduced} = Image.reduce_colors(image, colors: 4, key: Nx.Random.key(1))
      assert Image.shape(reduced) == Image.shape(image)
    end

    test "reduce_colors!/2 returns an image", %{image: image} do
      assert %Vimage{} = Image.reduce_colors!(image, colors: 2, key: Nx.Random.key(1))
    end

    test "k_means/2 returns an error for an invalid option value", %{image: image} do
      assert {:error,
              %Image.Error{
                reason: :invalid_option,
                operation: :k_means,
                value: {:num_clusters, 0}
              }} = Image.k_means(image, num_clusters: 0)
    end

    test "reduce_colors/2 returns an error for an unknown option", %{image: image} do
      assert {:error,
              %Image.Error{
                reason: :invalid_option,
                operation: :reduce_colors,
                value: [:unknown_option]
              }} = Image.reduce_colors(image, unknown_option: true)
    end

    test "reduce_colors/2 preserves the band format of the image" do
      image = Image.new!(2, 2, color: [255, 0, 0])

      assert {:ok, reduced} = Image.reduce_colors(image, colors: 1, key: Nx.Random.key(1))
      assert Image.band_format(reduced) == Image.band_format(image)

      pixels = Image.to_nx!(reduced) |> Nx.to_flat_list()
      assert pixels == List.flatten(List.duplicate([255, 0, 0], 4))
    end

    test "reduce_colors/2 rounds cluster colors rather than truncating them" do
      # The two pixels are one apart, so the single centroid lands on
      # exactly 100.5, where rounding and truncating disagree.
      image =
        Image.join!(
          [Image.new!(1, 1, color: [100, 100, 100]), Image.new!(1, 1, color: [101, 101, 101])],
          across: 2
        )

      assert {:ok, reduced} = Image.reduce_colors(image, colors: 1, key: Nx.Random.key(1))
      assert Image.to_nx!(reduced) |> Nx.to_flat_list() == List.duplicate(101, 6)
    end

    test "reduce_colors/2 returns an error for a single-pixel image" do
      assert {:error, %Image.Error{operation: :reduce_colors, message: message}} =
               Image.reduce_colors(Image.new!(1, 1, color: :red), colors: 2)

      assert message =~ "at least 2 samples"
    end

    test "reduce_colors/2 clamps :colors to the number of unique colors" do
      image =
        Image.join!([Image.new!(2, 2, color: :red), Image.new!(2, 2, color: :blue)], across: 2)

      assert {:ok, 2} = Image.Scholar.unique_color_count(image)

      assert {:ok, reduced} = Image.reduce_colors(image, colors: 100, key: Nx.Random.key(1))
      assert {:ok, 2} = Image.Scholar.unique_color_count(reduced)
    end

    test "reduce_colors/2 uses more than 256 colors when asked" do
      image =
        image_path("Hong-Kong-2015-07-1998.jpg")
        |> Image.open!()
        |> Image.thumbnail!(40)

      assert {:ok, {_counts, colors}} = Image.Scholar.unique_colors(image)
      assert Nx.axis_size(colors, 0) > 300

      assert {:ok, reduced} =
               Image.reduce_colors(image,
                 colors: 300,
                 key: Nx.Random.key(1),
                 num_runs: 1,
                 max_iterations: 5
               )

      assert {:ok, {_counts, reduced_colors}} = Image.Scholar.unique_colors(reduced)
      assert Nx.axis_size(reduced_colors, 0) > 256
    end
  end

  describe "Image.Scholar.fit/3" do
    test "returns an error when Scholar raises outside its option schema" do
      samples = Nx.tensor([1, 2, 3, 4])

      assert {:error, %Image.Error{reason: :invalid_option, message: message}} =
               Image.Scholar.fit(samples, num_clusters: 2, key: Nx.Random.key(1))

      assert message =~ "expected input tensor to have shape"
    end
  end

  describe "Image.Scholar.unique_color_count/1" do
    setup do
      image =
        image_path("Kip_small.jpg")
        |> Image.open!()
        |> Image.thumbnail!(32)

      {:ok, %{image: image}}
    end

    test "agrees with unique_colors/1", %{image: image} do
      assert {:ok, {_counts, colors}} = Image.Scholar.unique_colors(image)
      assert {:ok, count} = Image.Scholar.unique_color_count(image)
      assert count == Nx.axis_size(colors, 0)
    end

    test "an image and its tensor give the same answer", %{image: image} do
      assert {:ok, count} = Image.Scholar.unique_color_count(image)
      assert {:ok, ^count} = Image.Scholar.unique_color_count(Image.to_nx!(image))
    end

    test "counts a single pixel without calling Nx.diff/1" do
      assert {:ok, 1} = Image.Scholar.unique_color_count(Image.new!(1, 1, color: :red))
    end

    test "returns an error for a greyscale image, which it cannot encode", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.Scholar.unique_color_count(Image.to_colorspace!(image, :bw))

      assert message =~ "3- or 4-band"
    end

    test "returns an error for a 16-bit image, which it cannot encode", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.Scholar.unique_color_count(Image.cast!(image, {:u, 16}))

      assert message =~ "8-bit unsigned"
    end

    test "returns an error for a tensor that is not an image", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.Scholar.unique_color_count(Nx.flatten(Image.to_nx!(image)))

      assert message =~ "rank 1"
    end
  end

  describe "Image.preview/1 and Image.p/1" do
    setup do
      original = System.get_env("LC_TERMINAL")
      System.put_env("LC_TERMINAL", "not-an-iterm")

      on_exit(fn ->
        if original do
          System.put_env("LC_TERMINAL", original)
        else
          System.delete_env("LC_TERMINAL")
        end
      end)

      {:ok, %{image: Image.new!(2, 2, color: :red)}}
    end

    test "preview/1 returns an error on an unsupported terminal", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.preview(image)
      assert message =~ "Unsupported terminal"
    end

    test "preview/1 accepts an :ok tuple", %{image: image} do
      assert {:ok, {:error, %Image.Error{}}} = Image.preview({:ok, image})
    end

    test "p/1 delegates to preview/1", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.p(image)
      assert message =~ "Unsupported terminal"
    end
  end
end
