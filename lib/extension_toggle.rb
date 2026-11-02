# frozen_string_literal: true

require 'adwaita'
require_relative 'types'

# Binds a Gtk.Switch to an extension's enabled state.
#
# Ported from upstream's src/exm-extension-toggle.c, which is behaviour
# rather than a widget: two functions shared by the extension row and the
# detail view, so both treat the switch the same way.
#
# `bind` keeps the switch's `active` in step with the extension's `enabled`
# and its `state` (the slider's position) with whether the extension is
# actually running; `apply` is the state-set handler that asks the manager to
# enable or disable.
#
# Both carry upstream's workaround for GNOME Shell before 46: those shells
# report `enabled` without ever changing it back, so the extension's flag is
# flipped by hand whenever the switch's settled state disagrees with it.
module ExtensionToggle
  # The states in which an extension is, or is about to be, running.
  RUNNING_STATES = [
    Types::ExtensionState::ACTIVE,
    Types::ExtensionState::ACTIVATING,
  ].freeze

  def self.bind(extension, toggle)
    extension.bind_property(
      'enabled',
      toggle,
      'active',
      :sync_create,
    )
    sync_state(extension, toggle)
    extension.signal_connect('notify::state') { sync_state(extension, toggle) }

    if toggle.state? != extension.enabled && RUNNING_STATES.include?(extension.state)
      extension.set_property('enabled', !extension.enabled)
    end
  end

  # Upstream binds `state` through a transform that is true only for the
  # active state; the Ruby bindings have no bind_property_full, so the same
  # transform runs from the notify handler.
  def self.sync_state(extension, toggle)
    toggle.state = extension.state == Types::ExtensionState::ACTIVE
  end

  # The state-set handler: returning true tells Gtk.Switch that the state will
  # be set by whoever answers, which here is the shell's state-changed signal.
  def self.apply(manager, extension, toggle, state)
    if state == extension.enabled
      true
    else
      if toggle.state? != extension.enabled
        extension.set_property('enabled', !extension.enabled)
      end

      if state
        manager.enable_extension(extension)
      else
        manager.disable_extension(extension)
      end
      true
    end
  end
end
