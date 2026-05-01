if Code.ensure_loaded?(Scholar.Cluster.KMeans) and Code.ensure_loaded?(Nx) do
  defmodule Image.Palette do
    @moduledoc """
    Extracts a small representative colour palette from an image.

    The pipeline is the one described in Amanda Hinton's
    [palette post](https://amandahinton.com/blog/creating-a-color-palette-from-an-image),
    adapted for `:image`:

      1. **Resize** the image so its longest side is `:longest_dim`
         pixels (default 300). The cost of every later step is
         linear in pixel count, so this is the single biggest
         performance knob.
      2. **Drop transparent pixels** when the image has alpha and
         convert the rest to sRGB.
      3. **Sample** up to `:max_pixels` pixels (default 90 000)
         uniformly.
      4. **Convert** the pixel batch to **Oklab** in one
         vectorised pass via `Image.Color.srgb_tensor_to_oklab/1`.
      5. **Cluster** in Oklab using
         [`Scholar.Cluster.KMeans`](https://hexdocs.pm/scholar/Scholar.Cluster.KMeans.html)
         with the chromatic axes weighted twice as much as
         lightness (`a`, `b` columns scaled by `√ab_weight`
         before fitting).
      6. **Merge near-duplicate clusters** via
         `Color.Palette.Cluster.merge_until/3`.
      7. **Phantom guard**: drop low-mass low-chroma clusters
         (default `< 2.5%` of total mass *and* centroid chroma
         `< 0.05`) so small pockets of near-grey pixels can't
         claim a palette slot.
      8. **Pick a representative** sRGB swatch per surviving
         cluster via `Color.Palette.Cluster.representative/2`.
      9. **Sort** the result with `Color.Palette.sort/2` so the
         output reads as a perceptual rainbow.

    The clustering and rep-selection primitives live in
    [`Color.Palette.Cluster`](https://hexdocs.pm/color/Color.Palette.Cluster.html)
    so the algorithm doesn't drift between this library and
    other callers (e.g. `Color.Palette.Summarize`).

    ## Determinism

    Pass `:key` (any `Nx.Random` key) to make the K-means
    initialisation deterministic; otherwise different runs may
    produce slightly different palettes for the same image.

    ## Requires

    `Image.Palette` is only compiled when both
    [`scholar`](https://hex.pm/packages/scholar) and
    [`nx`](https://hex.pm/packages/nx) are present.

    """

    alias Vix.Vips.Image, as: Vimage
    alias Color.Palette.Cluster

    @default_k 14
    @default_final 5
    @default_longest_dim 300
    @default_max_pixels 90_000
    @default_ab_weight 2.0
    @default_phantom_min_mass 0.025
    @default_phantom_max_chroma 0.05
    @default_rep_chroma_threshold 0.03
    @default_sort :hue_lightness

    @doc """
    Extracts a representative colour palette from an image.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    * `options` is a keyword list of options.

    ### Options

    * `:final` is the maximum number of swatches in the output.
      Default `#{@default_final}`. The output may be shorter
      after the phantom guard or if the input image has very
      few distinct colours.

    * `:k` is the number of K-means clusters used internally
      before the merge / phantom-guard passes. Default
      `#{@default_k}`. Must satisfy `k >= final`.

    * `:longest_dim` is the pre-clustering resize target. The
      image is thumbnailed so its longest side is this many
      pixels. Default `#{@default_longest_dim}`.

    * `:max_pixels` caps the post-resize sample size. Default
      `#{@default_max_pixels}`.

    * `:ab_weight` is the multiplier on the chromatic axes
      `(a, b)` in the Oklab distance metric, relative to
      lightness `L`. Default `#{@default_ab_weight}`. Used both
      during K-means (by pre-scaling the input columns) and
      during merge / rep-selection.

    * `:phantom_min_mass` is the fraction of total pixel mass
      below which a cluster is "phantom"-eligible. Default
      `#{@default_phantom_min_mass}`.

    * `:phantom_max_chroma` is the Oklch chroma below which a
      phantom-eligible cluster is dropped. Default
      `#{@default_phantom_max_chroma}`.

    * `:rep_chroma_threshold` is forwarded to
      `Color.Palette.Cluster.representative/2`. Default
      `#{@default_rep_chroma_threshold}`.

    * `:sort` selects the post-extraction sort strategy. One of
      the strategies accepted by `Color.Palette.sort/2`, or
      `false` to skip sorting and return clusters in K-means
      order. Default `#{inspect(@default_sort)}`.

    * `:key` is an `Nx.Random` key for deterministic K-means
      initialisation. Default: a fresh random key per call (so
      results are stable within a call but may vary between
      calls).

    ### Returns

    * `{:ok, [%Color.SRGB{}, ...]}` on success — a list of at
      most `:final` representative swatches.

    * `{:error, reason}` if image conversion or sampling fails.

    ### Examples

        iex> {:ok, image} = Image.open("./test/support/images/Hong-Kong-2015-07-1998.jpg")
        iex> {:ok, palette} = Image.Palette.extract(image, key: Nx.Random.key(42))
        iex> length(palette) <= 5
        true
        iex> Enum.all?(palette, &match?(%Color.SRGB{}, &1))
        true

    """
    @doc subject: "Clusters", since: "0.67.0"
    @spec extract(image :: Vimage.t(), options :: Keyword.t()) ::
            {:ok, [Color.SRGB.t()]} | {:error, term()}
    def extract(%Vimage{} = image, options \\ []) do
      options = put_defaults(options)

      with {:ok, sampled} <- prepare_pixels(image, options),
           clusters <- cluster(sampled, options),
           survivors <- post_process(clusters, sampled.total_mass, options) do
        swatches =
          survivors
          |> Enum.map(&Cluster.representative(&1, rep_options(options)))
          |> maybe_sort(options[:sort])

        {:ok, swatches}
      end
    end

    @doc """
    Same as `extract/2` but raises on error.

    ### Examples

        iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
        iex> palette = Image.Palette.extract!(image, key: Nx.Random.key(42))
        iex> length(palette) <= 5
        true

    """
    @doc subject: "Clusters", since: "0.67.0"
    @spec extract!(image :: Vimage.t(), options :: Keyword.t()) :: [Color.SRGB.t()]
    def extract!(%Vimage{} = image, options \\ []) do
      case extract(image, options) do
        {:ok, palette} -> palette
        {:error, reason} -> raise Image.Error, reason
      end
    end

    # ---- option handling --------------------------------------------------

    defp put_defaults(options) do
      options
      |> Keyword.put_new(:k, @default_k)
      |> Keyword.put_new(:final, @default_final)
      |> Keyword.put_new(:longest_dim, @default_longest_dim)
      |> Keyword.put_new(:max_pixels, @default_max_pixels)
      |> Keyword.put_new(:ab_weight, @default_ab_weight)
      |> Keyword.put_new(:phantom_min_mass, @default_phantom_min_mass)
      |> Keyword.put_new(:phantom_max_chroma, @default_phantom_max_chroma)
      |> Keyword.put_new(:rep_chroma_threshold, @default_rep_chroma_threshold)
      |> Keyword.put_new(:sort, @default_sort)
    end

    defp rep_options(options) do
      [
        ab_weight: Keyword.fetch!(options, :ab_weight),
        rep_chroma_threshold: Keyword.fetch!(options, :rep_chroma_threshold)
      ]
    end

    defp maybe_sort(swatches, false), do: swatches
    defp maybe_sort(swatches, nil), do: swatches

    defp maybe_sort(swatches, strategy) when is_atom(strategy) do
      Color.Palette.sort(swatches, strategy: strategy)
    end

    # ---- pixel preparation ------------------------------------------------
    #
    # Returns `{:ok, %{srgb: tensor_n_by_3_u8, oklab: tensor_n_by_3_f32,
    # total_mass: integer}}` ready for K-means.
    defp prepare_pixels(%Vimage{} = image, options) do
      with {:ok, resized} <- resize_image(image, options[:longest_dim]),
           {:ok, srgb_image} <- Image.to_colorspace(resized, :srgb),
           {:ok, srgb_pixels} <- pixels_to_tensor(srgb_image),
           sampled <- subsample(srgb_pixels, options[:max_pixels]) do
        {:ok,
         %{
           srgb: sampled,
           oklab: Image.Color.srgb_tensor_to_oklab(sampled),
           total_mass: Nx.axis_size(sampled, 0)
         }}
      end
    end

    defp resize_image(image, longest_dim) do
      width = Image.width(image)
      height = Image.height(image)
      longest = max(width, height)

      if longest <= longest_dim do
        {:ok, image}
      else
        Image.thumbnail(image, longest_dim)
      end
    end

    # Read pixels into an Nx tensor of shape `{n, 3}`, dropping
    # the alpha band when present and discarding rows whose
    # original alpha was below 128 (Hinton's threshold). Returns
    # an u8 tensor.
    defp pixels_to_tensor(%Vimage{} = image) do
      with {:ok, tensor} <- Image.to_nx(image, shape: :hwc) do
        bands = Image.bands(image)

        flat = Nx.reshape(tensor, {:auto, bands})

        rgb =
          case bands do
            3 ->
              flat

            4 ->
              alpha = Nx.slice_along_axis(flat, 3, 1, axis: 1)
              colour = Nx.slice_along_axis(flat, 0, 3, axis: 1)
              keep = Nx.greater_equal(alpha, 128) |> Nx.reshape({:auto})
              indices = Nx.argsort(keep, direction: :desc)
              n_keep = Nx.sum(keep) |> Nx.to_number()
              kept_rows = Nx.take(colour, Nx.slice_along_axis(indices, 0, n_keep, axis: 0))
              kept_rows

            _ ->
              flat
          end

        {:ok, ensure_u8(rgb)}
      end
    end

    defp ensure_u8(tensor) do
      case Nx.type(tensor) do
        {:u, 8} -> tensor
        _ -> Nx.as_type(tensor, :u8)
      end
    end

    # Cap the total pixel count at `:max_pixels` by uniform-stride
    # sampling. Cheaper and more cache-friendly than random
    # selection; uniform-stride preserves an even spatial spread
    # for typical photographs.
    defp subsample(tensor, max_pixels) do
      n = Nx.axis_size(tensor, 0)

      if n <= max_pixels do
        tensor
      else
        stride = max(div(n, max_pixels), 1)
        n_keep = div(n, stride)
        Nx.take(tensor, Nx.multiply(Nx.iota({n_keep}), stride))
      end
    end

    # ---- K-means clustering -----------------------------------------------
    #
    # The chromatic-axis weight is applied by scaling the `a, b`
    # columns of the input by `√ab_weight` *before* fitting. The
    # fit then uses ordinary squared-Euclidean distance, but the
    # geometry it sees is the weighted one — so centroids and
    # assignments are perceptually weighted with no algorithm
    # changes. After fitting the centroids are descaled back to
    # raw Oklab so downstream code (Color.Palette.Cluster, etc.)
    # sees ordinary Oklab values.
    defp cluster(sampled, options) do
      ab_weight = options[:ab_weight]
      k = options[:k]
      key = options[:key] || Nx.Random.key(System.unique_integer([:positive]))

      scale = scale_tensor(ab_weight)
      weighted = Nx.multiply(sampled.oklab, scale)

      kmeans =
        Scholar.Cluster.KMeans.fit(weighted,
          num_clusters: k,
          key: key
        )

      centroids =
        kmeans.clusters
        |> Nx.divide(scale)
        |> Nx.to_list()
        |> Enum.map(&list_to_lab/1)

      assignments = Nx.to_list(kmeans.labels)

      build_clusters(centroids, assignments, sampled)
    end

    # `[1.0, √ab_weight, √ab_weight]` broadcast across rows.
    defp scale_tensor(ab_weight) do
      ab_scale = :math.sqrt(ab_weight)
      Nx.tensor([[1.0, ab_scale, ab_scale]], type: :f32)
    end

    # Wrap each centroid as a `Color.Palette.Cluster` map. Each
    # cluster's *single* member is the centroid itself — the rep
    # selection then just returns that member's `:output`. This
    # is intentional: with K-means in Oklab the centroid is
    # already the perceptually-best summary of its assigned
    # pixels. Storing every assigned pixel as a member would
    # blow up memory (≤ 90 000 inputs is the cap) for no
    # representativeness gain — `representative/2`'s
    # mass-weighted-chroma rule is a no-op when there's one
    # member.
    defp build_clusters(centroids, assignments, _sampled) do
      counts =
        Enum.reduce(assignments, %{}, fn idx, acc -> Map.update(acc, idx, 1, &(&1 + 1)) end)

      centroids
      |> Enum.with_index()
      |> Enum.map(fn {{l, a, b}, idx} ->
        mass = Map.get(counts, idx, 0) * 1.0
        oklab = %Color.Oklab{l: l, a: a, b: b}
        oklch = oklab |> oklch_from_oklab()
        srgb = oklab_to_srgb(oklab)

        member = %{output: srgb, oklab: oklab, oklch: oklch, mass: mass}

        %{centroid: {l, a, b}, mass: mass, members: [member]}
      end)
      |> Enum.reject(fn cluster -> cluster.mass == 0.0 end)
    end

    # Convert centroid → SRGB via existing :color paths. Falls
    # back to clamped sRGB on out-of-gamut centroids.
    defp oklab_to_srgb(%Color.Oklab{} = oklab) do
      case Color.Gamut.to_gamut(oklab, :SRGB) do
        {:ok, srgb} -> srgb
        # Mid-grey fallback for the rare case that gamut
        # mapping refuses (e.g. NaN/Inf inputs from a degenerate
        # K-means run).
        _ -> %Color.SRGB{r: 0.5, g: 0.5, b: 0.5}
      end
    end

    defp oklch_from_oklab(%Color.Oklab{l: l, a: a, b: b}) do
      c = :math.sqrt(a * a + b * b)

      h =
        case :math.atan2(b, a) * 180 / :math.pi() do
          deg when deg < 0 -> deg + 360.0
          deg -> deg
        end

      %Color.Oklch{l: l, c: c, h: h}
    end

    # Convert a list tuple `[l, a, b]` (as Nx returns) into a
    # `{l, a, b}` tuple for downstream consumption.
    @compile {:inline, list_to_lab: 1}
    defp list_to_lab([l, a, b]), do: {l, a, b}

    # ---- post-processing --------------------------------------------------
    #
    # Merge near-duplicates, drop phantoms, then collapse down to
    # the requested final count.
    defp post_process(clusters, total_mass, options) do
      ab_weight = options[:ab_weight]
      final = options[:final]
      phantom_min_mass = options[:phantom_min_mass]
      phantom_max_chroma = options[:phantom_max_chroma]

      clusters
      |> phantom_guard(total_mass, phantom_min_mass, phantom_max_chroma)
      |> Cluster.merge_until(final, ab_weight: ab_weight)
    end

    # Drop clusters that are simultaneously low-mass AND
    # low-chroma. The combination is the discriminator: a small
    # cluster of vivid pixels is keepable (a tiny accent), and a
    # large cluster of grey pixels is keepable (an achromatic
    # background) — but a small cluster of grey pixels is the
    # "phantom" pattern Hinton flags.
    defp phantom_guard(clusters, total_mass, min_mass_fraction, max_chroma)
         when total_mass > 0 do
      threshold_mass = min_mass_fraction * total_mass

      kept =
        Enum.reject(clusters, fn cluster ->
          {_l, a, b} = cluster.centroid
          centroid_chroma = :math.sqrt(a * a + b * b)

          cluster.mass < threshold_mass and centroid_chroma < max_chroma
        end)

      # Belt and braces: never drop *every* cluster — if the
      # filter would empty the list, return the input untouched.
      if kept == [], do: clusters, else: kept
    end

    defp phantom_guard(clusters, _total_mass, _min, _max), do: clusters
  end
end
