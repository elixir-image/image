defmodule Image.TestSupport do
  import ExUnit.Assertions
  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  @images_path Path.join(__DIR__, "images")
  @validate_path Path.join(__DIR__, "validate")

  def assert_files_equal(expected, result) do
    assert File.read!(expected) == File.read!(result)
  end

  def assert_images_equal(%Vimage{} = calculated, validate) when is_binary(validate) do
    validate = Image.open!(validate)
    assert calculated == validate
  end

  def assert_images_equal(calculated, validate) when is_binary(calculated) and is_binary(validate) do
    use Image.Math

    validate_image = Image.open!(validate, access: :random)
    calculated_image = Image.open!(calculated, access: :random)
    compared = calculated_image == validate_image

    case Operation.min!(compared, size: 1) do
      {255.0, _} ->
        assert true

      other ->
        path = String.replace(validate, "validate", "did_not_match")
        Image.write!(compared, path)
        flunk("images did not match: #{inspect other}")
    end
  end

  def assert_images_equal(%Vimage{} = calculated, %Vimage{} = validate) do
    use Image.Math

    assert calculated == validate
  end

  def image_path(name) do
    Path.join(@images_path, name)
  end

  def validate_path(name) do
    Path.join(@validate_path, name)
  end
end
