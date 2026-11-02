# frozen_string_literal: true

require 'adwaita'

# The org.gnome.Shell.Extensions D-Bus proxy.
#
# Ported from upstream's src/local/org.gnome.Shell.Extensions.xml and the
# 4,600 lines of gdbus-codegen output in src/local/shell-dbus-interface.c the
# build generates from it. Ruby needs none of that: Gio::DBusProxy marshals
# the calls, so this class is the interface's shape — its eleven methods, its
# ExtensionStateChanged signal and its two properties — and nothing else.
#
# The proxy is created asynchronously because the Ruby bindings expose
# g_dbus_proxy_new_for_bus only in its async form. Until it arrives, and
# whenever GNOME Shell does not own the name, #owned? is false, which is the
# condition behind the window's "GNOME Shell Unavailable" page.
#
# Arguments travel as GVariant tuples built from GVariant text format:
# GLib::Variant.new cannot build a tuple in these bindings, while
# GLib::Variant.parse infers one from its printed form.
class ShellDbusInterface
  BUS_NAME = 'org.gnome.Shell.Extensions'
  OBJECT_PATH = '/org/gnome/Shell/Extensions'
  INTERFACE_NAME = 'org.gnome.Shell.Extensions'
  PROPERTIES_INTERFACE = 'org.freedesktop.DBus.Properties'

  # The methods that take a uuid and answer with a single boolean.
  BOOLEAN_METHODS = {
    enable_extension:    'EnableExtension',
    disable_extension:   'DisableExtension',
    uninstall_extension: 'UninstallExtension',
  }.freeze

  # The methods that take a uuid and answer with nothing.
  VOID_METHODS = {
    reload_extension:       'ReloadExtension',
    launch_extension_prefs: 'LaunchExtensionPrefs',
  }.freeze

  attr_reader :proxy

  def initialize(on_ready: nil, on_name_owner_changed: nil, on_state_changed: nil)
    @on_ready = on_ready
    @on_name_owner_changed = on_name_owner_changed
    @on_state_changed = on_state_changed
    @proxy = nil
  end

  # Starts the connection. The callbacks fire on the main loop once the proxy
  # exists; a session bus that cannot be reached leaves the proxy nil, and
  # every method below then reads as "the shell is not there".
  def connect
    Gio::DBusProxy.new_for_bus(
      :session,
      :none,
      nil,
      BUS_NAME,
      OBJECT_PATH,
      INTERFACE_NAME,
    ) do |new_proxy, _result|
      new_proxy.then { |ready| if ready then adopt(ready) end }
    end
    self
  rescue GLib::Error => e
    warn "Could not create proxy: #{e.message}"
    self
  end

  # True when GNOME Shell is running and owns the name, which is upstream's
  # is-supported condition (g_dbus_proxy_get_name_owner being non-NULL).
  def owned? = !proxy.nil? && !proxy.g_name_owner.nil?

  def shell_version = cached_string('ShellVersion')

  def user_extensions_enabled? = cached_boolean('UserExtensionsEnabled')

  # The global "Use Extensions" switch. A property write goes through
  # org.freedesktop.DBus.Properties.Set on the proxy's own connection:
  # updating the proxy's cache alone would never reach the shell.
  def user_extensions_enabled=(enabled)
    write_property('UserExtensionsEnabled', "<#{enabled == true}>")
  end

  def list_extensions = call('ListExtensions', nil)&.first

  def extension_info(uuid) = call('GetExtensionInfo', uuid_tuple(uuid))&.first

  def extension_errors(uuid) = call('GetExtensionErrors', uuid_tuple(uuid))&.first

  # The one asynchronous call: the shell shows its own confirmation dialog and
  # does not answer until the user has decided, so a synchronous call would
  # freeze the window for as long as that dialog is up. The block is handed the
  # shell's result string, or nil when the call failed.
  def install_remote_extension(uuid, &block)
    if proxy.nil?
      block&.call(nil)
    else
      proxy.call(
        'InstallRemoteExtension',
        uuid_tuple(uuid),
        :none,
        -1,
        nil,
      ) do |source, result|
        block&.call(finish_install(source, result))
      end
    end
  end

  def check_for_updates = call('CheckForUpdates', nil)

  # The portal-aware preferences call, which takes the parent window handle and
  # an (empty) options dictionary alongside the uuid.
  def open_extension_prefs(uuid, parent_window, options = {})
    call(
      'OpenExtensionPrefs',
      GLib::Variant.parse("(#{uuid.to_s.inspect}, #{parent_window.to_s.inspect}, #{print_options(options)})"),
    )
  end

  BOOLEAN_METHODS.each do |method_name, dbus_name|
    define_method(method_name) do |uuid|
      call(dbus_name, uuid_tuple(uuid))&.first == true
    end
  end

  VOID_METHODS.each do |method_name, dbus_name|
    define_method(method_name) do |uuid|
      call(dbus_name, uuid_tuple(uuid))
    end
  end

  private

    def adopt(ready)
      @proxy = ready
      ready.signal_connect('notify::g-name-owner') { @on_name_owner_changed&.call }
      ready.signal_connect('g-signal') do |_proxy, _sender, signal_name, parameters|
        dispatch_signal(signal_name, parameters)
      end
      @on_ready&.call
    end

    # The interface declares ExtensionStateChanged(s, a{sv}) and the older
    # ExtensionStatusChanged(s, i, s); the manager needs only the first, which
    # carries the extension's whole new state.
    def dispatch_signal(signal_name, parameters)
      if signal_name == 'ExtensionStateChanged'
        @on_state_changed&.call(
          parameters.get_child_value(0).get_string,
          parameters.get_child_value(1),
        )
      end
    end

    # Every call is synchronous, as upstream's are for everything but the
    # install: the shell answers these immediately and the alternative is a
    # callback per method for no gain.
    def call(method_name, parameters)
      if proxy.nil?
        nil
      else
        proxy.call_sync(
          method_name,
          parameters,
          :none,
          -1,
          nil,
        )
      end
    end

    def write_property(name, printed_value)
      if proxy
        proxy.g_connection.call_sync(
          BUS_NAME,
          OBJECT_PATH,
          PROPERTIES_INTERFACE,
          'Set',
          GLib::Variant.parse("(#{INTERFACE_NAME.inspect}, #{name.inspect}, #{printed_value})"),
        )
      end
    rescue GLib::Error => e
      warn "Could not set #{name}: #{e.message}"
    end

    def print_options(options)
      if options.empty?
        '@a{sv} {}'
      else
        "{#{options.map { |key, value| "#{key.to_s.inspect}: <#{value}>" }.join(', ')}}"
      end
    end

    def finish_install(source, result)
      source.call_finish(result)&.first
    rescue Gio::DBusError, GLib::Error => e
      warn "Could not install extension: #{e.message}"
      nil
    end

    def uuid_tuple(uuid) = GLib::Variant.parse("(#{uuid.to_s.inspect},)")

    def cached_string(name) = proxy&.get_cached_property(name)&.get_string

    def cached_boolean(name) = proxy&.get_cached_property(name)&.get_boolean == true
end
