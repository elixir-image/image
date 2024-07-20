defmodule Image.Histogram do
  @moduledoc """
  A histogram is a graphical representation of the tonal
  distribution in a digital image. It plots the number
  of pixels for each tonal value. By looking at the histogram
  for a specific image a viewer will be able to judge the
  entire tonal distribution at a glance.

  The horizontal axis of the graph represents the tonal variations,
  while the vertical axis represents the total number of pixels in
  that particular tone.

  The left side of the horizontal axis represents the dark areas,
  the middle represents mid-tone values and the right hand side
  represents light areas. The vertical axis represents the size
  of the area (total number of pixels) that is captured in each
  one of these zones.

  Thus, the histogram for a very dark image will have most of
  its data points on the left side and center of the graph.

  Conversely, the histogram for a very bright image with few
  dark areas and/or shadows will have most of its data points
  on the right side and center of the graph.

  The histograms generated in this module have red, green,
  blue and luminance layers and can be returned as either an
  [svg](https://en.wikipedia.org/wiki/SVG) string or as an
  `t:Vimage.t/0`.

  The current implementation does not applying any scale
  compression or expansion and therefore where the image
  has very wide tonality differences the differences may
  be difficult to distinguish if `:height` is small.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation
  alias Image.Options

  # Both the number of histogram buckets
  # and the calculated max value of each
  # bucket.
  @max_value 255

  # In lch colorspace, the l band is
  # in the range 1..100 so we need to
  # extract the first 100 values and
  # expand the scale to cover 0..@max_value
  @number_of_luminance_values 100

  @doc """
  Returns an [svg](https://en.wikipedia.org/wiki/SVG) string
  representing a red, green, blue and luminance histogram
  for an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:width` is the integer width of the SVG image.
    The default is `:auto` which means the image is
    sized to its parent container.

  * `:height` is the integer height of the SVG image.
    The default is `:auto` which means the image is
    sized to its parent container.

  ### Returns

  * `{:ok, svg_string}` or

  * `{:error, reason}`.

  ### Histogram image sizing

  SVG will, by default, resize to fit its parent container
  in an HTMl page. `Image.Histogram.as_svg/2` will
  generate SVG with a default width and height of `auto`
  the reflects this intent.

  In some cases, such as generating images with
  `Image.Histogram.as_image/2`, `:width` and `:height` options
  should be provided (in pixels) to ensure the image is generated
  at the desired size.

  ### Attribution

  Thanks to [Alex Plescan](https://alexplescan.com/posts/2023/07/08/easy-svg-sparklines/)
  for the inspiration for the SVG design.

  """
  @doc since: "0.36.0"
  @doc subject: "Histogram"

  @spec as_svg(Vimage.t(), Options.Histogram.histogram_options()) ::
          {:ok, String.t()} | {:error, Image.error_message()}

  def as_svg(%Vimage{} = image, options \\ []) do
    with {:ok, options} <- Options.Histogram.validate_options(options),
         {:ok, srgb} <- Image.to_colorspace(image, :srgb),
         {:ok, lch} <- Image.to_colorspace(image, :lch),
         {:ok, srgb_histogram} <- Operation.hist_find(srgb),
         {:ok, lch_histogram} <- Operation.hist_find(lch),
         {:ok, {srgb_max, _}} <- Operation.max(srgb_histogram),
         {:ok, {lch_max, _}} <- Operation.max(lch_histogram) do
      svg =
        """
        <svg height="#{options.height}" width="#{options.width}" viewBox="0 0 #{@max_value} #{@max_value}" preserveAspectRatio="none">
          #{generate_histogram(srgb_histogram[2], srgb_max, :blue)}
          #{generate_histogram(srgb_histogram[1], srgb_max, :green)}
          #{generate_histogram(srgb_histogram[0], srgb_max, :red)}
          #{generate_histogram(lch_histogram[0], lch_max, :white)}
        </svg>
        """

      {:ok, svg}
    end
  end

  @doc """
  Returns an [svg](https://en.wikipedia.org/wiki/SVG) string
  representing a red, green, blue and luminance histogram for
  an image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:width` is the integer width of the SVG image.
    The default is `:auto` which means the image is
    sized to its parent container.

  * `:height` is the integer height of the SVG image.
    The default is `:auto` which means the image is
    sized to its parent container.

  ### Returns

  * `svg_string` or

  * raises an exception.

  ### Histogram image sizing

  SVG will, by default, resize to fit its parent container
  in an HTMl page. `Image.Histogram.as_svg/2` will
  generate SVG with a default width and height of `auto`
  the reflects this intent.

  In some cases, such as generating images with
  `Image.Histogram.as_image/2`, `:width` and `:height` options
  should be provided (in pixels) to ensure the image is generated
  at the desired size.

  ### Attribution

  Thanks to [Alex Plescan](https://alexplescan.com/posts/2023/07/08/easy-svg-sparklines/)
  for the inspiration for the SVG design.

  """
  @doc since: "0.36.0"
  @doc subject: "Histogram"

  @spec as_svg!(Vimage.t(), Options.Histogram.histogram_options()) ::
          String.t() | no_return()

  def as_svg!(%Vimage{} = image, options \\ []) do
    case as_svg(image, options) do
      {:ok, histogram} -> histogram
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns an image representing a red, green, blue and
  luminance histogram for an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:width` is the integer width of the SVG image.
    The default is `:auto` which means the image is
    sized to its parent container.

  * `:height` is the integer height of the SVG image.
    The default is `:auto` which means the image is
    sized to its parent container.

  ### Returns

  * `{:ok, histogram_image}` or

  * `{:error, reason}`.

  ### Histogram image sizing

  With `Image.Histogram.as_image/2` it is recommended that
  the `:width` and/or `:height` options be provided (in pixels)
  to ensure the image is generated at the desired size.

  The default of `:auto` will generate an image the size
  of the underlying SVG viewbox which is `#{@max_value}` pixels
  wide and `#{@max_value}` pixels high.

  """
  @doc since: "0.36.0"
  @doc subject: "Histogram"

  @spec as_image(Vimage.t(), Options.Histogram.histogram_options()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def as_image(%Vimage{} = image, options \\ []) do
    case as_svg(image, options) do
      {:ok, svg} -> Image.from_svg(svg)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns an image representing a red, green, blue and
  luminance histogram for an image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:width` is the integer width of the SVG image.
    The default is `:auto` which means the image is
    sized to its parent container.

  * `:height` is the integer height of the SVG image.
    The default is `:auto` which means the image is
    sized to its parent container.

  ### Returns

  * `histogram_image` or

  * raises an exception.

  ### Histogram image sizing

  With `Image.Histogram.as_image/2` it is recommended that
  the `:width` and/or `:height` options be provided (in pixels)
  to ensure the image is generated at the desired size.

  The default of `:auto` will generate an image the size
  of the underlying SVG viewbox which is `#{@max_value}` pixels
  wide and `#{@max_value}` pixels high.

  """
  @doc since: "0.36.0"
  @doc subject: "Histogram"

  @spec as_image!(Vimage.t(), Options.Histogram.histogram_options()) ::
          Vimage.t() | no_return()

  def as_image!(%Vimage{} = image, options \\ []) do
    case as_image(image, options) do
      {:ok, image} -> image
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_histogram(image, max, stroke_color, fill_color \\ nil) do
    {:ok, tensor} = Vix.Vips.Image.write_to_tensor(image)
    values = decode_binary(tensor, max)
    fill_color = fill_color || stroke_color

    """
    <path
      d="#{generate_fill(values)}"
      stroke="transparent"
      fill="#{fill_color}"
      fill-opacity="0.2"
    />
    <path
      d="#{generate_path(values)}"
      stroke-width="2"
      stroke="#{stroke_color}"
      fill="transparent"
      vector-effect="non-scaling-stroke"
    />
    """
  end

  defp decode_binary(tensor, image_max) do
    values =
      for <<value::native-integer-32 <- tensor.data>>,
        do: @max_value - fit(value, image_max)

    if rgb_histogram?(values) do
      values
    else
      resample_luminance(values)
    end
  end

  # This is a straight linear fit into
  # a range of 0..255. When there is a
  # spike in one tonal area we end up with
  # scale compression for the wider range.
  # Lightroom compresses the ranges in this
  # situation - something to look at for
  # the future.

  defp fit(value, image_max) do
    value * @max_value / image_max
  end

  # RGB histograms have 256 values,
  # lCH histograms have 360 values.

  defp rgb_histogram?(values) do
    length(values) == @max_value + 1
  end

  defp generate_path(values) do
    Enum.with_index(values, fn
      value, 0 ->
        [?M, ?\s, ?0, ?\s, to_string(value), ?\s]

      value, index ->
        [?L, ?\s, to_string(index), ?\s, to_string(value), ?\s]
    end)
    |> :erlang.iolist_to_binary()
  end

  @close_the_area "L #{@max_value} #{@max_value} L 0 #{@max_value} Z"

  defp generate_fill(values) do
    Enum.with_index(values, fn
      value, 0 ->
        [?M, ?\s, ?0, ?\s, to_string(value), ?\s]

      value, @max_value = index ->
        [?L, ?\s, to_string(index), ?\s, to_string(value), ?\s, @close_the_area]

      value, index ->
        [?L, ?\s, to_string(index), ?\s, to_string(value), ?\s]
    end)
    |> :erlang.iolist_to_binary()
  end

  # Here we are expanding the list of 100
  # luminanace values into a list of 256
  # luminance values. Its a bit ad-hoc but
  # reasonably efficient.

  defp resample_luminance(values) do
    values =
      values
      |> Enum.take(@number_of_luminance_values)
      |> Enum.with_index(fn
        v, i when rem(i, 3) == 0 -> [v, v, v]
        v, i when rem(i, 5) == 0 -> [v, v, v]
        v, i when rem(i, 7) == 0 -> [v, v, v]
        v, i when rem(i, 9) == 0 -> [v, v, v]
        v, _i -> [v, v]
      end)
      |> List.flatten()

    [hd(values) | values]
  end
end
