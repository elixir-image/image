defmodule Image.Blurhash do
  @moduledoc """
  BlurHash is an algorithm developed by [Wolt](https://github.com/woltapp)
  that allows encoding of an image into a compact string representation
  called a blurhash. This string can then be decoded back into
  an image, providing a low-resolution placeholder that can be
  displayed quickly while the actual image is being loaded.

  It combines the benefits of data compression and perceptual
  hashing to create visually pleasing representations of images.

  The blurhash string consists of a short sequence of characters
  that represents the image's colors and their distribution. By
   adjusting the length of the blurhash, you can control the level
  of detail and the amount of data required to represent the image.

  The encode and decoder in this implementation are a fork of
  the [rinpatch_blurhash](https://github.com/rinpatch/blurhash) library
  by @rinpatch.

  """

  alias Vix.Vips.Image, as: Vimage

  @doc """
  Encodes an image as a [blurhash](https://blurha.sh).

  `Image.Blurhash.encode/2` takes an image and returns a short string
  (only 20-30 characters) that represents the placeholder
  for this image.

  It is intended that calculating a blurhash is performed
  in a background process and stored for retrieval on demand
  when rendering a page.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options. The default is
    `[x_components: 4, y_components: 3]`.

  ### Options

  * `:x_components` represents the number of horizontal blocks used
    to calculate the blurhash.

  * `:y_components` represents the number of vertical blocks used
    to calculate the blurhash.

  ### Returns

  * `{:ok, blurhash}` or

  * `{:error, reason}`

  ### Selecting the number of X and Y components

  A higher `:x_components` and `:y_components` value will result in
  more details in the blurhash in the X and Y direction respectively.
  A lower value will create a more abstract representation.

  By adjusting the X and Y components, you can control the level of
  granularity and complexity in the generated blurhash. However, it's
  important to note that increasing the X and Y values also increases
  the size of the blurhash string, which may impact performance and
  bandwidth usage.

  The default of `[x_components: 4, y_components: 3]` is a good starting
  points but if the the image aspect ratio is portrait, a higher
  `:y_compnents` value may be appropriate.

  ### Example

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> Image.Blurhash.encode(image)
      {:ok, "LBA,zk9F00~qofWBt7t700%M?bD%"}

  """
  @doc subject: "Operation", since: "0.44.0"

  @spec encode(image :: Vimage.t(), options :: Keyword.t()) ::
    {:ok, String.t} | {:error, Image.error_message()}

  def encode(%Vimage{} = image, options \\ []) do
    with {:ok, options} <- Image.Options.Blurhash.validate_options(image, options),
         {:ok, binary} <- Vimage.write_to_binary(image) do
      {width, height, _bands} = Image.shape(image)
      Image.Blurhash.Encoder.encode(binary, width, height, options.x_components, options.y_components)
    end
  end
end