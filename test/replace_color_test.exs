defmodule Image.ReplaceColor.Test do
  use ExUnit.Case, async: true

  test "Replace color retains the DPI (resolution) of the final image" do
    image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
    xres = Vix.Vips.Image.xres(image)
    yres = Vix.Vips.Image.yres(image)

    {:ok, replaced} = Image.replace_color(image, replace_with: 255)
    assert Vix.Vips.Image.xres(replaced) == xres
    assert Vix.Vips.Image.yres(replaced) == yres
  end
end
