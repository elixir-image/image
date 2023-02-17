defmodule Image.Resize.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  setup do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, %{image: image}}
  end

  describe "thumbnail/3" do
    test "Resize to fit", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fit.png")

      {:ok, resized} = Image.thumbnail(image, 200)

      assert_images_equal resized, validate_path
    end

    test "Resize to fill with attention crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill.png")

      {:ok, resized} = Image.thumbnail(image, 200, height: 50, crop: :attention)

      assert_images_equal(resized, validate_path)
    end

    test "Resize to fill with low crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill_low.png")

      {:ok, resized} = Image.thumbnail(image, 200, height: 50, crop: :low)

      assert_images_equal(resized, validate_path)
    end

    test "Resize to fill with high crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill_high.png")

      {:ok, resized} = Image.thumbnail(image, 200, height: 50, crop: :high)

      assert_images_equal(resized, validate_path)
    end

    test "Resize to fill with center crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill_center.png")

      {:ok, resized} = Image.thumbnail(image, 200, height: 50, crop: :center)

      assert_images_equal(resized, validate_path)
    end

    test "Returns an error tuple if path is not found" do
      assert {:error, :enoent} = Image.thumbnail("some-non-existing-path", 200)
    end

    @tag :full
    test "Resize to fill with none crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill_none.png")

      {:ok, resized} = Image.thumbnail(image, 200, height: 50, crop: :none)

      assert_images_equal(resized, validate_path)
    end
  end

  describe "thumbnail!/3" do
    test "Resize to fit", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fit.png")

      resized = Image.thumbnail!(image, 200)

      assert_images_equal resized, validate_path
    end

    test "Resize to fill with attention crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill.png")

      resized = Image.thumbnail!(image, 200, height: 50, crop: :attention)

      assert_images_equal(resized, validate_path)
    end

    test "Resize to fill with low crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill_low.png")

      resized = Image.thumbnail!(image, 200, height: 50, crop: :low)

      assert_images_equal(resized, validate_path)
    end

    test "Resize to fill with high crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill_high.png")

      resized = Image.thumbnail!(image, 200, height: 50, crop: :high)

      assert_images_equal(resized, validate_path)
    end

    test "Resize to fill with center crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill_center.png")

      resized = Image.thumbnail!(image, 200, height: 50, crop: :center)

      assert_images_equal(resized, validate_path)
    end

    test "Raises if path is not found" do
      assert_raise Image.Error, fn ->
        Image.thumbnail!("some-non-existing-path", 200)
      end
    end

    @tag :full
    test "Resize to fill with none crop", %{image: image} do
      validate_path = validate_path("resize/kamchatka_fill_none.png")

      resized = Image.thumbnail!(image, 200, height: 50, crop: :none)

      assert_images_equal(resized, validate_path)
    end
  end
end
