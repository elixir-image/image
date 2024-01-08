raw_yuv_file = Path.expand("./test/support/images/image.yuv")
{:ok, binary} = File.read(raw_yuv_file)

Benchee.run(
  %{
    "Converting YUV binary to an RGB image" => fn ->
      {:ok, _i} = Image.YUV.new_from_binary(binary, 1920, 1080, :C420, :bt601)
    end,
    },
  time: 20,
  memory_time: 2
)