# frozen_string_literal: true

require 'adwaita'
require_relative 'zoom_picture'

# The full-screen screenshot viewer, reached from the detail view.
#
# Ported from upstream's src/exm-screenshot-view.blp and
# src/exm-screenshot-view.c: an Adw.NavigationPage holding a ZoomPicture under
# a header bar, with zoom in/out buttons overlaid in the bottom-right corner.
# Setting `screenshot=` resets the zoom to 1.0, as upstream's property setter
# does.
#
# The zoom-in/zoom-out/zoom-reset actions the buttons point at are upstream's
# too, but upstream installs them on the window class, not this page, because
# Ctrl+Plus/Minus/0 need to reach them from anywhere in the window — Window
# installs them (as plain "win." actions; see its `zoom_in_action` for why
# not upstream's own grouped prefix) and delegates to #zoom_in, #zoom_out and
# #zoom_reset here; #notify_zoom_changed is what it calls on the
# notify::zoom-level signal to keep the window's own action-enabled state in
# step, which is upstream's notify_zoom.
class ScreenshotView < Adwaita::NavigationPage
  TAG = 'screenshot-view'
  ZOOM_OUT_TOOLTIP = 'Zoom Out'
  ZOOM_IN_TOOLTIP = 'Zoom In'

  attr_reader :screenshot

  def initialize
    super(toolbar_view, '')
    add_css_class('tint')
    self.tag = TAG
    @screenshot = nil
  end

  def build
    tap do |page|
      toolbar_view.tap do |view|
        view.add_top_bar(Adwaita::HeaderBar.new)
        view.content = overlay
      end

      overlay.tap do |ov|
        ov.child = picture_bin
        ov.add_overlay(button_box)
      end

      picture_bin.child = zoom_picture.build.tap do |widget|
        widget.on_zoom_changed { |zoom_level| @on_zoom_changed&.call(zoom_level) }
      end

      button_box.tap do |box|
        box.append(zoom_out_button)
        box.append(zoom_in_button)
      end
    end
  end

  def screenshot=(paintable)
    @screenshot = paintable
    zoom_picture.paintable = paintable
    zoom_picture.zoom_level = 1.0
  end

  # Called by Window, which installs the "screenshot" action group so
  # Ctrl+Plus/Minus/0 reach it from anywhere, not only while this page's own
  # buttons have focus.
  def zoom_in = zoom_picture.zoom_level += zoom_picture.zoom_level_step
  def zoom_out = zoom_picture.zoom_level -= zoom_picture.zoom_level_step
  def zoom_reset = zoom_picture.zoom_level = 1.0

  def zoom_level_max = zoom_picture.zoom_level_max
  def zoom_level_min = zoom_picture.zoom_level_min

  # Window's hook for keeping its screenshot.zoom-in/zoom-out actions
  # enabled only while there is further to zoom, upstream's notify_zoom.
  def on_zoom_changed(&block) = @on_zoom_changed = block

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def overlay = @overlay ||= Gtk::Overlay.new

  def picture_bin
    @picture_bin ||= Adwaita::Bin.new.tap do |bin|
      bin.hexpand = true
      bin.vexpand = true
    end
  end

  def zoom_picture = @zoom_picture ||= ZoomPicture.new

  def button_box
    @button_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.halign = :end
      box.valign = :end
      box.margin_top = 18
      box.margin_bottom = 18
      box.margin_start = 18
      box.margin_end = 18
    end
  end

  def zoom_out_button = @zoom_out_button ||= zoom_button('zoom-out-symbolic', ZOOM_OUT_TOOLTIP, 'win.zoom-out')
  def zoom_in_button = @zoom_in_button ||= zoom_button('zoom-in-symbolic', ZOOM_IN_TOOLTIP, 'win.zoom-in')

  private

    def zoom_button(icon_name, tooltip, action_name)
      Gtk::Button.new.tap do |button|
        button.add_css_class('osd')
        button.add_css_class('circular')
        button.icon_name = icon_name
        button.tooltip_text = tooltip
        button.action_name = action_name
        button.height_request = 42
        button.width_request = 42
      end
    end
end
