defmodule ForDialyzer do
  # Juse to exorcise dialyzer errors. This module is not included
  # in the library published to hex.pm.

  def compose do
    small_kip = Image.open!("./test/support/images/Kip_small.jpg")

    texts = [
      {Image.Text.text!("hello", text_fill_color: :darkslategray, padding: 10), x: :center, y: :middle},
      {Image.Text.text!("world", text_fill_color: :darkslategray, padding: 10), dy: 12}
    ]

    Image.compose!(small_kip, texts)
  end

  def embed do
    penguin = Image.open!("./test/support/images/penguin_with_alpha.png")
    {width, height, _bands} = Image.shape(penguin)

    {:ok, _embed_1} = Image.embed(penguin, width, height + 50, extend_mode: :black)
    {:ok, _embed_1} = Image.embed(penguin, width, height + 50, x: 0, y: 0, extend_mode: :black, background_transparency: :transparent)
    {:ok, _embed_1} = Image.embed(penguin, width, height + 50, x: 0, y: 0, extend_mode: :black, background_transparency: :opaque)
    {:ok, _embed_1} = Image.embed(penguin, width, height + 50, x: 0, y: 0, extend_mode: :background, background_color: :green)

  end

  def open do
    Image.open! "./test/support/images/animated.gif", pages: -1
    Image.open! "./test/support/images/animated.gif", pages: :all
  end

  def avatar do
    small_kip = Image.open!("./test/support/images/Kip_small.jpg")
    Image.avatar(small_kip, size: 256)
  end

  def write do
    small_kip = Image.open!("./test/support/images/Kip_small.jpg")
    _ = Image.write!(small_kip, :memory)
  end

  def kmeans do
    small_kip = Image.open!("./test/support/images/Kip_small.jpg")
    _ = Image.kmeans(small_kip)
  end
end