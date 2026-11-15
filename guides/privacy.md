# Privacy and tracking metadata

A photo carries more than its pixels. The file can name the photographer, give the serial number of the camera and lens, record the GPS coordinates where it was taken, keep a thumbnail of the picture before it was cropped, and carry identifiers that a platform added as the image passed through it. Facebook, for example, writes an `FBMD` identifier into the IPTC metadata of the photos it processes. This guide shows how to find that data with `Image.Privacy.scan/1` and how to remove it.

## Scanning an image

`Image.Privacy.scan/1` returns a list of `Image.Privacy.Finding` structs. Each says where the data was found (`:source`), which field holds it (`:field`), what it is (`:kind`) and the data itself (`:value`). The examples use fixtures in this repository; `facebook_fbmd.jpg` is a photo of a park sign that was downloaded from Facebook.

```elixir
iex> {:ok, findings} = Image.Privacy.scan("test/support/images/facebook_fbmd.jpg")
iex> Enum.map(findings, &{&1.field, &1.kind})
[special_instructions: :tracking_id, original_transmission_reference: :tracking_id]
iex> hd(findings).value
"FBMD0f000771010000a94b0000aa04010014150100864801000f220200fa6303005f850300"
```

A photo straight from a camera usually says more:

```elixir
iex> {:ok, findings} = Image.Privacy.scan("test/support/images/gain_map.jpg")
iex> Enum.map(findings, &{&1.kind, &1.field})
[person: :artist, device_id: :body_serial_number, device_id: :lens_serial_number, location: :gps, hidden_data: :thumbnail]
```

An image with nothing to report returns `{:ok, []}`.

## What the scan reports

Each finding has one of these kinds:

| Kind | Examples |
|---|---|
| `:tracking_id` | Facebook's `FBMD` identifier, IPTC Original Transmission Reference |
| `:device_id` | camera body, lens and DNG serial numbers, the host computer |
| `:document_id` | EXIF `ImageUniqueID`, XMP document, instance and ancestor IDs |
| `:person` | artist, camera owner, photographer, IPTC by-line and contact, Windows author, people shown, face region names, creator contact details |
| `:location` | GPS coordinates in EXIF or XMP, place names in IPTC or XMP, IPTC locations shown and created |
| `:embedded_text` | EXIF user comment, Windows comment, JPEG comments, PNG text chunks |
| `:ai_label` | an IPTC digital source type that marks the image as made with generative AI |
| `:provenance` | any other IPTC digital source type |
| `:hidden_data` | the EXIF thumbnail, and data after the end of a JPEG or PNG |
| `:unreadable` | a metadata block that is present but cannot be read |

The scan reads IPTC, EXIF, XMP and PNG text from any format libvips opens, including HEIC, WebP and TIFF. AI image generators commonly record their prompt in a PNG text chunk, which is reported as `:embedded_text` under the chunk's keyword.

Photo managers such as Lightroom, Picasa and Windows Photo Gallery write the names of the people whose faces they recognise into the XMP, and the IPTC fields can list the people shown and the creator's email, phone and address. These are reported as `:person`.

An EXIF thumbnail is a second, small copy of the picture that not every editor updates, so it can show the image as it was before it was cropped or retouched. The finding gives its size so you can compare it with the image.

## Scanning a file rather than an image

libvips does not keep everything in a file. JPEG comment segments, and data appended after the end of a JPEG or PNG, are dropped when the file is opened. Give `Image.Privacy.scan/1` a path or the file's bytes, rather than an opened image, and it reads the file for them too.

```elixir
iex> {:ok, findings} = Image.Privacy.scan("test/support/images/kodak-dc210.jpg")
iex> Enum.map(findings, &{&1.source, &1.field})
[jpeg: :comment]
iex> image = Image.open!("test/support/images/kodak-dc210.jpg")
iex> Image.Privacy.scan(image)
{:ok, []}
```

Data after the end of an image is reported with its format when it is recognised: a JPEG, a PNG, a ZIP archive, an MP4 video (such as a motion photo), or Samsung's trailer. The extra images an UltraHDR file declares, such as its gain map, are expected and are not reported.

## Removing what the scan finds

The simplest way is `strip_metadata: true` when writing. It removes the IPTC, EXIF and XMP, the EXIF thumbnail and the PNG text. An UltraHDR gain map is kept.

```elixir
iex> image = Image.open!("test/support/images/gain_map.jpg")
iex> {:ok, jpeg} = Image.write(image, :memory, suffix: ".jpg", strip_metadata: true)
iex> Image.Privacy.scan(jpeg)
{:ok, []}
```

`Image.remove_metadata/2` removes one kind of metadata from an image and keeps the rest. `:iptc` removes Facebook's identifiers:

```elixir
iex> image = Image.open!("test/support/images/facebook_fbmd.jpg")
iex> {:ok, image} = Image.remove_metadata(image, :iptc)
iex> {:ok, jpeg} = Image.write(image, :memory, suffix: ".jpg")
iex> Image.Privacy.scan(jpeg)
{:ok, []}
```

The other choices are:

* **`Image.remove_metadata(image, :exif)`** — removes the EXIF, including the GPS, the serial numbers and the thumbnail. The orientation is kept, so the image still displays upright.

* **`Image.remove_metadata(image, :xmp)`** — removes the XMP.

* **`Image.remove_metadata/1`** — with no list of fields, removes all of it.

* **`Image.minimize_metadata/1`** — removes everything except the EXIF artist and copyright.

```elixir
iex> image = Image.open!("test/support/images/Kip_small.jpg")
iex> {:ok, minimized} = Image.minimize_metadata(image)
iex> {:ok, jpeg} = Image.write(minimized, :memory, suffix: ".jpg")
iex> {:ok, findings} = Image.Privacy.scan(jpeg)
iex> Enum.map(findings, &{&1.source, &1.field})
[exif: :artist]
```

Any image `Image` writes leaves out JPEG comments and data after the end of the image, because libvips never reads them. To check the result of a clean-up, scan the file that was written, as the examples do, rather than the image in memory.

## What the scan cannot find

* **Invisible watermarks** — marks hidden in the pixels, such as Google SynthID, Meta's Video Seal and Digimarc, can only be read with the vendor's own decoder. A scan with no findings is not evidence that an image carries no watermark.

* **Maker notes** — camera makers store their own block in EXIF, and it can hold a body serial number or the owner's name. Each maker uses its own format and the scan does not read them. `Image.remove_metadata(image, :exif)` removes them with the rest of the EXIF.

* **C2PA Content Credentials** — they record an image's authenticity rather than track it, and libvips has no API to read them, so they are not reported. libvips does not carry a JPEG's credentials through a save either, so a JPEG `Image` writes has none.

* **Other formats' hidden data** — comments and trailing data are read only from JPEG and PNG files.

* **Removing single fields** — metadata is removed a whole block at a time, so you cannot, for example, remove the GPS and keep the rest of the EXIF.
