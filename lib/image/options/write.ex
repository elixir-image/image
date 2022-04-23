defmodule Image.Options.Write do
  # Map the keyword option to the
  # Vix option.

  alias Image.Color
  import Color, only: [is_inbuilt_profile: 1, is_color: 1]

  @typedoc """
  Options for writing an image to a file with
  `Image.write/2`.

  """
  @type image_write_options :: [
          jpeg_write_options()
          | png_write_options()
          | tiff_write_options()
          | webp_write_options()
        ]

  @type jpeg_write_options :: [
          {:quality, 1..100},
          {:strip_metadata, boolean()},
          {:icc_profile, Path.t()},
          {:background, Image.pixel()}
        ]

  @type png_write_options :: [
          {:quality, 1..100},
          {:strip_metadata, boolean()},
          {:icc_profile, Path.t()},
          {:background, Image.pixel()}
        ]

  @type tiff_write_options :: [
          {:quality, 1..100},
          {:icc_profile, Path.t()},
          {:background, Image.pixel()}
        ]

  @type heif_write_options :: [
          {:quality, 1..100},
          {:background, Image.pixel()},
          {:compression, compression()}
        ]

  @type webp_write_options :: [
          {:quality, 1..100},
          {:icc_profile, Path.t()},
          {:background, Image.pixel()},
          {:strip_metadata, boolean()}
        ]

  @typedoc """
  Allowble compression types for heif images.

  """
  @type compression :: :hevc | :avc | :jpeg | :av1

  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option({:quality, quality}, options)
       when is_integer(quality) and quality in 1..100 do
    options =
      options
      |> Keyword.delete(:quality)
      |> Keyword.put(:Q, quality)

    {:cont, options}
  end

  defp validate_option({:strip_metadata, strip?}, options) when is_boolean(strip?) do
    options =
      options
      |> Keyword.delete(:strip_metadata)
      |> Keyword.put(:strip, strip?)

    {:cont, options}
  end

  defp validate_option({:progressive, progressive?}, options) when is_boolean(progressive?) do
    options =
      options
      |> Keyword.delete(:progressive)
      |> Keyword.put(:interlace, progressive?)

    {:cont, options}
  end

  defp validate_option({:icc_profile, profile}, options)
       when is_inbuilt_profile(profile) or is_binary(profile) do
    options =
      options
      |> Keyword.delete(:icc_profile)
      |> Keyword.put(:profile, to_string(profile))

    if Color.known_icc_profile?(profile) do
      {:cont, options}
    else
      {:halt, {:error, "The color profile #{inspect(profile)} is not known"}}
    end
  end

  defp validate_option({:background, background}, options) when is_color(background) do
    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end
end
