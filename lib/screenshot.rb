# frozen_string_literal: true

require 'adwaita'

# A 16:9 screenshot slot: a spinner while it loads, the image once it has.
#
# Ported from upstream's src/exm-screenshot.blp and src/exm-screenshot.c: a
# bare GtkWidget wrapping a crossfading Gtk.Stack of a loading spinner-style
# icon and a Gtk.Picture, which upstream measures itself rather than letting
# the stack answer: the widget's height for a given width is always that
# width scaled to a 16:9 aspect ratio, so the slot holds its shape before the
# image — or an error — ever arrives.
class Screenshot < Gtk::Widget
  type_register

  LOADING_ICON = 'image-loading-symbolic'

  def initialize
    super()
    @picture = nil
    @stack = nil
  end

  def build
    tap do |widget|
      stack.set_parent(widget)
      stack.add_named(spinner, 'page_spinner')
      stack.add_named(picture, 'page_picture')
      stack.visible_child_name = 'page_spinner'
    end
  end

  def set_paintable(paintable) = picture.paintable = paintable

  def reset = stack.visible_child_name = 'page_spinner'

  def display = stack.visible_child_name = 'page_picture'

  def virtual_do_get_request_mode = :height_for_width

  # Vertical: the natural height is always the given width scaled to 16:9,
  # upstream's "for_size / 16.0f * 9.0f". Horizontal: whatever the stack asks
  # for, unchanged.
  def virtual_do_measure(orientation, for_size)
    minimum, natural, min_baseline, nat_baseline = stack.measure(orientation, for_size)
    if orientation == :vertical
      height = (for_size / 16.0) * 9.0
      [height.to_i, height.to_i, min_baseline, nat_baseline]
    else
      [minimum, natural, min_baseline, nat_baseline]
    end
  end

  def virtual_do_size_allocate(width, height, baseline)
    stack.allocate(
      width,
      height,
      baseline,
      nil,
    )
  end

  private

    def stack
      @stack ||= Gtk::Stack.new.tap { |widget| widget.transition_type = :crossfade }
    end

    def spinner
      @spinner ||= Gtk::Image.new.tap do |image|
        image.icon_name = LOADING_ICON
        image.icon_size = :large
        image.valign = :center
      end
    end

    def picture
      @picture ||= Gtk::Picture.new.tap do |pic|
        pic.valign = :fill
        pic.halign = :fill
      end
    end
end
