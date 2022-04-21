defmodule Image.Options.Open do
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
          | other_open_options()

  @type jpeg_open_options :: [
          {:shrink, 1..16},
          {:autorotate, boolean()},
          {:access, file_access()},
          {:fail_on, fail_on()}
        ]

  @type png_open_options :: [
          {:access, file_access()},
          {:fail_on, fail_on()}
        ]

  @type tiff_open_options :: [
          {:autorotate, boolean()},
          {:access, file_access()},
          {:fail_on, fail_on()},
          {:pages, pos_integer()},
          {:page, 1..100_000}
        ]

  @type webp_open_options :: [
          {:autorotate, boolean()},
          {:access, file_access()},
          {:fail_on, fail_on()},
          {:pages, pos_integer()},
          {:page, 1..100_000},
          {:scale, 1..1024}
        ]

  @type other_open_options :: [
          {:access, file_access()},
          {:fail_on, fail_on()}
        ]

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
  @default_access :sequential

  @access [:sequential, :random]

  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        options = Keyword.put_new(options, :access, @default_access)
        {:ok, options}
    end
  end

  def validate_option({:autorotate, rotate}, options) when rotate in [true, false] do
    {:cont, options}
  end

  def validate_option({:page, n}, options) when is_integer(n) and n in 0..100_000 do
    {:cont, options}
  end

  def validate_option({:access, access}, options) when access in @access do
    {:cont, options}
  end

  def validate_option({:shrink, shrink}, options) when is_integer(shrink) and shrink in 1..16 do
    {:cont, options}
  end

  def validate_option({:scale, scale}, options) when is_integer(scale) and scale in 1..1024 do
    {:cont, options}
  end

  def validate_option({:pages, n}, options) when is_integer(n) and n in 1..100_000 do
    options =
      options
      |> Keyword.delete(:pages)
      |> Keyword.put(:n, n)

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
end
