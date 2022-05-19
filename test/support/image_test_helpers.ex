defmodule Image.TestSupport do
  import ExUnit.Assertions
  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  @images_path Path.join(__DIR__, "images")
  @validate_path Path.join(__DIR__, "validate")

  def assert_files_equal(expected, result) do
    assert File.read!(expected) == File.read!(result)
  end

  def assert_images_equal(%Vimage{} = calculated_image, validate) when is_binary(validate) do
    validate_image = Image.open!(validate)
    compare_images(calculated_image, validate_image)
  end

  def assert_images_equal(calculated, validate) when is_binary(calculated) and is_binary(validate) do
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

    compared = calculated_image == validate_image
    validate_path = Image.filename(validate_image)

    case Operation.min!(compared, size: 1) do
      {255.0, _} ->
        assert true

      other ->
        path = String.replace(validate_path, "validate", "did_not_match")
        Image.write!(compared, path)
        flunk("images did not match: #{inspect other}")
    end
  end
end
