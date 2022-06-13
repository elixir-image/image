defmodule StreamImage.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport

  @moduletag :stream

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