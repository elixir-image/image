defmodule Image.Privacy.Finding do
  @moduledoc """
  One piece of tracking or identifying data that `Image.Privacy.scan/1`
  found in an image.

  ### Fields

  * `:source` is where the data was found: `:iptc`, `:exif`, `:xmp`,
    `:png_text`, or `:jpeg` and `:png` for data found by reading a JPEG
    file's segments or a PNG file's chunks.

  * `:field` names the data within its source, such as
    `:special_instructions` or `:body_serial_number`. For a PNG text
    chunk it is the chunk's keyword, as a string. It is `nil` for an
    `:unreadable` finding.

  * `:value` is the data as the source's reader returns it.

  * `:kind` says what the data is:

    * `:tracking_id` — an identifier a platform or service added as
      the image passed through it, such as Facebook's `FBMD` string.

    * `:device_id` — identifies the camera, lens or phone, such as a
      serial number.

    * `:document_id` — identifies the image or file across edits, such
      as EXIF's `ImageUniqueID` or XMP's document identifiers.

    * `:person` — names a person, such as an artist, a camera owner or
      a contact.

    * `:location` — GPS coordinates or a place name.

    * `:embedded_text` — free text, such as a PNG text chunk, which
      AI image generators use to record a prompt.

    * `:ai_label` — labels the image as made or altered by AI.

    * `:provenance` — describes how the image was made, without an AI
      label.

    * `:hidden_data` — data a viewer does not show, such as bytes after
      the end of a JPEG or PNG. The value is a map with the `:format` of
      the data (`:jpeg`, `:png`, `:zip`, `:mp4`, `:samsung` or
      `:unknown`) and its size in `:bytes`.

    * `:unreadable` — a metadata block is present but cannot be read,
      so it may hold data the scan could not check. The value is the
      reason, such as `:invalid_xmp`.

  """

  @typedoc "Where a finding's data was found."
  @type source :: :iptc | :exif | :xmp | :png_text | :jpeg | :png

  @typedoc "What a finding's data is."
  @type kind ::
          :tracking_id
          | :device_id
          | :document_id
          | :person
          | :location
          | :embedded_text
          | :ai_label
          | :provenance
          | :hidden_data
          | :unreadable

  @typedoc "A finding from `Image.Privacy.scan/1`."
  @type t :: %__MODULE__{
          source: source(),
          field: atom() | String.t() | nil,
          value: term(),
          kind: kind()
        }

  @enforce_keys [:source, :field, :value, :kind]
  defstruct @enforce_keys
end
