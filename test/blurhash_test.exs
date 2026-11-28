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

    test "returns an Image.Error for every prefix of a valid blurhash" do
      blurhash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj"

      for length <- 0..(String.length(blurhash) - 1) do
        prefix = String.slice(blurhash, 0, length)

        assert {:error, %Image.Error{}} = Image.Blurhash.decode(prefix, 8, 8),
               "expected an Image.Error for #{inspect(prefix)}"
      end
    end

    test "returns an Image.Error for an over-long blurhash" do
      for blurhash <- ["LEHV6nWB2yk8pyo0adR*.7kCMdnjX", String.duplicate("L", 10_000)] do
        assert {:error, %Image.Error{}} = Image.Blurhash.decode(blurhash, 8, 8)
      end
    end

    test "returns an Image.Error for text that is not base83" do
      for blurhash <- ["Lé", "L\0\0\0\0\0", "LEHV6nWB2yk8pyo0adR*.7kCMdn é"] do
        assert {:error, %Image.Error{}} = Image.Blurhash.decode(blurhash, 8, 8)
      end
    end

    test "returns an Image.Error rather than raising for a blurhash that is not a string" do
      for blurhash <- [nil, :"", 42, ~c"LEHV6nWB2yk8pyo0adR*.7kCMdnj"] do
        assert {:error, %Image.Error{reason: :invalid_blurhash, value: ^blurhash}} =
                 Image.Blurhash.decode(blurhash, 8, 8)
      end
    end

    test "returns an Image.Error rather than raising for a size that is not a positive integer" do
      blurhash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj"

      for width <- [0, -1, 1.5, nil, :wide] do
        assert {:error, %Image.Error{reason: :invalid_width, value: ^width}} =
                 Image.Blurhash.decode(blurhash, width, 8)
      end

      for height <- [0, -1, 1.5, nil, :tall] do
        assert {:error, %Image.Error{reason: :invalid_height, value: ^height}} =
                 Image.Blurhash.decode(blurhash, 8, height)
      end
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
