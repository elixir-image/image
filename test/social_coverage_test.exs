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
                 :twitter,
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

    test "platforms without a configured default return an error" do
      assert {:error,
              %Image.Error{
                reason: :no_default_usage,
                operation: :default_image_usage,
                value: :twitter,
                message: "No default usage is configured for :twitter"
              }} = Image.Social.default_image_usage(:twitter)
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
      assert Image.width(resized) == 20
      assert Image.height(resized) == 20
      assert Image.colorspace(resized) == :srgb
    end

    test "resizes a landscape-ish crop for pinterest board usage" do
      image = Image.new!(444, 300, color: [200, 100, 50])

      assert {:ok, resized} = Image.Social.resize(image, :pinterest, usage: :board)
      assert Image.width(resized) == 222
      assert Image.height(resized) == 150
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

    test "returns an error when the platform has no default usage" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:error,
              %Image.Error{
                reason: :no_default_usage,
                operation: :resize,
                message: "No default usage is configured for :twitter"
              }} = Image.Social.resize(image, :twitter)
    end

    test "returns an error for an unknown usage" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:error,
              %Image.Error{
                reason: :unknown_usage,
                value: :bogus,
                message: "Unknown image usage :bogus"
              }} = Image.Social.resize(image, :twitter, usage: :bogus)
    end

    test "returns an error for a usage that is not an atom" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      for usage <- [nil, "", "profile", 42, %{}] do
        assert {:error, %Image.Error{reason: :unknown_usage}} =
                 Image.Social.resize(image, :twitter, usage: usage)
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
      assert Image.width(resized) == 20
      assert Image.height(resized) == 20
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
        Image.Social.resize!(image, :twitter, usage: :bogus)
      end
    end

    test "raises Image.Error when the image is not an image" do
      assert_raise Image.Error, fn ->
        Image.Social.resize!(not_an_image(), :tiktok, usage: :profile)
      end
    end
  end
end
