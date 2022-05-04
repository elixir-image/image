# Example Usage

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

<div class="row">
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/images/puppy_crop_none.jpg" alt="Image.resize/3">
  </figure>
  <figcaption>Image.resize(image, 200, crop: :none)</figcaption>
</div>
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/images/puppy_crop_attention.jpg" alt="Image.resize/3">
  </figure>
  <figcaption>Image.resize(image, 200, crop: :attention)</figcaption>
</div>
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/images/puppy_crop_550_320_200_200.jpg" alt="Image.crop/5">
  </figure>
  <figcaption>Image.crop!(image, 550, 320, 200, 200)</figcaption>
</div>
</div>

<div class="row">
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/images/puppy_rounded.png" alt="Image.rounded/2">
  </figure>
  <figcaption>image |> Image.resize!(200, crop: :attention) |> Image.rounded!()</figcaption>
</div>
<div class="column">
  <figure>
      <img src="https://raw.githubusercontent.com/kipcole9/image/main/images/puppy_avatar.png"
      alt="Image.avatar/3">
  </figure>
  <figcaption>Image.avatar(image, 200)</figcaption>
</div>
</div>
