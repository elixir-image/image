defmodule Image.Error do
  defexception message: "Unknown error"

  @impl true
  def exception({:enoent, path}) do
    message = "The image file #{inspect(path)} was not found or could not be opened"
    %__MODULE__{message: message}
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end
