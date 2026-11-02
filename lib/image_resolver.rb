# frozen_string_literal: true

require 'adwaita'
require_relative 'request_handler'

# Fetches an image from extensions.gnome.org and decodes it into a paintable.
#
# Ported from upstream's src/web/exm-image-resolver.c: the website hands out
# relative paths ("/static/extension-data/…"), which are resolved against
# https://extensions.gnome.org/, fetched, and decoded into a GdkPaintable the
# caller hands straight to a Gtk.Image.
#
# Upstream decodes through glycin, which also gives it the frame delay an
# animated image carries — that delay is what upstream's ExmAnimatedPaintable
# needs. glycin has no Ruby binding, so the decoding goes through GdkPixbuf
# here and the result is always a still Gdk::Texture: the first frame of an
# animation, which is what upstream shows for a delay of zero too.
#
# Decoding happens in #handle_response, which RequestHandler runs on the main
# loop, so the texture is created on the thread that will draw it.
class ImageResolver < RequestHandler
  BASE_URI = 'https://extensions.gnome.org/'

  # Icons and screenshots are asked for again every time a row scrolls back
  # into view, which upstream's SoupSession caches for it. Ten minutes is
  # long enough to cover a browse session.
  CACHE_TTL_SECONDS = 600

  def cache_ttl_seconds = CACHE_TTL_SECONDS

  # Resolves `rel_path` and yields the paintable, or the error, on the main
  # loop. A missing path resolves to nothing at all, as upstream's early
  # return does, and the caller gets no callback.
  def resolve(rel_path, &block)
    if rel_path.to_s.empty?
      nil
    else
      request(URI.join(BASE_URI, rel_path.to_s).to_s, &block)
    end
  end

  def handle_response(bytes) = Gdk::Texture.new(pixbuf_of(bytes))

  private

    # GdkPixbufLoader insists on being closed before the last reference to it
    # goes away, even when the write failed, so a failed write closes the
    # loader before re-raising and the close's own complaint is dropped: the
    # write's error is the one that describes what went wrong.
    def pixbuf_of(bytes)
      loader = GdkPixbuf::PixbufLoader.new
      begin
        loader.write(bytes)
        loader.close
      rescue GLib::Error
        close_quietly(loader)
        raise
      end
      loader.pixbuf
    end

    def close_quietly(loader)
      loader.close
    rescue GLib::Error
      nil
    end
end
