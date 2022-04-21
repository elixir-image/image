defmodule Image.Options.Resize do
  alias Image.Options.Crop

  @typedoc """
  Options applicable to Image.resize/3

  """
  @type resize_options :: [
          {:autorotate, boolean()},
          {:intent, Image.render_intent()},
          {:export_icc_profile, Color.icc_profile()},
          {:import_icc_profile, Color.icc_profile()},
          {:linear, boolean()},
          {:resize, resize_dimension()},
          {:height, pos_integer()},
          {:crop, Options.Crop.crop_focus()}
        ]

  @type resize_dimension :: :width | :height | :both

  def validate_options(options) do
    case Enum.reduce_while(options, [], &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  def validate_option(_other, options) do
    {:cont, options}
  end
end
