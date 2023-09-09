image_path = Path.expand("test/support/images/Kamchatka-2019-8754.jpg")
{:ok, image} = Image.open(image_path, access: :random)

Benchee.run(
  %{
    "Image.shape/1" => fn ->
      Image.shape(image)
    end,
    "Vix.Vips.Image.headers/1" => fn ->
      Vix.Vips.Image.headers(image)
    end
    },
  time: 20,
  memory_time: 2
)