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

    validate = Image.open!(validate)
    calculated = Image.open!(calculated)
    compared = calculated == validate

    case Operation.min!(compared, size: 1) do
      {255.0, _} -> assert true
      _other -> flunk("images did not match")
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
