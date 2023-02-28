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
          {:quality, 1..100}
          | {:background, Image.pixel()}
          | stream_write_option()
          | jpeg_write_option()
          | png_write_option()
          | tiff_write_option()
          | webp_write_option()
          | heif_write_option()
          | gif_write_option()
        ]

  @typedoc "Options for writing an image stream"
  @type stream_write_option ::
          {:buffer_size, pos_integer() | :unbuffered}
          | {:suffix, String.t()}

  @typedoc "Options for writing a jpeg file with `Image.write/2`."
  @type jpeg_write_option ::
          {:strip_metadata, boolean()}
          | {:icc_profile, Path.t()}
          | {:minimize_file_size, boolean()}

  @typedoc "Options for writing a png file with `Image.write/2`."
  @type png_write_option ::
          {:strip_metadata, boolean()}
          | {:icc_profile, Path.t()}
          | {:minimize_file_size, boolean()}
          | {:effort, 1..10}

  @typedoc "Options for writing a tiff file with `Image.write/2`."
  @type tiff_write_option ::
          {:icc_profile, Path.t()}

  @typedoc "Options for writing a heif file with `Image.write/2`."
  @type heif_write_option ::
          {:compression, heif_compression()}
          | {:effort, 1..10}

  @type gif_write_option ::
          {:interframe_maxerror, 0..32}
          | {:effort, 1..10}

  @typedoc "Options for writing a webp file with `Image.write/2`."
  @type webp_write_option ::
          {:icc_profile, Path.t()}
          | {:strip_metadata, boolean()}
          | {:minimize_file_size, boolean()}
          | {:effort, 1..10}

  @typedoc "Allowable compression types for heif images."
  @type heif_compression :: :hevc | :avc | :jpeg | :av1

  @doc false
  defguard is_jpg(image_type) when image_type in [".jpg", ".jpeg"]

  @doc false
  defguard is_png(image_type) when image_type == ".png"

  @doc false
  defguard is_webp(image_type) when image_type == ".webp"

  @doc false
  defguard is_tiff(image_type) when image_type in [".tiff", ".tif"]

  @doc false
  defguard is_heif(image_type) when image_type in [".heif", ".heic", ".avif"]

  @doc false
  defguard is_gif(image_type) when image_type == ".gif"

  def validate_options(options, :require_suffix) when is_list(options) do
    case Keyword.fetch(options, :suffix) do
      {:ok, _options} ->
        validate_options("", options)

      _other ->
        {:error, "The option :suffix must be provided. Example: suffix: \".jpg\""}
    end
  end

  def validate_options(path, options) when is_binary(path) and is_list(options) do
    with {:ok, image_type} <- path |> Path.extname() |> image_type_from(options[:suffix]) do
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
  defp validate_option({:minimize_file_size, true}, options, image_type) when is_jpg(image_type) do
    options =
      options
      |> Keyword.delete(:minimize_file_size)
      |> Keyword.put(:strip, true)
      |> Keyword.put(:"optimize-coding", true)
      |> Keyword.put(:interlace, true)
      |> Keyword.put(:"optimize-scans", true)
      |> Keyword.put(:"trellis-quant", true)
      |> Keyword.put(:quant_table, 3)

    {:cont, options}
  end

  # Quantize a png image
  defp validate_option({:minimize_file_size, true}, options, image_type) when is_png(image_type) do
    options =
      options
      |> Keyword.delete(:minimize_file_size)
      |> Keyword.put(:strip, true)
      |> Keyword.put(:palette, true)

    {:cont, options}
  end

  # For webp, apply min-size, strip, and mixed (allow mixed encoding which might reduce file size)
  defp validate_option({:minimize_file_size, true}, options, image_type) when is_webp(image_type) do
    options =
      options
      |> Keyword.delete(:minimize_file_size)
      |> Keyword.put(:min_size, true)
      |> Keyword.put(:strip, true)
      |> Keyword.put(:mixed, true)

    {:cont, options}
  end

  defp validate_option({:minimize_file_size, false}, options, image_type)
       when is_png(image_type) or is_jpg(image_type) or is_webp(image_type) do
    options =
      options
      |> Keyword.delete(:minimize_file_size)

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

  defp validate_option({:effort, effort}, options, image_type)
       when is_integer(effort) and effort in 1..10 and not is_jpg(image_type) and
              not is_tiff(image_type) do
    options = Keyword.put(options, :effort, conform_effort(effort, image_type))
    {:cont, options}
  end

  defp validate_option({:interframe_maxerror, int_max_error}, options, image_type)
       when is_gif(image_type) and int_max_error in 0..32 do
    {:cont, options}
  end

  defp validate_option(option, _options, image_type) do
    {:halt, {:error, invalid_option(option, image_type)}}
  end

  defp invalid_option(option, image_type) do
    "Invalid option or option value: #{inspect(option)} for image type #{inspect(image_type)}"
  end

  # Range 1..10
  defp conform_effort(effort, ".png"), do: effort

  # Range 0..9
  defp conform_effort(effort, image_type) when is_heif(image_type), do: effort - 1

  # Range 0..6
  defp conform_effort(effort, ".webp"), do: round(effort / 10 * 6)

  defp image_type_from("", "") do
    {:error, "Cannot determine image type"}
  end

  defp image_type_from("", suffix) do
    {:ok, suffix}
  end

  defp image_type_from(extname, _suffix) do
    {:ok, String.downcase(extname)}
  end
end
