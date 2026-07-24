defmodule Image.Perspective.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  @warp_from [
    {139, 125},
    {826, 74},
    {796, 559},
    {155, 483}
  ]

  @warp_to [
    {139, 125},
    {815, 125},
    {815, 528},
    {139, 528}
  ]

  test "warps an image to perspective" do
    image_path = image_path("warp_perspective.jpg")
    validate_path = validate_path("warp/warp_perspective.jpg")

    {:ok, image} = Image.open(image_path)
    {:ok, result} = Image.warp_perspective(image, @warp_from, @warp_to)

    # Image.write! result, validate_path
    {:ok, result} = Vix.Vips.Image.write_to_buffer(result, ".jpg")

    assert_images_equal(result, validate_path)
  end

  test "warps an image to a rectangular perspective" do
    image_path = image_path("warp_perspective.jpg")
    validate_path = validate_path("warp/warp_perspective_straighten.png")

    {:ok, image} = Image.open(image_path)
    {:ok, destination, result} = Image.straighten_perspective(image, @warp_from)

    # Image.write! result, validate_path
    {:ok, result} = Vix.Vips.Image.write_to_buffer(result, ".png")

    assert [{139, 125}, {826, 125}, {826, 483}, {139, 483}] = destination
    assert_images_equal(result, validate_path)
  end

  test "post-crop of a warped image" do
    image_path = image_path("warp_perspective.jpg")
    validate_path = validate_path("warp/warp_perspective_cropped.png")

    {:ok, image} = Image.open(image_path)
    {:ok, result} = Image.warp_perspective(image, @warp_from, @warp_to)

    {:ok, cropped} = Image.crop(result, @warp_to)

    # Image.write! cropped, validate_path
    assert_images_equal(cropped, validate_path)
  end

  test "warp an image with an alpha band" do
    image_path = image_path("image_with_alpha2.png")
    validate_path = validate_path("warp/warped_image_with_alpha2.png")

    {:ok, image} = Image.open(image_path)

    {:ok, result} =
      Image.warp_perspective(
        image,
        [{139, 125}, {826, 74}, {796, 559}, {155, 483}],
        [{139, 125}, {815, 125}, {815, 528}, {139, 528}]
      )

    # Image.write! result, validate_path
    {:ok, result} = Vix.Vips.Image.write_to_buffer(result, ".png")

    assert_images_equal(result, validate_path)
  end

  test "warp an image with an alpha band making the added pixels transparent" do
    image_path = image_path("image_with_alpha2.png")
    validate_path = validate_path("warp/warped_image_with_alpha2_transparent.png")

    {:ok, image} = Image.open(image_path)

    {:ok, result} =
      Image.warp_perspective(
        image,
        [{139, 125}, {826, 74}, {796, 559}, {155, 483}],
        [{139, 125}, {815, 125}, {815, 528}, {139, 528}],
        background: [1, 177, 64]
      )

    {:ok, result} = Image.chroma_key(result, color: [1, 177, 64], threshold: 0)

    # Image.write! result, validate_path
    {:ok, result} = Vix.Vips.Image.write_to_buffer(result, ".png")

    assert_images_equal(result, validate_path)
  end

  describe "alpha pass-through" do
    # expose canvas at the corners, so (1, 1) is pure background fill
    @inset_source [{0, 0}, {99, 0}, {99, 99}, {0, 99}]
    @inset_destination [{30, 30}, {70, 30}, {70, 70}, {30, 70}]

    test "warp_perspective/4 keeps the alpha band" do
      image = Image.new!(100, 100, color: [255, 0, 0, 255])

      {:ok, warped} = Image.warp_perspective(image, @inset_source, @inset_destination)

      assert Image.shape(warped) == {100, 100, 4}
      assert Image.get_pixel!(warped, 50, 50) == [255, 0, 0, 255]
    end

    test "warp_perspective/4 fills exposed canvas with transparent black by default" do
      image = Image.new!(100, 100, color: [255, 0, 0, 255])

      {:ok, warped} = Image.warp_perspective(image, @inset_source, @inset_destination)

      assert Image.get_pixel!(warped, 1, 1) == [0, 0, 0, 0]
    end

    test "warp_perspective/4 reproduces a partially transparent background exactly" do
      image = Image.new!(100, 100, color: [255, 0, 0, 255])

      {:ok, warped} =
        Image.warp_perspective(image, @inset_source, @inset_destination,
          background: [10, 20, 30, 40]
        )

      assert Image.get_pixel!(warped, 1, 1) == [10, 20, 30, 40]
    end

    test "warp_perspective/4 still zero-fills an image without an alpha band" do
      image = Image.new!(100, 100, color: :red)

      {:ok, warped} = Image.warp_perspective(image, @inset_source, @inset_destination)

      assert Image.shape(warped) == {100, 100, 3}
      assert Image.get_pixel!(warped, 1, 1) == [0, 0, 0]
    end
  end

  describe "straighten_perspective/3 source validation" do
    # Regression: a malformed source fell through a `with` that had no else,
    # returning the source list itself instead of an error (or an image from
    # the bang variant).

    test "returns an error for a source that is not four points" do
      image = Image.new!(100, 100, color: :red)

      assert {:error, %Image.Error{message: message}} =
               Image.straighten_perspective(image, [{0, 0}, {1, 1}])

      assert message =~ "quadrilateral"
    end

    test "straighten_perspective!/3 raises for a malformed source" do
      image = Image.new!(100, 100, color: :red)

      assert_raise Image.Error, ~r/quadrilateral/, fn ->
        Image.straighten_perspective!(image, :not_a_list)
      end
    end

    test "straightens a valid quadrilateral" do
      image = Image.new!(100, 100, color: :red)
      source = [{10, 10}, {90, 12}, {88, 90}, {12, 88}]

      assert {:ok, [_, _, _, _], %Vix.Vips.Image{}} =
               Image.straighten_perspective(image, source)
    end
  end
end
