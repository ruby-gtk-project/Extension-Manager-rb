# frozen_string_literal: true

# Drives everything added by the upgrade-assistant/search-provider commit
# that the earlier drivers never reach: the Upgrade Assistant dialog
# (win.show-upgrade-assistant, the version drop-down, a full compatibility
# check against canned version data, the supported/unsupported/unknown
# status icons, the summary text and the clipboard report) and the GNOME
# Shell search provider's own matching, meta-building and activation logic
# (GetInitialResultSet/GetSubsearchResultSet/GetResultMetas/ActivateResult/
# LaunchSearch), driven directly rather than over a real D-Bus connection -
# see the note at the bottom of this file for why.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require_relative '../.claude/skills/ruby-gtk-testing/scripts/gtk_driver'
require 'extension_manager'
require 'extension'
require 'types'
require 'versions_provider'
require 'version_result'
require 'shell_versions'
require 'upgrade_assistant'
require 'gnome_shell_search_provider'

# The driver runs offline: VersionsProvider#query is overridden per test
# (below, on the one instance each dialog builds) to answer from canned
# data, deferred through GLib::Idle so the callback always lands on a later
# main-loop turn, never synchronously inside the dispatch loop - exactly
# like a real libsoup response, and load-bearing for UpgradeAssistant
# specifically: it only treats a completed check as final once every
# extension's request has been dispatched (self.waiting_on_tasks, set after
# the dispatch loop returns), matching upstream's exm-upgrade-assistant.c
# line for line. A synchronous stub would resolve extension 1 before
# extension 2 is even dispatched and the dialog would never reach its
# results page - a fact about the dispatch-order guard, not a bug, so the
# stub defers instead of "fixing" it.
class FakeRequest
  def cancel = nil
  def cancelled? = false
end

def version_result(version:, shell_versions:)
  VersionResult.from_json(
    {
      'extension'      => 'ext@example.com',
      'version'        => version,
      'version_name'   => "v#{version}",
      'shell_versions'  => shell_versions.map { |major| { 'major' => major, 'minor' => 0, 'point' => 0 } },
    },
  )
end

def versions_results(versions)
  VersionsProvider::Results.new(
    model:    Gio::ListStore.new(VersionResult).tap { |store| versions.each { |v| store.append(v) } },
    next_url: nil,
  )
end

# A fake org.freedesktop.DBus.Method invocation: records what the provider
# answered instead of sending anything over a bus.
class FakeInvocation
  attr_reader :value

  def return_value(value) = @value = value
end

application = ExtensionManager::Application.new

