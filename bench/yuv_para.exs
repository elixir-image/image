raw_yuv_file = Path.expand("./test/support/images/image.yuv")
{:ok, yuv} = File.read(raw_yuv_file)

fun = fn ->
  {:ok, rgb} = Image.YUV.new_from_binary(yuv, 1920, 1080, :C420)
  {:ok, yuv} = Image.YUV.write_to_binary(rgb, :C420)
end

Benchee.run(%{
    convert: fn ->
      {:ok, rgb} = Image.YUV.new_from_binary(yuv, 1920, 1080, :C420)
      {:ok, yuv} = Image.YUV.write_to_binary(rgb, :C420)
    end,
    convert_20: fn ->
      [
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun)
      ]
      |> Task.await_many()
    end,

    convert_10: fn ->
      [
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun),
        Task.async(fun)
      ]
      |> Task.await_many()
    end
})