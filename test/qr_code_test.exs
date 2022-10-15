defmodule Image.QRcode.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "QR code detection and decoding" do
    {:ok, image} = Image.open image_path("qrcode/qr_code_con.png")

    assert Image.QRcode.decode(image) == {:ok, "MECARD:N:Joe;EMAIL:Joe@bloggs.com;;"}
  end

  test "QR code detection from an bigger image with embedded QR code" do
    {:ok, image} = Image.open image_path("qrcode/qrcode.webp")

    assert Image.QRcode.decode(image) == {:ok, "http://LearnOpenCV.com"}
  end

  test "QR code detection fails unless the image has three bands" do
    {:ok, image} = Image.open image_path("qrcode/qrcode_orig.png")

    assert Image.QRcode.decode(image) ==
      {:error,
         "Only images with three bands can be transferred to eVision. Found an image of shape {440, 440, 2}"}
  end

  test "QR code detection when there is no qrcode in the image" do
    {:ok, image} = Image.open image_path("Kip_small.png")

    assert Image.QRcode.decode(image) == {:error, "No QRcode detected in the image"}
  end

  test "QR code encoding and roundtrip validation" do
    string = "This is a string"

    {:ok, qrcode} = Image.QRcode.encode(string)
    assert {:ok, ^string} = Image.QRcode.decode(qrcode)
  end
end