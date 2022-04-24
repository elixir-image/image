defmodule Image.Social do
  @moduledoc """
  Functions to introspect standard image sizes for
  various social media platforms.

  """

  # Before Version 1.0, this content will move from being a static
  # list to a dynamic one that can be updated at runtime

  # Facebook: https://www.facebook.com/help/125379114252045?helpref=faq_content
  # https://www.socialpilot.co/blog/social-media-image-sizes
  # https://blog.hootsuite.com/social-media-image-sizes-guide/

  @social_sizes %{
    facebook: %{
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

end
