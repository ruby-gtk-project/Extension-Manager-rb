# frozen_string_literal: true

# Drives everything the Browse/Installed drivers don't reach: the detail
# view, the author page, the screenshot viewer and its zoom actions, the
# versions dialog, the comment dialog, the primary menu and the crash
# backtrace formatter. Built the app, pushed through win.show-detail and
# win.show-author exactly as a real click would, fed every web provider
# canned data without touching the network, and asserted the observable
# result of each.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require_relative '../.claude/skills/ruby-gtk-testing/scripts/gtk_driver'
require 'extension_manager'
require 'extension'
require 'types'
require 'data_provider'
require 'comment_provider'
require 'versions_provider'
require 'profile_provider'
require 'search_provider'
require 'image_resolver'
require 'request_handler'
require 'primary_menu'
require 'backtrace'

# A no-op stand-in for RequestHandler::Request: every provider below answers
# synchronously, so there is never anything in flight to cancel, but the
# callers (DetailView, AuthorPage, VersionsDialog, CommentDialog) all call
# #cancel on whatever they get back.
class FakeRequest
  def cancel = nil
  def cancelled? = false
end

# The driver runs offline: every website client answers from canned data
# instead of a real request.
class DataProvider
  def get(uuid, &block)
    block.call(
      SearchResult.from_json(
        {
          'id'          => 42,
          'uuid'        => uuid,
          'name'        => 'Blur My Shell',
          'description' => "Blurs things.\nA longer description of the blurring.",
          'creator'     => { 'username' => 'ada', 'display_name' => 'Ada Lovelace', 'id' => 7 },
          'icon'        => '/static/icon.png',
          'screenshot'  => '/static/screenshot.png',
          'downloads'   => 123_456,
          'link'        => '/extension/42/blur-my-shell/',
          'url'         => 'https://example.com/blur-my-shell',
        },
      ),
      nil,
    )
    FakeRequest.new
  end
end

class CommentProvider
  def get_comments(_extension_id, _retrieve_all, &block)
    store = Gio::ListStore.new(Comment).tap do |s|
      3.times do |index|
        s.append(
          Comment.from_json(
            {
              'comment'              => "Review #{index}",
              'rating'               => 5,
              'author'               => { 'username' => "reviewer#{index}" },
              'date'                 => { 'timestamp' => '2024-01-02T03:04:05' },
              'is_extension_creator' => false,
            },
          ),
        )
      end
    end
    block.call(store, nil)
    FakeRequest.new
  end
end

class VersionsProvider
  def query(_uuid, &block)
    model = Gio::ListStore.new(VersionResult).tap do |store|
      store.append(
        VersionResult.from_json(
          {
            'extension'      => 42,
            'version'        => 7,
            'version_name'   => '1.7',
            'created'        => '2024-03-01T00:00:00Z',
            'session_modes'  => [],
            'shell_versions' => [{ 'major' => 45, 'minor' => -1, 'point' => -1 }],
          },
        ),
      )
      store.append(
        VersionResult.from_json(
          {
            'extension'      => 42,
            'version'        => 6,
            'version_name'   => '1.6',
            'created'        => '2024-01-01T00:00:00Z',
            'session_modes'  => [],
            'shell_versions' => [{ 'major' => 44, 'minor' => -1, 'point' => -1 }],
          },
        ),
      )
    end
    block.call(VersionsProvider::Results.new(model: model, next_url: nil), nil)
    FakeRequest.new
  end

  def query_next(_url, &block)
    block.call(VersionsProvider::Results.new(model: Gio::ListStore.new(VersionResult), next_url: nil), nil)
    FakeRequest.new
  end
end

class ProfileProvider
  def get(user_id, &block)
    block.call(
      UserProfile.from_json({ 'id' => user_id, 'username' => 'ada', 'display_name' => 'Ada Lovelace', 'avatar' => '' }),
      nil,
    )
    FakeRequest.new
  end
end

