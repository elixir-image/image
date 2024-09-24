defmodule Image.ThumbHash do

  def average_color(pixels) do
    {avg_r, avg_g, avg_b, avg_a} =
      for <<r::8, g::8, b::8, a::8 <- pixels>>, reduce: {0, 0, 0, 0} do
        {avg_r, avg_g, avg_b, avg_a} ->
          a = a / 255
          avg_r = avg_r + (a * r)
          avg_g = avg_g + (a * g)
          avg_b = avg_b + (a * b)
          avg_a = avg_a + a
      end

    if avg_a > 0 do
      {avg_r / avg_a, avg_g / avg_a, avg_b / avg_a , avg_a}
    else
      {avg_r, avg_g, avg_b, avg_a}
    end
  end

  def convert_rbga_to_lpqa(pixels, {avg_r, avg_g, avg_b, avg_a}) do
    for <<r::8, g::8, b::8, a::8 <- pixels>> do
      a = a / 255.0
      r = avg_r * (1 - a) + a / 255.0 * r
      g = avg_g * (1 - a) + a / 255.0 * g
      b = avg_b * (1 - a) + a / 255.0 * b

      l = (r + g + b) / 3
      p = (r + g) / 2 - b
      q = r - g

      [l, p, q, a]
    end
  end

  def encode_channel(channel, nx, ny) do
    dc, ac, scale, fx = 0, [], 0, Array.new(w)

    (0...ny).each do |cy|
      (0...((nx * (ny - cy)).to_f / ny).ceil).each do |cx|
        f = 0

        w.times do |x|
          fx[x] = Math.cos(Math::PI / w * cx * (x + 0.5))
        end

        h.times do |y|
          h_scale = Math.cos(Math::PI / h * cy * (y + 0.5))
          w.times do |x|
            f += channel[x + y * w] * fx[x] * h_scale
          end
        end

        f /= w * h

        if cx.zero? && cy.zero?
          dc = f
        else
          ac.push(f)
          scale = [scale, f.abs].max
        end
      end
    end

    ac.map! { |x| 0.5 + 0.5 / scale * x } if scale > 0

    [dc, ac, scale]
  end

  # Encodes an RGBA image to a ThumbHash. RGB should not be premultiplied by A.
  def self.rgba_to_thumb_hash(w, h, rgba)
    # Encoding an image larger than 100x100 is slow with no benefit
    raise "#{w}x#{h} doesn't fit in 100x100" if w > 100 || h > 100

    # Determine the average color
    avg_r, avg_g, avg_b, avg_a = 0, 0, 0, 0
    (0...(w * h)).each do |i|
      j = i * 4
      alpha = rgba[j + 3] / 255.0
      avg_r += alpha / 255.0 * rgba[j]
      avg_g += alpha / 255.0 * rgba[j + 1]
      avg_b += alpha / 255.0 * rgba[j + 2]
      avg_a += alpha
    end

    if avg_a > 0
      avg_r /= avg_a
      avg_g /= avg_a
      avg_b /= avg_a
    end

    has_alpha = avg_a < w * h
    l_limit = has_alpha ? 5 : 7 # Use fewer luminance bits if there's alpha
    lx = [1, (l_limit * w / [w, h].max).round].max
    ly = [1, (l_limit * h / [w, h].max).round].max
    l = [] # luminance
    p = [] # yellow - blue
    q = [] # red - green
    a = [] # alpha

    # Convert the image from RGBA to LPQA (composite atop the average color)
    (0...(w * h)).each do |i|
      j = i * 4
      alpha = rgba[j + 3] / 255.0
      r = avg_r * (1 - alpha) + alpha / 255.0 * rgba[j]
      g = avg_g * (1 - alpha) + alpha / 255.0 * rgba[j + 1]
      b = avg_b * (1 - alpha) + alpha / 255.0 * rgba[j + 2]
      l[i] = (r + g + b) / 3
      p[i] = (r + g) / 2 - b
      q[i] = r - g
      a[i] = alpha
    end

    encode_channel = ->(channel, nx, ny) do
      dc, ac, scale, fx = 0, [], 0, Array.new(w)

      (0...ny).each do |cy|
        (0...((nx * (ny - cy)).to_f / ny).ceil).each do |cx|
          f = 0

          w.times do |x|
            fx[x] = Math.cos(Math::PI / w * cx * (x + 0.5))
          end

          h.times do |y|
            h_scale = Math.cos(Math::PI / h * cy * (y + 0.5))
            w.times do |x|
              f += channel[x + y * w] * fx[x] * h_scale
            end
          end

          f /= w * h

          if cx.zero? && cy.zero?
            dc = f
          else
            ac.push(f)
            scale = [scale, f.abs].max
          end
        end
      end

      ac.map! { |x| 0.5 + 0.5 / scale * x } if scale > 0

      [dc, ac, scale]
    end

    l_dc, l_ac, l_scale = encode_channel.(l, [3, lx].max, [3, ly].max)
    p_dc, p_ac, p_scale = encode_channel.(p, 3, 3)
    q_dc, q_ac, q_scale = encode_channel.(q, 3, 3)
    a_dc, a_ac, a_scale = has_alpha ? encode_channel.(a, 5, 5) : []

    # Write the constants
    is_landscape = w > h
    header24 = (63 * l_dc).round | ((31.5 + 31.5 * p_dc).round << 6) | ((31.5 + 31.5 * q_dc).round << 12) | ((31 * l_scale).round << 18) | (has_alpha ? (1 << 23) : 0)
    header16 = (is_landscape ? ly : lx) | ((63 * p_scale).round << 3) | ((63 * q_scale).round << 9) | (is_landscape ? (1 << 15) : 0)
    hash = [header24 & 255, (header24 >> 8) & 255, header24 >> 16, header16 & 255, header16 >> 8]
    ac_start = has_alpha ? 6 : 5
    ac_index = 0
    hash.push((15 * a_dc).round | ((15 * a_scale).round << 4)) if has_alpha

    # Write the varying factors
    ac = has_alpha ? [l_ac, p_ac, q_ac, a_ac] : [l_ac, p_ac, q_ac]

    ac.each do |a|
      a.each do |f|
        index = ac_start + (ac_index >> 1)
        result = (15 * f).round << ((ac_index & 1) * 4)
        hash[index] = hash[index].nil? ? result : hash[index] | result
        ac_index += 1
      end
    end

    hash.pack("C*")
  end

  # Decodes a ThumbHash to an RGBA image. RGB is not be premultiplied by A.
  def self.thumb_hash_to_rgba(hash)
    hash = hash.unpack("C*")

    # Read the constants
    header24 = hash[0] | (hash[1] << 8) | (hash[2] << 16)
    header16 = hash[3] | (hash[4] << 8)
    l_dc = (header24 & 63) / 63.0
    p_dc = ((header24 >> 6) & 63) / 31.5 - 1
    q_dc = ((header24 >> 12) & 63) / 31.5 - 1
    l_scale = ((header24 >> 18) & 31) / 31.0
    has_alpha = header24 >> 23
    p_scale = ((header16 >> 3) & 63) / 63.0
    q_scale = ((header16 >> 9) & 63) / 63.0
    is_landscape = header16 >> 15
    lx = [3, is_landscape.zero? ? header16 & 7 : (has_alpha.zero? ? 7 : 5)].max
    ly = [3, is_landscape.zero? ? has_alpha.zero? ? 7 : 5 : header16 & 7].max
    a_dc = has_alpha.zero? ? 1 : (hash[5] & 15) / 15
    a_scale = (hash[5] >> 4) / 15.0

    # Read the varying factors (boost saturation by 1.25x to compensate for quantization)
    ac_start = has_alpha.zero? ? 5 : 6
    ac_index = 0

    decode_channel = ->(nx, ny, scale) do
      ac = []
      (0...ny).each do |cy|
        cx = cy.zero? ? 1 : 0
        while cx * ny < nx * (ny - cy)
          ac.push(
            (((hash[ac_start + (ac_index >> 1)] >> ((ac_index & 1) << 2)) & 15) / 7.5 - 1) * scale
          )
          ac_index += 1
          cx += 1
        end
      end
      ac
    end
    l_ac = decode_channel.(lx, ly, l_scale)
    p_ac = decode_channel.(3, 3, p_scale * 1.25)
    q_ac = decode_channel.(3, 3, q_scale * 1.25)
    a_ac = !has_alpha.zero? && decode_channel.(5, 5, a_scale)

    # Decode using the DCT into RGB
    ratio = thumb_hash_to_approximate_aspect_ratio(hash)
    w = (ratio > 1 ? 32 : 32 * ratio).round
    h = (ratio > 1 ? 32 / ratio : 32).round
    fx, fy, rgba = [], [], Array.new(w * h * 4, 0)

    (0...h).each do |y|
      i = y * w * 4
      (0...w).each do |x|
        l, p, q, a = l_dc, p_dc, q_dc, a_dc

        # Precompute the coefficients
        (0...[lx, has_alpha ? 5 : 3].max).each do |cx|
          fx[cx] = Math.cos((Math::PI / w) * (x + 0.5) * cx)
        end
        (0...[ly, has_alpha ? 5 : 3].max).each do |cy|
          fy[cy] = Math.cos((Math::PI / h) * (y + 0.5) * cy)
        end

        # Decode L
        j = 0
        (0...ly).each do |cy|
          fy2 = fy[cy] * 2
          cx = cy.zero? ? 1 : 0

          while cx * ly < lx * (ly - cy)
            l += l_ac[j] * fx[cx] * fy2
            cx += 1
            j += 1
          end
        end

        # Decode P and Q
        j = 0
        (0...3).each do |cy|
          fy2 = fy[cy] * 2
          cx = cy.zero? ? 1 : 0
          while cx < 3 - cy
            f = fx[cx] * fy2
            p += p_ac[j] * f
            q += q_ac[j] * f
            cx += 1
            j += 1
          end
        end

        # Decode A
        if !has_alpha.zero?
          j = 0
          (0...5).each do |cy|
            fy2 = fy[cy] * 2
            cx = cy.zero? ? 1 : 0
            while cx < 5 - cy
              a += a_ac[j] * fx[cx] * fy2
              cx += 1
              j += 1
            end
          end
        end

        # Convert to RGB
        b = l - (2 / 3.0) * p
        r = (3 * l - b + q) / 2.0
        g = r - q
        rgba[i] = [0, 255 * [1, r].min].max.to_i
        rgba[i + 1] = [0, 255 * [1, g].min].max.to_i
        rgba[i + 2] = [0, 255 * [1, b].min].max.to_i
        rgba[i + 3] = [0, 255 * [1, a].min].max.to_i

        i += 4
      end
    end

    [w, h, rgba]
  end

  # Extracts the approximate aspect ratio of the original image.
  def self.thumb_hash_to_approximate_aspect_ratio(hash)
    header = hash[3]
    has_alpha = (hash[2] & 0x80) != 0
    is_landscape = (hash[4] & 0x80) != 0
    lx = is_landscape ? (has_alpha ? 5 : 7) : header & 7
    ly = is_landscape ? header & 7 : (has_alpha ? 5 : 7)
    lx.to_f / ly.to_f
  end

  # Decodes a ThumbHash to a PNG data URL. This is a convenience function that
  # just calls "thumb_hash_to_rgba" followed by "rgba_to_data_url".
  def self.thumb_hash_to_data_url(hash)
    width, height, rgba = thumb_hash_to_rgba(hash)
    rgba_to_data_url(width, height, rgba)
  end

  # Encodes an RGBA image to a PNG data URL. RGB should not be premultiplied by
  # A. This is optimized for speed and simplicity and does not optimize for size
  # at all. This doesn't do any compression (all values are stored uncompressed).
  def self.rgba_to_data_url(w, h, rgba)
    row = w * 4 + 1
    idat = 6 + h * (5 + row)

    unsigned_right_shift = ->(value, amount) do
      mask = (1 << (32 - amount)) - 1
      (value >> amount) & mask
    end

    bytes = [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0,
      w >> 8, w & 255, 0, 0, h >> 8, h & 255, 8, 6, 0, 0, 0, 0, 0, 0, 0,
      unsigned_right_shift.(idat, 24), (idat >> 16) & 255, (idat >> 8) & 255, idat & 255,
      73, 68, 65, 84, 120, 1,
    ]
    table = [
      0, 498536548, 997073096, 651767980, 1994146192, 1802195444, 1303535960,
      1342533948, -306674912, -267414716, -690576408, -882789492, -1687895376,
      -2032938284, -1609899400, -1111625188,
    ]

    a = 1
    b = 0
    i = 0
    end_index = row - 1
    for y in 0...h
      bytes.push(
        y + 1 < h ? 0 : 1,
        row & 255,
        row >> 8,
        ~row & 255,
        (row >> 8) ^ 255,
        0
      )
      b = (b + a) % 65521
      while i < end_index
        u = rgba[i] & 255
        bytes.push(u)
        a = (a + u) % 65521
        b = (b + a) % 65521
        i += 1
      end

      end_index += row - 1
    end

    bytes.push(b >> 8, b & 255, a >> 8, a & 255, 0, 0, 0, 0,
               0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130)

    [[12, 29], [37, 41 + idat]].each do |start_index, end_index|
      c = ~0
      for i in (start_index...end_index)
        c ^= bytes[i]
        c = unsigned_right_shift.(c, 4) ^ table[c & 15]
        c = unsigned_right_shift.(c, 4) ^ table[c & 15]
      end
      c = ~c

      bytes[end_index] = unsigned_right_shift.(c, 24)
      end_index += 1
      bytes[end_index] = (c >> 16) & 255
      end_index += 1
      bytes[end_index] = (c >> 8) & 255
      end_index += 1
      bytes[end_index] = c & 255
      end_index += 1
    end

    "data:image/png;base64," + Base64.encode64(bytes.map(&:chr).join).delete("\n")
  end
end