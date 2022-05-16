defmodule Image.Options.Text do
  alias Image.Color

  def default_options do
    [
      font: "Helvetica",
      font_size: 50,
      text_fill_color: "white",
      text_stroke_color: "none",
      text_stroke_width: "1px",
      font_weight: "normal",
      background_color: :none,
      background_stroke: "none",
      background_stroke_width: "1px",
      opacity: 0.7,
      padding: 0,
      x: :center,
      y: :middle
    ]
  end

  @doc """
  Validate the options for `Image.Text.render/3`.

  """
  def validate_options(options) do
    options =
      Keyword.merge(default_options(), options)

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
        |> ensure_background_color_if_transparent_text()
        |> wrap(:ok)

      other -> other
    end
  end

  defp validate_option({:background_color, color}, options) do
    cond do
      Map.get(Color.color_map(), Color.normalize(color)) ->
        {:cont, options}

      match?(<<"#", _rest::bytes-6>>, color) ->
        {:cont, options}

      String.downcase(to_string(color)) in ["none", ""] ->
        {:cont, Keyword.put(options, :background_color, :none)}
    end
  end

  defp validate_option(_, options) do
    {:cont, options}
  end

  # defp validate_option(option, _options) do
  #   {:halt, {:error, invalid_option(option)}}
  # end
  #
  # defp invalid_option(option) do
  #   "Invalid option or option value: #{inspect(option)}"
  # end

  def ensure_background_color_if_transparent_text(options) do
    case options do
      %{text_fill_color: :transparent, background_color: :none} ->
        Map.put(options, :background_color, "black")

      _other ->
        options
    end
  end

  defp wrap(term, atom) do
    {atom, term}
  end
end