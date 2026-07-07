defmodule Image.Options.WarpPerspective do
  @moduledoc """
  Options and option validation for `Image.warp_perspective/4`.

  """
  alias Vix.Vips.Image, as: Vimage
  alias Image.BackgroundColor

  @extend_modes [background: :VIPS_EXTEND_BACKGROUND, copy: :VIPS_EXTEND_COPY]

  @typedoc """
  Options for Image.warp_perspective/4.

  """
  @type t :: [warp_perspective_option()]

  @typedoc """
  Options applicable to `Image.warp_perspective/4`.

  """
  @type warp_perspective_option ::
          {:background, BackgroundColor.spec() | nil}
          | {:extend_mode, Image.Options.Affine.extend_mode()}

  @doc """
  Validate the options for `Image.warp_perspective/4`.

  """
  @spec validate_options(Vimage.t(), Keyword.t()) ::
          {:ok, Keyword.t()} | {:error, Image.error()}
  def validate_options(image, options) when is_list(options) do
    # A nil `:background` means "unset", i.e. it falls back to the default.
    options = Enum.reject(options, &match?({:background, nil}, &1))
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option({:background, background}, image, options) do
    case Image.BackgroundColor.resolve(image, background) do
      {:ok, pixel} -> {:cont, Keyword.put(options, :background, pixel)}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  # The public option is `:extend_mode`, renamed to `:extend` for `libvips`.
  # Only `:background` and `:copy` are exposed. See the `@extend_modes`
  # comment in `Image.Options.Affine` for the rationale.
  defp validate_option({:extend_mode, extend_mode}, _image, options)
       when extend_mode in [:background, :copy] do
    options =
      options
      |> Keyword.delete(:extend_mode)
      |> Keyword.put(:extend, Keyword.fetch!(@extend_modes, extend_mode))

    {:cont, options}
  end

  defp validate_option(option, _image, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    %Image.Error{
      reason: :invalid_option,
      value: option,
      message: "Invalid option or option value: #{inspect(option)}"
    }
  end

  # `:extend_mode` defaults to `:background` so the edge fringe blends
  # into the canvas fill.
  defp default_options do
    [background: :black, extend_mode: :background]
  end
end
