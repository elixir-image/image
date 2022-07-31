defmodule Image.Options.Draw do
  @moduledoc false

  alias Image.Color

  @type circle :: [
    {:fill, boolean()} |
    {:color, Color.t()}
  ]

  @type flood :: [
    {:equal, boolean()} |
    {:color, Color.t()}
  ]


  def default_options(:circle) do
    [
      color: :black,
      fill: true
    ]
  end

  def default_options(:flood) do
    [
      color: :black,
      equal: false
    ]
  end

  def default_options(:image) do
    [

    ]
  end

  @doc """
  Validate the options for `Image.Draw`.

  """
  def validate_options(type, options) do
    options =
      Keyword.merge(default_options(type), options)

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

      other -> other
    end
  end

  defp validate_option(:circle, {:fill, fill}, options) do
    if fill do
      {:cont, Keyword.put(options, :fill, true)}
    else
      {:halt, {:error, invalid_option(:circle, :fill, fill)}}
    end
  end

  defp validate_option(type, {:color, color}, options) when type in [:circle, :flood] do
    case Color.rgb_color(color) do
      {:ok, color} ->
        rgb =  if Keyword.keyword?(color), do: Keyword.fetch!(color, :rgb), else: color
        {:cont, Keyword.put(options, :color, rgb)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
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
    "Invalid option or option value for draw_#{type}: #{option}: #{inspect value}"
  end

  defp wrap(term, atom) do
    {atom, term}
  end
end