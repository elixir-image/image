defmodule Image.TestSupport do
  import ExUnit.Assertions

  @images_path Path.join(__DIR__, "images")
  @validate_path Path.join(__DIR__, "validate")

  def assert_files_equal(expected, result) do
    assert File.read!(expected) == File.read!(result)
  end

  def image_path(name) do
    Path.join(@images_path, name)
  end

  def validate_path(name) do
    Path.join(@validate_path, name)
  end
end
