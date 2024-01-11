raw_yuv_file = Path.expand("./test/support/images/image.yuv")
{:ok, binary} = File.read(raw_yuv_file)
{:ok, image} = Image.YUV.new_from_binary(binary, 1920, 1080, :C420, :bt601)

# Force the pipeline for `image`
Vix.Vips.Operation.avg!(image)

Benchee.run(
  %{
    "Converting YUV 4:2:0 binary in BT601 to an RGB image" => fn ->
      {:ok, i} = Image.YUV.new_from_binary(binary, 1920, 1080, :C420, :bt601)
      Vix.Vips.Operation.avg!(i)
    end,

    "Converting an RGB image to YUV 4:2:0 binary in BT601" => fn ->
      {:ok, _} = Image.YUV.write_to_binary(image, :C420, :bt601)
    end
  },
  time: 20,
  memory_time: 2
)