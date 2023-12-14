defmodule Image.Options.Open do
  @moduledoc """
  Options and option validation for `Image.open/2`.

  """

  # Map the keyword option to the
  # Vix option.

  @typedoc """
  The options applicable to opening an
  image.

  """
  @type image_open_options ::
          jpeg_open_options()
          | png_open_options()
          | tiff_open_options()
          | webp_open_options()
          | gif_open_options()
          | other_open_options()

  @type jpeg_open_options :: [
          {:shrink, 1..16}
          | {:access, file_access()}
          | {:fail_on, fail_on()}
        ]

  @type png_open_options :: [
          {:access, file_access()}
          | {:fail_on, fail_on()}
        ]

  @type tiff_open_options :: [
          {:access, file_access()}
          | {:fail_on, fail_on()}
          | {:pages, pages()}
          | {:page, 1..100_000}
        ]

  @type webp_open_options :: [
          {:access, file_access()}
          | {:fail_on, fail_on()}
          | {:pages, pages()}
          | {:page, 0..100_000}
          | {:scale, non_neg_integer() | float()}
        ]

  @type gif_open_options :: [
          {:access, file_access()}
          | {:fail_on, fail_on()}
          | {:pages, pages()}
          | {:page, 0..100_000}
        ]

  @type other_open_options :: [
          {:access, file_access()}
          | {:fail_on, fail_on()}
        ]

  @typedoc """
  The number of pages to open. Either
  a positive integer or one of `-1` or `:all`
  meaning all pages.

  """
  @type pages :: pos_integer() | -1 | :all

  @typedoc """
  The file access mode when opening
  image files. The default in `:sequential`.

  """
  @type file_access :: :sequential | :random

  @typedoc """
  Stop attempting to load an image file
  when a level of error is detected.
  The default is `:none`.

  Each error state implies all the states
  before it such that `:error` implies
  also `:truncated`.

  """
  @type fail_on :: :none | :truncated | :error | :warning

  @fail_on_open %{
    none: :VIPS_FAIL_ON_NONE,
    truncated: :VIPS_FAIL_ON_TRUNCATED,
    error: :VIPS_FAIL_ON_ERROR,
    warning: :VIPS_FAIL_ON_WARNING
  }

  @failure_modes Map.keys(@fail_on_open)

  @access [:sequential, :random]
  @default_access :random

  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, Keyword.put_new(options, :access, @default_access)}
    end
  end

  def validate_option({:access, access}, options) when access in @access do
    {:cont, options}
  end

  def validate_option({:autorotate, rotate}, _options) do
    {:halt, {:error, invalid_autorotate_option(rotate)}}
  end

  def validate_option({:page, n}, options) when is_integer(n) and n in 0..100_000 do
    {:cont, options}
  end

  def validate_option({:pages, :all}, options) do
    options =
      options
      |> Keyword.delete(:pages)
      |> Keyword.put(:n, -1)

    {:cont, options}
  end

  def validate_option({:pages, n}, options) when is_number(n) and n >= -1 and n <= 100_000 do
    options =
      options
      |> Keyword.delete(:pages)
      |> Keyword.put(:n, n)

    {:cont, options}
  end

  def validate_option({:shrink, shrink}, options) when is_integer(shrink) and shrink in 1..16 do
    {:cont, options}
  end

  def validate_option({:scale, scale}, options) when is_integer(scale) and scale in 1..1024 do
    {:cont, options}
  end

  def validate_option({:scale, scale}, options)
      when is_float(scale) and scale > 0.0 and scale <= 1024.0 do
    {:cont, options}
  end

  def validate_option({:fail_on, failure}, options) when failure in @failure_modes do
    failure = Map.fetch!(@fail_on_open, failure)

    options =
      options
      |> Keyword.delete(:fail_on)
      |> Keyword.put(:"fail-on", failure)

    {:cont, options}
  end

  def validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  defp invalid_autorotate_option(_option) do
    "Autorotate is no longer a supported option. Call `Image.autorotate/1` after opening the image instead."
  end
end
