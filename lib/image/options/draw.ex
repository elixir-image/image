defmodule Image.Options.Draw do
  @moduledoc """
  Options and options validation for the
  drawing functions.

  """

  alias Vix.Vips.Image, as: Vimage

  alias Image.Pixel
  alias Image.CombineMode

  @type circle ::
          [
            {:fill, boolean()}
            | {:color, Pixel.t()}
          ]

  @type rect ::
          [
            {:fill, boolean()}
            | {:color, Pixel.t()}
            | {:stroke_width, pos_integer()}
          ]

  @type point ::
          [
            {:color, Pixel.t()}
          ]

  @type flood ::
          [
            {:equal, boolean()}
            | {:color, Pixel.t()}
          ]

  @type mask ::
          [
            {:color, Pixel.t()}
          ]

  @type line ::
          [
            {:color, Pixel.t()}
          ]

  @type smudge :: []

  @type image ::
          [
            {:mode, CombineMode.t()}
          ]

  defp default_options(:circle) do
    [
      color: :black,
      fill: true,
      stroke_width: 1
    ]
  end

  defp default_options(:rect) do
    [
      color: :black,
      fill: true,
      stroke_width: 1
    ]
  end

  defp default_options(:line) do
    [
      color: :black
    ]
  end

  defp default_options(:point) do
    [
      color: :black
    ]
  end

  defp default_options(:mask) do
    [
      color: :black
    ]
  end

  defp default_options(:flood) do
    [
      color: :black,
      equal: false
    ]
  end

  defp default_options(:image) do
    [
      mode: :VIPS_COMBINE_MODE_SET
    ]
  end

  defp default_options(:smudge) do
    []
  end

  @doc """
  Validate the options for `Image.Draw`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` the options apply to.

  * `type` is the drawing operation the options are for, such as
    `:circle`, `:rect` or `:line`.

  * `options` is a keyword list of options.

  ### Returns

  * `{:ok, validated_options}` where `validated_options` is
    a map of the options with their defaults applied, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(10, 10, color: :red)
      iex> {:ok, options} = Image.Options.Draw.validate_options(image, :circle, fill: false)
      iex> options.fill
      false

  """
  @spec validate_options(image :: Vimage.t(), type :: atom(), options :: Keyword.t()) ::
          {:ok, map()} | {:error, Image.error()}
  def validate_options(image, type, options) when is_list(options) do
    options = Keyword.merge(default_options(type), options)

    options =
      case Enum.reduce_while(options, options, &validate_option(image, type, &1, &2)) do
        {:error, value} ->
          {:error, value}

        options ->
          {:ok, options}
      end

    case options do
      {:ok, options} ->
        options
        |> Map.new()
        |> wrap(:ok)

      other ->
        other
    end
  end

  defp validate_option(_image, type, {:fill, fill}, options) when type in [:circle, :rect] do
    if fill do
      {:cont, Keyword.put(options, :fill, true)}
    else
      {:cont, Keyword.put(options, :fill, false)}
    end
  end

  defp validate_option(image, type, {:color, color}, options)
       when type in [:mask, :point, :circle, :rect, :line, :flood] do
    case Pixel.to_pixel(image, color) do
      {:ok, pixel} ->
        {:cont, Keyword.put(options, :color, pixel)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option(_image, :flood, {:equal, equal}, options) do
    if equal do
      {:cont, Keyword.put(options, :equal, true)}
    else
      {:cont, Keyword.put(options, :equal, false)}
    end
  end

  defp validate_option(_image, :image, {:mode, mode}, options) do
    case Image.CombineMode.validate(mode) do
      {:ok, mode} ->
        {:cont, Keyword.put(options, :mode, mode)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option(_image, type, {:stroke_width, stroke_width}, options)
       when type in [:rect, :circle] and is_integer(stroke_width) and stroke_width > 0 do
    {:cont, options}
  end

  defp validate_option(_image, type, {option, value}, _options) do
    {:halt, {:error, invalid_option(type, option, value)}}
  end

  defp invalid_option(type, option, value) do
    message = "Invalid option or option value for draw_#{type}: #{option}: #{inspect(value)}"
    %Image.Error{reason: :invalid_option, value: value, message: message}
  end

  defp wrap(term, atom) do
    {atom, term}
  end
end
