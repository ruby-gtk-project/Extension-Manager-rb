# frozen_string_literal: true

# Drives the Installed view: builds the app, waits for the shell client to
# settle, then exercises search, selection mode and the dialogs.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require_relative '../.claude/skills/ruby-gtk-testing/scripts/gtk_driver'
require 'extension_manager'
require 'extension'
require 'types'
require 'utils'
require 'shell_versions'
require 'search_result'
require 'comment'
require 'rating'
require 'install_button'
require 'comment_tile'
require 'extension_error_dialog'
require 'shortcuts_dialog'
require 'confirm_dialogs'
require 'primary_menu'

app = ExtensionManager::Application.new

GtkDriver.drive(app, shots: 'tmp/shots') do |d, application|
  d.window { application.window }

  d.step('window is up') do
    d.check('window present') { application.window.visible? }
    d.check('stack has both pages') do
      !application.main_stack.get_child_by_name('app').nil? &&
        !application.main_stack.get_child_by_name('noshell').nil?
    end
    d.shot('01-start')
  end

  d.step('inject two extensions') do
    store = application.manager.extensions
    store.append(
      Extension.new('user@example.com').tap do |extension|
        extension.set_property('name', 'Alpha')
        extension.set_property('is-user', true)
        extension.set_property('state', Types::ExtensionState::ACTIVE)
        extension.set_property('enabled', true)
        extension.set_property('has-prefs', true)
      end,
    )
    store.append(
      Extension.new('system@example.com').tap do |extension|
        extension.set_property('name', 'Beta')
        extension.set_property('is-user', false)
        extension.set_property('state', Types::ExtensionState::ERROR)
        extension.set_property('error', 'TypeError: nope')
      end,
    )
    d.check('two in the store') { store.n_items == 2 }
  end

  d.step('groups bound') do
    page = application.installed_page
    d.check('one user row') { page.user_model.n_items == 1 }
    d.check('one system row') { page.system_model.n_items == 1 }
    d.check('user row built') { page.user_prefs_group.get_row(0).is_a?(ExtensionRow) }
    d.check('row title') { page.user_prefs_group.get_row(0).title == 'Alpha' }
    application.main_stack.visible_child_name = 'app'
  end

  d.step('list renders') do
    d.check('app page showing') { application.main_stack.visible_child_name == 'app' }
    d.check('window mapped') { application.window.mapped? }
    puts "      realized=#{application.window.realized?} size=#{application.window.width}x#{application.window.height}"
    d.shot('02-list')
  end

  d.step('search narrows') do
    page = application.installed_page
    page.search_mode_enabled = true
    page.search_query = 'alp'
    d.check('one result') { page.search_model.n_items == 1 }
    d.check('results page') { page.stack.visible_child_name == 'page_results' }
    page.search_query = 'zzz'
    d.check('no results page') { page.stack.visible_child_name == 'page_no_results' }
    page.search_mode_enabled = false
    page.search_query = ''
  end

  d.step('sort enabled first') do
    page = application.installed_page
    page.sort_enabled_first = true
    d.check('sorted model still has two') { page.sorted_model.n_items == 2 }
    d.check('active first') { page.sorted_model.get_item(0).name == 'Alpha' }
    page.sort_enabled_first = false
  end

  d.step('selection mode') do
    page = application.installed_page
    page.selection_mode = true
    d.check('system group hidden') { !page.system_prefs_group.visible? }
    row = page.user_prefs_group.get_row(0)
    d.check('row is selectable') { row.selection_mode? }
    row.select_check.active = true
    d.check('one selected') { page.n_selected == 1 }
    d.check('uninstall sensitive') { application.uninstall_button.sensitive? }
    d.check('selection title') { application.window_title.title == '1 Selected' }
    d.shot('03-selection')
  end

  d.step('leave selection mode') do
    page = application.installed_page
    page.selection_mode = false
    d.check('none selected') { page.n_selected.zero? }
    d.check('title restored') { application.window_title.title == 'Extension Manager' }
  end

  d.step('error dialog') do
    extension = application.manager.by_uuid('system@example.com')
    ExtensionErrorDialog.new(extension.name, extension.error, 'https://example.com').build.tap do |dialog|
      dialog.present(application.window)
      d.check('trace in buffer') { dialog.text_view.buffer.text == 'TypeError: nope' }
      d.check('report shown') { dialog.report_button.visible? }
    end
    d.shot('04-error-dialog')
  end

  d.step('shortcuts dialog') do
    ShortcutsDialog.new.build.tap do |dialog|
      dialog.present(application.window)
      d.check('titled') { dialog.title == 'Keyboard Shortcuts' }
    end
    d.shot('05-shortcuts')
  end

  d.step('confirm dialog') do
    answered = []
    ConfirmDialogs.remove_selected(application.window, 2) { answered << true }
    d.check('dialog built') { !answered.frozen? }
    d.shot('06-confirm')
  end

  d.step('small widgets') do
    rating = Rating.new(rating: 3).build
    d.check('three stars filled') do
      rating.stars.first.icon_name == Rating::FILLED_ICON_NAME &&
        rating.stars.last.icon_name == Rating::EMPTY_ICON_NAME
    end
    button = InstallButton.new.build
    d.check('install label') { button.label.label == 'Install…' }
    button.state = Types::InstallButtonState::UNSUPPORTED
    d.check('unsupported label') { button.label.label == 'Unsupported…' }
    tile = CommentTile.new(
      Comment.from_json(
        {
          'comment'              => 'Nice <b>one</b>',
          'rating'               => 4,
          'author'               => { 'username' => 'ada' },
          'date'                 => { 'timestamp' => '2024-01-02T03:04:05' },
          'is_extension_creator' => true,
        },
      ),
    ).build
    d.check('tile author') { tile.author_label.label == 'ada' }
    d.check('tile badge shown') { tile.author_badge.visible? }
  end

  d.step('formatters and models') do
    d.check('downloads') { Utils.format_downloads(1_234_567) == '1,234,567' }
    d.check('first line') { Utils.first_line("one\ntwo") == 'one' }
    d.check('author link') do
      Utils.format_author_link('A & B', 'ab') == '<a href="author">A &amp; B</a>'
    end
    d.check('no homepage') { !Utils.has_homepage?('') }
    d.check('html') { Utils.convert_html('<p>a<br><b>b</b>&amp;c</p>') == "a\n<b>b</b>&amp;c" }
    d.check('shell versions') do
      ShellVersions.from_json([{ 'major' => 45, 'minor' => -1, 'point' => -1 }]).supports?('45.2')
    end
    d.check('shell versions reject') do
      !ShellVersions.from_json([{ 'major' => 3, 'minor' => 38, 'point' => -1 }]).supports?('45')
    end
    d.check('search result creator') do
      SearchResult.from_json(
        { 'uuid' => 'x', 'creator' => { 'username' => 'ada', 'id' => 7 } },
      ).creator == 'ada'
    end
  end
end
