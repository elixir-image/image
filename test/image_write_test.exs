defmodule Image.WriteTest do
  use ExUnit.Case, async: true

  describe "write/3 format-specific options" do
    test "writes a GIF with the :effort option" do
      # Regression: conform_effort/2 had no clause for GIF although the
      # option is documented and admitted for GIF writes.
      image = Image.new!(10, 10, color: :red)

      assert {:ok, _binary} = Image.write(image, :memory, suffix: ".gif", effort: 7)
    end

    test "writing to a File.Stream infers the suffix from the path" do
      # Regression: the README streaming example failed because an
      # explicit :suffix was required even when the File.Stream path
      # carried a usable extension.
      Temp.track!()
      dir = Temp.mkdir!()
      out_path = Path.join(dir, "streamed.jpg")
      image = Image.new!(10, 10, color: :red)

      assert {:ok, _} = Image.write(image, File.stream!(out_path))
      assert File.exists?(out_path)
    end

    test "writing to an extensionless File.Stream still requires :suffix" do
      Temp.track!()
      dir = Temp.mkdir!()
      out_path = Path.join(dir, "streamed_noext")
      image = Image.new!(10, 10, color: :red)

      assert {:error, %Image.Error{}} = Image.write(image, File.stream!(out_path))
      assert {:ok, _} = Image.write(image, File.stream!(out_path), suffix: ".png")
    end

    test "writes a PNG, WEBP, and GIF with boundary :effort values" do
      image = Image.new!(10, 10, color: :red)

      for suffix <- [".png", ".webp", ".gif"], effort <- [1, 10] do
        assert {:ok, _binary} = Image.write(image, :memory, suffix: suffix, effort: effort)
      end
    end
  end
end
