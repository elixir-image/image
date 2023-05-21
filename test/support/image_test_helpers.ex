defmodule Image.TestSupport do
  import ExUnit.Assertions
  alias Vix.Vips.Image, as: Vimage

  @images_path Path.join(__DIR__, "images")
  @validate_path Path.join(__DIR__, "validate")
  @acceptable_similarity 1.1

  @dialyzer {:nowarn_function, {:assert_files_equal, 2}}
  def assert_files_equal(expected, result) do
    assert File.read!(expected) == File.read!(result)
  end

  @dialyzer {:nowarn_function, {:assert_images_equal, 2}}
  @dialyzer {:nowarn_function, {:assert_images_equal, 3}}

  def assert_images_equal(calculated_image, validate, similarity \\ @acceptable_similarity)

  def assert_images_equal(%Vimage{} = calculated_image, validate, similarity)
      when is_binary(validate) do
    validate_image = Image.open!(validate, access: :random)
    compare_images(calculated_image, validate_image, similarity)
  end

  def assert_images_equal(calculated, validate, similarity)
      when is_binary(calculated) and is_binary(validate) do
    validate_image = Image.open!(validate, access: :random)
    calculated_image = Image.open!(calculated, access: :random)

    compare_images(calculated_image, validate_image, similarity)
  end

  def assert_images_equal(%Vimage{} = calculated, %Vimage{} = validate, similarity) do
    compare_images(calculated, validate, similarity)
  end

  def image_path(name) do
    Path.join(@images_path, name)
  end

  def validate_path(name) do
    Path.join(@validate_path, name)
  end

  # From: https://github.com/libvips/libvips/discussions/2232
  # Calculate a single number for the match between two images, calculate the sum
  # of squares of differences,
  @dialyzer {:nowarn_function, {:compare_images, 3}}
  def compare_images(calculated_image, validate_image, acceptable_similarity) do
    alias Image.Math
    validate_path = Image.filename(validate_image)

    {calculated_image, validate_image} =
      if Vimage.format(calculated_image) == Vimage.format(validate_image) do
        {calculated_image, validate_image}
      else
        {
          Vix.Vips.Operation.cast!(calculated_image, :VIPS_FORMAT_UCHAR),
          Vix.Vips.Operation.cast!(validate_image, :VIPS_FORMAT_UCHAR)
        }
      end

    similarity =
      calculated_image
      |> Math.subtract!(validate_image)
      |> Math.pow!(2)
      |> Vix.Vips.Operation.avg!()

    if similarity < acceptable_similarity do
      assert true
    else
      path = String.replace(validate_path, "validate", "did_not_match")

      comparison_image =
        Vix.Vips.Operation.relational!(
          calculated_image,
          validate_image,
          :VIPS_OPERATION_RELATIONAL_EQUAL
        )

      Image.write!(comparison_image, path)

      flunk(
        "Calculated image did not match pre-existing validation image. " <>
          "Similarity score was #{inspect(similarity)}. " <>
          "See the image at #{path} for the image diff."
      )
    end
  end
end
