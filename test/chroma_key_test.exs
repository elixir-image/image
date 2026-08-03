defmodule Image.ChromaKey.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport
  alias Vix.Vips.Image, as: Vimage

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "Chroma Key an image", %{dir: dir} do
    image = image_path("chroma_key/greenscreen.jpg")
    validate_path = validate_path("chroma_key/person.jpg")

    {:ok, image} = Vimage.new_from_file(image)
    {:ok, meme} = Image.chroma_key(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(meme, out_path)

    # Image.write!(meme, validate_path)
    assert_images_equal out_path, validate_path
  end

  describe "strategy selection" do
    setup do
      {:ok, %{image: Image.new!(10, 10, color: [0, 255, 0])}}
    end

    test "no strategy options selects the threshold strategy", %{image: image} do
      assert {:ok, %{strategy: :threshold, color: :auto, threshold: 20}} =
               Image.Options.ChromaKey.validate_options(image, [])
    end

    test ":color and :threshold select the threshold strategy", %{image: image} do
      assert {:ok, %{strategy: :threshold, color: [0, 255, 0], threshold: 30}} =
               Image.Options.ChromaKey.validate_options(image, color: [0, 255, 0], threshold: 30)
    end

    test ":greater_than and :less_than select the color range strategy", %{image: image} do
      assert {:ok, %{strategy: :range, greater_than: [0, 200, 0], less_than: [50, 255, 50]}} =
               Image.Options.ChromaKey.validate_options(image,
                 greater_than: [0, 200, 0],
                 less_than: [50, 255, 50]
               )
    end

    test "options from both strategies are an error", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option} = error} =
               Image.chroma_mask(image,
                 color: [0, 255, 0],
                 threshold: 30,
                 greater_than: [0, 200, 0],
                 less_than: [50, 255, 50]
               )

      assert error.value == [:color, :threshold, :greater_than, :less_than]
    end

    test ":threshold combined with a complete color range is an error", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option} = error} =
               Image.chroma_mask(image,
                 threshold: 30,
                 greater_than: [0, 200, 0],
                 less_than: [50, 255, 50]
               )

      assert error.value == [:threshold, :greater_than, :less_than]
    end

    test ":greater_than without :less_than is an error", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option} = error} =
               Image.chroma_mask(image, greater_than: [0, 200, 0])

      assert error.value == [:greater_than]
    end

    test ":less_than without :greater_than is an error", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option} = error} =
               Image.chroma_mask(image, less_than: [50, 255, 50])

      assert error.value == [:less_than]
    end

    test "chroma_key/2 reports the strategy conflict", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.chroma_key(image, color: [0, 255, 0], greater_than: [0, 200, 0])
    end

    test "chroma_mask!/2 raises on an incomplete color range", %{image: image} do
      assert_raise Image.Error, fn -> Image.chroma_mask!(image, less_than: [50, 255, 50]) end
    end

    test "the strategy is resolved before the option values are validated", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option, value: [:greater_than]}} =
               Image.chroma_mask(image, greater_than: :not_a_color)
    end
  end

  describe "unknown options" do
    setup do
      {:ok, %{image: Image.new!(10, 10, color: [0, 255, 0])}}
    end

    test "an unknown option is an error", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option, value: {:unknown, 1}}} =
               Image.chroma_mask(image, unknown: 1)
    end
  end

  describe "color range bounds" do
    test ":greater_than is the lower bound and :less_than the upper bound" do
      dark = Image.new!(1, 1, color: [0, 0, 0])
      mid = Image.new!(1, 1, color: [100, 100, 100])
      light = Image.new!(1, 1, color: [200, 200, 200])

      {:ok, image} = Image.join([dark, mid, light], across: 3)

      {:ok, mask} =
        Image.chroma_mask(image, greater_than: [50, 50, 50], less_than: [150, 150, 150])

      # Only the pixel inside the range is masked out. The mask keeps (255)
      # everything outside it.
      assert Enum.map(0..2, &Image.get_pixel!(mask, &1, 0)) == [[255], [0], [255]]
    end
  end
end
