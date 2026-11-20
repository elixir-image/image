defmodule Image.Options.Shape do
  @moduledoc false

  import Image.Options.Text,
    only: [
      invalid_option: 1,
      validate_color: 3,
      validate_opacity: 3,
      validate_stroke_width: 3,
      wrap: 2
    ]

  defp default_polygon_options do
    [
      opacity: 0.7,
      fill_color: "none",
      stroke_color: "white",
      stroke_width: 1
    ]
  end

  @doc false
  def validate_polygon_options(options) do
    validate_options(options, default_polygon_options())
  end

  @doc """
  Validate the options for `Image.Shape functions`.

  ### Arguments

  * `options` is a keyword list of options.

  * `default_options` is a keyword list of default values that
    `options` override.

  ### Returns

  * `{:ok, validated_options}` where `validated_options` is
    a map of the options with their defaults applied, or

  * `{:error, reason}`.

  ### Examples

      iex> Image.Options.Shape.validate_options([width: 10], [])
      {:ok, %{width: 10}}

  """
  @spec validate_options(options :: Keyword.t(), default_options :: Keyword.t()) ::
          {:ok, map()} | {:error, Image.error()}
  def validate_options(options, default_options) do
    options = Keyword.merge(default_options, options)

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
        |> wrap(:ok)

      other ->
        other
    end
  end

  defp validate_option({:height, height}, options) when is_integer(height) and height > 0 do
    {:cont, options}
  end

  defp validate_option({:width, width}, options) when is_integer(width) and width > 0 do
    {:cont, options}
  end

  defp validate_option({:fill_color = option, color}, options) do
    validate_color(option, color, options)
  end

  defp validate_option({:stroke_color = option, color}, options) do
    validate_color(option, color, options)
  end

  defp validate_option({:stroke_width = option, width}, options) do
    validate_stroke_width(option, width, options)
  end

  defp validate_option({:opacity = option, opacity}, options) do
    validate_opacity(option, opacity, options)
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end
end
