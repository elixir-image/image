if Image.evision_configured?() do
  defmodule Image.QRcode do
    @moduledoc """
    Detects and decodes QRcodes.

    Note that the implementation, which is based upon
    [eVision](https://github.com/cocoa-xu/evision) requires that
    the image be a 3-channel image in order to support
    detection.

    Images that are in different formats must be converted
    first.

    ### Note

    This module is only available if the optional dependency
    [eVision](https://hex.pm/packages/evision) is configured in
    `mix.exs`.

    """

    alias Vix.Vips.Image, as: Vimage
    alias Evision.QRCodeDetector, as: Detector
    alias Evision.QRCodeEncoder, as: Encoder

    import Detector, only: [qrCodeDetector: 0]

    @dialyzer {:nowarn_function, {:decode, 1}}

    @doc """
    Encodes a string as a QRCode.

    ### Arguments

    * `string` is any string to be encoded,

    * `options` is a keyword list of options. The
      default is `size: :auto`.

    ## Options

    * `:size` is the size in pixels of the QRcode
      dimensions. The default is `:auto` in which
      the generated QRcode will be the minimum dimensions
      necessary to encode the `string`.

    ### Returns

    * `{:ok, image}` or

    * `{:error, reason}`

    """

    @doc since: "0.13.0"

    def encode(string, options \\ []) when is_binary(string) do
      size = Keyword.get(options, :size, :auto)

      with %Evision.Mat{} = mat <- Encoder.encode(Encoder.create(), string) do
        case size do
          :auto ->
            Image.from_evision(mat)

          size when is_integer(size) and size > 0 ->
            {:ok, image} = Image.from_evision(mat)
            scale = scale_from_size(image, size)
            Image.resize(image, scale, interpolate: :nearest)

          other ->
            {
              :error,
              "Invalid `:size` option. `:size` must be a positive " <>
                "integer or `:auto`. Found #{inspect(other)}."
            }
        end
      end
    end

    defp scale_from_size(image, size) do
      width = Image.width(image)
      max(size / width, 1)
    end

    @doc """
    Detects and decodes a QR code in an image.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0` that
      has three bands (for example, a typical srgb
      image).

    ### Returns

    * `{:ok, string}` or

    * `{:error, reason}`

    ### Note

    Only images with three bands (channels) are
    supported. This restriction may be lifted in
    a future release.

    """
    @doc since: "0.9.0"

    def decode(%Vimage{} = image) do
      with {:ok, evision} <- Image.to_evision(image) do
        decode(evision)
      end
    end

    # The QRcode encoder will encode the smallest possible image
    # as a result, its often not recognised by the decoder. So we
    # resize to a minimum size.  Sizes less than 300px do not
    # reliably decode (based upon informal testing).

    @minumum_dimension 300
    @dimensions {@minumum_dimension, @minumum_dimension}

    def decode(%Evision.Mat{shape: {height, width, _}} = evision)
        when height < @minumum_dimension or width < @minumum_dimension do
      resized =
        Evision.resize(evision, @dimensions, interpolation: Evision.Constant.cv_INTER_NEAREST())

      decode(resized)
    end

    def decode(%Evision.Mat{} = evision) do
      case Detector.detectAndDecode(qrCodeDetector(), evision) do
        {string, %Evision.Mat{} = _points, %Evision.Mat{} = _rectified} ->
          {:ok, string}

        {"", %Evision.Mat{}, {:error, "empty matrix"}} ->
          {:error, "QRcode detected but could not be decoded"}

        {"", {:error, "empty matrix"}, {:error, "empty matrix"}} ->
          {:error, "No QRcode detected in the image"}
      end
    end
  end
end
