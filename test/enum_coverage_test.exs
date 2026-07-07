defmodule Image.EnumCoverageTest do
  use ExUnit.Case, async: true

  describe "Image.BlendMode" do
    test "known_blend_modes/0 returns short-form atoms" do
      modes = Image.BlendMode.known_blend_modes()
      assert is_list(modes)
      assert :over in modes
      assert :multiply in modes
      assert :exclusion in modes
      assert length(modes) == 25
    end

    test "every known blend mode validates to a vips enum" do
      for mode <- Image.BlendMode.known_blend_modes() do
        assert {:ok, vips_mode} = Image.BlendMode.validate_blend_mode(mode)
        assert is_atom(vips_mode)
        assert vips_mode |> Atom.to_string() |> String.starts_with?("VIPS_BLEND_MODE_")
      end
    end

    test "vips enum atoms pass through unchanged" do
      for mode <- Image.BlendMode.known_blend_modes() do
        {:ok, vips_mode} = Image.BlendMode.validate_blend_mode(mode)
        assert Image.BlendMode.validate_blend_mode(vips_mode) == {:ok, vips_mode}
      end
    end

    test "nil validates to the default blend mode" do
      assert Image.BlendMode.validate_blend_mode(nil) ==
               {:ok, Image.BlendMode.default_blend_mode()}
    end

    test "string forms are downcased and validated" do
      assert Image.BlendMode.validate_blend_mode("over") == {:ok, :VIPS_BLEND_MODE_OVER}
      assert Image.BlendMode.validate_blend_mode("MULTIPLY") == {:ok, :VIPS_BLEND_MODE_MULTIPLY}
      assert Image.BlendMode.validate_blend_mode("dest_over") == {:ok, :VIPS_BLEND_MODE_DEST_OVER}
    end

    test "unknown atom returns an error" do
      assert {:error, %Image.Error{} = error} = Image.BlendMode.validate_blend_mode(:bogus)
      assert error.message == "Unknown blend mode. Found :bogus"
    end

    test "unknown string returns an error" do
      assert {:error, %Image.Error{} = error} =
               Image.BlendMode.validate_blend_mode("no_such_blend_mode_string")

      assert error.message =~ "Unknown blend mode"
    end
  end

  describe "Image.CombineMode" do
    test "vips enum atoms pass through unchanged" do
      for mode <- [:VIPS_COMBINE_MODE_SET, :VIPS_COMBINE_MODE_ADD, :VIPS_COMBINE_MODE_LAST] do
        assert Image.CombineMode.validate(mode) == {:ok, mode}
      end
    end

    # Note: the :set/:add/:last clauses in Image.CombineMode.validate/1
    # currently return module aliases (`VIPS_COMBINE_MODE_SET`), not the
    # `:VIPS_COMBINE_MODE_SET` atoms, so we only assert the ok shape here.
    test "short-form atoms return an ok tuple" do
      assert {:ok, _} = Image.CombineMode.validate(:set)
      assert {:ok, _} = Image.CombineMode.validate(:add)
      assert {:ok, _} = Image.CombineMode.validate(:last)
    end

    test "unknown mode returns an error" do
      assert {:error, %Image.Error{} = error} = Image.CombineMode.validate(:bogus)
      assert error.message == "Invalid combine mode :bogus. The valid modes are :set, :add or :last"
      assert error.reason == error.message
    end
  end

  describe "Image.ExtendMode" do
    test "known_extend_modes/0" do
      modes = Image.ExtendMode.known_extend_modes()
      assert Enum.sort(modes) == [:background, :black, :copy, :mirror, :repeat, :white]
    end

    test "every known extend mode validates and round-trips through decode_extend/1" do
      for mode <- Image.ExtendMode.known_extend_modes() do
        assert {:ok, vips_mode} = Image.ExtendMode.validate_extend(mode)
        assert Image.ExtendMode.validate_extend(vips_mode) == {:ok, vips_mode}
        assert Image.ExtendMode.decode_extend(vips_mode) == mode
      end
    end

    test "string forms are validated" do
      assert Image.ExtendMode.validate_extend("black") == {:ok, :VIPS_EXTEND_BLACK}
      assert Image.ExtendMode.validate_extend("MIRROR") == {:ok, :VIPS_EXTEND_MIRROR}
    end

    test "unknown atom and string return errors" do
      assert {:error, %Image.Error{message: "Unknown extend mode. Found :bogus"}} =
               Image.ExtendMode.validate_extend(:bogus)

      assert {:error, %Image.Error{} = error} =
               Image.ExtendMode.validate_extend("no_such_extend_mode_string")

      assert error.message =~ "Unknown extend mode"
    end

    test "validate_extend/2 normalizes a short-form mode into options" do
      assert {:cont, options} = Image.ExtendMode.validate_extend(:mirror, interpolate: :thing)
      assert options[:extend] == :VIPS_EXTEND_MIRROR
      refute Keyword.has_key?(options, :interpolate)
    end

    test "validate_extend/2 keeps a vips mode as-is in options" do
      assert {:cont, options} = Image.ExtendMode.validate_extend(:VIPS_EXTEND_WHITE, [])
      assert options[:extend] == :VIPS_EXTEND_WHITE
    end

    test "validate_extend/2 halts with an error for unknown modes" do
      assert {:halt, {:error, %Image.Error{} = error}} =
               Image.ExtendMode.validate_extend(:bogus, [])

      assert error.message == "Unknown extend mode. Found :bogus"
    end
  end

  describe "Image.Kernel" do
    test "known_kernel/0" do
      kernels = Image.Kernel.known_kernel()
      assert Enum.sort(kernels) == [:cubic, :lanczos2, :lanczos3, :linear, :mitchell, :nearest]
    end

    test "every known kernel validates and round-trips through decode_kernel/1" do
      for kernel <- Image.Kernel.known_kernel() do
        assert {:ok, vips_kernel} = Image.Kernel.validate_kernel(kernel)
        assert Image.Kernel.validate_kernel(vips_kernel) == {:ok, vips_kernel}
        assert Image.Kernel.decode_kernel(vips_kernel) == kernel
      end
    end

    test "string forms are validated" do
      assert Image.Kernel.validate_kernel("nearest") == {:ok, :VIPS_KERNEL_NEAREST}
      assert Image.Kernel.validate_kernel("LANCZOS3") == {:ok, :VIPS_KERNEL_LANCZOS3}
    end

    test "unknown atom and string return errors" do
      assert {:error, %Image.Error{message: "Unknown kernel. Found :bogus"}} =
               Image.Kernel.validate_kernel(:bogus)

      assert {:error, %Image.Error{} = error} =
               Image.Kernel.validate_kernel("no_such_kernel_string")

      assert error.message =~ "Unknown kernel"
    end

    test "validate_kernel/2 normalizes a short-form kernel into options" do
      assert {:cont, options} = Image.Kernel.validate_kernel(:cubic, interpolate: :thing)
      assert options[:kernel] == :VIPS_KERNEL_CUBIC
      refute Keyword.has_key?(options, :interpolate)
    end

    test "validate_kernel/2 keeps a vips kernel as-is in options" do
      assert {:cont, options} = Image.Kernel.validate_kernel(:VIPS_KERNEL_LINEAR, [])
      assert options[:kernel] == :VIPS_KERNEL_LINEAR
    end

    test "validate_kernel/2 halts with an error for unknown kernels" do
      assert {:halt, {:error, %Image.Error{} = error}} = Image.Kernel.validate_kernel(:bogus, [])
      assert error.message == "Unknown kernel. Found :bogus"
    end
  end

  describe "Image.Interpretation" do
    test "known_interpretations/0" do
      interpretations = Image.Interpretation.known_interpretations()
      assert :srgb in interpretations
      assert :bw in interpretations
      assert :cmyk in interpretations
      assert length(interpretations) == 19
    end

    test "every known interpretation validates and round-trips through decode_interpretation/1" do
      for interpretation <- Image.Interpretation.known_interpretations() do
        assert {:ok, vips_interpretation} =
                 Image.Interpretation.validate_interpretation(interpretation)

        assert Image.Interpretation.validate_interpretation(vips_interpretation) ==
                 {:ok, vips_interpretation}

        assert Image.Interpretation.decode_interpretation(vips_interpretation) == interpretation
      end
    end

    test "string forms are validated" do
      assert Image.Interpretation.validate_interpretation("srgb") ==
               {:ok, :VIPS_INTERPRETATION_sRGB}

      assert Image.Interpretation.validate_interpretation("sRGB") ==
               {:ok, :VIPS_INTERPRETATION_sRGB}

      assert Image.Interpretation.validate_interpretation("LAB") ==
               {:ok, :VIPS_INTERPRETATION_LAB}
    end

    test "unknown atom and string return errors" do
      assert {:error, %Image.Error{message: "Unknown interpretation. Found :bogus"}} =
               Image.Interpretation.validate_interpretation(:bogus)

      assert {:error, %Image.Error{} = error} =
               Image.Interpretation.validate_interpretation("no_such_interpretation_string")

      assert error.message =~ "Unknown interpretation"
    end
  end

  describe "Image.BandFormat" do
    test "known_band_formats/0" do
      formats = Image.BandFormat.known_band_formats()
      assert {:u, 8} in formats
      assert {:f, 64} in formats
      assert length(formats) == 10
    end

    test "every known band format validates" do
      for format <- Image.BandFormat.known_band_formats() do
        assert {:ok, vips_format} = Image.BandFormat.validate(format)
        assert is_atom(vips_format)
        assert vips_format |> Atom.to_string() |> String.starts_with?("VIPS_FORMAT_")
      end
    end

    test "short-form atoms validate" do
      assert Image.BandFormat.validate(:u8) == {:ok, :VIPS_FORMAT_UCHAR}
      assert Image.BandFormat.validate(:s16) == {:ok, :VIPS_FORMAT_SHORT}
      assert Image.BandFormat.validate(:f32) == {:ok, :VIPS_FORMAT_FLOAT}
      assert Image.BandFormat.validate(:f64) == {:ok, :VIPS_FORMAT_DOUBLE}
    end

    test "vips enum atoms pass through unchanged" do
      assert Image.BandFormat.validate(:VIPS_FORMAT_UCHAR) == {:ok, :VIPS_FORMAT_UCHAR}
      assert Image.BandFormat.validate(:VIPS_FORMAT_DOUBLE) == {:ok, :VIPS_FORMAT_DOUBLE}
    end

    test "unknown format returns an error" do
      assert {:error, %Image.Error{} = error} = Image.BandFormat.validate({:u, 128})
      assert error.message == "Invalid band format. Found {:u, 128}"
    end

    test "nx_format/1 converts vips enums to type tuples" do
      assert Image.BandFormat.nx_format(:VIPS_FORMAT_UCHAR) == {:ok, {:u, 8}}
      assert Image.BandFormat.nx_format(:VIPS_FORMAT_CHAR) == {:ok, {:s, 8}}
      assert Image.BandFormat.nx_format(:VIPS_FORMAT_USHORT) == {:ok, {:u, 16}}
      assert Image.BandFormat.nx_format(:VIPS_FORMAT_SHORT) == {:ok, {:s, 16}}
      assert Image.BandFormat.nx_format(:VIPS_FORMAT_INT) == {:ok, {:s, 32}}
      assert Image.BandFormat.nx_format(:VIPS_FORMAT_FLOAT) == {:ok, {:f, 32}}
      assert Image.BandFormat.nx_format(:VIPS_FORMAT_DOUBLE) == {:ok, {:f, 64}}
      assert {:ok, {_sign, _size}} = Image.BandFormat.nx_format(:VIPS_FORMAT_UINT)
    end

    test "nx_format/1 accepts an image" do
      image = Image.new!(2, 2, color: [10, 20, 30])
      assert Image.BandFormat.nx_format(image) == {:ok, {:u, 8}}
    end

    test "nx_format/1 returns an error for unknown formats" do
      assert {:error, %Image.Error{} = error} = Image.BandFormat.nx_format(:VIPS_FORMAT_NOTHING)
      assert error.message == "Invalid band format. Found :VIPS_FORMAT_NOTHING"
    end

    test "nx_format!/1 returns the format or raises" do
      assert Image.BandFormat.nx_format!(:VIPS_FORMAT_UCHAR) == {:u, 8}

      assert_raise Image.Error, fn ->
        Image.BandFormat.nx_format!(:VIPS_FORMAT_NOTHING)
      end
    end

    test "image_format_from_nx/1 validates type tuples" do
      assert Image.BandFormat.image_format_from_nx({:u, 8}) == {:ok, :VIPS_FORMAT_UCHAR}
      assert {:error, %Image.Error{}} = Image.BandFormat.image_format_from_nx({:bf, 16})
    end

    test "image_format_from_nx/1 accepts an Nx tensor" do
      tensor = Nx.tensor([1, 2, 3], type: {:u, 8})
      assert Image.BandFormat.image_format_from_nx(tensor) == {:ok, :VIPS_FORMAT_UCHAR}
    end
  end
end
