image_path = Path.expand("test/support/images/Kamchatka-2019-8754.jpg")
Temp.track!()
temp_dir = Temp.mkdir!()

Benchee.run(
  %{
    "Image resize to fit from 1000x542 to 25% size" => fn ->
      {:ok, image} = Image.open(image_path)
      {:ok, image} = Image.resize(image, 250)

      out_path = Temp.path!(suffix: ".jpg", basedir: temp_dir)
      :ok = Image.write(image, out_path)
    end,
    "Mogrify resize to fit from 1000x542 to 25% size" => fn ->
      out_path = Temp.path!(suffix: ".jpg", basedir: temp_dir)

      image_path
      |> Mogrify.open()
      |> Mogrify.resize("250x")
      |> Mogrify.save(path: out_path)
    end
    },
  time: 10,
  memory_time: 2
)