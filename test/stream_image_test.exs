if match?({:module, _module}, Code.ensure_compiled(Plug)) do
  defmodule StreamImage.Test do
    use ExUnit.Case, async: true

    import Plug.Test
    import Image.TestSupport

    setup do
      Temp.track!()
      dir = Temp.mkdir!()
      {:ok, %{dir: dir}}
    end

    test "Filename from a streamed image is nil" do
      assert nil ==
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.filename()
    end

    test "Stream an image for reading", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)

      assert {:ok, _image} =
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.write(out_path)
    end

    test "Stream an image for writing", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      stream = File.stream!(out_path, 2048, [])

      assert {:ok, _image} =
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.write(stream, suffix: ".jpg")
    end

    test "Stream an image for writing with invalid writer options", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      stream = File.stream!(out_path, 2048, [])

      assert {:error, %Image.Error{}} =
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.write(stream, suffix: ".invalid")
    end

    test "Stream an image for writing infers the suffix from the path", %{dir: dir} do
      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      stream = File.stream!(out_path, 2048, [])

      assert {:ok, _image} =
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.write(stream)
    end

    test "Stream an image for writing with no suffix and no path extension", %{dir: dir} do
      out_path = Temp.path!(basedir: dir)
      stream = File.stream!(out_path, 2048, [])

      assert {:error, %Image.Error{}} =
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.write(stream)
    end

    test "Stream an image into a Plug.Conn" do
      conn =
        :get
        |> conn("/")
        |> Plug.Conn.send_chunked(200)

      assert {:ok, _image} =
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.write(conn, suffix: ".jpg")
    end

    test "Image.stream! into a Plug.Conn" do
      conn =
        :get
        |> conn("/")
        |> Plug.Conn.send_chunked(200)

      assert %Plug.Conn{} =
               image_path("Singapore-2016-09-5887.jpg")
               |> File.stream!(2048, [])
               |> Image.open!()
               |> Image.thumbnail!(200)
               |> Image.stream!(suffix: ".jpg")
               |> Enum.reduce_while(conn, fn chunk, conn ->
                 case Plug.Conn.chunk(conn, chunk) do
                   {:ok, conn} ->
                     {:cont, conn}

                   {:error, :closed} ->
                     {:halt, conn}
                 end
               end)
    end

    test "Streaming without a :suffix raises" do
      assert_raise Image.Error, ~r"The option :suffix must be provided", fn ->
        image_path("Singapore-2016-09-5887.jpg")
        |> File.stream!(2048, [])
        |> Image.open!()
        |> Image.thumbnail!(200)
        |> Image.stream!()
      end
    end

    # test "Streaming from a req async response" do
    #   url = "https://files.amoi.no/dog.webp"
    #   assert {:ok, %Vix.Vips.Image{}} = Image.from_req_stream(url)
    # end
  end
end
