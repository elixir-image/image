defmodule Image.Options.Avatar do
  @type avatar_options :: []

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
