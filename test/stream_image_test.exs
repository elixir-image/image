defmodule StreamImage.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
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
      |> Image.write(stream)
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
  end

end