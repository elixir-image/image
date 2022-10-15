defmodule Image.Hash.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Hashing an image" do
    image = image_path("San-Francisco-2018-04-2549.jpg")

    {:ok, hash} =
      image
      |> Image.open!()
      |> Image.dhash()

    assert :erlang.bit_size(hash) == 512
  end

  test "Comparing an image to itself is 0 difference" do
    image = image_path("San-Francisco-2018-04-2549.jpg")
    {:ok, image} = Image.open(image, access: :random)

    assert Image.hamming_distance(image, image) == {:ok, 0}
  end

  test "Comparing an image to cropped version of itself is < 10 difference" do
    image = image_path("San-Francisco-2018-04-2549.jpg")
    {:ok, image} = Image.open(image, access: :random)
    {:ok, image_2} = Image.thumbnail(image, 100)
    {:ok, distance} = Image.hamming_distance(image, image_2)

    assert distance < 10
  end

end