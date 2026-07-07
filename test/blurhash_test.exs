defmodule Image.BlurhashTest do
  use ExUnit.Case, async: true

  describe "decode/3 error handling" do
    test "returns an error for characters outside the base83 alphabet" do
      # Regression: decode_char/1 had no fallback clause, so any character
      # outside the base83 alphabet raised FunctionClauseError.
      assert {:error, %Image.Error{message: "Invalid blurhash"}} =
               Image.Blurhash.decode("!!!!!!", 10, 10)
    end

    test "returns an error for a truncated blurhash" do
      assert {:error, %Image.Error{message: "Invalid blurhash"}} =
               Image.Blurhash.decode("L", 10, 10)
    end

    test "returns an error for an empty blurhash" do
      assert {:error, %Image.Error{message: "Invalid blurhash"}} =
               Image.Blurhash.decode("", 10, 10)
    end
  end

  describe "encode/2 then decode/3 round trip" do
    test "decodes an encoded blurhash" do
      {:ok, image} = Image.open("./test/support/images/Kip_small.jpg")
      {:ok, blurhash} = Image.Blurhash.encode(image)

      assert {:ok, %Vix.Vips.Image{} = decoded} = Image.Blurhash.decode(blurhash, 40, 20)
      assert Image.width(decoded) == 40
      assert Image.height(decoded) == 20
    end
  end
end
