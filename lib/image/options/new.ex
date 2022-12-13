defmodule Image.Options.New do
  @moduledoc """
  Options for new images.

  """
  alias Image.{Color, BandFormat, Interpretation}

  @type t :: [
          {:bands, pos_integer()}
          | {:format, Image.BandFormat.t()}
          | {:interpretation, Image.Interpretation.t()}
          | {:color, float() | Image.pixel()}
          | {:x_res, number()}
          | {:y_res, number()}
          | {:x_offset, number()}
          | {:y_offset, number()}
        ]

  @default_bands 3

  def default_options do
    [
      format: {:u, 8},
      interpretation: :srgb,
      color: 0,
      x_res: 0,
      y_res: 0,
      x_offset: 0,
      y_offset: 0
    ]
  end

  @doc """
  Validate the options for `Image.new/2`.

  """
  def validate_options(options) do
    options = Keyword.merge(default_options(), options)

    options =
      case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
        {:error, value} ->
          {:error, value}

        options ->
          {:ok, options}
      end

    case options do
      {:ok, options} ->
        options
        |> Map.new()
        |> set_default_bands()
        |> wrap(:ok)

      other ->
        other
    end
  end

  defp validate_option({:format, format}, options) when is_tuple(format) do
    case BandFormat.image_format_from_nx(format) do
      {:ok, format} ->
        {:cont, Keyword.put(options, :format, format)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option({:format, format}, options) when is_atom(format) do
    case BandFormat.nx_format(format) do
      {:ok, _nx_type} ->
        {:cont, options}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option({:interpretation, interpretation}, options) do
    case Interpretation.validate_interpretation(interpretation) do
      {:ok, interpretation} ->
        {:cont, Keyword.put(options, :interpretation, interpretation)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  @numeric_options [:x_res, :y_res, :x_offset, :y_offset, :bands]
  defp validate_option({option, value}, options)
       when option in @numeric_options and is_number(value) and value >= 0 do
    {:cont, options}
  end

  defp validate_option({:color, color}, options) do
    case Color.rgb_color(color) do
      {:ok, color} ->
        rgb = if Keyword.keyword?(color), do: Keyword.fetch!(color, :rgb), else: color
        {:cont, Keyword.put(options, :color, rgb)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option({option, value}, _options) do
    {:halt, {:error, invalid_option(option, value)}}
  end

  def set_default_bands(%{bands: _bands} = options) do
    options
  end

  def set_default_bands(%{color: color} = options) when is_integer(color) do
    Map.put(options, :bands, @default_bands)
  end

  def set_default_bands(%{color: color} = options) when is_list(color) do
    Map.put(options, :bands, length(color))
  end

  @doc false
  def invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  @doc false
  def invalid_option(option, value) do
    "Invalid option or option value: #{option}: #{inspect(value)}"
  end

  defp wrap(term, atom) do
    {atom, term}
  end
end
