defmodule Image.Options.Thumbnail do
  @moduledoc """
  Options and option validation for `Image.thumbnail/3`.

  """

  alias Image.Options.Crop
  alias Image.Color

  import Color, only: [is_inbuilt_profile: 1]
  import Image, only: [is_size: 1]

  @typedoc """
  Options applicable to Image.thumbnail/3

  """
  @type thumbnail_options :: [
          {:autorotate, boolean()}
          | {:intent, Image.render_intent()}
          | {:export_icc_profile, Color.icc_profile()}
          | {:import_icc_profile, Color.icc_profile()}
          | {:linear, boolean()}
          | {:resize, resize_dimension()}
          | {:height, pos_integer()}
          | {:crop, Crop.crop_focus()}
          | {:fit, :fill | :contain | :cover}
        ]

  @type resize_dimension :: :width | :height | :both

  @intent_map %{
    perceptual: :VIPS_INTENT_PERCEPTUAL,
    relative: :VIPS_INTENT_RELATIVE,
    saturation: :VIPS_INTENT_SATURATION,
    absolute: :VIPS_INTENT_ABSOLUTE
  }

  @intent Map.keys(@intent_map)

  @resize_map %{
    up: :VIPS_SIZE_UP,
    down: :VIPS_SIZE_DOWN,
    both: :VIPS_SIZE_BOTH,
    force: :VIPS_SIZE_FORCE
  }

  @resize Map.keys(@resize_map)

  @doc """
  Validate the options for `Image.resize/2`.

  See `t:Image.Options.Resize.resize_options/0`.

  """
  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option({:autorotate, autorotate}, options) when is_boolean(autorotate) do
    options =
      options
      |> Keyword.delete(:autorotate)
      |> Keyword.put(:"auto-rotate", autorotate)

    {:cont, options}
  end

  defp validate_option({:resize, resize}, options) when resize in @resize do
    resize = Map.fetch!(@resize_map, resize)

    options =
      options
      |> Keyword.delete(:resize)
      |> Keyword.put(:size, resize)

    {:cont, options}
  end

  defp validate_option({:crop, crop}, options) do
    Crop.validate_crop(crop, options)
  end

  defp validate_option({:linear, linear}, options) when is_boolean(linear) do
    {:cont, options}
  end

  defp validate_option({:height, height}, options) when is_integer(height) and height > 0 do
    {:cont, options}
  end

  defp validate_option({:intent, intent}, options) when intent in @intent do
    intent = Map.fetch!(@intent_map, intent)
    {:cont, Keyword.put(options, :intent, intent)}
  end

  defp validate_option({:import_icc_profile, profile}, options)
       when is_inbuilt_profile(profile) or is_binary(profile) do
    options =
      options
      |> Keyword.delete(:import_icc_profile)
      |> Keyword.put(:"import-profile", to_string(profile))

    if Image.Color.known_icc_profile?(profile) do
      {:cont, options}
    else
      {:halt, {:error, "The color profile #{inspect(profile)} is not known"}}
    end
  end

  defp validate_option({:export_icc_profile, profile}, options)
       when is_inbuilt_profile(profile) or is_binary(profile) do
    options =
      options
      |> Keyword.delete(:export_icc_profile)
      |> Keyword.put(:"export-profile", to_string(profile))

    if Image.Color.known_icc_profile?(profile) do
      {:cont, options}
    else
      {:halt, {:error, "The color profile #{inspect(profile)} is not known"}}
    end
  end

  defp validate_option({:fit, :fill}, options) do
    options =
      options
      |> Keyword.put(:size, :VIPS_SIZE_FORCE)
      |> Keyword.delete(:fit)

    {:cont, options}
  end

  defp validate_option({:fit, :contain}, options) do
    options =
      options
      |> Keyword.put(:crop, :VIPS_INTERESTING_NONE)
      |> Keyword.put(:size, :VIPS_SIZE_BOTH)

    {:cont, options}
  end

  defp validate_option({:fit, :cover}, options) do
    current_crop = Keyword.get(options, :crop, :VIPS_INTERESTING_NONE)

    crop =
      if current_crop == :VIPS_INTERESTING_NONE, do: :VIPS_INTERESTING_CENTRE, else: current_crop

    options =
      options
      |> Keyword.put(:crop, crop)
      |> Keyword.put(:size, :VIPS_SIZE_BOTH)
      |> Keyword.delete(:fit)

    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid Image.thumbnail option or option value: #{inspect(option)}"
  end

  @doc false
  def validate_dimensions(dimensions, options) do
    case dimensions(String.split(dimensions, ["x"])) do
      width when is_size(width) ->
        {:ok, width, options}

      {width, height} when is_size(width) and is_size(height) ->
        {:ok, width, Keyword.put(options, :height, height)}

      _other ->
        {:error, "Invalid dimensions. Found #{inspect(dimensions)}"}
    end
  end

  defp dimensions([width]) do
    case Integer.parse(width) do
      {integer, ""} -> integer
      _other -> width
    end
  end

  defp dimensions([width, ""]) do
    dimensions([width])
  end

  defp dimensions([width, height]) do
    width = dimensions([width])
    height = dimensions([height])
    {width, height}
  end
end
