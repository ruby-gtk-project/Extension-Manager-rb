# frozen_string_literal: true

require 'fileutils'
require 'json'

# The app's persisted settings.
#
# Ported from upstream's data/com.mattjakeman.ExtensionManager.gschema.xml.in,
# which declares exactly these four keys with these defaults: the window
# geometry upstream binds to the window, and the sort-enabled-first flag the
# primary menu toggles and the installed page reads.
#
# Upstream uses GSettings, which needs the schema compiled into a system
# directory before the app will start. Requiring an install step to run from a
# checkout is worse than the alternative, so the same keys, defaults and
# semantics are backed by a JSON file under XDG_CONFIG_HOME.
class Settings
  APP_ID = 'com.mattjakeman.ExtensionManager'

  DEFAULTS = {
    'width'              => 800,
    'height'             => 600,
    'is-maximized'       => false,
    'sort-enabled-first' => false,
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
    @callbacks = {}
  end

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    @callbacks.fetch(key.to_s, []).each { |callback| callback.call(value) }
    value
  end

  # Upstream binds these keys to widget properties with g_settings_bind;
  # watching a key is what a Ruby port binds with instead.
  def watch(key, &block)
    @callbacks[key.to_s] = @callbacks.fetch(key.to_s, []) << block
    self
  end

  def location = @path

  DEFAULTS.each_key do |key|
    method_name = key.tr('-', '_')
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
    if DEFAULTS[key] == false
      define_method(:"#{method_name}?") { self[key] == true }
    end
  end

  # The geometry binding upstream sets up in exm_application's
  # get_current_window: the window starts where the last run left it, and
  # writes the new geometry back as it closes.
  def apply_to(window)
    window.set_default_size(self['width'], self['height'])
    if self['is-maximized']
      window.maximize
    end
  end

  def store_from(window)
    self['is-maximized'] = window.maximized?
    unless window.maximized?
      self['width'] = window.default_width
      self['height'] = window.default_height
    end
  end

  private

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.join(Dir.home, '.config')),
        APP_ID,
        'settings.json',
      )
    end

    def read
      JSON.parse(File.read(@path))
    rescue Errno::ENOENT, JSON::ParserError
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@values))
    rescue SystemCallError => e
      warn "Could not save settings to #{@path}: #{e.message}"
    end
end
