defmodule Image.Social do
  @moduledoc """
  Functions to introspect standard image sizes for
  various social media platforms.

  """

  alias Vix.Vips.Image, as: Vimage

  @typedoc """
  The social media platform image usage.

  """
  @type image_usage :: atom()

  @typedoc """
  The known social media platforms.

  """
  @type platform ::
          :facebook
          | :twitter
          | :linkedin
          | :pinterest
          | :instagram
          | :tumblr
          | :youtube
          | :snapchat
          | :tiktok

  # Before Version 1.0, this content will move from being a static
  # list to a dynamic one that can be updated at runtime

  # Facebook: https://www.facebook.com/help/125379114252045?helpref=faq_content
  # https://www.socialpilot.co/blog/social-media-image-sizes
  # https://blog.hootsuite.com/social-media-image-sizes-guide/

  @social_sizes %{
    facebook: %{
      default: :post,
      profile: "170x170",
      cover_desktop: "820x312",
      cover_mobile: "640x360",
      post: "1200x630",
      banner: "1200x630",
      story: "1080x1920"
    },
    twitter: %{
      profile: "400x400",
      cover: "1500x500",
      shared: "900x450",
      stream: "440x220"
    },
    linkedin: %{
      profile: "400x400",
      cover: "1584x396",
      company_logo: "400x400",
      blog: "1200x627"
    },
    pinterest: %{
      profile: "165x165",
      cover: "800x450",
      pin: "1080x1920",
      board: "222x150"
    },
    instagram: %{
      profile: "320x320",
      cover: "1080x1920",
      photo: %{
        landscape: "1080x596",
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
      profile: "128x128",
      banner: "3000x1055",
      post: "500x750"
    },
    youtube: %{
      cover: "2560x1440",
      profile: "800x800",
      banner: "2048x1152",
      thumbnail: "1280x720"
    },
    snapchat: %{
      photo: "1080x1920",
      share: "750x1334"
    },
    tiktok: %{
      profile: "20x20",
      video: "1080x1920"
    }
  }

  @social_platforms Map.keys(@social_sizes)

  @doc """
  Return the map of social media image
  sizes.

  The returned map of maps is of a standard form:

  * The first key is the platform name (ie `:twitter`)
  * The second key is the image type for the platform (ie `:profile`)
  * The third level is optional. But if it exists it must
    have three keys: `:landscape`, `:portrait` and `:square`

  The values are all of the form "WxH" where `W` is the
  width in pixels and `H` is the height in pixels.

  """
  def media_sizes do
    @social_sizes
  end

  @doc """
  Returns a list of known social
  platforms.

  ### Example


  """
  @spec known_platforms :: [platform()]
  def known_platforms do
    @social_platforms
  end

  @doc """
  Returns the image types for the given
  social platform.

  ### Arguments

  * `platform` is any known social platform.
    See `Image.Social.known_platforms/0`.

  ### Returns

  * A list of images uses available for the
    platform.

  ### Example


  """
  @spec image_usages(platform()) :: [image_usage()]
  def image_usages(platform) when platform in @social_platforms do
    media_sizes()
    |> Map.fetch!(platform)
    |> Map.delete(:default)
    |> Map.keys()
  end

  @doc """
  Returns the default image type that an
  image is resized to for a given platform
  is no `:type` parameter is provided.

  ### Arguments

  * `platform` is any known social platform.
    See `Image.Social.known_platforms/0`.

  ### Returns

  * The default image type for the platform.

  ### Example

  """
  @spec default_image_usage(platform()) :: image_usage()
  def default_image_usage(platform) when platform in @social_platforms do
    media_sizes()
    |> Map.fetch!(platform)
    |> Map.get(:default)
  end

  @doc """
  Resize an image for a particular social
  platform and usage.

  This function:

  * Resizes an image to the correct dimensions, including being
    image aspect aware
  * Converts to the sRGB color space
  * Minimises metadata (retains only Artist and Copyright)

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  * `platform` is the name of a known social
    media platform. See `Image.Social.known_platforms/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:type` is the image type within the social
    platform for which the image should be resized. See
    `Image.Social.image_usages/1`

  * All other options are passed to `Image.thumbnail!/3`.

  ### Returns

  * `{:ok, resized_image}` or

  * `{:error, reason}`

  """
  @spec resize(Vimage.t(), platform(), Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def resize(image, platform, options \\ [])

  def resize(%Vimage{} = image, platform, options) when platform in @social_platforms do
    {usage, options} = Keyword.pop(options, :usage, :default)
    options = Keyword.put_new(options, :crop, :attention)
    aspect = Image.aspect(image)
    platform = Map.fetch!(media_sizes(), platform)

    with {:ok, size} <- get_image_size(platform, usage, aspect) do
      image
      |> Image.thumbnail!(size, options)
      |> Image.to_colorspace!(:srgb)
      |> Image.minimize_metadata()
    end
  end

  def resize(%Vimage{} = _image, platform, _options) do
    {:error, unknown_platform_error(platform)}
  end

  @doc """
  Resize an image for a particular social
  platform and usage.

  This function:

  * Resizes an image to the correct dimensions, including being
    image orientation aware
  * Converts to the sRGB color space
  * Minimises metadata (retains only Artist and Copyright)

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  * `platform` is the name of a known social
    media platform. See `Image.Social.known_platforms/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:type` is the image type within the social
    platform for which the image should be resized. See
    `Image.Social.image_usages/1`

  * All other options are passed to `Image.thumbnail!/3`.

  ## Returns

  * `resized_image` or

  * Raises an exception.

  """
  @spec resize!(Vimage.t(), platform(), Keyword.t()) ::
          Vimage.t() | no_return

  def resize!(%Vimage{} = image, platform, options \\ []) do
    case resize(image, platform, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # ---- Helpers -----

  defp get_image_size(platform, :default = type, orientation) do
    default = Map.get(platform, type, {nil, type})
    get_image_size(platform, default, orientation)
  end

  defp get_image_size(_platform, {nil, usage}, _orientation) do
    {:error, unknown_usage_error(usage)}
  end

  defp get_image_size(platform, usage, orientation) when is_map_key(platform, usage) do
    platform
    |> Map.get(usage)
    |> resolve_orientation(orientation)
  end

  defp get_image_size(_platform, usage, _orientation) do
    {:error, unknown_usage_error(usage)}
  end

  defp resolve_orientation(size, _orientation) when is_binary(size) do
    {:ok, size}
  end

  defp resolve_orientation(sizes, orientation) when is_map_key(sizes, orientation) do
    {:ok, Map.fetch!(sizes, orientation)}
  end

  defp resolve_orientation(_sizes, orientation) do
    {:error, unknown_orientation_error(orientation)}
  end

  defp unknown_platform_error(platform) do
    "Unknown social platform #{inspect(platform)}"
  end

  defp unknown_usage_error(:default) do
    "No :default usage is configured"
  end

  defp unknown_usage_error(usage) do
    "Unknown image usage #{inspect(usage)}"
  end

  defp unknown_orientation_error(orientation) do
    "Unknown orientation #{inspect(orientation)}"
  end
end
