if match?({:module, _module}, Code.ensure_compiled(ExAws.S3)) do
  defmodule StreamImage.S3Test do
    # Streams images to and from an S3-compatible endpoint, configured in
    # `config/test.exs`. CI runs Adobe S3Mock as a service container; see
    # guides/development.md for running it locally. Tagged `:s3`, which
    # `test/test_helper.exs` excludes unless `mix test --include s3`.
    use ExUnit.Case, async: true

    import Image.TestSupport

    @moduletag :s3

    @bucket "images"
    @fixture "Hong-Kong-2015-07-1998.jpg"

    # Minimum part size for an S3 multipart upload, except the last part.
    @s3_buffer_size 5 * 1024 * 1024

    setup_all do
      ensure_bucket(@bucket)

      {:ok, _} =
        @fixture
        |> image_path()
        |> ExAws.S3.Upload.stream_file()
        |> ExAws.S3.upload(@bucket, @fixture)
        |> ExAws.request()

      :ok
    end

    setup do
      Temp.track!()
      dir = Temp.mkdir!()
      {:ok, %{dir: dir}}
    end

    test "Streaming from S3", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)

      assert {:ok, _image} =
               ExAws.S3.download_file(@bucket, @fixture, :memory)
               |> ExAws.stream!()
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.write(out_path)
    end

    test "Streaming from S3 into a file stream", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      stream = File.stream!(out_path, 2048, [])

      assert {:ok, _image} =
               ExAws.S3.download_file(@bucket, @fixture, :memory)
               |> ExAws.stream!()
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.write(stream, suffix: ".jpg")
    end

    test "Streaming from S3 then into a non-streamed S3 put" do
      out_path = "test/streaming_from_s3_into_non_streamed_s3.jpg"

      {:ok, buffer} =
        ExAws.S3.download_file(@bucket, @fixture, :memory)
        |> ExAws.stream!()
        |> Image.open!()
        |> Image.thumbnail!(200)
        |> Image.write(:memory, suffix: ".jpg")

      assert {:ok, _} =
               @bucket
               |> ExAws.S3.put_object(out_path, buffer)
               |> ExAws.request()
    end

    test "Streaming from a file then into a streamed S3 upload" do
      out_path = "test/streaming_from_a_file_then_into_streamed_s3.jpg"

      assert {:ok, _} =
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.stream!(suffix: ".jpg", buffer_size: @s3_buffer_size)
               |> ExAws.S3.upload(@bucket, out_path)
               |> ExAws.request()
    end

    test "Streaming from S3 then into a streamed S3 upload with resize" do
      out_path = "test/streaming_from_s3_into_streamed_s3_with_resize.jpg"

      assert {:ok, _} =
               ExAws.S3.download_file(@bucket, @fixture, :memory)
               |> ExAws.stream!()
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.stream!(suffix: ".jpg", buffer_size: @s3_buffer_size)
               |> ExAws.S3.upload(@bucket, out_path)
               |> ExAws.request()
    end

    test "Streaming from S3 then into a streamed S3 upload" do
      out_path = "test/streaming_from_s3_into_streamed_s3.jpg"

      assert {:ok, _} =
               ExAws.S3.download_file(@bucket, @fixture, :memory)
               |> ExAws.stream!()
               |> Image.open!()
               |> Image.stream!(suffix: ".jpg", buffer_size: @s3_buffer_size)
               |> ExAws.S3.upload(@bucket, out_path)
               |> ExAws.request()
    end

    # Creates the bucket unless it already exists, which it does when the
    # server was started with it (S3Mock's initial buckets) or by a
    # previous run against a persistent store.
    defp ensure_bucket(bucket) do
      head =
        bucket
        |> ExAws.S3.head_bucket()
        |> ExAws.request()

      case head do
        {:ok, _} ->
          :ok

        {:error, _} ->
          {:ok, _} =
            bucket
            |> ExAws.S3.put_bucket("us-east-1")
            |> ExAws.request()

          :ok
      end
    end
  end
end
