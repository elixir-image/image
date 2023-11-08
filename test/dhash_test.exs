defmodule Image.Dhash.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "that two images compare equally with dhash" do
    i1_path = image_path("Kamchatka-2019-8754.jpg")
    {:ok, i1} = Image.open(i1_path, access: :random)

    assert {:ok, <<227, 127, 61, 34, 206, 143, 156, 122>>} = Image.dhash(i1)
    assert {:ok, 0} == Image.hamming_distance(i1, i1)
  end

  test "two images produce different dhash" do
    i1_path = image_path("Kamchatka-2019-8754.jpg")
    {:ok, i1} = Image.open(i1_path, access: :random)

    cat_path = image_path("cat.png")
    {:ok, cat} = Image.open(cat_path, access: :random)
    {:ok, i2} = Image.compose!(i1, cat, x: :middle, y: :center) |> Image.flatten()

    assert {:ok, <<227, 127, 61, 34, 206, 143, 156, 122>>} == Image.dhash(i1)
    assert {:ok, <<227, 111, 13, 78, 206, 151, 148, 122>>} == Image.dhash(i2)
    assert {:ok, 10} == Image.hamming_distance(i1, i2)
  end

end