# frozen_string_literal: true

require 'adwaita'
require_relative 'extension'
require_relative 'shell_dbus_interface'
require_relative 'types'

# The GNOME Shell client: the list of installed extensions and the operations
# that change it.
#
# Ported from upstream's src/local/exm-manager.c. It keeps the same surface:
# an `extensions` list model, the shell version, the global enabled flag, an
# is-supported flag, and the three signals upstream emits —
# updates-available, error-occurred and install-status. Ruby callbacks stand
# in for those signals, registered with #on_updates_available, #on_error and
# #on_install_status, because this class is not a widget and nothing binds to
# it through GObject.
#
# The D-Bus property names, the double-typed `state` and `version` members and
# the nested session modes and donations dictionaries are all parsed the way
# upstream's parse_single_extension parses them.
class Manager
  attr_reader :extensions, :shell_version

  def initialize
    @extensions = Gio::ListStore.new(Extension)
    @shell_version = nil
    @is_supported = false
    @update_queued = false
    @updates_callbacks = []
    @error_callbacks = []
    @install_callbacks = []
    @supported_callbacks = []
    @enabled_callbacks = []
    @interface = build_interface
  end

  # Opens the connection to the shell. Separate from the constructor so a
  # caller can register its callbacks first and still hear the first
  # is-supported change.
  def connect
    @interface.connect
    self
  end

  def on_updates_available(&block) = @updates_callbacks << block
  def on_error(&block) = @error_callbacks << block
  def on_install_status(&block) = @install_callbacks << block

  # Upstream's rows connect to install-status for one install and disconnect
  # in the handler, so dropping a callback again has to be possible.
  def off_install_status(block) = @install_callbacks.delete(block)

  def on_supported_changed(&block) = @supported_callbacks << block
  def on_extensions_enabled_changed(&block) = @enabled_callbacks << block

  # Upstream's window emits install-status itself when the user refuses the
  # unsupported-extension warning, so that refusal has to be reportable from
  # outside the install itself.
  def report_install_status(state) = notify_install_status(state)

  def supported? = @is_supported

  def extensions_enabled? = @interface.user_extensions_enabled?

  def extensions_enabled=(enabled)
    @interface.user_extensions_enabled = enabled
  end

  def enable_extension(extension)
    unless @interface.enable_extension(extension.uuid)
      notify_error("Could not enable extension '#{extension.uuid}': unknown failure")
    end
  end

  def disable_extension(extension)
    unless @interface.disable_extension(extension.uuid)
      notify_error("Could not disable extension '#{extension.uuid}': unknown failure")
    end
  end

  def remove_extension(extension)
    unless @interface.uninstall_extension(extension.uuid)
      notify_error("Could not remove extension '#{extension.uuid}': unknown failure")
    end
  end

  # Upstream ignores errors from the preferences launch: the call fails
  # harmlessly on shells that cannot export a window handle.
  def open_prefs(extension)
    @interface.launch_extension_prefs(extension.uuid)
  rescue Gio::DBusError, GLib::Error
    nil
  end

  def by_uuid(uuid)
    each_extension.find { |extension| extension.uuid == uuid }
  end

  def installed_uuid?(uuid) = !by_uuid(uuid).nil?

  # Installing is asynchronous, because the shell asks the user to confirm
  # before it answers. `failure_state` is the install-status value to report
  # when the install does not happen: upstream reports DEFAULT for an ordinary
  # install and UNSUPPORTED when the user went ahead from the unsupported
  # dialog, so the button falls back to the warning it was wearing.
  def install(uuid, failure_state: Types::InstallButtonState::DEFAULT)
    @interface.install_remote_extension(uuid) do |result|
      if result.nil? || result == 'cancelled'
        notify_install_status(failure_state)
      else
        notify_install_status(Types::InstallButtonState::INSTALLED)
      end
    end
  end

  def check_for_updates
    @interface.check_for_updates
    queue_notify_extension_updates
  rescue Gio::DBusError, GLib::Error => e
    notify_error("Could not check for updates: #{e.message}")
    queue_notify_extension_updates
  end

  def number_of_updates = each_extension.count { |extension| extension.has_update == true }

  def each_extension
    Enumerator.new do |yielder|
      extensions.n_items.times { |index| yielder << extensions.get_item(index) }
    end
  end

  private

    def build_interface
      ShellDbusInterface.new(
        on_ready:              method(:on_proxy_ready),
        on_name_owner_changed: method(:update_is_supported),
        on_state_changed:      method(:on_state_changed),
      )
    end

    def on_proxy_ready
      @shell_version = @interface.shell_version
      update_is_supported
      @enabled_callbacks.each { |callback| callback.call(@interface.user_extensions_enabled?) }
    end

    def update_is_supported
      @interface.owned?.then do |supported|
        if supported != @is_supported
          @is_supported = supported
          @shell_version = @interface.shell_version
          if supported then update_extension_list end
          @supported_callbacks.each { |callback| callback.call(supported) }
        end
      end
    end

    def update_extension_list
      list = @interface.list_extensions
      if list.nil?
        notify_error('Could not list extensions')
      else
        extensions.remove_all
        list.each do |uuid, properties|
          parse_single_extension(Extension.new(uuid), uuid, properties).then do |extension|
            unless extension.uninstalled?
              extensions.append(extension)
            end
          end
        end
        queue_notify_extension_updates
      end
    end

    # Upstream parses the new state into the existing extension so the bound
    # rows update in place, inserting it sorted when the uuid is new and
    # removing it when the state says the extension is being uninstalled.
    def on_state_changed(uuid, state)
      existing = by_uuid(uuid)
      extension = existing || Extension.new(uuid)
      parse_single_extension(extension, uuid, state.to_a.first)

      if existing.nil?
        unless extension.uninstalled?
          extensions.insert_sorted(extension) { |a, b| a <=> b }
        end
      elsif extension.uninstalled?
        remove_from_store(extension)
      else
        touch_in_store(extension)
      end

      if extension.has_update == true
        queue_notify_extension_updates
      end
    end

    def remove_from_store(extension)
      extensions.find(extension).then do |found, position|
        if found
          extensions.remove(position)
        end
      end
    end

    # Emitting items-changed for the row's own position is what re-sorts the
    # list without rebuilding it, which is how upstream keeps the enabled-first
    # ordering honest after a toggle.
    def touch_in_store(extension)
      extensions.find(extension).then do |found, position|
        if found
          extensions.items_changed(position, 0, 0)
        end
      end
    end

    # The D-Bus dictionary uses the shell's own property names, and sends the
    # state and the version as doubles.
    def parse_single_extension(extension, uuid, properties)
      Hash(properties).then do |values|
        extension.set_property('name', values['name'].to_s)
        extension.set_property('description', values['description'].to_s)
        extension.set_property('state', state_of(values))
        extension.set_property('enabled', values.fetch('enabled', false) == true)
        extension.set_property('path', values['path'].to_s)
        extension.set_property('url', values['url'].to_s)
        extension.set_property('version', version_of(values))
        extension.set_property('version-name', values['version-name'].to_s)
        extension.set_property('error', values['error'].to_s)
        extension.set_property('has-prefs', values.fetch('hasPrefs', false) == true)
        extension.set_property('has-update', values.fetch('hasUpdate', false) == true)
        extension.set_property('can-change', values.fetch('canChange', true) == true)
        extension.set_property('is-user', type_of(values) == Types::ExtensionType::PER_USER)
        extension.session_modes = Array(values['sessionModes']).map(&:to_s)
        extension.donations = parse_donations(values['donations'])
      end
      extension
    end

    def state_of(values) = values.fetch('state', Types::ExtensionState::INITIALIZED).to_i

    def type_of(values) = values.fetch('type', Types::ExtensionType::SYSTEM).to_i

    # The shell sends the version as a double; upstream prints it as an int.
    def version_of(values)
      if values.key?('version')
        values.fetch('version').to_i.to_s
      else
        ''
      end
    end

    # Each donation platform maps either to a single username or to a list of
    # them; upstream normalises both into an array per platform.
    def parse_donations(donations)
      {}.tap do |parsed|
        Hash(donations).each do |platform, usernames|
          case usernames
          when Array then parsed[platform.to_s] = usernames.map(&:to_s)
          else parsed[platform.to_s] = [usernames.to_s]
          end
        end
      end
    end

    # Counting the updates is deferred to an idle callback, so a burst of
    # state changes notifies once, which is what upstream's
    # queue_notify_extension_updates achieves with a zero-length timeout.
    def queue_notify_extension_updates
      unless @update_queued
        @update_queued = true
        GLib::Idle.add do
          @update_queued = false
          notify_extension_updates
          GLib::Source::REMOVE
        end
      end
    end

    def notify_extension_updates
      number_of_updates.then do |count|
        if count.positive?
          @updates_callbacks.each { |callback| callback.call(count) }
        end
      end
    end

    def notify_error(message)
      warn message
      @error_callbacks.each { |callback| callback.call(message) }
    end

    # Over a copy: a search row drops its own callback from inside the
    # handler, which would otherwise be a mutation mid-iteration.
    def notify_install_status(state)
      @install_callbacks.dup.each { |callback| callback.call(state) }
    end
end
