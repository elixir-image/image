defmodule Image.Social do
  @moduledoc """
  Functions to introspect standard image sizes for
  various social media platforms, and to resize an image
  for a platform.

  The public API is `resize/3` and `resize!/3`, which resize
  an image for a platform and image usage, and
  `known_platforms/0`, `image_usages/1`,
  `default_image_usage/1` and `media_sizes/0`, which describe
  the platforms and sizes available.

  The known platforms are `:facebook`, `:x`, `:linkedin`,
  `:pinterest`, `:instagram`, `:tumblr`, `:youtube`,
  `:snapchat` and `:tiktok`. Every platform has a default
  usage, which `resize/3` uses when no `:usage` is given.

  `:twitter` is accepted wherever a platform is expected and
  is treated as `:x`. It is deprecated and will be removed at
  version 1.0.

  The sizes are each platform's recommended upload size, taken
  from the platform's own help pages where they publish one and
  otherwise from current social media image size guides.

  """

  alias Vix.Vips.Image, as: Vimage

  @typedoc """
  The social media platform image usage.

  """
  @type image_usage :: atom()

  @typedoc """
  The known social media platforms. `:twitter` is a deprecated
  alias for `:x`.

  """
  @type platform ::
          :facebook
          | :x
          | :twitter
          | :linkedin
          | :pinterest
          | :instagram
          | :tumblr
          | :youtube
          | :snapchat
          | :tiktok

  # Sources, reviewed 2026-11-21:
  # Facebook: https://www.facebook.com/help/125379114252045
  # X: https://help.x.com/en/managing-your-account/common-issues-when-uploading-profile-photo
  # LinkedIn: https://www.linkedin.com/help/linkedin/answer/a563309
  # Pinterest: https://business.pinterest.com/creative-best-practices
  # YouTube: https://support.google.com/youtube/answer/10456525
  # Others: https://blog.hootsuite.com/social-media-image-sizes-guide/
  # and https://sproutsocial.com/insights/social-media-image-sizes-guide/

  @social_sizes %{
    facebook: %{
      default: :post,
      profile: "320x320",
      cover: "851x315",
      post: "1200x630",
      story: "1080x1920"
    },
    x: %{
      default: :post,
      profile: "400x400",
      cover: "1500x500",
      post: "1600x900"
    },
    linkedin: %{
      default: :blog,
      profile: "400x400",
      cover: "1584x396",
      company_logo: "400x400",
      blog: "1200x627"
    },
    pinterest: %{
      default: :pin,
      profile: "165x165",
      cover: "800x450",
      pin: "1000x1500"
    },
    instagram: %{
      default: :photo,
      profile: "320x320",
      photo: %{
        landscape: "1080x566",
        portrait: "1080x1350",
        square: "1080x1080"
      },
      thumb: "161x161",
      story: "1080x1920",
      carousel: %{
        landscape: "1080x566",
        portrait: "1080x1350",
        square: "1080x1080"
      }
    },
    tumblr: %{
      default: :post,
      profile: "128x128",
      banner: "3000x1055",
      post: "500x750"
    },
    youtube: %{
      default: :thumbnail,
      profile: "800x800",
      banner: "2560x1440",
      thumbnail: "1280x720"
    },
    snapchat: %{
      default: :photo,
      photo: "1080x1920"
    },
    tiktok: %{
      default: :video,
      profile: "200x200",
      video: "1080x1920"
    }
  }

  @social_platforms Map.keys(@social_sizes)

  # Deprecated platform names and the platform each now names.
  @platform_aliases %{twitter: :x}

  @doc """
  Return the map of social media image
  sizes.

  The returned map of maps is of a standard form:

  * The first key is the platform name, such as `:x`.

  * The second key is the image usage for that platform, such as
    `:profile`. The `:default` key names the usage that
    `resize/3` uses when no `:usage` is given.

  * The third level is optional, but when it exists it has three
    keys: `:landscape`, `:portrait` and `:square`.

  The values are all of the form `"WxH"` where `W` is the width
  in pixels and `H` is the height in pixels.

  ### Returns

  * a map of maps in the form described above.

  ### Examples

      iex> sizes = Image.Social.media_sizes()
      iex> Map.has_key?(sizes, :x)
      true

      iex> sizes = Image.Social.media_sizes()
      iex> get_in(sizes, [:youtube, :thumbnail])
      "1280x720"

  """
  @spec media_sizes() :: %{optional(platform()) => %{optional(image_usage()) => term()}}
  def media_sizes do
    @social_sizes
  end

  @doc """
  Returns a list of known social platforms.

  ### Returns

  * a list of platform names as atoms. The deprecated
    `:twitter` alias is not included.

  ### Examples

      iex> :x in Image.Social.known_platforms()
      true

      iex> :instagram in Image.Social.known_platforms()
      true

  """
  @spec known_platforms :: [platform()]
  def known_platforms do
    @social_platforms
  end

  @doc """
  Returns the image usages for the given
  social platform.

  ### Arguments

  * `platform` is any known social platform.
    See `Image.Social.known_platforms/0`.

  ### Returns

  * `{:ok, usages}` where `usages` is a list of the image
    usages available for the platform, or

  * `{:error, %Image.Error{reason: :unknown_platform}}`.

  ### Examples

      iex> {:ok, usages} = Image.Social.image_usages(:x)
      iex> Enum.sort(usages)
      [:cover, :post, :profile]

      iex> {:error, %Image.Error{reason: :unknown_platform}} =
      ...>   Image.Social.image_usages(:myspace)

  """
  @spec image_usages(platform()) :: {:ok, [image_usage()]} | {:error, Image.Error.t()}
  def image_usages(platform) do
    platform
    |> canonical_platform()
    |> usages()
  end

  @doc """
  Returns the default image usage that an
  image is resized to for a given platform
  if no `:usage` option is provided.

  ### Arguments

  * `platform` is any known social platform.
    See `Image.Social.known_platforms/0`.

  ### Returns

  * `{:ok, usage}` where `usage` is the platform's default
    image usage, or

  * `{:error, %Image.Error{reason: :unknown_platform}}`.

  ### Examples

      iex> Image.Social.default_image_usage(:facebook)
      {:ok, :post}

      iex> Image.Social.default_image_usage(:youtube)
      {:ok, :thumbnail}

  """
  @spec default_image_usage(platform()) :: {:ok, image_usage()} | {:error, Image.Error.t()}
  def default_image_usage(platform) do
    platform
    |> canonical_platform()
    |> default_usage(:default_image_usage)
  end

  @doc """
  Resize an image for a particular social
  platform and usage.

  This function:

  * Resizes an image to the correct dimensions, including being
    image aspect aware.

  * Converts to the sRGB color space.

  * Minimises metadata (retains only Artist and Copyright).

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `platform` is the name of a known social
    media platform. See `Image.Social.known_platforms/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:usage` is the image usage within the social
    platform for which the image should be resized. See
    `Image.Social.image_usages/1`. The default is the
    platform's default usage. See
    `Image.Social.default_image_usage/1`.

  * All other options are passed to `Image.thumbnail/3`.
    `:crop` defaults to `:attention`.

  ### Returns

  * `{:ok, resized_image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(1500, 1500, color: :blue)
      iex> {:ok, resized} = Image.Social.resize(image, :youtube, usage: :thumbnail)
      iex> Image.shape(resized)
      {1280, 720, 3}

      iex> image = Image.new!(1500, 1500, color: :blue)
      iex> {:error, %Image.Error{reason: :unknown_platform}} =
      ...>   Image.Social.resize(image, :not_a_platform)

  """
  @spec resize(Vimage.t(), platform(), Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def resize(image, platform, options \\ []) do
    do_resize(image, canonical_platform(platform), options)
  end

  @doc """
  Resize an image for a particular social
  platform and usage, raising on error.

  This function:

  * Resizes an image to the correct dimensions, including being
    image aspect aware.

  * Converts to the sRGB color space.

  * Minimises metadata (retains only Artist and Copyright).

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `platform` is the name of a known social
    media platform. See `Image.Social.known_platforms/0`.

  * `options` is a keyword list of options.

  ### Options

  * See `Image.Social.resize/3`.

  ### Returns

  * `resized_image`, or

  * raises an exception.

  ### Examples

      iex> image = Image.new!(1500, 1500, color: :blue)
      iex> resized = Image.Social.resize!(image, :x, usage: :profile)
      iex> Image.shape(resized)
      {400, 400, 3}

  """
  @spec resize!(Vimage.t(), platform(), Keyword.t()) :: Vimage.t() | no_return()

  def resize!(image, platform, options \\ []) do
    case resize(image, platform, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # ---- Helpers -----

  defp canonical_platform(platform) do
    Map.get(@platform_aliases, platform, platform)
  end

  defp usages(platform) when platform in @social_platforms do
    usages =
      media_sizes()
      |> Map.fetch!(platform)
      |> Map.delete(:default)
      |> Map.keys()

    {:ok, usages}
  end

  defp usages(platform) do
    {:error, unknown_platform_error(platform, :image_usages)}
  end

  defp do_resize(%Vimage{} = image, platform, options) when platform in @social_platforms do
    {usage, options} = Keyword.pop(options, :usage, :default)
    options = Keyword.put_new(options, :crop, :attention)

    with {:ok, usage} <- resolve_usage(platform, usage),
         {:ok, size} <- image_size(platform, usage, Image.aspect(image)),
         {:ok, resized} <- Image.thumbnail(image, size, options),
         {:ok, srgb} <- Image.to_colorspace(resized, :srgb) do
      Image.minimize_metadata(srgb)
    end
  end

  defp do_resize(%Vimage{} = _image, platform, _options) do
    {:error, unknown_platform_error(platform, :resize)}
  end

  defp do_resize(other, _platform, _options) do
    {:error,
     social_error(:invalid_image, :resize, other, "Expected an image, got #{inspect(other)}")}
  end

  defp resolve_usage(platform, :default) do
    default_usage(platform, :resize)
  end

  defp resolve_usage(_platform, usage) do
    {:ok, usage}
  end

  # Every platform in @social_sizes has a :default usage, which a test
  # checks, so the fetch cannot fail.
  defp default_usage(platform, _operation) when platform in @social_platforms do
    usage =
      media_sizes()
      |> Map.fetch!(platform)
      |> Map.fetch!(:default)

    {:ok, usage}
  end

  defp default_usage(platform, operation) do
    {:error, unknown_platform_error(platform, operation)}
  end

  # A :default usage is resolved by resolve_usage/2 before this is
  # called, so the :default key is never looked up as a size.
  defp image_size(platform, usage, aspect) do
    sizes = Map.fetch!(media_sizes(), platform)

    case Map.fetch(sizes, usage) do
      {:ok, size} when is_binary(size) -> {:ok, size}
      {:ok, %{} = sizes_by_aspect} -> size_for_aspect(sizes_by_aspect, aspect)
      :error -> {:error, unknown_usage_error(usage)}
    end
  end

  defp size_for_aspect(sizes_by_aspect, aspect) do
    case Map.fetch(sizes_by_aspect, aspect) do
      {:ok, size} ->
        {:ok, size}

      :error ->
        message = "Unknown aspect #{inspect(aspect)}"
        {:error, social_error(:unknown_aspect, :resize, aspect, message)}
    end
  end

  defp unknown_platform_error(platform, operation) do
    message = "Unknown social platform #{inspect(platform)}"
    social_error(:unknown_platform, operation, platform, message)
  end

  defp unknown_usage_error(usage) do
    message = "Unknown image usage #{inspect(usage)}"
    social_error(:unknown_usage, :resize, usage, message)
  end

  defp social_error(reason, operation, value, message) do
    %Image.Error{reason: reason, operation: operation, value: value, message: message}
  end
end
