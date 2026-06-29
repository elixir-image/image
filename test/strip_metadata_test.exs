defmodule Image.StripMetadataTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  # Counts the number of EXIF/XMP metadata fields present on the image
  # at `path` after reloading it from disk.
  defp metadata_field_count(path) do
    {:ok, image} = Image.open(path, access: :random)
    {:ok, names} = Vimage.header_field_names(image)
    Enum.count(names, &(&1 =~ ~r/exif|xmp/i))
  end

  defp out(name) do
    unique = System.unique_integer([:positive])
    path = Path.join(System.tmp_dir!(), "image_strip_test_#{unique}_#{name}")
    on_exit(fn -> File.rm(path) end)
    path
  end

  describe "strip_metadata: true when writing to a file path" do
    test "removes EXIF/XMP metadata from a JPEG" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"), access: :random)

      kept = out("keep.jpg")
      stripped = out("strip.jpg")

      assert {:ok, _} = Image.write(image, kept, strip_metadata: false)
      assert {:ok, _} = Image.write(image, stripped, strip_metadata: true)

      # The source image genuinely has metadata, and not stripping retains it.
      assert metadata_field_count(kept) > 0
      # Stripping on a file path must actually remove it.
      assert metadata_field_count(stripped) == 0
      assert File.stat!(stripped).size < File.stat!(kept).size
    end

    test "removes EXIF/XMP metadata from a PNG" do
      {:ok, image} = Image.open(image_path("jose.png"), access: :random)

      kept = out("keep.png")
      stripped = out("strip.png")

      assert {:ok, _} = Image.write(image, kept, strip_metadata: false)
      assert {:ok, _} = Image.write(image, stripped, strip_metadata: true)

      assert metadata_field_count(kept) > 0
      assert metadata_field_count(stripped) == 0
    end
  end

  describe "minimize_file_size: true when writing to a file path" do
    test "removes EXIF/XMP metadata from a JPEG" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"), access: :random)

      stripped = out("min.jpg")
      assert {:ok, _} = Image.write(image, stripped, minimize_file_size: true)
      assert metadata_field_count(stripped) == 0
    end

    test "removes EXIF/XMP metadata from a PNG" do
      {:ok, image} = Image.open(image_path("jose.png"), access: :random)

      stripped = out("min.png")
      assert {:ok, _} = Image.write(image, stripped, minimize_file_size: true)
      assert metadata_field_count(stripped) == 0
    end
  end

  describe "strip_metadata when writing to :memory" do
    # already worked, guards against regression

    test "removes EXIF/XMP metadata from a JPEG buffer" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"), access: :random)

      {:ok, kept} = Image.write(image, :memory, suffix: ".jpg", strip_metadata: false)
      {:ok, stripped} = Image.write(image, :memory, suffix: ".jpg", strip_metadata: true)

      assert byte_size(stripped) < byte_size(kept)
    end
  end
end
