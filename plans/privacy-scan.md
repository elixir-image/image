# Privacy scan

**Status:** in progress, 2026-11-15

A function that checks an image for known tracking and identifying data, reports each finding, and pairs with the existing metadata removal so a caller can scan and then strip. Prompted by the `FBMD` identifier Facebook writes into IPTC 2:40 Special Instructions of the photos it processes.

## The problem

Images carry identifiers that their owners rarely see. Some are written by platforms (Facebook's `FBMD` string and Original Transmission Reference), some by cameras and phones (serial numbers, unique image IDs, GPS), some by editing software (XMP document IDs, ancestor lists that name every file ever pasted in), and some by AI generators (prompts and seeds in PNG text chunks, provenance labels). `Image` can remove metadata wholesale with `Image.remove_metadata/2` and `strip_metadata: true`, but it cannot tell a caller what is there, and it cannot read IPTC at all.

## What can be detected

* **Platform identifiers** — `FBMD…` in IPTC 2:40 Special Instructions and the ID Facebook writes into IPTC 2:103 Original Transmission Reference. Meta does not document what the value encodes, so a finding reports an identifier, not proof of tracking.

* **Device identifiers** — EXIF `ImageUniqueID`, `BodySerialNumber`, `LensSerialNumber`, `CameraOwnerName` and `Artist`. `Image.Exif` already decodes all of them.

* **Location** — EXIF GPS, and the location fields of IPTC and XMP.

* **Document identifiers** — XMP `xmpMM:DocumentID`, `xmpMM:InstanceID`, `xmpMM:OriginalDocumentID` and `photoshop:DocumentAncestors`.

* **Embedded text** — PNG text chunks (AI generators write prompts and seeds there) and JPEG comment segments.

* **Provenance and AI labels** — C2PA manifests (JUMBF boxes in JPEG APP11) and IPTC `DigitalSourceType`, the field Meta, Google and others use to label AI-generated images. These are not tracking, but they can name a person, an organisation or a tool.

* **Data outside the image** — bytes after the JPEG end-of-image marker (Samsung's trailer and others), and an EXIF thumbnail that still shows the picture as it was before cropping or editing.

* **Encoder fingerprints** — JPEG quantisation tables identify the encoder that last wrote the file, which can indicate a platform re-encode. A heuristic only.

## What cannot be detected

Invisible watermarks embedded in the pixels — Google SynthID, Meta's Video Seal and Stable Signature, Digimarc, IMATAG — can only be read with the vendor's own decoder. The scan does not attempt them, and its documentation must say so plainly, so a clean result is never read as proof that an image carries no watermark.

## Findings from probing libvips 8.18.7

Probed on 2026-11-15 with hand-built JPEGs (vix 0.42.0):

* **`iptc-data` is the whole APP13 payload**, starting with the `Photoshop 3.0` header, followed by the Photoshop image resource blocks. The IPTC IIM records are in resource `0x0404`. So IPTC can be read from a decoded image, but a parser has to unwrap the resource blocks first.

* **IPTC survives a plain re-save**, and is removed by `strip_metadata: true`. A scan is therefore useful on images `Image` itself writes, not only on files it reads.

* **JPEG comment (COM) segments, APP11 (C2PA) segments and data after end-of-image are not exposed as header fields**, and none of them survives a re-save. They can only be found by reading the file's bytes, and any `Image` re-encode already removes them.

## Proposed API

* `Image.Privacy.scan/1` takes a `t:Vix.Vips.Image.t/0`, a path or a binary and returns `{:ok, [Image.Privacy.Finding.t()]}` or `{:error, Image.Error.t()}`. An image is scanned through its metadata only; a path or binary is also scanned at the byte level.

* `Image.Privacy.Finding` is a struct with `:source` (`:iptc`, `:exif`, `:xmp`, `:png_text`, `:jpeg_comment`, `:c2pa`, `:trailer`, `:thumbnail`, `:encoder`), `:field`, `:value` and `:kind` (`:tracking_id`, `:device_id`, `:location`, `:document_id`, `:embedded_text`, `:provenance`, `:ai_label`, `:hidden_data`, `:encoder_fingerprint`).

* `Image.Iptc` parses IPTC IIM, unwrapping the Photoshop resource blocks, into a map keyed by dataset name. It is useful on its own, the way `Image.Exif` and `Image.Xmp` are.

## Open questions

* **Module name** — decided 2026-11-15: `Image.Privacy.scan/1`, with `Image.Privacy.Finding`.

* **C2PA** — decided 2026-11-15 not to scan for it. Content Credentials record authenticity rather than track, and libvips has no API to read them, so the scan leaves them alone. The open issue runs the other way: libvips does not carry a JPEG's APP11 segments through a save (probed 2026-11-15), so every JPEG `Image` re-saves loses its Content Credentials. PNG `caBX` chunks have not been checked. Revisit if libvips gains C2PA support, or if preserving credentials through a save becomes a goal. libvips tracks this in [libvips#4420](https://github.com/libvips/libvips/issues/4420): it is not in 8.19.0-rc1, and on 2026-11-04 the maintainer moved it to the 8.20 cycle, noting that the C2PA libraries work on whole files rather than as a component and that a separate post-processing step may suit better.

* **Targeted removal** — whether to add a way to remove only the identifying fields (FBMD, Original Transmission Reference, serial numbers, GPS, document IDs) while keeping copyright and captions. libvips sets metadata as whole blobs, so this means rewriting the IPTC, EXIF and XMP blobs, which is a larger piece of work than the scan.

* **PNG text chunks** — confirmed 2026-11-15: libvips exposes them as `png-comment-<index>-<keyword>` header fields.

* **Maker notes** — camera makers' proprietary EXIF blocks can hold serial numbers and owner names (Canon's `OwnerName` and `InternalSerialNumber`, for example). Each maker has its own format, so reading them is a parser per maker. Not reported.

* **Encoder fingerprints** — needs reference quantisation tables per platform, and those tables change without notice. Likely deferred.

## Tasks

* [ ] **Stage 2: PNG chunks** — data after `IEND`.

* [ ] **Stage 2: EXIF thumbnail** — report an embedded thumbnail, which can show the picture before it was cropped or edited.

* [ ] **Guide section** — what the scan finds, what it cannot find (invisible watermarks), and how to remove what it reports.

### Done

* [x] **Stage 2: JPEG segments** — `scan/1` takes a path or bytes and walks a JPEG's segments for comments and data after the end of the image, past restart markers, progressive scans and the images an MPF index declares; trailers are recognised as JPEG, MP4 or Samsung. 2026-11-15, v0.74.0.

* [x] **Further EXIF fields** — `UserComment` decoded as text; `XP*`, `HostComputer`, `Photographer`, `ImageEditor` and DNG `CameraSerialNumber` decoded; all reported, with GPS destination coordinates. 2026-11-15, v0.74.0.

* [x] **Stage 1: metadata scan** — `Image.Privacy.scan/1` reports IPTC, EXIF, XMP and PNG text findings; `Image.exif/1` gained `:camera_owner_name` and `Image.xmp/1` the document IDs, GPS and digital source type. 2026-11-15, v0.74.0.

* [x] **`Image.Iptc` parser** — `Image.iptc/1` and `Image.Iptc.extract_iptc/1` read APP13, resource-block and bare IIM forms; missing EXIF, XMP and IPTC now share atom reasons. 2026-11-15, v0.74.0.

### Deferred

* [ ] **C2PA** — not scanned; see the open question.

* [ ] **Encoder fingerprints** — needs maintained reference tables; revisit once stages 1 and 2 are in.

* [ ] **Targeted removal** — see the open question above.
