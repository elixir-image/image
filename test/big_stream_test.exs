defmodule Image.BigStream.Test do
  use ExUnit.Case, async: true

  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  @s3_buffer_size 5 * 1024 * 1024
  @resize 7.839

  @spec stream!(Vimage.t(), options :: Options.Write.image_write_options()) :: Enumerable.t()
  def stream!(%Vimage{} = image, options \\ []) do
    {suffix, options} = Keyword.pop(options, :suffix)
    {buffer_size, _options} = Keyword.pop(options, :buffer_size, :unbuffered)

    stream = Vimage.write_to_stream(image, suffix)

    if buffer_size == :unbuffered || buffer_size == 0 do
      stream
    else
      buffer!(stream, buffer_size)
    end
  end

  # Rebuffers a stream into chunks of a minimum size.
  # This is useful when streaming to AWS S3 which requires
  # a minimum 5 MiB chunk size for multi-part uploads.

  defp buffer!(stream, buffer_size) do
    chunker = fn bin, acc ->
      acc_size = IO.iodata_length(acc)

      if IO.iodata_length(bin) + acc_size >= buffer_size do
        size = buffer_size - acc_size
        <<chunk::binary-size(size), rest::binary>> = bin
        {:cont, IO.iodata_to_binary([acc, chunk]), [rest]}
      else
        {:cont, [acc, bin]}
      end
    end

    final = fn
      [] -> {:cont, []}
      acc -> {:cont, IO.iodata_to_binary(acc), []}
    end

    Stream.chunk_while(stream, [], chunker, final)
  end

  test "Streaming from file then into streamed minio with HUGE resize" do
    out_path = "test/huge_streaming_test.jpg"
    in_path = "./test/support/images/Hong-Kong-2015-07-1998.jpg"

    {:ok, image_stream} =
      in_path
      |> File.stream!()
      |> Vimage.new_from_enum()

    image_stream
    |> Operation.resize!(@resize)
    |> stream!(suffix: ".jpg", buffer_size: @s3_buffer_size)
    |> ExAws.S3.upload("images", out_path)
    |> ExAws.request()
  end

  test "Streaming from file then into memory with HUGE resize" do
    in_path = "./test/support/images/Hong-Kong-2015-07-1998.jpg"

    {:ok, image_stream} =
      in_path
      |> File.stream!()
      |> Vimage.new_from_enum()

    image_stream
    |> Operation.resize!(@resize)
    |> stream!(suffix: ".jpg", buffer_size: @s3_buffer_size)
    |> Stream.into(<<>>)
  end

end