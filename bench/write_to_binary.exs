# THis is a 1920 x 1080 image
raw_yuv_file = Path.expand("./test/support/images/image.yuv")
{:ok, binary} = File.read(raw_yuv_file)
{:ok, image} = Image.YUV.new_from_binary(binary, 1920, 1080, :C420, :bt601)
one_band = image[0]

Benchee.run(
  %{
    "Write full image to binary" => fn ->
      {:ok, _} = Vix.Vips.Image.write_to_binary(image)
    end,

    "Write one band to binary" => fn ->
      {:ok, _} = Vix.Vips.Image.write_to_binary(image)
    end
  },
  time: 20,
  memory_time: 2
)