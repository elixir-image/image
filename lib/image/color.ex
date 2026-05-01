if Code.ensure_loaded?(Nx) do
  defmodule Image.Color do
    @moduledoc """
    Vectorised colour-space conversions for `Nx` tensors of pixel
    rows.

    Per-pixel conversion via `Color.convert/2` is correct but slow
    when there are tens of thousands of pixels in flight (e.g.
    palette extraction from an image). The helpers in this module
    do the same conversions as a single tensor op so the cost is
    `O(matmul + element-wise)` rather than `O(n × Elixir-call)`.

    All functions in this module require [`Nx`](https://hex.pm/packages/nx).
    They are not compiled if `Nx` is not loaded.

    """

    import Nx, warn: false

    # ---- sRGB → XYZ ──────────────────────────────────────────
    #
    # Bruce Lindbloom's published sRGB → CIE XYZ matrix relative
    # to D65 (https://www.brucelindbloom.com/), in row-major form.
    @srgb_to_xyz_d65 [
      [0.4124564, 0.3575761, 0.1804375],
      [0.2126729, 0.7151522, 0.0721750],
      [0.0193339, 0.1191920, 0.9503041]
    ]

    # ---- XYZ (D65) → LMS ────────────────────────────────────
    #
    # Ottosson's M1 matrix (`Color.Conversion.Oklab` mirrors
    # this — kept here as a literal so the inner loop avoids a
    # module attribute lookup per call).
    @m1 [
      [0.8189330101, 0.3618667424, -0.1288597137],
      [0.0329845436, 0.9293118715, 0.0361456387],
      [0.0482003018, 0.2643662691, 0.6338517070]
    ]

    # ---- LMS' → Oklab ───────────────────────────────────────
    @m2 [
      [0.2104542553, 0.7936177850, -0.0040720468],
      [1.9779984951, -2.4285922050, 0.4505937099],
      [0.0259040371, 0.7827717662, -0.8086757660]
    ]

    @doc """
    Converts a tensor of sRGB pixel rows to an Oklab tensor.

    Input values are interpreted as 8-bit sRGB (0–255) when the
    tensor type is integer; as unit-range linear sRGB (0.0–1.0)
    is **not** assumed — even float tensors are treated as
    gamma-encoded sRGB on the [0, 1] scale, matching what
    `Image.to_nx/2` returns when the source image is in the
    sRGB colourspace.

    The pipeline is the standard one:

        sRGB → linear-sRGB → XYZ (D65) → LMS → ∛ → LMS' → Oklab

    All of it is expressed as Nx tensor ops so a 90 000-row
    input is one matmul-heavy pass rather than 90 000 Elixir
    function calls.

    ### Arguments

    * `tensor` is an `Nx.Tensor.t/0` of shape `{n, 3}` (alpha
      bands must be stripped before calling — alpha is a property
      of the *source* image, not of the colour conversion).

    ### Returns

    * An `Nx.Tensor.t/0` of shape `{n, 3}`, type `f32`, where
      column `0` is `L`, column `1` is `a`, and column `2` is
      `b`.

    ### Examples

        iex> rgb = Nx.tensor([[255, 0, 0], [0, 255, 0], [0, 0, 255]], type: :u8)
        iex> oklab = Image.Color.srgb_tensor_to_oklab(rgb)
        iex> Nx.shape(oklab)
        {3, 3}

    """
    @spec srgb_tensor_to_oklab(Nx.Tensor.t()) :: Nx.Tensor.t()
    def srgb_tensor_to_oklab(tensor) do
      tensor
      |> normalise_to_unit()
      |> srgb_to_linear()
      |> matmul_rows(@srgb_to_xyz_d65)
      |> matmul_rows(@m1)
      |> Nx.cbrt()
      |> matmul_rows(@m2)
    end

    # Dispatch on tensor type. Integer u8 inputs are scaled by
    # 1/255; float inputs are assumed to already live in [0, 1].
    defp normalise_to_unit(tensor) do
      case Nx.type(tensor) do
        {:u, _} -> Nx.divide(tensor, 255.0)
        {:s, _} -> Nx.divide(tensor, 255.0)
        {:f, _} -> tensor
        {:bf, _} -> tensor
      end
    end

    # IEC 61966-2-1 inverse-gamma. Element-wise, branchless via
    # Nx.select so the whole tensor processes in one pass.
    defp srgb_to_linear(tensor) do
      threshold = 0.04045
      lin_lo = Nx.divide(tensor, 12.92)
      lin_hi = Nx.pow(Nx.divide(Nx.add(tensor, 0.055), 1.055), 2.4)

      Nx.select(Nx.less_equal(tensor, threshold), lin_lo, lin_hi)
    end

    # Right-multiply each row of `tensor` (shape `{n, k}`) by the
    # transpose of `matrix` (a literal `k×k` row-major list). The
    # net effect is that each output row is `matrix · row`, the
    # standard convention used in `Color.Conversion.Lindbloom`.
    defp matmul_rows(tensor, matrix) do
      m = Nx.tensor(matrix, type: :f32)
      Nx.dot(tensor, Nx.transpose(m))
    end
  end
end
