defmodule ForDialyzer do
  # Juse to exorcise dialyzer errors. This module is not included
  # in the library.

  def compose do
    small_kip = Image.open!("test/images/Kip_small.jpg")

    texts = [
      {Image.Text.text!("hello", text_fill_color: :darkslategray, padding: 10), x: :center, y: :middle},
      {Image.Text.text!("world", text_fill_color: :darkslategray, padding: 10), dy: 12}
    ]

    Image.compose!(small_kip, texts)
  end
end