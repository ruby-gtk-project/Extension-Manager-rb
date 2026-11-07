# frozen_string_literal: true

# Regenerates test/fixtures/animated.gif: a hand-rolled, dependency-free
# 2-frame GIF89a (2x2 pixels, black frame then white frame, 50ms then 300ms
# delay) used by test/drive_detail.rb to prove the real glycin decode path —
# Gly::Loader + GlyGtk4.frame_get_texture + AnimatedPaintable's
# timer-driven frame advance — rather than exercising ImageResolver's stub.
#
# No image library (ImageMagick, PIL, chunky_png, ...) is available in this
# project's environments, so the GIF is built by hand: literal LZW codes (one
# per pixel, no dictionary matching) are valid per the GIF89a spec as long as
# the encoder and decoder agree on how the code table grows, which this
# mirrors exactly.
#
# Run with: ruby test/fixtures/generate_animated_gif.rb

def lzw_encode(min_code_size, indices)
  clear_code = 1 << min_code_size
  end_code = clear_code + 1
  next_code = end_code + 1
  code_size = min_code_size + 1

  bits = []
  emit = ->(code, size) { size.times { |i| bits << ((code >> i) & 1) } }

  emit.call(clear_code, code_size)
  indices.each do |index|
    emit.call(index, code_size)
    next_code += 1
    code_size += 1 if next_code > (1 << code_size) && code_size < 12
  end
  emit.call(end_code, code_size)

  bytes = []
  bits.each_slice(8) do |slice|
    byte = 0
    slice.each_with_index { |b, i| byte |= (b << i) }
    bytes << byte
  end
  bytes
end

def gif_sub_blocks(bytes)
  out = String.new(encoding: Encoding::ASCII_8BIT)
  bytes.each_slice(255) do |chunk|
    out << [chunk.size].pack('C') << chunk.pack('C*')
  end
  out << [0].pack('C')
  out
end

def gif_frame(width, height, color_index, delay_cs)
  pixels = Array.new(width * height, color_index)
  lzw_bytes = lzw_encode(2, pixels)

  gce = [0x21, 0xF9, 0x04, 0x00].pack('C*') +
        [delay_cs].pack('v') +
        [0x00, 0x00].pack('C*')

  image_descriptor = [0x2C].pack('C') +
                      [0, 0].pack('vv') +
                      [width, height].pack('vv') +
                      [0x00].pack('C')

  gce + image_descriptor + [2].pack('C') + gif_sub_blocks(lzw_bytes)
end

def build_gif(path)
  width = 2
  height = 2
  header = 'GIF89a'
  lsd = [width, height].pack('vv') + [0x80, 0x00, 0x00].pack('C*') # global color table, 2 colors
  gct = [0, 0, 0, 255, 255, 255].pack('C*') # black, white
  app_ext = [0x21, 0xFF, 0x0B].pack('C*') + 'NETSCAPE2.0' + [0x03, 0x01, 0x00, 0x00, 0x00].pack('C*')

  data = header + lsd + gct + app_ext +
         gif_frame(width, height, 0, 5) +
         gif_frame(width, height, 1, 30) +
         [0x3B].pack('C')

  File.binwrite(path, data)
end

build_gif(File.join(__dir__, 'animated.gif'))
