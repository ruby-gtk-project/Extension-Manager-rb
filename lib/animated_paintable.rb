# frozen_string_literal: true

require 'adwaita'
require 'glycin'
require 'libglycin_gtk4'

# A GdkPaintable that keeps decoding an animated image's frames.
#
# Ported from upstream's src/exm-animated-paintable.c: holds the glycin
# `GlyImage` and the current frame as a `GdkTexture`, and a frame's delay
# schedules the next `gly_image_next_frame_async` call, which replaces the
# current frame and invalidates the paintable's contents.
#
# Upstream implements the GdkPaintable interface in C; the Ruby bindings let
# a GLib::Object do the same by including Gdk::Paintable and defining the
# vfuncs it calls, `virtual_do_*`, the way ruby-gnome's own Gio::RubyOutputStream
# implements GOutputStream.
class AnimatedPaintable < GLib::Object
  type_register

  include Gdk::Paintable

  def initialize(image, first_frame, delay_us)
    super()
    @image = image
    @current_frame = first_frame
    @cancellable = Gio::Cancellable.new
    @timeout_id = nil
    schedule_next_frame(delay_us)
  end

  # Cancels the pending decode and stops the frame timer, which is what
  # upstream's dispose does. The caller — ImageResolver's holder, or whatever
  # widget drops its reference — is responsible for calling this once the
  # paintable is no longer shown.
  def stop
    @cancellable.cancel
    clear_timeout
  end

  def virtual_do_snapshot(snapshot, width, height)
    @current_frame&.snapshot(snapshot, width, height)
  end

  def virtual_do_get_intrinsic_width = @current_frame.width

  def virtual_do_get_intrinsic_height = @current_frame.height

  # No virtual_do_get_flags: GdkPaintableFlags is an out-param the Ruby
  # bindings cannot marshal back from a vfunc override (every return value
  # tried aborts the process in GObjectIntrospection::Loader::Invoker#invoke).
  # Leaving the vfunc unimplemented falls back to GTK's own default of no
  # flags set, which asks it to re-check size and contents on every frame —
  # exactly right here, since both do change.

  private

    def schedule_next_frame(delay_us)
      clear_timeout

      # A non-positive delay means the animation has no more frames to show,
      # matching upstream's early return.
      if delay_us.to_i.positive?
        @timeout_id = GLib::Timeout.add(delay_us.to_i / 1000) { on_timeout }
      end
    end

    def clear_timeout
      if @timeout_id
        GLib::Source.remove(@timeout_id)
        @timeout_id = nil
      end
    end

    def on_timeout
      @timeout_id = nil
      @image.next_frame_async(@cancellable) { |_source, task, _token| on_next_frame(task) }
      GLib::Source::REMOVE
    end

    def on_next_frame(task)
      frame = @image.next_frame_finish(task)
      @current_frame = GlyGtk4.frame_get_texture(frame)
      invalidate_contents
      schedule_next_frame(frame.delay)
    rescue GLib::Error => e
      unless @cancellable.cancelled?
        warn "Could not load next frame: #{e.message}"
      end
    end
end
