defmodule Image.CopyMemoryTest do
  @moduledoc """
  Tests for `Image.copy_memory/1`.

  See https://github.com/elixir-image/image/issues/175.

  """
  use ExUnit.Case, async: true
  import Image.TestSupport

  setup do
    %{path: image_path("Kip_small.png")}
  end

  describe "Image.copy_memory/1" do
    test "makes a path-sourced thumbnail reusable", %{path: path} do
      thumbnail = Image.thumbnail!(path, 90)

      # A thumbnail taken from a pathname streams from the file using the
      # loader's shrink-on-load support, so it can only be consumed once.
      assert {:ok, _first} = Vix.Vips.Image.write_to_binary(thumbnail)
      assert {:error, _reason} = Vix.Vips.Image.write_to_binary(thumbnail)

      assert {:ok, reusable} = Image.copy_memory(Image.thumbnail!(path, 90))

      assert {:ok, first} = Vix.Vips.Image.write_to_binary(reusable)
      assert {:ok, second} = Vix.Vips.Image.write_to_binary(reusable)
      assert first == second
    end

    test "produces the same pixels as the image it copied", %{path: path} do
      thumbnail = Image.thumbnail!(path, 90)
      {:ok, expected} = Vix.Vips.Image.write_to_binary(thumbnail)

      {:ok, copied} = Image.copy_memory(Image.thumbnail!(path, 90))
      {:ok, actual} = Vix.Vips.Image.write_to_binary(copied)

      assert actual == expected
      assert Image.shape(copied) == Image.shape(thumbnail)
    end

    test "is a no-op for an image that is already reusable" do
      image = Image.new!(20, 20, color: :red)

      assert {:ok, copied} = Image.copy_memory(image)
      assert Image.shape(copied) == Image.shape(image)
      assert Vix.Vips.Image.write_to_binary(copied) == Vix.Vips.Image.write_to_binary(image)
    end

    test "copy_memory!/1 returns the image directly" do
      image = Image.new!(10, 10, color: :blue)

      assert %Vix.Vips.Image{} = copied = Image.copy_memory!(image)
      assert Image.shape(copied) == Image.shape(image)
    end
  end
end
