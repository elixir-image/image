defmodule Image.Options.Write do
  @moduledoc """
  Options and option validation for `Image.write/3`.

  """

  # Map the keyword option to the
  # Vix option.

  alias Image.Color
  import Color, only: [is_inbuilt_profile: 1, is_color: 1]

  @typedoc "Options for writing an image to a file with `Image.write/2`."
  @type image_write_options :: [
          {:suffix, String.t()}
          | jpeg_write_options()
          | png_write_options()
          | tiff_write_options()
          | webp_write_options()
        ]

  @typedoc "Options for writing a jpeg file with `Image.write/2`."
  @type jpeg_write_options :: [
          {:quality, 1..100}
          | {:strip_metadata, boolean()}
          | {:icc_profile, Path.t()}
          | {:background, Image.pixel()}
          | {:maximise_compression, boolean()}
        ]

  @typedoc "Options for writing a png file with `Image.write/2`."
  @type png_write_options :: [
          {:quality, 1..100}
          | {:strip_metadata, boolean()}
          | {:icc_profile, Path.t()}
          | {:background, Image.pixel()}
          | {:palette, boolean()}
        ]

  @typedoc "Options for writing a tiff file with `Image.write/2`."
  @type tiff_write_options :: [
          {:quality, 1..100}
          | {:icc_profile, Path.t()}
          | {:background, Image.pixel()}
        ]

  @typedoc "Options for writing a heif file with `Image.write/2`."
  @type heif_write_options :: [
          {:quality, 1..100}
          | {:background, Image.pixel()}
          | {:compression, heif_compression()}
        ]

  @typedoc "Options for writing a webp file with `Image.write/2`."
  @type webp_write_options :: [
          {:quality, 1..100}
          | {:icc_profile, Path.t()}
          | {:background, Image.pixel()}
          | {:strip_metadata, boolean()}
        ]

  @typedoc "Allowable compression types for heif images."
  @type heif_compression :: :hevc | :avc | :jpeg | :av1

  @doc false
  defguard is_jpg(image_type) when image_type in [".jpg", ".jpeg"]

  @doc false
  defguard is_png(image_type) when image_type == ".png"

  def validate_options(options, :require_suffix) when is_list(options) do
    case Keyword.fetch(options, :suffix) do
      {:ok, _options} ->
        validate_options("", options)

      _other ->
        {:error, "The option :suffix must be provided. Example: suffix: \".jpg\""}
    end
  end

  def validate_options(path, options) when is_binary(path) and is_list(options) do
    with {:ok, image_type} <- image_type_from(Path.extname(path), options[:suffix]) do
      case Enum.reduce_while(options, options, &validate_option(&1, &2, image_type)) do
        {:error, value} ->
          {:error, value}

        options ->
          {:ok, options}
      end
    end
  end

  defp validate_option({:suffix, "." <> _suffix}, options, _image_type) do
    {:cont, options}
  end

  defp validate_option({:quality, quality}, options, image_type)
       when is_png(image_type) and is_integer(quality) and quality in 1..100 do
    compression = round(quality / 10)

    options =
      options
      |> Keyword.delete(:quality)
      |> Keyword.put(:compression, compression)

    {:cont, options}
  end

  defp validate_option({:quality, quality}, options, _image_type)
       when is_integer(quality) and quality in 1..100 do
    options =
      options
      |> Keyword.delete(:quality)
      |> Keyword.put(:Q, quality)

    {:cont, options}
  end

  defp validate_option({:buffer_size, buffer_size}, options, _image_type)
       when (is_integer(buffer_size) and buffer_size >= 0) or buffer_size == :unbuffered do
    {:cont, options}
  end

  defp validate_option({:strip_metadata, strip?}, options, _image_type) when is_boolean(strip?) do
    options =
      options
      |> Keyword.delete(:strip_metadata)
      |> Keyword.put(:strip, strip?)

    {:cont, options}
  end

  # Quantize a png image
  defp validate_option({:palette, palette?}, options, ".png") when is_boolean(palette?) do
    {:cont, options}
  end

  defp validate_option({:progressive, progressive?}, options, _image_type)
       when is_boolean(progressive?) do
    options =
      options
      |> Keyword.delete(:progressive)
      |> Keyword.put(:interlace, progressive?)

    {:cont, options}
  end

  # From: https://www.libvips.org/API/current/VipsForeignSave.html#vips-jpegsave
  # Applies only to jpeg save
  # For maximum compression with mozjpeg, a useful set of options is
  # strip, optimize-coding, interlace, optimize-scans, trellis-quant, quant_table=3.
  defp validate_option({:maximize_compression, maximize?}, options, image_type)
       when is_boolean(maximize?) and is_jpg(image_type) do
    options =
      options
      |> Keyword.delete(:maximize_compression)
      |> Keyword.put(:strip, true)
      |> Keyword.put(:"optimize-coding", true)
      |> Keyword.put(:interlace, true)
      |> Keyword.put(:"optimize-scans", true)
      |> Keyword.put(:"trellis-quant", true)
      |> Keyword.put(:quant_table, 3)

    {:cont, options}
  end

  defp validate_option({:icc_profile, profile}, options, _image_type)
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

  defp validate_option({:background, background}, options, _image_type) when is_color(background) do
    {:cont, options}
  end

  defp validate_option(option, _options, image_type) do
    {:halt, {:error, invalid_option(option, image_type)}}
  end

  defp invalid_option(option, image_type) do
    "Invalid option or option value: #{inspect(option)} for image type #{inspect(image_type)}"
  end

  defp image_type_from("", "") do
    {:error, "Cannot determine image type"}
  end

  defp image_type_from("", suffix) do
    {:ok, suffix}
  end

  defp image_type_from(extname, _suffix) do
    {:ok, extname}
  end
end
