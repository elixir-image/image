defmodule Image.Options.Embed do
  @moduledoc """
  Options and option validation for `Image.embed/4`.

  """
  alias Image.BackgroundColor

  @typedoc """
  Options applicable to `Image.embed/4`.

  """
  @type embed_option ::
          {:background, BackgroundColor.spec() | nil}
          | {:extend_mode, extend_mode()}
          | {:x, non_neg_integer() | :center}
          | {:y, non_neg_integer() | :center}

  @typedoc """
  How the generated border pixels are produced.

  * `:copy`, `:repeat` and `:mirror` synthesize the border from the *image
    content*.
  * `:background` fills the border with the `:background` color. This is the
    default behavior when no `:extend_mode` is given, so passing it is only
    ever explicit documentation of intent. The color still comes from the
    `:background` option.

  """
  @type extend_mode ::
          :copy
          | :repeat
          | :mirror
          | :background

  @typedoc """
  Options list for `Image.embed/4`.

  """
  @type embed_options :: [embed_option()]

  # The extend modes that synthesize the border from the image content. All
  # other (color/transparency) fills go through the `:background` option.
  @content_extends [copy: :VIPS_EXTEND_COPY, repeat: :VIPS_EXTEND_REPEAT, mirror: :VIPS_EXTEND_MIRROR]
  @content_extend_modes Keyword.keys(@content_extends)
  @vips_content_extends Keyword.values(@content_extends)

  @doc """
  Validate the options for `Image.embed/4`.

  """
  def validate_options(image, width, height, options) when is_list(options) do
    # A nil `:background` means "unset". It falls back to the default and does
    # not count as an explicitly-supplied background, so it does not conflict
    # with a content `:extend_mode`.
    options = Enum.reject(options, &match?({:background, nil}, &1))
    user_supplied_keys = Keyword.keys(options)
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, width, height, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        options
        |> Map.new()
        |> adjust_background(user_supplied_keys)
    end
  end

  def validate_options(_image, _width, _height, %{} = options) do
    {:ok, options}
  end

  # `:average`, colors, and the `{color, alpha: a}` form are all resolved by
  # `Image.BackgroundColor.resolve/2`. The resolved pixel keeps its alpha band
  # (unlike `write`/`flatten`) so a transparent border can be requested.
  defp validate_option({:background, background}, image, _width, _height, options) do
    case BackgroundColor.resolve(image, background) do
      {:ok, pixel} ->
        {:cont, Keyword.put(options, :background, pixel)}

      # The resolve error is already an %Image.Error{} with a more specific
      # message than invalid_option/1 would produce.
      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  # `:extend_mode` now only names the content-derived borders. Color and
  # transparency fills go through `:background`, so `:black`/`:white`/
  # `:background` are no longer extend modes, they fall through to
  # `invalid_option/1`.
  defp validate_option({:extend_mode, extend}, _image, _width, _height, options)
       when extend in @content_extend_modes do
    case Image.ExtendMode.validate_extend(extend) do
      {:ok, extend_mode} ->
        options = Keyword.put(options, :extend_mode, extend_mode)
        {:cont, options}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  # `:background` is accepted as an explicit selector for the color fill (the
  # default behavior). The color itself comes from the `:background` option.
  # It is a *mode*, not a color, so it is allowed here even though `:black`/
  # `:white` (which are colors) are not: those go through `:background`.
  defp validate_option({:extend_mode, :background}, _image, _width, _height, options) do
    {:cont, Keyword.put(options, :extend_mode, :VIPS_EXTEND_BACKGROUND)}
  end

  defp validate_option({:x, :center}, image, width, height, options) do
    x = trunc((width - Image.width(image)) / 2)
    validate_option({:x, x}, image, width, height, options)
  end

  defp validate_option({:y, :center}, image, width, height, options) do
    y = trunc((height - Image.height(image)) / 2)
    validate_option({:y, y}, image, width, height, options)
  end

  defp validate_option({:x, x}, image, width, _height, options) when is_integer(x) do
    x = normalize_dim(x, width)

    if x + width >= Image.width(image) do
      options = Keyword.put(options, :x, x)
      {:cont, options}
    else
      {:halt, offset_error(:x, x)}
    end
  end

  defp validate_option({:y, y}, image, _width, height, options) when is_integer(y) do
    y = normalize_dim(y, height)

    if y + height >= Image.height(image) do
      options = Keyword.put(options, :y, y)
      {:cont, options}
    else
      {:halt, offset_error(:y, y)}
    end
  end

  defp validate_option(option, _image, _width, _height, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    %Image.Error{
      reason: :invalid_option,
      value: option,
      message: "Invalid option or option value: #{inspect(option)}"
    }
  end

  # Resolves the interaction between :extend_mode and :background.
  #
  # * A content-derived extend mode (:copy/:repeat/:mirror) synthesizes the
  #   border from the image and consumes no color, so combining it with an
  #   explicit :background is contradictory and returns an error. A nil
  #   :background was stripped as "unset" and does not conflict.
  #
  # * Otherwise the border is filled with :background via VIPS_EXTEND_BACKGROUND.
  #   With no user-supplied background, no background is passed and libvips
  #   uses its native all-zeros fill.
  defp adjust_background(options, user_supplied_keys) do
    explicit_background? = :background in user_supplied_keys
    content_extend = Map.get(options, :extend_mode)

    cond do
      content_extend in @vips_content_extends and explicit_background? ->
        contradictory_options_error(content_extend)

      content_extend in @vips_content_extends ->
        {:ok, options}

      true ->
        {:ok, Map.put(options, :extend_mode, :VIPS_EXTEND_BACKGROUND)}
    end
  end

  defp contradictory_options_error(vips_extend) do
    {extend_mode, _vips} = List.keyfind!(@content_extends, vips_extend, 1)

    {:error,
     %Image.Error{
       reason: :invalid_option,
       value: {:extend_mode, extend_mode},
       message:
         "extend_mode: #{inspect(extend_mode)} generates the border from the image " <>
           "content and cannot be combined with an explicit :background. " <>
           "Pass one or the other (background: nil is treated as unset)."
     }}
  end

  @doc false
  def normalize_dim(a, _max) when a >= 0, do: a
  def normalize_dim(a, max) when a < 0, do: max + a

  defp default_options do
    [
      x: :center,
      y: :center
    ]
  end

  defp offset_error(_dim, value) when value < 0 do
    {:error,
     %Image.Error{
       message: "The canvas image must be larger than the image being embedded in it",
       reason: "The canvas image must be larger than the image being embedded in it"
     }}
  end

  defp offset_error(dim, value) do
    {:error,
     "#{inspect(dim)} offset #{inspect(value)} cannot fit the image inside the embedded image"}
  end
end
