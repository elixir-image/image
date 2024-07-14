defmodule Image.Options.Draw do
  @moduledoc """
  Options and options validation for the
  drawing functionss.

  """

  alias Image.Color
  alias Image.CombineMode

  @type circle ::
          [
            {:fill, boolean()}
            | {:color, Color.t()}
          ]
          | map()

  @type rect ::
          [
            {:fill, boolean()}
            | {:color, Color.t()}
            | {:stroke_width, pos_integer()}
          ]
          | map()

  @type point ::
          [
            {:color, Color.t()}
          ]
          | map()

  @type flood ::
          [
            {:equal, boolean()}
            | {:color, Color.t()}
          ]
          | map()

  @type mask ::
          [
            {:color, Color.t()}
          ]
          | map()

  @type line ::
          [
            {:color, Color.t()}
          ]
          | map()

  @type smudge :: [] | map()

  @type image ::
          [
            {:mode, CombineMode.t()}
          ]
          | map()

  @doc false
  def default_options(:circle) do
    [
      color: :black,
      fill: true,
      stroke_width: 1
    ]
  end

  @doc false
  def default_options(:rect) do
    [
      color: :black,
      fill: true,
      stroke_width: 1
    ]
  end

  @doc false
  def default_options(:line) do
    [
      color: :black
    ]
  end

  @doc false
  def default_options(:point) do
    [
      color: :black
    ]
  end

  @doc false
  def default_options(:mask) do
    [
      color: :black
    ]
  end

  @doc false
  def default_options(:flood) do
    [
      color: :black,
      equal: false
    ]
  end

  @doc false
  def default_options(:image) do
    [
      mode: :VIPS_COMBINE_MODE_SET
    ]
  end

  @doc false
  def default_options(:smudge) do
    []
  end

  @doc """
  Validate the options for `Image.Draw`.

  """
  def validate_options(_type, %{} = options) do
    {:ok, options}
  end

  def validate_options(type, options) do
    options = Keyword.merge(default_options(type), options)

    options =
      case Enum.reduce_while(options, options, &validate_option(type, &1, &2)) do
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

  defp validate_option(type, {:fill, fill}, options) when type in [:circle, :rect] do
    if fill do
      {:cont, Keyword.put(options, :fill, true)}
    else
      {:cont, Keyword.put(options, :fill, false)}
    end
  end

  defp validate_option(type, {:color, color}, options)
       when type in [:mask, :point, :circle, :rect, :line, :flood] do
    case Color.rgb_color(color) do
      {:ok, color} ->
        rgb = if Keyword.keyword?(color), do: Keyword.fetch!(color, :rgb), else: color
        {:cont, Keyword.put(options, :color, rgb)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option(:flood, {:equal, equal}, options) do
    if equal do
      {:cont, Keyword.put(options, :equal, true)}
    else
      {:cont, Keyword.put(options, :equal, false)}
    end
  end

  defp validate_option(:image, {:mode, mode}, options) do
    case Image.CombineMode.validate(mode) do
      {:ok, mode} ->
        {:cont, Keyword.put(options, :mode, mode)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option(type, {:stroke_width, stroke_width}, options)
       when type in [:rect, :circle]
       when is_integer(stroke_width) and stroke_width > 0 do
    {:cont, options}
  end

  defp validate_option(type, {option, value}, _options) do
    {:halt, {:error, invalid_option(type, option, value)}}
  end

  @doc false
  def invalid_option(type, option) do
    "Invalid option or option value for draw_#{type}: #{inspect(option)}"
  end

  @doc false
  def invalid_option(type, option, value) do
    "Invalid option or option value for draw_#{type}: #{option}: #{inspect(value)}"
  end

  defp wrap(term, atom) do
    {atom, term}
  end
end
