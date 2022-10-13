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
    import Detector, only: [qrCodeDetector: 0]

    @dialyzer {:nowarn_function, {:decode, 1}}

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
      with {:ok, %Evision.Mat{} = evision} <- Image.to_evision(image) do
        decode(evision)
      end
    end

    def decode(%Evision.Mat{} = evision) do
      case Detector.detectAndDecode(qrCodeDetector(), evision) do
        {string, %Evision.Mat{}, %Evision.Mat{}} ->
          {:ok, string}

        {"", {:error, "empty matrix"}, {:error, "empty matrix"}} ->
          {:error, "No QRcode detected in the image"}
      end
    end
  end
end