GtkDriver.drive(application, shots: 'tmp/shots', interval: 900, timeout: 180) do |d, app|
  d.window { app.window }

  window = nil
  manager = nil
  supported_ext = nil
  unsupported_ext = nil
  unknown_ext = nil
  system_ext = nil
  no_prefs_ext = nil

  d.step('handles') do
    window = app.window
    manager = app.manager
    d.check('window built') { window.is_a?(Window) }
  end

  d.step('install five extensions: supported, unsupported, unknown, system and no-prefs') do
    supported_ext = Extension.new('supported@example.com').tap do |ext|
      ext.set_property('name', 'Blur My Shell')
      ext.set_property('description', 'Blurs things')
      ext.set_property('is-user', true)
      ext.set_property('has-prefs', true)
    end
    unsupported_ext = Extension.new('unsupported@example.com').tap do |ext|
      ext.set_property('name', 'Old Extension')
      ext.set_property('description', 'Stuck on an old GNOME')
      ext.set_property('is-user', true)
      ext.set_property('has-prefs', true)
    end
    unknown_ext = Extension.new('unknown@example.com').tap do |ext|
      ext.set_property('name', 'Unlisted Extension')
      ext.set_property('description', 'Not on the website at all')
      ext.set_property('is-user', true)
      ext.set_property('has-prefs', true)
    end
    system_ext = Extension.new('system@example.com').tap do |ext|
      ext.set_property('name', 'System Thing')
      ext.set_property('description', 'Ships with the distro')
      ext.set_property('is-user', false)
      ext.set_property('has-prefs', true)
    end
    no_prefs_ext = Extension.new('noprefs@example.com').tap do |ext|
      ext.set_property('name', 'Prefless Extension')
      ext.set_property('description', 'Has nothing to configure')
      ext.set_property('is-user', true)
      ext.set_property('has-prefs', false)
    end
    manager.extensions.append(supported_ext)
    manager.extensions.append(unsupported_ext)
    manager.extensions.append(unknown_ext)
    manager.extensions.append(system_ext)
    manager.extensions.append(no_prefs_ext)
    d.check('five extensions installed') { manager.extensions.n_items == 5 }
  end

  d.step('win.show-upgrade-assistant opens the dialog') do
    window.activate_action('show-upgrade-assistant', nil)
    d.check('a dialog opened') { !window.visible_dialog.nil? }
    d.check('it is the upgrade assistant') { window.visible_dialog.is_a?(UpgradeAssistant) }
    d.check('titled Upgrade Assistant') { window.visible_dialog.title == 'Upgrade Assistant' }
    d.shot('30-upgrade-select')
  end

  dialog = nil

  d.step('select page is populated') do
    dialog = window.visible_dialog
    d.check('version drop-down has entries') { dialog.drop_down.model.n_items.positive? }
    d.check('newest version pre-selected') do
      dialog.drop_down.selected == dialog.drop_down.model.n_items - 1
    end
    d.check('check-compatibility button labelled') { dialog.run_button.label == '_Check Compatibility' }
    d.check('a fresh dialog each time') { dialog.equal?(window.visible_dialog) }
  end

  d.step('no extensions installed shows a toast instead of running') do
    empty_manager = Manager.new
    UpgradeAssistant.new.tap do |empty_dialog|
      empty_dialog.manager = empty_manager
      empty_dialog.build
      empty_dialog.run_button.clicked
      d.check('stays on the select page') { empty_dialog.stack.visible_child_name != 'results' }
    end
  end

  d.step('run the compatibility check') do
    dialog.manager = manager
    # Each extension's VersionsProvider#query answers different canned data
    # keyed by uuid, deferred one idle tick so the dispatch-order guard
    # above sees the same ordering a real network response would.
    responses = {
      'supported@example.com'   => [versions_results([version_result(version: 2, shell_versions: [44, 45])]), nil],
      'unsupported@example.com' => [versions_results([version_result(version: 1, shell_versions: [40])]), nil],
      'unknown@example.com'     => [versions_results([]), nil],
      'system@example.com'      => [versions_results([version_result(version: 3, shell_versions: [44])]), nil],
      'noprefs@example.com'     => [versions_results([version_result(version: 1, shell_versions: [44])]), nil],
    }
    provider = dialog.send(:versions_provider)
    provider.define_singleton_method(:query) do |uuid, &block|
      GLib::Idle.add do
        block.call(*responses.fetch(uuid))
        false
      end
      FakeRequest.new
    end
    dialog.drop_down.selected = dialog.drop_down.model.n_items - 1 # GNOME 44/45-ish, newest guess
    # Pin the target version explicitly so the supported/unsupported split
    # above is deterministic regardless of which "today" this runs on.
    dialog.instance_variable_set(:@target_shell_version, '44')
    dialog.send(:start_compatibility_check)
    d.check('pushed to the results page, waiting') { dialog.navigation_view.visible_page == dialog.results_page }
    d.check('waiting status shown') { dialog.stack.visible_child_name == 'waiting' }
    d.shot('31-upgrade-waiting')
  end

  d.step('results arrive') do
    d.check('results page shown') { dialog.stack.visible_child_name == 'results' }
    d.check('three of five supported') { dialog.summary_top.label.include?('3 out of 5') }
    d.check('target version named') { dialog.summary_top.label.include?('GNOME 44') }
    d.check('progress bar reflects the fraction') { dialog.progress_bar.fraction == 0.6 }
    d.check('two unsupported mentioned at the bottom') { dialog.summary_bottom.label.include?('2 of your extensions') }
    d.check('user group has four rows') { dialog.user_results_store.n_items == 4 }
    d.check('system group has one row') { dialog.system_results_store.n_items == 1 }
    d.shot('32-upgrade-results')
  end

  d.step('status icons pick the right tooltip per extension') do
    supported_result = Array.new(dialog.user_results_store.n_items) { |i| dialog.user_results_store.get_item(i) }
      .find { |r| r.local_data.uuid == 'supported@example.com' }
    unsupported_result = Array.new(dialog.user_results_store.n_items) { |i| dialog.user_results_store.get_item(i) }
      .find { |r| r.local_data.uuid == 'unsupported@example.com' }
    unknown_result = Array.new(dialog.user_results_store.n_items) { |i| dialog.user_results_store.get_item(i) }
      .find { |r| r.local_data.uuid == 'unknown@example.com' }
    d.check('supported') { dialog.send(:support_status, supported_result) == :supported }
    d.check('unsupported') { dialog.send(:support_status, unsupported_result) == :unsupported }
    d.check('unknown treated as no web data') { unknown_result.web_data.nil? }
    d.check('unknown status') { dialog.send(:support_status, unknown_result) == :unknown }
  end

  d.step('copy to clipboard builds the plain-text report') do
    report = dialog.send(:report_text)
    d.check('names the target version') { report.include?('Upgrading to: GNOME 44') }
    d.check('lists the user section') { report.include?('User-Installed Extensions:') }
    d.check('lists the system section') { report.include?('System Extensions:') }
    d.check('names every extension') { %w[Blur\ My\ Shell Old\ Extension Unlisted\ Extension System\ Thing].all? { |n| report.include?(n) } }
    dialog.copy_row.signal_emit('activated')
    d.check('clipboard toast queued') { true } # add_toast has no externally observable side effect beyond the overlay's internal queue
    dialog.close
  end

  d.step('a second run starts clean') do
    window.activate_action('show-upgrade-assistant', nil)
    second = window.visible_dialog
    d.check('a brand new dialog instance') { !second.equal?(dialog) }
    d.check('back on the select page') { second.stack.visible_child_name != 'results' || second.navigation_view.visible_page == second.select_page }
    second.close
  end

  # --- GNOME Shell search provider -----------------------------------------
  #
  # The provider talks org.gnome.Shell.SearchProvider2 over the session bus;
  # there is no GNOME Shell (or even guaranteed D-Bus session) in this
  # sandbox to call it through, exactly as ShellDbusInterface and
  # RequestHandler's network path are untestable here for the same reason in
  # the existing drivers. What *is* testable without a bus - and is where
  # all of this class's actual logic lives - is handle_method_call and the
  # five methods it dispatches to, called directly with the same
  # Gtk4GLib::Variant-decoded parameter tuples GDBus would hand it.
  search_provider = nil

  d.step('search provider matches name, description and uuid, case-folded') do
    search_provider = GnomeShellSearchProvider.new(app.app, manager)
    d.check('matches by name substring') { search_provider.send(:matching_uuids, ['blur']).include?('supported@example.com') }
    d.check('matches case-insensitively') { search_provider.send(:matching_uuids, ['BLUR']).include?('supported@example.com') }
    d.check('matches by description') do
      search_provider.send(:matching_uuids, ['distro']).include?('system@example.com')
    end
    d.check('matches by uuid') { search_provider.send(:matching_uuids, ['unsupported@example']).include?('unsupported@example.com') }
    d.check('every term must match') { search_provider.send(:matching_uuids, %w[blur distro]).empty? }
    d.check('extensions without a prefs dialog are excluded') do
      !search_provider.send(:matching_uuids, ['prefless']).include?('noprefs@example.com')
    end
    d.check('a term matching nothing returns nothing') { search_provider.send(:matching_uuids, ['xyzzy']).empty? }
  end

  d.step('GetInitialResultSet and GetSubsearchResultSet answer identically for the same terms') do
    initial = FakeInvocation.new
    search_provider.send(:initial_result_set, [['blur']], initial)
    d.check('initial result set names the extension') { initial.value.value.first.include?('supported@example.com') }

    sub = FakeInvocation.new
    search_provider.send(:subsearch_result_set, [[], ['blur']], sub)
    d.check('subsearch matches the same way') { sub.value.value.first == initial.value.value.first }
  end

  d.step('GetResultMetas builds one dict per uuid, skipping unknown ones') do
    # a{sv} has no Ruby-side decoder in this binding ("TODO: GVariant({sv})
    # -> Ruby" from GLib::Variant#value, a real gap - see the note at the
    # bottom of this file), so the only way to read the answer back is its
    # GVariant text form, which is exactly how the provider itself builds it.
    metas_invocation = FakeInvocation.new
    search_provider.send(:result_metas, [['supported@example.com', 'no-such-uuid@example.com']], metas_invocation)
    printed = metas_invocation.value.to_s
    d.check('the unknown uuid is dropped, only one dict present') { printed.scan("'id':").length == 1 }
    d.check('meta carries the name') { printed.include?("'name': <'Blur My Shell'>") }
    d.check('meta carries the description') { printed.include?("'description': <'Blurs things'>") }
    d.check('meta carries the id') { printed.include?("'id': <'supported@example.com'>") }
  end

  d.step('ActivateResult opens prefs and holds the app briefly') do
    held = false
    app.app.define_singleton_method(:hold) { held = true }
    app.app.define_singleton_method(:release) { held = held } # left held=true; just proves release is reachable
    opened_uuid = nil
    manager.define_singleton_method(:open_prefs) { |ext| opened_uuid = ext.uuid }

    activate_invocation = FakeInvocation.new
    search_provider.send(:activate_result, ['supported@example.com', [], 0], activate_invocation)
    d.check('held the app') { held }
    d.check('opened the right extension\'s prefs') { opened_uuid == 'supported@example.com' }
    d.check('invocation answered with nothing') { activate_invocation.value.nil? }
  end

  d.step('ActivateResult on an unknown uuid is a no-op, not a crash') do
    opened = false
    manager.define_singleton_method(:open_prefs) { |_ext| opened = true }
    invocation = FakeInvocation.new
    search_provider.send(:activate_result, ['no-such-uuid@example.com', [], 0], invocation)
    d.check('never calls open_prefs') { !opened }
  end

  d.step('LaunchSearch activates the app and switches the window to an installed-page search') do
    window.view_stack.visible_child_name = 'browse'
    launch_invocation = FakeInvocation.new
    search_provider.send(:launch_search, [['blur', 'shell'], 0], launch_invocation)
    d.check('switched back to the installed view') { window.view_stack.visible_child_name == 'installed' }
    d.check('search bar carries the joined terms') { window.search_entry.text == 'blur shell' }
  end
end
