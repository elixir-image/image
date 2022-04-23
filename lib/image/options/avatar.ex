defmodule Image.Options.Avatar do
  alias Image.Options.Crop

  @type avatar_options :: Crop.crop_options()

  # Same as crop options but we default to
  # cropping for attention as the default

  def validate_options(options) do
    with {:ok, options} <- Crop.validate_options(options) do
      options = Keyword.put_new(options, :crop, :VIPS_INTERESTING_ATTENTION)
      {:ok, options}
    end
  end
end
