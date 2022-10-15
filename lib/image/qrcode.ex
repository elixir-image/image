if match?({:module, _module}, Code.ensure_compiled(Evision)) do
  defmodule Image.QRcode do
    @moduledoc """
    Detects and decodes QRcodes.

    Note that the implementation, which is based upon
    [eVision](https://github.com/cocoa-xu/evision) requires that
    the image be a 3-channel image in order to support
    detection.

    Images that are in different formats must be converted
    first.

    """

    alias Vix.Vips.Image, as: Vimage
    alias Evision.QRCodeDetector, as: Detector
    alias Evision.QRCodeEncoder, as: Encoder

    import Detector, only: [qrCodeDetector: 0]

    @dialyzer {:nowarn_function, {:decode, 1}}

    @doc """
    Encodes a string as a QRCode.

    ### Arguments

    * `string` is any string to be encodedd

    ### Returns

    * `{:ok, image}` or

    * `{:error, reason}`

    """

    @doc since: "0.13.0"

    def encode(string) when is_binary(string) do
      with %Evision.Mat{} = mat <- Encoder.encode(Encoder.create(), string) do
        Image.from_evision(mat)
      end
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
    # resize to a minimum size.

    @minimum_dimensions {300, 300}

    def decode(%Evision.Mat{shape: {height, width, _}} = evision) when height < 300 or width < 300 do
      resized = Evision.resize(evision, @minimum_dimensions, interpolate: Evision.cv_INTER_AREA)
      decode(resized)
    end

    def decode(%Evision.Mat{} = evision) do
      case Detector.detectAndDecode(qrCodeDetector(), evision) do
        {string, %Evision.Mat{}, %Evision.Mat{}} ->
          {:ok, string}

        {"", %Evision.Mat{}, {:error, "empty matrix"}} ->
          {:error, "No QRcode detected in the image"}

        {"", {:error, "empty matrix"}, {:error, "empty matrix"}} ->
          {:error, "No QRcode detected in the image"}
      end
    end
  end
end