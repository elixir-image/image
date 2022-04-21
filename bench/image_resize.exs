image_path = Path.expand("test/support/images/Kamchatka-2019-8754.jpg")

Benchee.run(
  %{
    "Resize to fit from 1000x542 to 50% size" => fn ->
      {:ok, image} = Image.open(image_path)
      {:ok, image} = Image.resize(image, 500)
      {:ok, buffer} = Vix.Vips.Image.write_to_buffer(image, ".jpg")
    end,
    "Resize to fit from 1000x542 to 25% size" => fn ->
      {:ok, image} = Image.open(image_path)
      {:ok, image} = Image.resize(image, 250)
      {:ok, buffer} = Vix.Vips.Image.write_to_buffer(image, ".jpg")
    end
    },
  time: 10,
  memory_time: 2
)