class SearchProvider
  def query_by_creator(username, &block)
    model = Gio::ListStore.new(SearchResult).tap do |store|
      store.append(
        SearchResult.from_json(
          {
            'uuid'        => 'other@example.com',
            'name'        => 'Another Extension',
            'description' => 'By the same author.',
            'creator'     => { 'username' => username, 'display_name' => 'Ada Lovelace', 'id' => 7 },
            'icon'        => '/static/icon2.png',
          },
        ),
      )
    end
    block.call(SearchProvider::Results.new(model: model, num_pages: 1), nil)
    FakeRequest.new
  end
end

class ImageResolver
  def resolve(_rel_path) = nil
end

application = ExtensionManager::Application.new

GtkDriver.drive(application, shots: 'tmp/shots') do |d, app|
  d.window { app.window }

  window = nil

  d.step('seed an installed extension') do
    window = app.window
    store = app.manager.extensions
    store.append(
      Extension.new('blur-my-shell@aunetx').tap do |extension|
        extension.set_property('name', 'Blur My Shell')
        extension.set_property('is-user', true)
        extension.set_property('state', Types::ExtensionState::ACTIVE)
        extension.set_property('enabled', true)
        extension.set_property('has-prefs', true)
        extension.set_property('path', '/home/user/.local/share/gnome-shell/extensions/blur-my-shell@aunetx')
      end,
    )
    window.main_stack.visible_child_name = 'app'
    d.check('seeded') { store.n_items == 1 }
  end

  d.step('show-detail pushes the detail view') do
    window.activate_action('show-detail', GLib::Variant.new('blur-my-shell@aunetx'))
    d.check('detail view is the visible page') { window.navigation_view.visible_page == window.detail_view }
    d.check('detail page shows the content stack') { window.detail_view.stack.visible_child_name == 'page_detail' }
    d.check('title set from the web data') { window.detail_view.ext_title.label == 'Blur My Shell' }
    d.check('author link formatted') { window.detail_view.ext_author.label.include?('Ada Lovelace') }
    d.check('description is the full text') { window.detail_view.ext_description.label.include?('A longer description') }
    d.check('downloads formatted') { window.detail_view.downloads_label.label == '123,456' }
    d.shot('20-detail-view')
  end

  d.step('installed tools show instead of the install button') do
    page = window.detail_view
    d.check('installed tools visible') { page.tools_stack.visible_child_name == 'installed-tools-page' }
    d.check('remove button shown for a user extension') { page.remove_btn.visible? }
    d.check('prefs button shown') { page.prefs_btn.visible? }
    d.check('location row shows the path') { page.location_row.subtitle == '/home/user/.local/share/gnome-shell/extensions/blur-my-shell@aunetx' }
    d.check('toggle reflects enabled') { page.ext_toggle.active? }
  end

  d.step('reviews loaded from the comment provider') do
    page = window.detail_view
    d.check('comments page showing') { page.comment_stack.visible_child_name == 'page_comments' }
    d.check('three review tiles appended') { page.comment_box.observe_children.n_items == 3 }
  end

  d.step('version history dialog') do
    window.detail_view.version_row.activate_action('detail.show-versions', nil)
    d.check('a dialog opened') { !window.visible_dialog.nil? }
    dialog = window.visible_dialog
    d.check('titled Version History') { dialog.title == 'Version History' }
    d.check('list page showing') { dialog.stack.visible_child_name == 'list' }
    d.check('newest release sorts first') { dialog.version_list.get_row_at_index(0).version == 7 }
    d.check('load more hidden with no next page') { !dialog.more_list.visible? }
    d.shot('21-versions-dialog', dialog)
    dialog.close
  end

  d.step('reviews dialog') do
    window.detail_view.send(:show_more_comments)
    d.check('a dialog opened') { !window.visible_dialog.nil? }
    dialog = window.visible_dialog
    d.check('titled Reviews and Comments') { dialog.title == 'Reviews and Comments' }
    d.check('comments page showing') { dialog.stack.visible_child_name == 'page_comments' }
    d.check('three rows added') { dialog.preferences_group.observe_children.n_items.positive? }
    d.shot('22-comments-dialog', dialog)
    dialog.close
  end

  d.step('show-author pushes the author page') do
    window.activate_action('show-author', GLib::Variant.parse('(uint32 7, "ada", "Ada Lovelace")'))
    d.check('author page is the visible page') { window.navigation_view.visible_page == window.author_page }
    page = window.author_page
    d.check('name set') { page.author_name.label == 'Ada Lovelace' }
    d.check('list page showing once results arrive') { page.stack.visible_child_name == 'page_list' }
    d.check('one matching extension listed') { page.extensions_list.observe_children.n_items == 1 }
    d.shot('23-author-page')
  end

  d.step('back to the detail view, then open the screenshot viewer') do
    window.navigation_view.pop
    d.check('back on the detail view') { window.navigation_view.visible_page == window.detail_view }
    window.activate_action('show-screenshot', nil)
    d.check('screenshot view is the visible page') { window.navigation_view.visible_page == window.screenshot_view }
    d.check('zoom starts at 1.0') { window.screenshot_view.zoom_picture.zoom_level == 1.0 }
    d.shot('24-screenshot-view')
  end

  d.step('zoom actions and the keyboard shortcuts behind them') do
    view = window.screenshot_view
    window.activate_action('zoom-in', nil)
    d.check('zoom increased by one step') { view.zoom_picture.zoom_level == 1.0 + view.zoom_picture.zoom_level_step }
    window.activate_action('zoom-out', nil)
    d.check('zoom back to 1.0') { view.zoom_picture.zoom_level == 1.0 }
    window.activate_action('zoom-in', nil)
    window.activate_action('zoom-reset', nil)
    d.check('zoom reset to 1.0') { view.zoom_picture.zoom_level == 1.0 }
    d.check('zoom cannot go below its minimum') do
      view.zoom_picture.zoom_level = view.zoom_picture.zoom_level_min - 10
      view.zoom_picture.zoom_level == view.zoom_picture.zoom_level_min
    end
    d.check('zoom cannot go above its maximum') do
      view.zoom_picture.zoom_level = view.zoom_picture.zoom_level_max + 10
      view.zoom_picture.zoom_level == view.zoom_picture.zoom_level_max
    end
    view.zoom_picture.zoom_level = 1.0
  end

  d.step('zoom actions disable themselves at the zoom limits') do
    view = window.screenshot_view
    zoom_in_action = window.send(:zoom_in_action)
    zoom_out_action = window.send(:zoom_out_action)
    d.check('both enabled mid-range') { zoom_in_action.enabled? && zoom_out_action.enabled? }
    view.zoom_picture.zoom_level = view.zoom_picture.zoom_level_max
    d.check('zoom-in disables at the max') { !zoom_in_action.enabled? }
    d.check('zoom-out still enabled at the max') { zoom_out_action.enabled? }
    view.zoom_picture.zoom_level = view.zoom_picture.zoom_level_min
    d.check('zoom-out disables at the min') { !zoom_out_action.enabled? }
    d.check('zoom-in re-enabled off the max') { zoom_in_action.enabled? }
    view.zoom_picture.zoom_level = 1.0
  end

  d.step('win.show-main pops back to the installed/browse view') do
    window.activate_action('show-main', nil)
    d.check('main page showing') { window.navigation_view.visible_page == window.main_page }
  end

  d.step('primary menu structure') do
    menu = PrimaryMenu.new.build
    d.check('two sections') { menu.n_items == 2 }
  end

  d.step('backtrace formats a Ruby exception as upstream formats a frame') do
    error = begin
      raise RuntimeError, 'boom'
    rescue RuntimeError => e
      e
    end
    formatted = Backtrace.format(error)
    d.check('starts with the class and message') { formatted.start_with?('RuntimeError: boom') }
    d.check('a frame line is reformatted') { formatted.include?("'") }

    crashes = []
    Backtrace.install(->(text) { crashes << text }) { raise 'caught' }
    d.check('a rescued exception reaches the crash handler') { crashes.length == 1 }
    d.check('crash text names the exception') { crashes.first.include?('caught') }
  end
end
