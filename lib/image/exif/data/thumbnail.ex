defmodule Image.Exif.Thumbnail do
  @moduledoc false
  # The thumbnail IFD1 describes: the offset of its JPEG data, counted
  # from the start of the EXIF TIFF data, and its size in bytes.

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

  defimpl String.Chars, for: Image.Exif.Thumbnail do
    @spec to_string(data :: Image.Exif.Thumbnail.t()) :: <<_::64, _::_*8>>
    def to_string(data), do: "Image Thumbnail of size #{data.thumbnail_size}"
  end
end
