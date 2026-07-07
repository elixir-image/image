defmodule Image.ExifTagCoverageTest do
  use ExUnit.Case, async: true

  alias Image.Exif.Tag

  # Tag.value/4 receives the whole EXIF blob (for out-of-line values),
  # the IFD offset (unused by Tag) and a byte-order decoder function.

  defp context(exif_blob \\ <<>>) do
    {exif_blob, 0, &:binary.decode_unsigned(&1, :big)}
  end

  describe "value/4 for byte values (format 1)" do
    test "a single byte value" do
      assert Tag.value(1, 1, <<7, 0, 0, 0>>, context()) == 7
    end

    test "an inline byte array" do
      assert Tag.value(1, 3, <<1, 2, 3, 0>>, context()) == [1, 2, 3]
    end

    test "a byte array longer than four bytes is read from an offset" do
      blob = <<0, 0, 10, 20, 30, 40, 50, 60>>
      assert Tag.value(1, 6, <<0, 0, 0, 2>>, context(blob)) == [10, 20, 30, 40, 50, 60]
    end

    test "a byte array with an out-of-range offset is nil" do
      assert Tag.value(1, 6, <<0, 0, 0, 99>>, context(<<1, 2, 3>>)) == nil
    end
  end

  describe "value/4 for ascii strings (format 2)" do
    test "a zero-count string is empty" do
      assert Tag.value(2, 0, <<0, 0, 0, 0>>, context()) == ""
    end

    test "a short string is stored inline" do
      assert Tag.value(2, 4, "abc" <> <<0>>, context()) == "abc"
    end

    test "a long string is read from an offset" do
      blob = <<0, 0, 0, 0, "hello world", 0>>
      assert Tag.value(2, 12, <<0, 0, 0, 4>>, context(blob)) == "hello world"
    end

    test "a long string with an out-of-range offset is nil" do
      assert Tag.value(2, 12, <<0, 0, 0, 99>>, context(<<1, 2, 3>>)) == nil
    end
  end

  describe "value/4 for unsigned shorts (format 3)" do
    test "a single short value" do
      assert Tag.value(3, 1, <<640::16, 0::16>>, context()) == 640
    end

    test "two shorts fit inline" do
      assert Tag.value(3, 2, <<1::16, 2::16>>, context()) == [1, 2]
    end

    test "three shorts are read from an offset" do
      blob = <<0, 0, 1::16, 2::16, 3::16>>
      assert Tag.value(3, 3, <<0, 0, 0, 2>>, context(blob)) == [1, 2, 3]
    end
  end

  describe "value/4 for unsigned longs (format 4)" do
    test "a single long value" do
      assert Tag.value(4, 1, <<70_000::32>>, context()) == 70_000
    end

    test "multiple longs are read from an offset" do
      blob = <<0, 0, 100::32, 200::32>>
      assert Tag.value(4, 2, <<0, 0, 0, 2>>, context(blob)) == [100, 200]
    end
  end

  describe "value/4 for unsigned rationals (format 5)" do
    test "a rational with denominator 1 is the numerator" do
      blob = <<0, 0, 300::32, 1::32>>
      assert Tag.value(5, 1, <<0, 0, 0, 2>>, context(blob)) == 300
    end

    test "a rational with numerator 1 is a fraction string" do
      blob = <<0, 0, 1::32, 125::32>>
      assert Tag.value(5, 1, <<0, 0, 0, 2>>, context(blob)) == "1/125"
    end

    test "a rational with denominator 0 is infinity" do
      blob = <<0, 0, 5::32, 0::32>>
      assert Tag.value(5, 1, <<0, 0, 0, 2>>, context(blob)) == :infinity
    end

    test "a general rational is rounded to three decimal places" do
      blob = <<0, 0, 28::32, 10::32>>
      assert Tag.value(5, 1, <<0, 0, 0, 2>>, context(blob)) == 2.8

      blob = <<0, 0, 1000::32, 3::32>>
      assert Tag.value(5, 1, <<0, 0, 0, 2>>, context(blob)) == 333.333
    end

    test "a rational array returns a list" do
      blob = <<0, 0, 24::32, 1::32, 70::32, 1::32>>
      assert Tag.value(5, 2, <<0, 0, 0, 2>>, context(blob)) == [24, 70]
    end

    test "a rational with an out-of-range offset is an empty list" do
      assert Tag.value(5, 1, <<0, 0, 0, 99>>, context(<<1, 2, 3>>)) == []
    end

    test "a truncated rational array returns the values read so far" do
      blob = <<0, 0, 24::32, 1::32, 0, 0>>
      assert Tag.value(5, 2, <<0, 0, 0, 2>>, context(blob)) == [24]
    end
  end

  describe "value/4 for undefined bytes (format 7)" do
    test "a single undefined byte" do
      assert Tag.value(7, 1, <<3, 0, 0, 0>>, context()) == 3
    end

    test "four undefined bytes decode to a list" do
      assert Tag.value(7, 4, <<48, 50, 51, 48>>, context()) == [48, 50, 51, 48]
    end

    test "more than four undefined bytes are read from an offset" do
      blob = <<0, 0, 1, 2, 3, 4, 5>>
      assert Tag.value(7, 5, <<0, 0, 0, 2>>, context(blob)) == [1, 2, 3, 4, 5]
    end
  end

  describe "value/4 for signed rationals (format 10)" do
    test "a negative numerator produces a negative result" do
      blob = <<0, 0, 4_294_967_295::32, 3::32>>
      assert Tag.value(10, 1, <<0, 0, 0, 2>>, context(blob)) == -0.333
    end

    test "a negative denominator is interpreted as signed" do
      blob = <<0, 0, 10::32, 4_294_967_292::32>>
      assert Tag.value(10, 1, <<0, 0, 0, 2>>, context(blob)) == -2.5
    end

    test "a positive signed rational decodes like an unsigned one" do
      blob = <<0, 0, 3::32, 2::32>>
      assert Tag.value(10, 1, <<0, 0, 0, 2>>, context(blob)) == 1.5
    end
  end

  describe "value/4 for unknown formats" do
    test "unknown formats are nil" do
      assert Tag.value(0, 1, <<0, 0, 0, 0>>, context()) == nil
      assert Tag.value(6, 1, <<0, 0, 0, 0>>, context()) == nil
      assert Tag.value(99, 1, <<0, 0, 0, 0>>, context()) == nil
    end
  end

  describe "value/4 with a little-endian decoder" do
    test "decodes little-endian shorts" do
      little_context = {<<>>, 0, &:binary.decode_unsigned(&1, :little)}
      assert Tag.value(3, 1, <<640::little-16, 0::16>>, little_context) == 640
    end

    test "decodes little-endian rationals from an offset" do
      blob = <<0, 0, 1::little-32, 125::little-32>>
      little_context = {blob, 0, &:binary.decode_unsigned(&1, :little)}
      assert Tag.value(5, 1, <<2::little-32>>, little_context) == "1/125"
    end
  end
end
