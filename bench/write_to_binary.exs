# THis is a 1920 x 1080 image
video_image_tif = Image.open!(Path.expand("./test/support/images/video_image.tif"))

video_image_jpg = Image.open!(Path.expand("./test/support/images/video_image.jpg"))

{:ok, video_image_yuv} =
  Image.YUV.new_from_file(Path.expand("./test/support/images/image.yuv"), 1920, 1080, :C420, :bt601)

one_band = video_image_tif[0]

# Black image
{:ok, black} = Vix.Vips.Operation.black(1920, 1080, bands: 3)


Benchee.run(
  %{
    "Write full TIF image to binary" => fn ->
      {:ok, _} = Vix.Vips.Image.write_to_binary(video_image_tif)
    end,

    "Write full JPG image to binary" => fn ->
      {:ok, _} = Vix.Vips.Image.write_to_binary(video_image_jpg)
    end,

    "Write full YUV image to binary" => fn ->
      {:ok, _} = Vix.Vips.Image.write_to_binary(video_image_yuv)
    end,

    "Write one band to binary" => fn ->
      {:ok, _} = Vix.Vips.Image.write_to_binary(one_band)
    end,

    "Write a generated black image" => fn ->
      {:ok, _} = Vix.Vips.Image.write_to_binary(black)
    end

  },
  time: 20,
  memory_time: 2
)