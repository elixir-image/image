defmodule Image.Exif.Thumbnail do
  @moduledoc false
  # Internal representation of Thumbnail tag in the EXIF.

  @type t :: %__MODULE__{
          thumbnail_offset: non_neg_integer(),
          thumbnail_size: non_neg_integer()
        }

  @fields [
    :thumbnail_offset,
    :thumbnail_size
  ]

  @spec fields :: [:thumbnail_offset | :thumbnail_size]
  @doc false
  def fields, do: @fields

  defstruct @fields

  @spec to_image(binary(), t()) :: :ok | {:error, :bad_thumbnail_data | :file.posix()}
  @doc "Converts the thumbnail to image and writes it to the file"
  def to_image(_, %__MODULE__{thumbnail_offset: offset, thumbnail_size: size})
      when is_nil(offset) or is_nil(size),
      do: {:error, :bad_thumbnail_data}

  def to_image(file, %__MODULE__{thumbnail_offset: offset, thumbnail_size: size})
      when is_binary(file) do
    [name, dot, ext] = String.split(file, ~r/(?=.{3,4}\z)/)

    with {:ok, src} <-
           File.open(file, [:read], fn f ->
             IO.binread(f, offset)
             IO.binread(f, size)
           end),
         {:ok, _dst} <- File.open("#{name}-thumb#{dot}#{ext}", [:write], &IO.binwrite(&1, src)),
         do: :ok
  end

  defimpl String.Chars, for: Image.Exif.Thumbnail do
    @spec to_string(data :: Image.Exif.Thumbnail.t()) :: <<_::64, _::_*8>>
    def to_string(data), do: "Image Thumbnail of size #{data.thumbnail_size}"
  end
end
