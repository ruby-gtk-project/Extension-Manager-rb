# frozen_string_literal: true

require 'adwaita'
require 'glycin'
require 'libglycin_gtk4'
require 'glib2'
require 'uri'
require_relative 'animated_paintable'
require_relative 'request_handler'

# Fetches an image from extensions.gnome.org and decodes it into a paintable.
#
# Ported from upstream's src/web/exm-image-resolver.c: the website hands out
# relative paths ("/static/extension-data/…"), which are resolved against
# https://extensions.gnome.org/, fetched, and decoded through glycin into a
# GdkPaintable the caller hands straight to a Gtk.Image.
#
# Upstream decodes through glycin via libglycin-gtk4, which also gives it the
# frame delay an animated image carries; AnimatedPaintable is what turns that
# delay into the keep-decoding-frames loop upstream's ExmAnimatedPaintable
# runs. The `glycin` and `libglycin-gtk4` gems are what make that the real
# decoder here too, rather than a GdkPixbuf stand-in that could only ever show
# a still first frame.
#
# Decoding happens in #handle_response, which RequestHandler runs on the main
# loop, so the texture and the glycin image are created on the thread that
# will draw and keep animating them.
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

  def handle_response(bytes)
    Gly::Loader.new(GLib::Bytes.new(bytes)).load.then do |image|
      image.next_frame.then do |frame|
        AnimatedPaintable.new(image, GlyGtk4.frame_get_texture(frame), frame.delay)
      end
    end
  end
end
