if String.starts_with?(to_string(:erlang.system_info(:system_architecture)), "x86_64") do
  defmodule Image.Resize.Test do
    use ExUnit.Case
    import Image.TestSupport

    alias Vix.Vips.Image, as: Vimage

    setup do
      Temp.track!()
      dir = Temp.mkdir!()
      {:ok, %{dir: dir}}
    end

    test "Resize to fit", %{dir: dir} do
      image = image_path("Kamchatka-2019-8754.jpg")
      {:ok, image} = Vimage.new_from_file(image)

      {:ok, resized} = Image.resize(image, 200)

      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      validate_path = validate_path("resize/kamchatka_fit.jpg")

      assert :ok = Vimage.write_to_file(resized, out_path)

      assert_files_equal(out_path, validate_path)
    end

    test "Resize to fill with attention crop", %{dir: dir} do
      image = image_path("Kamchatka-2019-8754.jpg")
      {:ok, image} = Vimage.new_from_file(image)

      {:ok, resized} = Image.resize(image, 200, height: 50, crop: :attention)

      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      validate_path = validate_path("resize/kamchatka_fill.jpg")

      assert {:ok, _image} = Image.write(resized, out_path, quality: 50)

      assert_files_equal(out_path, validate_path)
    end

    test "Resize to fill with low crop", %{dir: dir} do
      image = image_path("Kamchatka-2019-8754.jpg")
      {:ok, image} = Vimage.new_from_file(image)

      {:ok, resized} = Image.resize(image, 200, height: 50, crop: :low)

      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      validate_path = validate_path("resize/kamchatka_fill_low.jpg")

      assert :ok = Vimage.write_to_file(resized, out_path)

      assert_files_equal(out_path, validate_path)
    end

    test "Resize to fill with high crop", %{dir: dir} do
      image = image_path("Kamchatka-2019-8754.jpg")
      {:ok, image} = Vimage.new_from_file(image)

      {:ok, resized} = Image.resize(image, 200, height: 50, crop: :high)

      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      validate_path = validate_path("resize/kamchatka_fill_high.jpg")

      assert :ok = Vimage.write_to_file(resized, out_path)

      assert_files_equal(out_path, validate_path)
    end

    test "Resize to fill with center crop", %{dir: dir} do
      image = image_path("Kamchatka-2019-8754.jpg")
      {:ok, image} = Vimage.new_from_file(image)

      {:ok, resized} = Image.resize(image, 200, height: 50, crop: :center)

      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      validate_path = validate_path("resize/kamchatka_fill_center.jpg")

      assert :ok = Vimage.write_to_file(resized, out_path)

      assert_files_equal(out_path, validate_path)
    end

    test "Resize to fill with none crop", %{dir: dir} do
      image = image_path("Kamchatka-2019-8754.jpg")
      {:ok, image} = Vimage.new_from_file(image)

      {:ok, resized} = Image.resize(image, 200, height: 50, crop: :none)

      out_path = Temp.path!(suffix: ".jpg", basedir: dir)
      validate_path = validate_path("resize/kamchatka_fill_none.jpg")

      assert :ok = Vimage.write_to_file(resized, out_path)

      assert_files_equal(out_path, validate_path)
    end
  end
end