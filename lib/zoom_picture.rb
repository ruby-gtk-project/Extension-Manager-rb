# frozen_string_literal: true

require 'adwaita'

# A paintable shown scaled to fit, zoomable and pannable.
#
# Ported from upstream's src/exm-zoom-picture.c: a bare GtkWidget that scales
# its paintable to fill the widget — horizontally first, falling back to
# vertically when that would overflow — then multiplies by the zoom level,
# centres the result, and clamps panning so the image can never be dragged
# past its own edge. A pinch gesture sets the zoom and tracks the pinch
# centre; a drag gesture pans.
class ZoomPicture < Gtk::Widget
  type_register

  ZOOM_STEP = 0.5
  ZOOM_MIN = 0.5
  ZOOM_MAX = 5.0

  attr_reader :paintable, :zoom_level

  def initialize
    super()
    set_overflow(:hidden)
    @paintable = nil
    @zoom_level = 1.0
    @image_x = 0.0
    @image_y = 0.0
    @gesture_start_zoom = 1.0
    @gesture_image_start_x = 0.0
    @gesture_image_start_y = 0.0
    @gesture_touch_start_x = 0.0
    @gesture_touch_start_y = 0.0
    @invalidate_contents_id = nil
    @invalidate_size_id = nil
  end

  def build
    tap do |widget|
      widget.add_controller(zoom_gesture)
      widget.add_controller(drag_gesture)
    end
  end

  def paintable=(value)
    if @paintable
      @paintable.signal_handler_disconnect(@invalidate_contents_id)
      @paintable.signal_handler_disconnect(@invalidate_size_id)
    end

    @paintable = value

    if @paintable
      @invalidate_contents_id = @paintable.signal_connect('invalidate-contents') { queue_draw }
      @invalidate_size_id = @paintable.signal_connect('invalidate-size') { queue_resize }
    end

    queue_draw
  end

  def zoom_level=(value)
    @zoom_level = value.clamp(ZOOM_MIN, ZOOM_MAX)
    queue_draw
  end

  def zoom_level_max = ZOOM_MAX
  def zoom_level_min = ZOOM_MIN
  def zoom_level_step = ZOOM_STEP

  def virtual_do_snapshot(snapshot)
    if @paintable
      dims = scaled_dimensions
      snapshot.translate(Graphene::Point.new(dims[:x], dims[:y]))
      @paintable.snapshot(snapshot, dims[:width], dims[:height])
    end
  end

  private

    # Mirrors upstream's compute_scaled_dimensions: fill horizontally, fall
    # back to filling vertically when that overflows, scale by the zoom
    # level, centre, then clamp the pan offset to the image's own edges.
    def scaled_dimensions
      width = self.width.to_f
      height = self.height.to_f
      paintable_width = @paintable.intrinsic_width.to_f
      paintable_height = @paintable.intrinsic_height.to_f

      scale_factor = width / paintable_width
      scaled_width = paintable_width * scale_factor
      scaled_height = paintable_height * scale_factor

      if scaled_height > height
        scale_factor = height / paintable_height
        scaled_width = paintable_width * scale_factor
        scaled_height = paintable_height * scale_factor
      end

      scaled_width *= @zoom_level
      scaled_height *= @zoom_level

      x = (width - scaled_width) / 2
      y = (height - scaled_height) / 2

      @image_x = @image_x.clamp([x, -x].min, [x, -x].max)
      @image_y = @image_y.clamp([y, -y].min, [y, -y].max)

      if scaled_width > width
        x += @image_x
      else
        @image_x = 0.0
      end

      if scaled_height > height
        y += @image_y
      else
        @image_y = 0.0
      end

      { x: x, y: y, width: scaled_width, height: scaled_height }
    end

    def zoom_gesture
      @zoom_gesture ||= Gtk::GestureZoom.new.tap do |gesture|
        gesture.propagation_phase = :capture
        gesture.signal_connect('begin') { |g, _sequence| on_gesture_begin(g) }
        gesture.signal_connect('scale-changed') { |g, scale| on_scale_changed(g, scale) }
      end
    end

    def drag_gesture
      @drag_gesture ||= Gtk::GestureDrag.new.tap do |gesture|
        gesture.propagation_phase = :capture
        gesture.signal_connect('begin') { |g, _sequence| on_gesture_begin(g) }
        gesture.signal_connect('drag-update') { |g, offset_x, offset_y| on_drag_update(g, offset_x, offset_y) }
      end
    end

    def on_gesture_begin(gesture)
      gesture.set_state(:claimed)
      @gesture_start_zoom = @zoom_level
      @gesture_image_start_x = @image_x
      @gesture_image_start_y = @image_y
      center = gesture.bounding_box_center
      @gesture_touch_start_x = center[1]
      @gesture_touch_start_y = center[2]
    end

    def on_scale_changed(gesture, scale)
      self.zoom_level = @gesture_start_zoom * scale
      center = gesture.bounding_box_center
      @image_x = @gesture_image_start_x + (center[1] - @gesture_touch_start_x)
      @image_y = @gesture_image_start_y + (center[2] - @gesture_touch_start_y)
      queue_draw
    end

    def on_drag_update(_gesture, offset_x, offset_y)
      @image_x = @gesture_image_start_x + offset_x
      @image_y = @gesture_image_start_y + offset_y
      queue_draw
    end
end
