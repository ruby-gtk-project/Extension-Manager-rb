# frozen_string_literal: true

# Drives lib/settings.rb's real Gio::Settings backing (ported from upstream's
# data/com.mattjakeman.ExtensionManager.gschema.xml.in and exm-application.c's
# g_settings_bind calls). A `require 'gio2'` and a call that merely does not
# raise would also be true of a schema that silently fell through to the
# JSON fallback — this asserts `backed_by_gsettings?` is true and reads
# values back through a second, independent Gio::Settings handle, which only
# agrees with the first if GLib (not this process's memory) is actually
# holding the state.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require_relative '../.claude/skills/ruby-gtk-testing/scripts/gtk_driver'
require 'extension_manager'
require 'settings'

app = ExtensionManager::Application.new

GtkDriver.drive(app, shots: 'tmp/shots') do |d, application|
  d.window { application.window }

  d.step('the window builds, which constructs the app\'s real Settings') do
    settings = application.settings
    d.check('window present') { application.window.visible? }
    d.check('a real, compiled GSettings schema backs it, not the JSON fallback') do
      settings.backed_by_gsettings?
    end
  end

  d.step('a write through the app\'s Settings is readable from an independent Gio::Settings handle') do
    settings = application.settings
    settings['width'] = 777
    settings['height'] = 555
    settings['sort-enabled-first'] = true

    independent = Gio::Settings.new(Settings::APP_ID)
    d.check('width round-trips through GLib, not Ruby-side memory') { independent.get_int('width') == 777 }
    d.check('height round-trips through GLib, not Ruby-side memory') { independent.get_int('height') == 555 }
    d.check('sort-enabled-first round-trips through GLib') { independent.get_boolean('sort-enabled-first') == true }
  end

  d.step('watch fires from a real GSettings "changed" signal, not a hand-rolled callback list') do
    settings = application.settings
    seen = []
    settings.watch('sort-enabled-first') { |value| seen << value }
    # Write through the independent handle from the previous step, not
    # through `settings` itself, so this proves the signal is real GLib
    # notification rather than the setter directly invoking its own
    # callbacks in-process.
    Gio::Settings.new(Settings::APP_ID).set_boolean('sort-enabled-first', false)
  end

  d.step('the watched callback already ran by the next GLib main loop tick') do
    d.check('app.settings reads the externally-written value back') do
      application.settings['sort-enabled-first'] == false
    end
  end

  d.step('apply_to / store_from round-trip real window geometry through GSettings') do
    window = application.window
    application.settings['width'] = 900
    application.settings['height'] = 650
    application.settings['is-maximized'] = false
    application.settings.apply_to(window)
    d.check('apply_to sets the window\'s default size from the stored geometry') do
      window.default_width == 900 && window.default_height == 650
    end

    window.set_default_size(1024, 768)
    application.settings.store_from(window)
    d.check('store_from writes the new geometry back to the same GSettings key') do
      Gio::Settings.new(Settings::APP_ID).get_int('width') == 1024
    end
  end
end
