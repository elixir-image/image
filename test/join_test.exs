defmodule Image.Join.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  @rainbow_colors [
    violet: [148, 0, 211],
    indigo: [75, 0, 130],
    blue: [0, 0, 255],
    green: [0, 255, 0],
    yellow: [255, 255, 0],
    orange: [255, 127, 0],
    red: [255, 0 , 0]
  ]

  @width 64
  @height 64

  def rainbow do
    for color <- Keyword.values(@rainbow_colors) do
      Image.new!(@width, @height, color: color)
    end
  end

  test "Image.join/2" do
    validate_file = "join/rainbow.png"
    validate_path = validate_path(validate_file)

    rainbow = rainbow()
    {:ok, joined} = Image.join(rainbow, across: length(rainbow))

    # {:ok, _image} = Image.write(joined, validate_path)
    assert_images_equal(joined, validate_path)
  end
end