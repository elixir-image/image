defmodule Image.Options.Rotate do
  @typedoc """
  The options applicable to rotating an
  image.

  """
  @type rotation_options :: [
          {:idy, float()},
          {:idx, float()},
          {:ody, float()},
          {:odx, float()},
          {:background, Image.pixel()}
        ]

  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
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
