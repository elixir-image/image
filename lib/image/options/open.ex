defmodule Image.Options.Open do
  # Map the keyword option to the
  # Vix option.
  @fail_on_open %{
    none: :VIPS_FAIL_ON_NONE,
    truncated: :VIPS_FAIL_ON_TRUNCATED,
    error: :VIPS_FAIL_ON_ERROR,
    warning: :VIPS_FAIL_ON_WARNING
  }

  @failure_modes Map.keys(@fail_on_open)
  @default_access :sequential

  @access [:sequential, :random]

  def validate_open_options(options) do
    case Enum.reduce_while(options, [], &validate_option(&1, &2)) do
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
