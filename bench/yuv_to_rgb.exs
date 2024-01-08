raw_yuv_file = Path.expand("/Users/kip/Desktop/image.yuv")
{:ok, f} = File.open(raw_yuv_file)
data = IO.binread(f, :all)
decoded = Image.YUV.decode(data, 1920, 1080, :C420)

Benchee.run(
  %{
    "Converting YUV to RGB" => fn ->
      {:ok, i} = Image.YUV.to_rgb(decoded, 1920, 1080, :C420, :bt601)
    end,
    "Decoding and then converting YUV to RGB" => fn ->
      decoded = Image.YUV.decode(data, 1920, 1080, :C420)
      {:ok, i} = Image.YUV.to_rgb(decoded, 1920, 1080, :C420, :bt601)
    end,
    },
  time: 20,
  memory_time: 2
)