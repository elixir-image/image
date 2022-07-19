if Code.ensure_loaded?(Plug) do
  defmodule StreamImage.Test do
    use ExUnit.Case, async: true
    use Plug.Test

    import Image.TestSupport

    @s3_buffer_size 5 * 1024 * 1024

    setup do
      Temp.track!()
      dir = Temp.mkdir!()
      {:ok, %{dir: dir}}
    end

    test "Filename from a streamed image is nil" do
      assert nil ==
        image_path("Singapore-2016-09-5887.jpg")
        |> File.stream!([], 2048)
        |> Image.open!()
        |> Image.filename()
    end

    test "Stream an image for reading", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)

      assert {:ok, _image} =
        image_path("Singapore-2016-09-5887.jpg")
        |> File.stream!([], 2048)
        |> Image.open!()
        |> Image.resize!(200)
        |> Image.write(out_path)
    end

    test "Stream an image for writing", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      stream = File.stream!(out_path, [], 2048)

      assert {:ok, _image} =
        image_path("Singapore-2016-09-5887.jpg")
        |> File.stream!([], 2048)
        |> Image.open!()
        |> Image.resize!(200)
        |> Image.write(stream, suffix: ".jpg")
    end

    test "Stream an image for writing with invalid writer options", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      stream = File.stream!(out_path, [], 2048)

      assert {:error, _reason} =
        image_path("Singapore-2016-09-5887.jpg")
        |> File.stream!([], 2048)
        |> Image.open!()
        |> Image.resize!(200)
        |> Image.write(stream, suffix: ".invalid")
    end

    test "Stream an image for writing with no suffix provided", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      stream = File.stream!(out_path, [], 2048)

      assert {:error, _reason} =
        image_path("Singapore-2016-09-5887.jpg")
        |> File.stream!([], 2048)
        |> Image.open!()
        |> Image.resize!(200)
        |> Image.write(stream)
    end

    test "Stream an image into a Plug.Conn" do
      conn =
        :get
        |> conn("/")
        |> Plug.Conn.send_chunked(200)

      assert %Plug.Conn{} =
        image_path("Singapore-2016-09-5887.jpg")
        |> File.stream!([], 2048)
        |> Image.open!()
        |> Image.resize!(200)
        |> Image.write(conn, suffix: ".jpg")
    end

    test "Image.stream! into a Plug.Conn" do
      conn =
        :get
        |> conn("/")
        |> Plug.Conn.send_chunked(200)

      assert %Plug.Conn{} =
        image_path("Singapore-2016-09-5887.jpg")
        |> File.stream!([], 2048)
        |> Image.open!()
        |> Image.resize!(200)
        |> Image.stream!(suffix: ".jpg")
        |> Enum.reduce_while(conn, fn (chunk, conn) ->
          case Plug.Conn.chunk(conn, chunk) do
            {:ok, conn} ->
              {:cont, conn}
            {:error, :closed} ->
              {:halt, conn}
          end
        end)
    end

    if System.find_executable("minio") do
      test "Streaming from minio", %{dir: dir} do
        out_path = Temp.path!(suffix: ".jpg", basedir: dir)

        assert {:ok, _image} =
          ExAws.S3.download_file("images", "Hong-Kong-2015-07-1998.jpg", :memory)
          |> ExAws.stream!
          |> Image.open!()
          |> Image.resize!(200)
          |> Image.write(out_path)
      end

      test "Streaming from minio into a file stream", %{dir: dir} do
        out_path = Temp.path!(suffix: ".jpg", basedir: dir)
        stream = File.stream!(out_path, [], 2048)

        assert {:ok, _image} =
          ExAws.S3.download_file("images", "Hong-Kong-2015-07-1998.jpg", :memory)
          |> ExAws.stream!
          |> Image.open!()
          |> Image.resize!(200)
          |> Image.write(stream, suffix: ".jpg")
      end

      test "Streaming from minio then into non-streamed minio", %{dir: dir} do
        out_path = Temp.path!(suffix: ".jpg", basedir: dir)

        {:ok, buffer} =
          ExAws.S3.download_file("images", "Hong-Kong-2015-07-1998.jpg", :memory)
          |> ExAws.stream!
          |> Image.open!()
          |> Image.resize!(200)
          |> Image.write(:memory, suffix: ".jpg")

        assert {:ok, _} =
          ExAws.S3.put_object("images", out_path, buffer)
          |> ExAws.request()
      end

      test "Streaming from a file then into streamed minio", %{dir: dir} do
        out_path = Temp.path!(suffix: ".jpg", basedir: dir)

        assert {:ok, _} =
          image_path("Singapore-2016-09-5887.jpg")
          |> File.stream!([], 2048)
          |> Image.open!()
          |> Image.resize!(200)
          |> Image.stream!(suffix: ".jpg", buffer_size: @s3_buffer_size)
          |> ExAws.S3.upload("images", out_path)
          |> ExAws.request()
      end

      test "Streaming from a file then into streamed minio with exception" do
        assert_raise Image.Error, ~r"The option :suffix must be provided", fn ->
          image_path("Singapore-2016-09-5887.jpg")
          |> File.stream!([], 2048)
          |> Image.open!()
          |> Image.resize!(200)
          |> Image.stream!()
        end
      end

      test "Streaming from minio then into streamed minio", %{dir: dir}  do
        out_path = Temp.path!(suffix: ".jpg", basedir: dir)

        assert {:ok, _} =
          ExAws.S3.download_file("images", "Hong-Kong-2015-07-1998.jpg", :memory)
          |> ExAws.stream!()
          |> Image.open!()
          |> Image.resize!(200)
          |> Image.stream!(suffix: ".jpg", buffer_size: @s3_buffer_size)
          |> ExAws.S3.upload("images", out_path)
          |> ExAws.request()
      end
    end
  end
end