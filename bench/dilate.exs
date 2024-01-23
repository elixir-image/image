i = Image.open! "/Users/kip/Desktop/dilate_image.png"

Benchee.run(
  %{
    "Image.dilate/1" => fn ->
      Image.dilate!(i)
      |> Image.write("/tmp/dilate.png")
    end
    },
  time: 30,
  memory_time: 2
)