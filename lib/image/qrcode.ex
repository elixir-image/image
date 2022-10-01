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
    import Detector, only: [qrCodeDetector!: 0]

    def decode(%Vimage{} = image) do
      with {:ok, %Evision.Mat{} = evision} <- Image.to_evision(image) do
        decode(evision)
      end
    end

    def decode(%Evision.Mat{} = evision) do
      case Detector.detectAndDecode(qrCodeDetector!(), evision) do
        {:ok, {charlist, %Evision.Mat{}, %Evision.Mat{}}} ->
          {:ok, List.to_string(charlist)}

        {:ok, {[], {:error, "empty matrix"}, {:error, "empty matrix"}}} ->
          {:error, "No QRcode detected in the image"}
      end
    end
  end
end