# frozen_string_literal: true

require 'adwaita'
require_relative 'types'

# The button that installs an extension.
#
# Ported from upstream's src/exm-install-button.blp and
# src/exm-install-button.c: a Gtk.Button whose child is a crossfading stack of
# a label and a download icon, so the same button can be a labelled button in
# the detail view and an icon-only one in a search row.
#
# The five states are upstream's, with the label, sensitivity, style class and
# tooltip each one sets. The loading state replaces the whole stack with a
# spinner, exactly as upstream does.
class InstallButton < Gtk::Button
  attr_reader :state

  def initialize(state: Types::InstallButtonState::DEFAULT, icon_only: false)
    super()
    self.valign = :center
    @state = state
    @icon_only = icon_only
  end

  def build
    tap do |button|
      stack.tap do |widget|
        widget.add_child(label)
        widget.add_child(icon)
      end

      button.state = @state
      button.icon_only = @icon_only
    end
  end

  def state=(value)
    @state = value
    reset_appearance
    apply_state(value)
  end

  def icon_only=(value)
    @icon_only = value == true
    if @icon_only
      stack.visible_child = icon
    else
      stack.visible_child = label
    end
  end

  def icon_only? = @icon_only

  def stack
    @stack ||= Gtk::Stack.new.tap do |widget|
      widget.hhomogeneous = false
      widget.interpolate_size = true
      widget.transition_type = :crossfade
    end
  end

  def label = @label ||= Gtk::Label.new

  def icon = @icon ||= Gtk::Image.new.tap { |image| image.icon_name = 'folder-download-symbolic' }

  private

    def reset_appearance
      remove_css_class('warning')
      remove_css_class('suggested-action')
      self.tooltip_text = nil
      self.child = stack
    end

    def apply_state(value)
      case value
      when Types::InstallButtonState::DEFAULT then apply_default
      when Types::InstallButtonState::INSTALLING then apply_installing
      when Types::InstallButtonState::INSTALLED then apply_installed
      when Types::InstallButtonState::UNSUPPORTED then apply_unsupported
      when Types::InstallButtonState::LOADING then apply_loading
      end
    end

    def apply_default
      label.label = 'Install…'
      self.sensitive = true
      add_css_class('suggested-action')
    end

    def apply_installing
      label.label = 'Installing'
      self.sensitive = false
    end

    # Translators: the state an already-installed extension is in
    def apply_installed
      label.label = 'Installed'
      self.sensitive = false
    end

    def apply_unsupported
      label.label = 'Unsupported…'
      add_css_class('warning')
      # Translators: Icon's tooltip when an extension is incompatible
      self.tooltip_text = 'This extension is incompatible with your current version of GNOME'
      self.sensitive = true
    end

    def apply_loading
      self.child = Adwaita::Spinner.new
      self.tooltip_text = 'Loading'
      self.sensitive = false
    end
end
