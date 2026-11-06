# frozen_string_literal: true

require 'adwaita'
require_relative 'author_page'
require_relative 'browse_page'
require_relative 'confirm_dialogs'
require_relative 'detail_view'
require_relative 'error_dialog'
require_relative 'extension_error_dialog'
require_relative 'installed_page'
require_relative 'primary_menu'
require_relative 'screenshot_view'
require_relative 'types'

# The application window.
#
# Ported from upstream's src/exm-window.blp and src/exm-window.c: a toast
# overlay over a stack of the app and the "GNOME Shell Unavailable" page; the
# app side being a navigation view whose main page is a toolbar view with the
# header bar, the installed search bar, the Installed/Browse view stack, the
# selection action bar and the view switcher bar.
#
# The header bar's title is upstream's crossfading stack: the view switcher
# while browsing, and the selection count while selecting. The narrow
# breakpoint drops that title and reveals the switcher bar instead, which is
# the same pair of setters upstream's Adw.Breakpoint carries.
#
# Every action upstream installs on the window class is installed here now
# bar win.show-upgrade-assistant, which still has no upgrade assistant to
# show: win.show-detail, win.show-author, win.show-main and win.show-screenshot
# push the detail view, the author page or the one shared screenshot view, and
# the three screenshot.zoom-* actions delegate to whichever view is showing.
#
# The keyboard bindings that survive that are upstream's too: Ctrl+F opens the
# installed search or focuses the browse entry depending on what is showing,
# and Alt+1 and Alt+2 switch the view stack.
class Window < Adwaita::ApplicationWindow
  TITLE = 'Extension Manager'
  SEARCH_TOOLTIP = 'Search Installed Extensions'
  SEARCH_PLACEHOLDER = 'Search for installed extensions'
  MENU_TOOLTIP = 'Main Menu'
  NOSHELL_TITLE = 'GNOME Shell Unavailable'
  NOSHELL_DESCRIPTION = 'Log in to a GNOME session to manage extensions'
  DISCOVER_URI = 'https://www.gnome.org'
  ERROR_TOAST = 'An Error Occurred'
  ERROR_TOAST_BUTTON = '_Details'
  SELECT_TITLE = 'Select Extensions'
  INSTALLED_TITLE = '_Installed'
  BROWSE_TITLE = '_Browse'
  NARROW_CONDITION = 'max-width: 400sp'

  attr_reader :manager, :settings

  def initialize(app, manager, settings, version:)
    super(app)
    self.title = TITLE
    self.width_request = 360
    self.height_request = 294
    @manager = manager
    @settings = settings
    @version = version
  end

  def build
    tap do |win|
      win.content = toast_overlay
      win.add_breakpoint(narrow_breakpoint)
      win.insert_action_group('ext', extension_actions)
      install_window_actions
      win.add_controller(shortcuts)
      settings.apply_to(win)

      toast_overlay.child = main_stack

      main_stack.tap do |stack|
        stack.add_named(navigation_view, 'app')
        stack.add_named(noshell_view, 'noshell')
      end

      navigation_view.add(main_page)
      detail_view.build
      author_page.build
      screenshot_view.build

      app_view.tap do |view|
        view.add_top_bar(header_bar)
        view.add_top_bar(search_bar)
        view.content = view_stack
        view.add_bottom_bar(selection_bar)
        view.add_bottom_bar(switcher_bar)
      end

      header_bar.tap do |bar|
        bar.title_widget = title_stack
        bar.pack_start(cancel_selection_button)
        bar.pack_start(search_button)
        bar.pack_end(menu_button)
      end

      title_stack.tap do |stack|
        stack.add_named(view_switcher, 'switcher')
        stack.add_named(window_title, 'selection')
      end

      view_stack.tap do |stack|
        installed_stack_page
        browse_stack_page
        stack.visible_child_name = 'installed'
      end

      search_bar.tap do |bar|
        bar.child = search_entry
        bar.key_capture_widget = win
      end

      selection_bar.pack_end(uninstall_button)

      noshell_view.tap do |view|
        view.add_top_bar(noshell_header_bar)
        view.content = noshell_page
      end

      noshell_header_bar.title_widget = noshell_title
      noshell_page.child = discover_button

      connect_signals
    end
  end

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

  def main_stack
    @main_stack ||= Gtk::Stack.new.tap { |stack| stack.transition_type = :crossfade }
  end

  def navigation_view = @navigation_view ||= Adwaita::NavigationView.new

  # NavigationPage takes its child positionally and cannot be given one
  # afterwards, so the toolbar view is built first.
  def main_page
    @main_page ||= Adwaita::NavigationPage.new(app_view, TITLE).tap do |page|
      page.can_pop = false
      page.tag = 'main'
    end
  end

  def app_view = @app_view ||= Adwaita::ToolbarView.new
  def noshell_view = @noshell_view ||= Adwaita::ToolbarView.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.show_back_button = false }
  end

  def noshell_header_bar = @noshell_header_bar ||= Adwaita::HeaderBar.new

  def title_stack
    @title_stack ||= Gtk::Stack.new.tap { |stack| stack.transition_type = :crossfade }
  end

  def view_switcher
    @view_switcher ||= Adwaita::ViewSwitcher.new.tap do |switcher|
      switcher.policy = :wide
      switcher.stack = view_stack
    end
  end

  def window_title = @window_title ||= Adwaita::WindowTitle.new(TITLE, '')
  def noshell_title = @noshell_title ||= Adwaita::WindowTitle.new(TITLE, '')

  def view_stack
    @view_stack ||= Adwaita::ViewStack.new.tap { |stack| stack.enable_transitions = true }
  end

  # Translators: Navigation
  def installed_stack_page
    @installed_stack_page ||= view_stack.add_titled_with_icon(
      installed_page.build,
      'installed',
      INSTALLED_TITLE,
      'puzzle-piece-symbolic',
    ).tap { |page| page.use_underline = true }
  end

  # Translators: Navigation
  def browse_stack_page
    @browse_stack_page ||= view_stack.add_titled_with_icon(
      browse_page.build,
      'browse',
      BROWSE_TITLE,
      'globe-symbolic',
    ).tap { |page| page.use_underline = true }
  end

  def switcher_bar
    @switcher_bar ||= Adwaita::ViewSwitcherBar.new.tap { |bar| bar.stack = view_stack }
  end

  def installed_page = @installed_page ||= InstalledPage.new(manager, settings)

  def browse_page
    @browse_page ||= BrowsePage.new(manager, on_show_detail: ->(uuid) { show_detail(uuid) })
  end

  def detail_view
    @detail_view ||= DetailView.new.tap { |view| view.manager = manager }
  end

  def author_page
    @author_page ||= AuthorPage.new.tap { |page| page.manager = manager }
  end

  def screenshot_view
    @screenshot_view ||= ScreenshotView.new.tap do |view|
      view.on_zoom_changed do |zoom_level|
        action_set_enabled('screenshot.zoom-in', zoom_level < view.zoom_level_max)
        action_set_enabled('screenshot.zoom-out', zoom_level > view.zoom_level_min)
      end
    end
  end

  def cancel_selection_button
    @cancel_selection_button ||= Gtk::Button.new.tap do |button|
      button.label = 'Cancel'
      button.visible = false
    end
  end

  def search_button
    @search_button ||= Gtk::ToggleButton.new.tap do |button|
      button.icon_name = 'edit-find-symbolic'
      # Translators: Tooltip of the search icon in the header bar
      button.tooltip_text = SEARCH_TOOLTIP
      button.receives_default = true
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'open-menu-symbolic'
      button.menu_model = PrimaryMenu.new.build
      button.primary = true
      button.tooltip_text = MENU_TOOLTIP
    end
  end

  def search_bar
    @search_bar ||= Gtk::SearchBar.new.tap { |bar| bar.visible = true }
  end

  def search_entry
    @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
      entry.placeholder_text = SEARCH_PLACEHOLDER
      entry.max_width_chars = 35
    end
  end

  def selection_bar
    @selection_bar ||= Gtk::ActionBar.new.tap { |bar| bar.revealed = false }
  end

  def uninstall_button
    @uninstall_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('destructive-action')
      button.label = 'Uninstall…'
      button.sensitive = false
    end
  end

  def noshell_page
    @noshell_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'puzzle-piece-symbolic'
      page.title = NOSHELL_TITLE
      page.description = NOSHELL_DESCRIPTION
    end
  end

  def discover_button
    @discover_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('pill')
      button.add_css_class('suggested-action')
      button.halign = :center
      button.label = '_Discover GNOME'
      button.use_underline = true
      button.action_name = 'win.discover-gnome'
      button.tooltip_text = DISCOVER_URI
    end
  end

  # Upstream's breakpoint: the header bar loses its title so the window is
  # not cramped, and the switcher moves to the bottom bar.
  def narrow_breakpoint
    @narrow_breakpoint ||= Adwaita::Breakpoint.new(
      Adwaita::BreakpointCondition.parse(NARROW_CONDITION),
    ).tap do |breakpoint|
      breakpoint.signal_connect('apply') { apply_narrow(true) }
      breakpoint.signal_connect('unapply') { apply_narrow(false) }
    end
  end

  # The "ext" group upstream installs on the window class.
  def extension_actions
    @extension_actions ||= Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(install_action)
      group.add_action(remove_action)
      group.add_action(open_prefs_action)
      group.add_action(show_extension_error_action)
    end
  end

  def install_action
    @install_action ||= Gio::SimpleAction.new('install', GLib::VariantType.new('(sb)')).tap do |action|
      action.signal_connect('activate') { |_action, parameter| on_install(parameter) }
    end
  end

  def remove_action
    @remove_action ||= string_action('remove') { |uuid| on_remove(uuid) }
  end

  def open_prefs_action
    @open_prefs_action ||= string_action('open-prefs') { |uuid| on_open_prefs(uuid) }
  end

  def show_extension_error_action
    @show_extension_error_action ||= string_action('show-error') { |uuid| on_show_extension_error(uuid) }
  end

  def show_page_action
    @show_page_action ||= string_action('show-page') { |name| view_stack.visible_child_name = name }
  end

  def show_error_action
    @show_error_action ||= string_action('show-error') { |text| on_show_error(text) }
  end

  def show_error_dialog_action
    @show_error_dialog_action ||= string_action('show-error-dialog') { |text| on_show_error_dialog(text) }
  end

  def search_online_action
    @search_online_action ||= Gio::SimpleAction.new('search-online').tap do |action|
      action.signal_connect('activate') { on_search_online }
    end
  end

  def search_installed_action
    @search_installed_action ||= string_action('search-installed') { |query| on_search_installed(query) }
  end

  def discover_gnome_action
    @discover_gnome_action ||= Gio::SimpleAction.new('discover-gnome').tap do |action|
      action.signal_connect('activate') { Gtk::UriLauncher.new(DISCOVER_URI).launch(self, nil) }
    end
  end

  def show_detail_action
    @show_detail_action ||= string_action('show-detail') { |uuid| show_detail(uuid) }
  end

  # "(uss)": the creator id, their username and their display name, exactly
  # as upstream's win.show-author parameter is typed.
  def show_author_action
    @show_author_action ||= Gio::SimpleAction.new('show-author', GLib::VariantType.new('(uss)')).tap do |action|
      action.signal_connect('activate') { |_action, parameter| show_author(parameter.to_a) }
    end
  end

  def show_main_action
    @show_main_action ||= Gio::SimpleAction.new('show-main').tap do |action|
      action.signal_connect('activate') { navigation_view.pop_to_page(main_page) }
    end
  end

  def show_screenshot_action
    @show_screenshot_action ||= Gio::SimpleAction.new('show-screenshot').tap do |action|
      action.signal_connect('activate') { show_screenshot }
    end
  end

  # The "screenshot" group every screenshot.zoom-* button and Ctrl+Plus/
  # Minus/0 points at, delegating to whichever ScreenshotView the window
  # shares across every detail view and the screenshot view itself.
  def screenshot_actions
    @screenshot_actions ||= Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(zoom_action('zoom-in') { screenshot_view.zoom_in })
      group.add_action(zoom_action('zoom-out') { screenshot_view.zoom_out })
      group.add_action(zoom_action('zoom-reset') { screenshot_view.zoom_reset })
    end
  end

  def shortcuts
    @shortcuts ||= Gtk::ShortcutController.new.tap do |controller|
      controller.scope = :managed
      controller.add_shortcut(search_shortcut)
      controller.add_shortcut(show_page_shortcut(Gdk::Keyval::KEY_1, 'installed'))
      controller.add_shortcut(show_page_shortcut(Gdk::Keyval::KEY_2, 'browse'))
      controller.add_shortcut(named_action_shortcut(Gdk::Keyval::KEY_plus, :control_mask, 'screenshot.zoom-in'))
      controller.add_shortcut(named_action_shortcut(Gdk::Keyval::KEY_minus, :control_mask, 'screenshot.zoom-out'))
      controller.add_shortcut(named_action_shortcut(Gdk::Keyval::KEY_0, :control_mask, 'screenshot.zoom-reset'))
    end
  end

  # Ctrl+F means "open the installed search" on the Installed page and "focus
  # the browse entry" on the Browse one, and nothing anywhere else.
  def search_shortcut
    @search_shortcut ||= Gtk::Shortcut.new(
      Gtk::KeyvalTrigger.new(Gdk::Keyval::KEY_f, :control_mask),
      Gtk::CallbackAction.new { on_search_open },
    )
  end

  private

    # Upstream writes the two narrow-layout changes as breakpoint setters.
    # Adwaita::Breakpoint#add_setter cannot be given a null value from Ruby —
    # it refuses anything that is not a GValue — and clearing the header bar's
    # title is exactly such a setter, so both changes are made from the
    # breakpoint's own apply and unapply signals instead.
    def apply_narrow(narrow)
      if narrow
        header_bar.title_widget = nil
      else
        header_bar.title_widget = title_stack
      end

      switcher_bar.reveal = narrow
    end

    # The Ruby bindings hand the activate handler the action's target already
    # converted — a String for an "s" action, an Array for the "(sb)" one —
    # rather than the GLib::Variant the C API passes.
    def string_action(name, &block)
      Gio::SimpleAction.new(name, GLib::VariantType.new('s')).tap do |action|
        action.signal_connect('activate') { |_action, parameter| block.call(parameter.to_s) }
      end
    end

    def show_page_shortcut(keyval, target)
      Gtk::Shortcut.new(
        Gtk::KeyvalTrigger.new(keyval, :alt_mask),
        Gtk::NamedAction.new('win.show-page'),
      ).tap { |shortcut| shortcut.arguments = GLib::Variant.new(target) }
    end

    def named_action_shortcut(keyval, modifier, action_name)
      Gtk::Shortcut.new(
        Gtk::KeyvalTrigger.new(keyval, modifier),
        Gtk::NamedAction.new(action_name),
      )
    end

    def zoom_action(name, &block)
      Gio::SimpleAction.new(name).tap { |action| action.signal_connect('activate') { block.call } }
    end

    def install_window_actions
      insert_action_group('screenshot', screenshot_actions)
      add_action(show_page_action)
      add_action(show_error_action)
      add_action(show_error_dialog_action)
      add_action(search_online_action)
      add_action(search_installed_action)
      add_action(discover_gnome_action)
      add_action(show_detail_action)
      add_action(show_author_action)
      add_action(show_main_action)
      add_action(show_screenshot_action)
    end

    def connect_signals
      search_button.signal_connect('toggled') { on_search_toggled }
      search_bar.signal_connect('notify::search-mode-enabled') { on_search_mode_changed }
      search_entry.signal_connect('search-changed') { installed_page.search_query = search_entry.text }
      cancel_selection_button.signal_connect('clicked') { installed_page.selection_mode = false }
      uninstall_button.signal_connect('clicked') { on_uninstall_selected }
      view_stack.signal_connect('notify::visible-child') { on_visible_page_changed }
      installed_page.on_selection_changed { |count| on_selection_changed(count) }
      manager.on_error { |message| activate_action('show-error', GLib::Variant.new(message.to_s)) }
      manager.on_supported_changed { |supported| sync_visible_page(supported) }
      manager.on_updates_available { |count| installed_stack_page.badge_number = count }
      signal_connect('close-request') do
        settings.store_from(self)
        false
      end
      sync_visible_page(manager.supported?)
      on_visible_page_changed
    end

    def on_search_toggled
      search_bar.search_mode_enabled = search_button.active?
    end

    def on_search_mode_changed
      search_button.active = search_bar.search_mode_enabled?
      installed_page.search_mode_enabled = search_bar.search_mode_enabled?
    end

    # Upstream's selection_mode_page_name and selection_title_text closures.
    def on_selection_changed(count)
      selection_bar.revealed = installed_page.selection_mode?
      cancel_selection_button.visible = installed_page.selection_mode?
      uninstall_button.sensitive = count.positive?

      if installed_page.selection_mode?
        title_stack.visible_child_name = 'selection'
      else
        title_stack.visible_child_name = 'switcher'
      end

      window_title.title = selection_title(count)
    end

    # Translators: "%u" = number of selected extensions; shown as the header
    # bar title
    def selection_title(count)
      if count.zero?
        SELECT_TITLE
      else
        "#{count} Selected"
      end
    end

    def on_uninstall_selected
      ConfirmDialogs.remove_selected(self, installed_page.n_selected) do
        installed_page.uninstall_selected
        installed_page.selection_mode = false
      end
    end

    # Leaving the Installed page leaves selection mode with it, the update
    # badge asks for attention from anywhere else, and the installed search
    # bar and its button only belong to that page.
    def on_visible_page_changed
      installed?.then do |installed|
        unless installed
          installed_page.selection_mode = false
        end

        installed_stack_page.needs_attention = !installed && installed_stack_page.badge_number.positive?
        search_bar.visible = installed
        search_button.visible = installed
      end
    end

    def installed? = view_stack.visible_child_name == 'installed'

    def sync_visible_page(supported)
      if supported
        main_stack.visible_child_name = 'app'
      else
        main_stack.visible_child_name = 'noshell'
      end
    end

    # Upstream's search_open_cb: the binding only claims the key press on the
    # two pages that have a search to open.
    def on_search_open
      if installed? && navigation_view.visible_page == main_page
        search_button.active = !search_button.active?
        true
      elsif view_stack.visible_child_name == 'browse'
        browse_page.focus_entry
        true
      else
        false
      end
    end

    # Hands the installed search text to the Browse page, which is what the
    # "Search Online" buttons on the two empty states do.
    def on_search_online
      view_stack.visible_child_name = 'browse'
      browse_page.search(search_entry.text)
      search_button.active = false
    end

    def on_search_installed(query)
      navigation_view.pop_to_page(main_page)
      view_stack.visible_child_name = 'installed'
      search_entry.text = query
      search_button.active = true
    end

    # An extension no published release supports is installed only after the
    # warning; backing out puts the button back in its warning state, which is
    # what upstream reports from the dialog's "back" response.
    def on_install(parameter)
      Array(parameter).then do |uuid, warn|
        if warn
          confirm_unsupported(uuid.to_s)
        else
          manager.install(uuid.to_s)
        end
      end
    end

    def confirm_unsupported(uuid)
      ConfirmDialogs.unsupported(
        self,
        on_decline: -> { manager.report_install_status(Types::InstallButtonState::UNSUPPORTED) },
      ) { manager.install(uuid, failure_state: Types::InstallButtonState::UNSUPPORTED) }
    end

    def on_remove(uuid)
      manager.by_uuid(uuid).then do |extension|
        if extension
          ConfirmDialogs.remove(self) { manager.remove_extension(extension) }
        end
      end
    end

    def on_open_prefs(uuid)
      manager.by_uuid(uuid).then { |extension| if extension then manager.open_prefs(extension) end }
    end

    def on_show_extension_error(uuid)
      manager.by_uuid(uuid).then do |extension|
        if extension && !extension.error.to_s.empty?
          ExtensionErrorDialog.new(
            extension.name,
            extension.error,
            homepage_of(extension),
          ).build.present(self)
        end
      end
    end

    def homepage_of(extension)
      if extension.url.to_s.empty?
        nil
      else
        extension.url
      end
    end

    # Upstream's show_view, split by action: a fresh push every time, with
    # the uuid-keyed load starting right after, exactly as
    # exm_detail_view_load_for_uuid is called right after the push.
    def show_detail(uuid)
      navigation_view.push(detail_view)
      detail_view.load_for_uuid(uuid)
    end

    def show_author(parameter)
      creator_id, username, display_name = parameter
      navigation_view.push(author_page)
      author_page.load(creator_id.to_i, username.to_s, display_name.to_s)
    end

    # Upstream's win.show-screenshot: the shared screenshot view borrows
    # whatever the currently visible detail view resolved, and titles itself
    # from that page, before being pushed on top of it.
    def show_screenshot
      visible = navigation_view.visible_page
      if visible.is_a?(DetailView)
        screenshot_view.title = visible.title.to_s
        screenshot_view.screenshot = visible.screenshot
      end

      navigation_view.push(screenshot_view)
    end

    # The toast carries the error text to the reporter as its action target.
    def on_show_error(text)
      Adwaita::Toast.new(ERROR_TOAST).tap do |toast|
        toast.button_label = ERROR_TOAST_BUTTON
        toast.action_name = 'win.show-error-dialog'
        toast.action_target_value = GLib::Variant.new(text)
        toast_overlay.add_toast(toast)
      end
    end

    def on_show_error_dialog(text)
      ErrorDialog.new(text, version: @version).build.tap do |dialog|
        dialog.modal = true
        dialog.transient_for = self
        dialog.present
      end
    end
end
