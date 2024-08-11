# Generate random colored circles and place them randomly on
# an image

width = 1000
height = 500
circles = 1_000
radius = 3

cx = fn width -> Enum.random((1 + radius)..(width - radius)) end
cy = fn height -> Enum.random((1 + radius)..(height - radius)) end
color = fn -> [Enum.random(1..255), Enum.random(1..255), Enum.random(1..255)] end

{:ok, image} = Image.new(width, height, bands: 3, color: :white)

{time, {:ok, image}} = :timer.tc fn ->
  Vix.Vips.Image.mutate image, fn mut_img ->
    Enum.each(1..circles, fn _circle ->
      :ok = Vix.Vips.MutableOperation.draw_circle(mut_img,
        color.(),
        cx.(width),
        cy.(height),
        radius,
        fill: true)
    end)
  end
end

{:ok, _} = Image.write(image, "test/perf/circles.png")
IO.puts "#{time / 1_000} milliseconds to generate and add #{circles} random circles to an image"
