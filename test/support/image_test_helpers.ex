defmodule Image.TestSupport do
  import ExUnit.Assertions
  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  @images_path Path.join(__DIR__, "images")
  @validate_path Path.join(__DIR__, "validate")
  @acceptible_similarity 0.97

  def assert_files_equal(expected, result) do
    assert File.read!(expected) == File.read!(result)
  end

  def assert_images_equal(%Vimage{} = calculated_image, validate) when is_binary(validate) do
    validate_image = Image.open!(validate, access: :random)
    compare_images(calculated_image, validate_image)
  end

  def assert_images_equal(calculated, validate)
      when is_binary(calculated) and is_binary(validate) do
    validate_image = Image.open!(validate, access: :random)
    calculated_image = Image.open!(calculated, access: :random)

    compare_images(calculated_image, validate_image)
  end

  def assert_images_equal(%Vimage{} = calculated, %Vimage{} = validate) do
    compare_images(calculated, validate)
  end

  def image_path(name) do
    Path.join(@images_path, name)
  end

  def validate_path(name) do
    Path.join(@validate_path, name)
  end

  defp compare_images(calculated_image, validate_image) do
    use Image.Math

    {calculated_image, validate_image} =
      if Vimage.format(calculated_image) == Vimage.format(validate_image) do
        {calculated_image, validate_image}
      else
        {
          Vix.Vips.Operation.cast!(calculated_image, :VIPS_FORMAT_UCHAR),
          Vix.Vips.Operation.cast!(validate_image, :VIPS_FORMAT_UCHAR)
        }
      end

    # creates an Image (via Image.Math.==) that is white when pixels match, black when pixels don't
    comparison_image = calculated_image == validate_image

    # from 0 (black) to 255 (white), what is the average pixel of that comparison_image?
    average_comparison_pixel = Operation.avg!(comparison_image)

    # what is the percentage similarity?
    similarity_percentage = average_comparison_pixel / 255

    # is the percentage similarity above our defined threshold?
    # NOTE: threshold is defined as "highest value for which all tests pass, at time of writing".
    images_acceptably_similar = similarity_percentage >= @acceptible_similarity

    if images_acceptably_similar do
      assert true
    else
      path =
        validate_image
        |> Image.filename()
        |> String.replace("validate", "did_not_match")

      Image.write!(comparison_image, path)

      flunk("images did not match. \
        They are #{(similarity_percentage * 100) |> trunc()}% similar. \
        This is below our threshold of %{@acceptible_similarity * 100 }% \
        See the image at #{path} for the image diff.")
    end
  end
end
