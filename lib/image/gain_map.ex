defmodule Image.GainMap do
  @moduledoc """
  Functions to inspect and remove the gain map of an UltraHDR image.

  An UltraHDR JPEG pairs a standard dynamic range (SDR) base image with a
  gain map: a second, usually lower-resolution image recording how much
  brighter each region should be shown on an HDR display. libvips 8.18 and
  later, when built with libuhdr as the precompiled libvips in `vix` is,
  loads the gain map as image metadata, and `Image.write/3` writes it back
  when saving a JPEG.

  `Image` keeps the gain map aligned with the base image through its
  geometric operations, so most callers never need this module. Use it to
  check whether an image has a gain map, read the gain map or its
  parameters, or remove it so the image saves as plain SDR.

  ### How the gain map is stored

  libvips holds the gain map in two metadata fields: `gainmap-data`, the
  compressed gain map as read from the file, and `gainmap`, a decoded gain
  map image. When both are present, `gainmap` takes precedence on save.
  `Image` sets `gainmap` whenever it transforms the gain map and leaves
  `gainmap-data` as loaded, since its presence is also what tells the libvips
  JPEG saver to write an UltraHDR file.

  The gain map may have one band or three, and its size is the base image
  size divided by its scale factor, rounded up, so it is rarely an exact
  fraction of the base image.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.MutableImage
  alias Vix.Vips.Operation

  @typedoc """
  The parameters of a gain map, as returned by `info/1`.

  The per-channel parameters are lists of three floats, one for each colour
  channel, as libvips reports them even for a one-band gain map.

  """
  @type t :: %__MODULE__{
          scale_factor: pos_integer() | nil,
          min_content_boost: [float()] | nil,
          max_content_boost: [float()] | nil,
          gamma: [float()] | nil,
          offset_sdr: [float()] | nil,
          offset_hdr: [float()] | nil,
          hdr_capacity_min: float() | nil,
          hdr_capacity_max: float() | nil,
          use_base_color_gamut: boolean() | nil
        }

  defstruct [
    :scale_factor,
    :min_content_boost,
    :max_content_boost,
    :gamma,
    :offset_sdr,
    :offset_hdr,
    :hdr_capacity_min,
    :hdr_capacity_max,
    :use_base_color_gamut
  ]

  @doc """
  Returns whether an image carries a gain map.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `true` if `image` has a gain map, or

  * `false` otherwise.

  ### Examples

      iex> image = Image.open!("./test/support/images/gain_map.jpg")
      iex> Image.GainMap.gain_map?(image)
      true

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> Image.GainMap.gain_map?(image)
      false

  """
  @doc since: "0.74.0"
  @spec gain_map?(image :: Vimage.t()) :: boolean()
  def gain_map?(%Vimage{} = image) do
    case Vimage.header_field_names(image) do
      {:ok, names} -> "gainmap" in names or "gainmap-data" in names
      {:error, _reason} -> false
    end
  end

  @doc """
  Returns the decoded gain map of an image.

  The decoded `gainmap` field is returned when present, since it reflects any
  transformation `Image` has applied. Otherwise the compressed `gainmap-data`
  field is decoded.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, gain_map}` where `gain_map` is a `t:Vix.Vips.Image.t/0`, or

  * `{:ok, nil}` if `image` has no gain map, or

  * `{:error, reason}` if the gain map cannot be decoded.

  ### Examples

      iex> image = Image.open!("./test/support/images/gain_map.jpg")
      iex> {:ok, gain_map} = Image.GainMap.gain_map(image)
      iex> Image.shape(gain_map)
      {240, 130, 1}

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> Image.GainMap.gain_map(image)
      {:ok, nil}

  """
  @doc since: "0.74.0"
  @spec gain_map(image :: Vimage.t()) :: {:ok, Vimage.t() | nil} | {:error, Image.Error.t()}
  def gain_map(%Vimage{} = image) do
    case Vimage.header_value(image, "gainmap") do
      {:ok, %Vimage{} = gain_map} -> {:ok, gain_map}
      _other -> decode_gain_map_data(image)
    end
  end

  defp decode_gain_map_data(image) do
    case Vimage.header_value(image, "gainmap-data") do
      {:ok, data} when is_binary(data) -> decode(data)
      _other -> {:ok, nil}
    end
  end

  # libvips decodes `gainmap-data` with `jpegload_buffer`, so this does too
  # rather than letting the loader be detected.
  defp decode(data) do
    case Operation.jpegload_buffer(data) do
      {:ok, {gain_map, _flags}} ->
        {:ok, gain_map}

      {:error, reason} ->
        {:error,
         Image.Error.exception(
           reason: :invalid_gain_map,
           operation: :gain_map,
           message: "Could not decode the gain map: #{inspect(reason)}"
         )}
    end
  end

  @doc """
  Returns the parameters of an image's gain map.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, info}` where `info` is an `t:Image.GainMap.t/0`, or

  * `{:ok, nil}` if `image` has no gain map.

  ### Examples

      iex> image = Image.open!("./test/support/images/gain_map.jpg")
      iex> {:ok, info} = Image.GainMap.info(image)
      iex> info.scale_factor
      2
      iex> info.min_content_boost
      [1.0, 1.0, 1.0]
      iex> info.use_base_color_gamut
      true

  """
  @doc since: "0.74.0"
  @spec info(image :: Vimage.t()) :: {:ok, t() | nil}
  def info(%Vimage{} = image) do
    {:ok, parameters(image)}
  end

  defp parameters(image) do
    if gain_map?(image) do
      %__MODULE__{
        scale_factor: field(image, "gainmap-scale-factor"),
        min_content_boost: field(image, "gainmap-min-content-boost"),
        max_content_boost: field(image, "gainmap-max-content-boost"),
        gamma: field(image, "gainmap-gamma"),
        offset_sdr: field(image, "gainmap-offset-sdr"),
        offset_hdr: field(image, "gainmap-offset-hdr"),
        hdr_capacity_min: field(image, "gainmap-hdr-capacity-min"),
        hdr_capacity_max: field(image, "gainmap-hdr-capacity-max"),
        use_base_color_gamut: use_base_color_gamut(image)
      }
    end
  end

  defp field(image, name) do
    case Vimage.header_value(image, name) do
      {:ok, value} -> value
      {:error, _reason} -> nil
    end
  end

  defp use_base_color_gamut(image) do
    value = field(image, "gainmap-use-base-cg")

    if is_nil(value) do
      nil
    else
      value != 0
    end
  end

  @doc """
  Removes the gain map from an image.

  Every `gainmap` metadata field is removed, so the image saves as a plain
  SDR file in every format, JPEG included.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image}` where `image` has no gain map, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.open!("./test/support/images/gain_map.jpg")
      iex> {:ok, sdr} = Image.GainMap.remove(image)
      iex> Image.GainMap.gain_map?(sdr)
      false

  """
  @doc since: "0.74.0"
  @spec remove(image :: Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.Error.t()}
  def remove(%Vimage{} = image) do
    with {:ok, names} <- field_names(image) do
      remove_fields(image, Enum.filter(names, &String.starts_with?(&1, "gainmap")))
    end
  end

  defp field_names(image) do
    case Vimage.header_field_names(image) do
      {:ok, names} -> {:ok, names}
      {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :remove_gain_map)}
    end
  end

  # An image without a gain map is returned as it is, without a copy.
  defp remove_fields(image, []) do
    {:ok, image}
  end

  defp remove_fields(image, [_ | _] = fields) do
    case Vimage.mutate(image, &remove_each(&1, fields)) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :remove_gain_map)}
    end
  end

  @doc """
  Renders an image to HDR by applying its gain map.

  The result is a floating point scRGB image in which `1.0` is SDR white
  and values above it are the highlights the gain map records. The gain
  map is applied at full strength and then discarded. Saving the result as
  a JPEG still writes an UltraHDR file: libvips hands an scRGB image to
  libultrahdr, which computes a new gain map from it.

  An image without a gain map is converted to scRGB with no boost, so
  `apply/1` always returns the same kind of image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, hdr_image}` where `hdr_image` is an scRGB image without a gain
    map, or

  * `{:error, reason}`, including when libvips was built without libuhdr.

  ### Examples

      iex> image = Image.open!("./test/support/images/gain_map.jpg")
      iex> {:ok, hdr} = Image.GainMap.apply(image)
      iex> Image.colorspace(hdr)
      :scrgb
      iex> Image.GainMap.gain_map?(hdr)
      false

  """
  @doc since: "0.74.0"
  @spec apply(image :: Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.Error.t()}
  def apply(%Vimage{} = image) do
    if gain_map?(image) do
      render_hdr(image)
    else
      Image.to_colorspace(image, :scrgb)
    end
  end

  defp render_hdr(image) do
    with {:ok, hdr} <- uhdr_to_scrgb(image) do
      remove(hdr)
    end
  end

  # `uhdr2scrgb` exists only when libvips is built with libuhdr, so it is
  # looked up at runtime: a direct call would not compile cleanly against a
  # libvips without it.
  defp uhdr_to_scrgb(image) do
    if Code.ensure_loaded?(Operation) and function_exported?(Operation, :uhdr2scrgb, 1) do
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      case Kernel.apply(Operation, :uhdr2scrgb, [image]) do
        {:ok, hdr} -> {:ok, hdr}
        {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :apply_gain_map)}
      end
    else
      {:error,
       Image.Error.exception(
         reason: :unsupported,
         operation: :apply_gain_map,
         message: "Applying a gain map needs libvips 8.18 or later built with libuhdr"
       )}
    end
  end

  defp remove_each(mutable, fields) do
    Enum.reduce_while(fields, :ok, fn field, :ok ->
      case MutableImage.remove(mutable, field) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc false
  # Carries the gain map of `source` through a geometric operation whose
  # result is `result`, for the `Image` functions that transform images.
  # `transform` receives the gain map and the `{x_scale, y_scale}` ratio of
  # gain map pixels to base image pixels, and returns the gain map transformed
  # the same way as the base image. The output gets the transformed gain map,
  # or loses its gain map if the transform fails, so a stale gain map is never
  # written. An error result passes through untouched.
  @spec carry(
          result :: {:ok, Vimage.t()} | {:error, term()},
          source :: Vimage.t(),
          transform :: (Vimage.t(), {float(), float()} -> {:ok, Vimage.t()} | {:error, term()})
        ) :: {:ok, Vimage.t()} | {:error, term()}
  def carry({:ok, %Vimage{} = output}, %Vimage{} = source, transform)
      when is_function(transform, 2) do
    case gain_map(source) do
      {:ok, nil} -> {:ok, output}
      {:ok, gain_map} -> attach(output, transform.(gain_map, scale(source, gain_map)))
      {:error, _reason} -> remove(output)
    end
  end

  def carry(result, _source, _transform) do
    result
  end

  # The scale is derived from the dimensions on every call, never stored, so
  # successive operations cannot accumulate drift.
  defp scale(source, gain_map) do
    {Vimage.width(gain_map) / Vimage.width(source), Vimage.height(gain_map) / Vimage.height(source)}
  end

  defp attach(output, {:ok, %Vimage{} = gain_map}) do
    case Vimage.mutate(output, &MutableImage.set(&1, "gainmap", :VipsImage, gain_map)) do
      {:ok, image} -> {:ok, image}
      {:error, _reason} -> remove(output)
    end
  end

  defp attach(output, _failure) do
    remove(output)
  end

  @doc false
  # The encoded gain map value meaning "no boost", one per gain map band, for
  # filling the new area an operation such as `Image.embed/4` creates. The
  # gain map encodes a gain g as
  # ((log2(g) - log2(min)) / (log2(max) - log2(min))) ^ gamma, scaled to the
  # band format's range, so the value for g = 1 is 0 only when the minimum
  # content boost is 1.0.
  @spec unit_gain(image :: Vimage.t(), gain_map :: Vimage.t()) :: [number()]
  def unit_gain(%Vimage{} = image, %Vimage{} = gain_map) do
    info = parameters(image)
    full_scale = full_scale(Vimage.format(gain_map))

    for band <- 0..(Vimage.bands(gain_map) - 1) do
      band_unit_gain(info, band) * full_scale
    end
  end

  defp band_unit_gain(
         %__MODULE__{min_content_boost: [_ | _] = min_boost, max_content_boost: [_ | _] = max_boost} =
           info,
         band
       ) do
    log_min = :math.log2(Enum.at(min_boost, band))
    log_max = :math.log2(Enum.at(max_boost, band))
    gamma = gamma_for(info, band)

    if log_max == log_min do
      0.0
    else
      ((0.0 - log_min) / (log_max - log_min))
      |> max(0.0)
      |> min(1.0)
      |> :math.pow(gamma)
    end
  end

  defp band_unit_gain(_info, _band) do
    0.0
  end

  defp gamma_for(%__MODULE__{gamma: [_ | _] = gamma}, band) do
    Enum.at(gamma, band)
  end

  defp gamma_for(_info, _band) do
    1.0
  end

  defp full_scale(:VIPS_FORMAT_UCHAR) do
    255
  end

  defp full_scale(:VIPS_FORMAT_USHORT) do
    65_535
  end

  defp full_scale(_format) do
    1.0
  end

  @doc false
  # Reattaches the source's gain map to the result of an operation that keeps
  # the image's frame but is built from steps that move the gain map, such as
  # a crop followed by an embed back to the original size.
  @spec keep(result :: {:ok, Vimage.t()} | {:error, term()}, source :: Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, term()}
  def keep(result, %Vimage{} = source) do
    carry(result, source, fn gain_map, _scale -> {:ok, gain_map} end)
  end

  @doc false
  # Removes the gain map from the result of an operation that cannot yet
  # transform it, so the output saves as valid SDR rather than with a stale
  # gain map. An error result passes through untouched.
  @spec drop(result :: {:ok, Vimage.t()} | {:error, term()}) ::
          {:ok, Vimage.t()} | {:error, term()}
  def drop({:ok, %Vimage{} = image}) do
    remove(image)
  end

  def drop(result) do
    result
  end

  @doc false
  # Maps an area of the base image to gain map pixels. The near edges round
  # down and the far edges round up, clamped to the gain map, so the mapped
  # area always covers the base area and never loses an edge row or column.
  @spec scale_area(
          scale :: {float(), float()},
          gain_map :: Vimage.t(),
          left :: non_neg_integer(),
          top :: non_neg_integer(),
          width :: pos_integer(),
          height :: pos_integer()
        ) :: {non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer()}
  def scale_area({x_scale, y_scale}, %Vimage{} = gain_map, left, top, width, height) do
    {gain_left, gain_width} = scale_span(left, width, x_scale, Vimage.width(gain_map))
    {gain_top, gain_height} = scale_span(top, height, y_scale, Vimage.height(gain_map))
    {gain_left, gain_top, gain_width, gain_height}
  end

  defp scale_span(start, length, scale, limit) do
    first = min(max(floor(start * scale), 0), limit - 1)
    last = min(ceil((start + length) * scale), limit)
    {first, max(last - first, 1)}
  end
end
