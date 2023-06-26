defmodule Image.Options.Equalize do
  @moduledoc """
  Options and option validation for `Image.equalize/2`.

  """

  @typedoc """
  Options applicable to `Image.equalize/2`.
  """
  @type equalize_option :: :all | :each | :luminance

  @bands [:all, :each, :luminance]
  @default_band :all

  @doc """
  Validate the options for `Image.equalize/2`.

  """
  def validate_options(options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, Map.new(options)}
    end
  end

  defp validate_option({:bands, bands}, options) when bands in @bands do
    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  defp default_options do
    [
      bands: @default_band
    ]
  end
end
