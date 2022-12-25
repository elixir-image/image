if Code.ensure_loaded?(Vix.Vips.Operation) && function_exported?(Vix.Vips.Operation, :fwfft!, 1) do
  defmodule Image.Skew.Test do
    use ExUnit.Case, async: true
    import Image.TestSupport

    test "Autorotate an image based upon the skew angle" do
      image = image_path("skewed.jpg")
      validate_path = validate_path("skew_correction.tif")

      {:ok, image} = Image.open(image, access: :random)

      skew_angle = Image.skew_angle(image)
      {:ok, straight} = Image.rotate(image, skew_angle)

      assert_in_delta skew_angle, 1.1628, 0.0001
      assert_images_equal(straight, validate_path)
    end
  end
end
