defmodule Image.OptionsDoctestTest do
  use ExUnit.Case, async: true

  # The options modules document validate_options/1..4 with examples
  # that no other test module runs.

  doctest Image.Options.Affine
  doctest Image.Options.Avatar
  doctest Image.Options.Blur
  doctest Image.Options.Blurhash
  doctest Image.Options.ChromaKey
  doctest Image.Options.Compare
  doctest Image.Options.Compose
  doctest Image.Options.Crop
  doctest Image.Options.Draw
  doctest Image.Options.Embed
  doctest Image.Options.Equalize
  doctest Image.Options.Histogram
  doctest Image.Options.Join
  doctest Image.Options.LinearGradient
  doctest Image.Options.LocalContrast
  doctest Image.Options.Mapim
  doctest Image.Options.Meme
  doctest Image.Options.Modulate
  doctest Image.Options.New
  doctest Image.Options.Open
  doctest Image.Options.RadialGradient
  doctest Image.Options.Resize
  doctest Image.Options.Rotate
  doctest Image.Options.Shape
  doctest Image.Options.Sharpen
  doctest Image.Options.Text
  doctest Image.Options.Thumbnail
  doctest Image.Options.ToneCurve
  doctest Image.Options.Trim
  doctest Image.Options.Vibrance
  doctest Image.Options.Vignette
  doctest Image.Options.Write
end
