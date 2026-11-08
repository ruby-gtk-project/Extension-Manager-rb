# frozen_string_literal: true

require 'gio2'
require 'fileutils'
require 'json'

# The app's persisted settings.
#
# Ported from upstream's data/com.mattjakeman.ExtensionManager.gschema.xml.in,
# which declares exactly these four keys with these defaults: the window
# geometry upstream binds to the window, and the sort-enabled-first flag the
# primary menu toggles and the installed page reads.
#
# A real `Gio::Settings` backs these keys, matching upstream's own
# `g_settings_bind` / `g_settings_new` calls. GSettings needs its schema
# compiled into a directory GLib looks in before a `Gio::Settings` for that
# id can be constructed; a system package does that once, as part of
# installing the schema under /usr/share/glib-2.0/schemas. A gem has no such
# install step, so the schema template below is compiled into this user's
# own cache directory the first time the app starts, and
# `GSETTINGS_SCHEMA_DIR` is pointed at that directory before any
# `Gio::Settings` is constructed.
#
# If `glib-compile-schemas` is missing, or compiling or loading the schema
# fails for any other reason, settings fall back to a JSON file under
# XDG_CONFIG_HOME with the same four keys and defaults, so a host without
# the GLib dev tools on PATH still gets working (if unintegrated) settings
# instead of a crash.
class Settings
  APP_ID = 'com.mattjakeman.ExtensionManager'

  SCHEMA_TEMPLATE = File.expand_path('../data/com.mattjakeman.ExtensionManager.gschema.xml.in', __dir__)

  DEFAULTS = {
    'width'              => 800,
    'height'             => 600,
    'is-maximized'       => false,
    'sort-enabled-first' => false,
  }.freeze

  BOOLEAN_KEYS = %w[is-maximized sort-enabled-first].freeze

  def initialize(gio_settings: :auto)
    @gio_settings = (gio_settings == :auto ? self.class.build_gio_settings : gio_settings)
    @callbacks = {}
    @gio_settings&.signal_connect('changed') do |_settings, key|
      notify(key.to_s, self[key])
    end
  end

  def [](key)
    key = key.to_s
    if @gio_settings
      BOOLEAN_KEYS.include?(key) ? @gio_settings.get_boolean(key) : @gio_settings.get_int(key)
    else
      json_values.fetch(key, DEFAULTS[key])
    end
  end

  def []=(key, value)
    key = key.to_s
    if @gio_settings
      BOOLEAN_KEYS.include?(key) ? @gio_settings.set_boolean(key, value) : @gio_settings.set_int(key, value)
    else
      json_values[key] = value
      write_json
      notify(key, value)
    end
    value
  end

  # Upstream binds these keys to widget properties with g_settings_bind;
  # watching a key is what a Ruby port binds with instead (and, backed by a
  # real Gio::Settings, also fires for a change made outside this process,
  # e.g. `gsettings set`).
  def watch(key, &block)
    @callbacks[key.to_s] = @callbacks.fetch(key.to_s, []) << block
    self
  end

  # Whether a real, compiled GSettings schema backs this instance, or the
  # JSON fallback took over. Exposed for the drive script to assert on,
  # rather than let a silently-fallen-back instance look identical to a
  # working one.
  def backed_by_gsettings? = !@gio_settings.nil?

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

  class << self
    # Compiles the schema into this user's cache directory (idempotent -
    # glib-compile-schemas is cheap and safe to re-run) and constructs a
    # real Gio::Settings against it. Returns nil, rather than raising, on
    # any failure along the way, which is the signal the instance method
    # above uses to fall back to the JSON store instead.
    def build_gio_settings
      schema_dir = cache_schema_dir
      compile_schema!(schema_dir)
      ENV['GSETTINGS_SCHEMA_DIR'] = schema_dir
      Gio::Settings.new(APP_ID)
    rescue StandardError => e
      warn "Could not load the #{APP_ID} GSettings schema, falling back to a JSON settings file: #{e.message}"
      nil
    end

    private

      def cache_schema_dir
        File.join(
          ENV.fetch('XDG_CACHE_HOME', File.join(Dir.home, '.cache')),
          'extension-manager',
          'glib-2.0',
          'schemas',
        )
      end

      def compile_schema!(schema_dir)
        FileUtils.mkdir_p(schema_dir)
        File.write(
          File.join(schema_dir, "#{APP_ID}.gschema.xml"),
          File.read(SCHEMA_TEMPLATE).gsub('@app_id@', APP_ID),
        )
        system('glib-compile-schemas', schema_dir, exception: true)
      end
  end

  private

    def notify(key, value)
      @callbacks.fetch(key, []).each { |callback| callback.call(value) }
    end

    def json_values
      @json_values ||= DEFAULTS.merge(read_json)
    end

    def json_path
      @json_path ||= File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.join(Dir.home, '.config')),
        APP_ID,
        'settings.json',
      )
    end

    def read_json
      JSON.parse(File.read(json_path))
    rescue Errno::ENOENT, JSON::ParserError
      {}
    end

    def write_json
      FileUtils.mkdir_p(File.dirname(json_path))
      File.write(json_path, JSON.pretty_generate(json_values))
    rescue SystemCallError => e
      warn "Could not save settings to #{json_path}: #{e.message}"
    end
end
