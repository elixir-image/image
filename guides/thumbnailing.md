# Thumbnailing

<style>
  .column {
    float: left;
    width: 33.33%;
    padding: 5px;
  }

  /* Clear floats after image containers */
  .row::after {
    content: "";
    clear: both;
    display: table;
  }

  figure {
      border: 3px solid #FF1493;
      display: flex;
      flex-flow: column;
      padding: 0;
      width: 200px;
      height: 200px;
      margin: auto;
      width: 200px;
      height: 200px;
  }

  img {
      max-width: 200px;
      max-height: 200px;
      padding: 0;
      margin: 0
  }

  figcaption {
      background-color: #222;
      color: #fff;
      font: smaller sans-serif;
      margin-top: 10px;
      padding: 3px;
      text-align: center;
  }
</style>

Basic code:

```elixir
iex> original_raw = File.read!("/path/to_original.jpg"); nil
nil
iex> {:ok, original} = Image.from_binary(original_raw)
{:ok, %Vix.Vips.Image{ref: #Reference<0.4099923103.164495390.164069>}}
iex> {:ok, thumbnail} = Image.thumbnail(original, 200)
{:ok, %Vix.Vips.Image{ref: #Reference<0.4099923103.164495390.164078>}}
iex> Image.write(thumbnail, "/tmp/thumbnail.png")
{:ok, %Vix.Vips.Image{ref: #Reference<0.4099923103.164495390.164078>}}
iex> Image.write(thumbnail, "/path/to_thumbnail.png")
{:ok, %Vix.Vips.Image{ref: #Reference<0.4099923103.164495390.164078>}}
```

Examples:

<div class="row">
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/guides/images/puppy_crop_none.jpg" alt="Image.thumbnail/3">
  </figure>
  <figcaption>Image.thumbnail(image, 200, crop: :none)</figcaption>
</div>
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/guides/images/puppy_crop_attention.jpg" alt="Image.thumbnail/3">
  </figure>
  <figcaption>Image.thumbnail(image, 200, crop: :attention)</figcaption>
</div>
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/guides/images/puppy_crop_550_320_200_200.jpg" alt="Image.crop/5">
  </figure>
  <figcaption>Image.crop!(image, 550, 320, 200, 200)</figcaption>
</div>
</div>

<div class="row">
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/guides/images/puppy_rounded.png" alt="Image.rounded/2">
  </figure>
  <figcaption>image |> Image.thumbnail!(200, crop: :attention) |> Image.rounded!()</figcaption>
</div>
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/elixir-image/image/main/guides/images/puppy_squircle.png" alt="Image.squircle/2">
  </figure>
  <figcaption>image |> Image.thumbnail!(200, crop: :attention) |> Image.squircle!()</figcaption>
</div>
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/guides/images/puppy_avatar.png"
      alt="Image.avatar/3">
  </figure>
  <figcaption>Image.avatar(image, 200)</figcaption>
</div>
</div>
