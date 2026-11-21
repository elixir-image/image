defmodule Image.SocialCoverageTest do
  use ExUnit.Case, async: true

  describe "media_sizes/0" do
    test "returns a map keyed by platform" do
      sizes = Image.Social.media_sizes()
      assert is_map(sizes)

      for platform <- Image.Social.known_platforms() do
        assert Map.has_key?(sizes, platform)
      end
    end

    test "all leaf sizes are in WxH form" do
      for {_platform, usages} <- Image.Social.media_sizes(),
          {usage, size} <- usages,
          usage != :default do
        case size do
          size when is_binary(size) ->
            assert size =~ ~r/^\d+x\d+$/

          %{} = orientations ->
            assert Enum.sort(Map.keys(orientations)) == [:landscape, :portrait, :square]

            for {_orientation, orientation_size} <- orientations do
              assert orientation_size =~ ~r/^\d+x\d+$/
            end
        end
      end
    end
  end

  describe "known_platforms/0" do
    test "returns the expected platforms" do
      platforms = Image.Social.known_platforms()

      assert Enum.sort(platforms) ==
               Enum.sort([
                 :facebook,
                 :x,
                 :linkedin,
                 :pinterest,
                 :instagram,
                 :tumblr,
                 :youtube,
                 :snapchat,
                 :tiktok
               ])
    end
  end

  # An atom the type checker cannot narrow to a literal, so that
  # deliberately-invalid arguments do not raise compile-time type warnings.
  defp unknown_platform do
    String.to_atom("myspace")
  end

  # A value the type checker cannot narrow to nil, for the same reason.
  defp not_an_image do
    List.first([nil])
  end

  describe "image_usages/1" do
    test "returns the usages for each known platform without :default" do
      for platform <- Image.Social.known_platforms() do
        assert {:ok, usages} = Image.Social.image_usages(platform)
        assert is_list(usages)
        refute Enum.empty?(usages)
        refute :default in usages
      end
    end

    test "youtube usages include :thumbnail" do
      assert {:ok, usages} = Image.Social.image_usages(:youtube)
      assert :thumbnail in usages
    end

    test ":twitter returns the usages of :x" do
      assert Image.Social.image_usages(:twitter) == Image.Social.image_usages(:x)
    end

    test "returns an error for an unknown platform" do
      assert {:error,
              %Image.Error{
                reason: :unknown_platform,
                operation: :image_usages,
                value: :myspace,
                message: "Unknown social platform :myspace"
              }} = Image.Social.image_usages(unknown_platform())
    end

    test "returns an error for a non-atom platform" do
      for platform <- [nil, "", "twitter", 42, %{}] do
        assert {:error, %Image.Error{reason: :unknown_platform}} =
                 Image.Social.image_usages(platform)
      end
    end
  end

  describe "default_image_usage/1" do
    test "facebook default is :post" do
      assert Image.Social.default_image_usage(:facebook) == {:ok, :post}
    end

    test ":twitter returns the default of :x" do
      assert Image.Social.default_image_usage(:twitter) == {:ok, :post}
    end

    test "every platform has a default that is one of its usages" do
      for platform <- Image.Social.known_platforms() do
        assert {:ok, default} = Image.Social.default_image_usage(platform)
        assert {:ok, usages} = Image.Social.image_usages(platform)
        assert default in usages, "#{platform} default #{default} is not a usage"
      end
    end

    test "the platform defaults" do
      defaults =
        Map.new(Image.Social.known_platforms(), fn platform ->
          {:ok, default} = Image.Social.default_image_usage(platform)
          {platform, default}
        end)

      assert defaults == %{
               facebook: :post,
               x: :post,
               linkedin: :blog,
               pinterest: :pin,
               instagram: :photo,
               tumblr: :post,
               youtube: :thumbnail,
               snapchat: :photo,
               tiktok: :video
             }
    end

    test "returns an error for an unknown platform" do
      assert {:error, %Image.Error{reason: :unknown_platform, value: :myspace}} =
               Image.Social.default_image_usage(unknown_platform())
    end

    test "returns an error for a non-atom platform" do
      for platform <- [nil, "", "facebook", 42, %{}] do
        assert {:error, %Image.Error{reason: :unknown_platform}} =
                 Image.Social.default_image_usage(platform)
      end
    end
  end

  describe "resize/3" do
    test "resizes to a named usage for a platform" do
      image = Image.new!(100, 100, color: [10, 20, 30])

      assert {:ok, resized} = Image.Social.resize(image, :tiktok, usage: :profile)
      assert Image.width(resized) == 200
      assert Image.height(resized) == 200
      assert Image.colorspace(resized) == :srgb
    end

    test "crops to the 2:3 pinterest pin size" do
      image = Image.new!(444, 300, color: [200, 100, 50])

      assert {:ok, resized} = Image.Social.resize(image, :pinterest, usage: :pin)
      assert Image.width(resized) == 1000
      assert Image.height(resized) == 1500
    end

    test "resizes for each platform's default usage" do
      image = Image.new!(160, 90, color: [10, 20, 30])

      assert {:ok, resized} = Image.Social.resize(image, :x)
      assert {Image.width(resized), Image.height(resized)} == {1600, 900}

      assert {:ok, resized} = Image.Social.resize(image, :youtube)
      assert {Image.width(resized), Image.height(resized)} == {1280, 720}

      assert {:ok, resized} = Image.Social.resize(image, :tiktok)
      assert {Image.width(resized), Image.height(resized)} == {1080, 1920}
    end

    test "the instagram default follows the image aspect" do
      landscape = Image.new!(200, 100, color: [10, 20, 30])
      portrait = Image.new!(100, 200, color: [10, 20, 30])

      assert {:ok, resized} = Image.Social.resize(landscape, :instagram)
      assert {Image.width(resized), Image.height(resized)} == {1080, 566}

      assert {:ok, resized} = Image.Social.resize(portrait, :instagram)
      assert {Image.width(resized), Image.height(resized)} == {1080, 1350}
    end

    test ":twitter is an alias for :x" do
      image = Image.new!(160, 90, color: [10, 20, 30])

      assert {:ok, resized} = Image.Social.resize(image, :twitter, usage: :profile)
      assert {Image.width(resized), Image.height(resized)} == {400, 400}

      assert {:ok, resized} = Image.Social.resize(image, :twitter)
      assert {Image.width(resized), Image.height(resized)} == {1600, 900}
    end

    test "removed usages return an unknown usage error" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      for {platform, usage} <- [
            x: :stream,
            x: :shared,
            facebook: :banner,
            facebook: :cover_desktop,
            pinterest: :board,
            instagram: :cover,
            youtube: :cover,
            snapchat: :share
          ] do
        assert {:error, %Image.Error{reason: :unknown_usage, value: ^usage}} =
                 Image.Social.resize(image, platform, usage: usage)
      end
    end

    test "uses the platform default usage when no usage is given" do
      image = Image.new!(120, 63, color: [10, 20, 30])

      assert {:ok, resized} = Image.Social.resize(image, :facebook)
      assert Image.width(resized) == 1200
      assert Image.height(resized) == 630
    end

    test "resolves orientation-specific sizes for a square image" do
      image = Image.new!(108, 108, color: [10, 20, 30])

      assert {:ok, resized} = Image.Social.resize(image, :instagram, usage: :photo)
      assert Image.width(resized) == 1080
      assert Image.height(resized) == 1080
    end

    test "returns an error for an unknown usage" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:error,
              %Image.Error{
                reason: :unknown_usage,
                value: :bogus,
                message: "Unknown image usage :bogus"
              }} = Image.Social.resize(image, :x, usage: :bogus)
    end

    test "returns an error for a usage that is not an atom" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      for usage <- [nil, "", "profile", 42, %{}] do
        assert {:error, %Image.Error{reason: :unknown_usage}} =
                 Image.Social.resize(image, :x, usage: usage)
      end
    end

    test "an explicit :default usage resolves to the platform default" do
      image = Image.new!(120, 63, color: [10, 20, 30])

      assert {:ok, resized} = Image.Social.resize(image, :facebook, usage: :default)
      assert Image.width(resized) == 1200
    end

    test "returns an error for an invalid thumbnail option rather than raising" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:error, %Image.Error{}} =
               Image.Social.resize(image, :tiktok, usage: :profile, crop: :bogus)
    end

    test "returns an error when the image is not an image" do
      for image <- [nil, "", "image.jpg", 42, %{}] do
        assert {:error, %Image.Error{reason: :invalid_image, operation: :resize}} =
                 Image.Social.resize(image, :tiktok, usage: :profile)
      end
    end

    test "returns an error for an unknown platform" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:error,
              %Image.Error{
                reason: :unknown_platform,
                operation: :resize,
                value: :myspace,
                message: "Unknown social platform :myspace"
              }} = Image.Social.resize(image, unknown_platform())
    end
  end

  describe "resize!/3" do
    test "returns the resized image" do
      image = Image.new!(100, 100, color: [10, 20, 30])

      resized = Image.Social.resize!(image, :tiktok, usage: :profile)
      assert Image.width(resized) == 200
      assert Image.height(resized) == 200
    end

    test "raises for an unknown platform" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert_raise Image.Error, "Unknown social platform :myspace", fn ->
        Image.Social.resize!(image, unknown_platform())
      end
    end

    test "raises for an unknown usage" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert_raise Image.Error, "Unknown image usage :bogus", fn ->
        Image.Social.resize!(image, :x, usage: :bogus)
      end
    end

    test "raises Image.Error when the image is not an image" do
      assert_raise Image.Error, fn ->
        Image.Social.resize!(not_an_image(), :tiktok, usage: :profile)
      end
    end
  end
end
