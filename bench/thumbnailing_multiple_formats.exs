image_path = Path.expand("test/support/images/Singapore-2016-09-5887.jpg")
dims = "500x200"

Benchee.run(
  %{
    "Image.open |> Image.thumbnail" => fn ->
      image =
        image_path
        |> Image.open!(access: :random)
        |> Image.thumbnail!(dims)

      Image.write!(image, :memory, suffix: ".jpg")
      Image.write!(image, :memory, suffix: ".png")
      Image.write!(image, :memory, suffix: ".tiff")
      Image.write!(image, :memory, suffix: ".heic")
      Image.write!(image, :memory, suffix: ".webp")
    end,

    "Image.thumbnail(path)" => fn ->
      Image.thumbnail!(image_path, dims) |> Image.write!(:memory, suffix: ".jpg")
      Image.thumbnail!(image_path, dims) |> Image.write!(:memory, suffix: ".png")
      Image.thumbnail!(image_path, dims) |> Image.write!(:memory, suffix: ".tiff")
      Image.thumbnail!(image_path, dims) |> Image.write!(:memory, suffix: ".heic")
      Image.thumbnail!(image_path, dims) |> Image.write!(:memory, suffix: ".webp")
    end
    },
  time: 20,
  memory_time: 2
)