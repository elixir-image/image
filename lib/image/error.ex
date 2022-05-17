defmodule Image.Error do
  @moduledoc false

  defexception message: "Unknown error"

  @impl true
  def exception({:enoent, path}) do
    message = "The image file #{inspect(path)} was not found or could not be opened"
    %__MODULE__{message: message}
  end

  def exception({message, path}) when is_binary(message) and is_binary(path) do
    message = "#{message}: #{path}"
    %__MODULE__{message: message}
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end
