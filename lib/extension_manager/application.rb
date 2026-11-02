# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative '../confirm_dialogs'
require_relative '../extension_error_dialog'
require_relative '../installed_page'
require_relative '../manager'
require_relative '../primary_menu'
require_relative '../settings'
require_relative '../shortcuts_dialog'

module ExtensionManager
  # The application.
  #
  # Ported from upstream's src/exm-application.c: it owns the manager every
  # window shares, installs the app.quit, app.about, app.logout and
  # app.sort-enabled-first actions, binds <primary>q and <primary>w, and binds
  # the window's geometry to the settings.
  #
  # app.shortcuts is installed here too. Upstream gets it from AdwApplication,
  # which finds src/exm-shortcuts-dialog.blp in the resource bundle on its own;
  # the Ruby bindings cannot use Adwaita::Application, so the action presents
  # ShortcutsDialog itself.
  #
  # The window this builds hosts the Installed view, the search bar, the
  # selection action bar and the "GNOME Shell Unavailable" page. The Browse,
  # Detail, Author and Screenshot views are not ported yet, so the actions
  # that would reach them are not installed and the buttons pointing at them
  # stay insensitive.
  class Application
    APP_ID = 'com.mattjakeman.ExtensionManager'
    TITLE = 'Extension Manager'
    STYLESHEET = File.expand_path('../style.css', __dir__)
    SESSION_MANAGER = 'org.gnome.SessionManager'
    SESSION_MANAGER_PATH = '/org/gnome/SessionManager'

    SEARCH_TOOLTIP = 'Search Installed Extensions'
    SEARCH_PLACEHOLDER = 'Search for installed extensions'
    MENU_TOOLTIP = 'Main Menu'
    NOSHELL_TITLE = 'GNOME Shell Unavailable'
    NOSHELL_DESCRIPTION = 'Log in to a GNOME session to manage extensions'
    DISCOVER_URI = 'https://www.gnome.org'

    ABOUT_COMMENTS = 'Browse, install, and manage GNOME Shell Extensions.'
    ABOUT_COPYRIGHT = '© 2022-2025 Matthew Jakeman'
    ABOUT_DEVELOPERS = ['Matthew Jakeman', 'Óscar Fernández Díaz'].freeze

    # The gem's version file declares a module named Extension, which is also
    # the name of the extension model, so it is loaded into an anonymous module
    # the way the gemspec loads it rather than required into this one.
    VERSION_FILE = File.expand_path('../extension/manager/rb/version.rb', __dir__)

    def self.version
      Module.new.tap { |mod| Kernel.load(VERSION_FILE, mod) }::Extension::Manager::Rb::VERSION
    end

    def build
      app.tap do
        app.signal_connect('activate') do
          install_stylesheet

          window.tap do |win|
            win.content = toast_overlay
            win.add_action(discover_gnome_action)
            win.insert_action_group('ext', extension_actions)
            settings.apply_to(win)
          end

          toast_overlay.child = main_stack

          main_stack.tap do |stack|
            stack.add_named(app_view, 'app')
            stack.add_named(noshell_view, 'noshell')
          end

          app_view.tap do |view|
            view.add_top_bar(header_bar)
            view.add_top_bar(search_bar)
            view.content = installed_page.build
            view.add_bottom_bar(selection_bar)
          end

          header_bar.tap do |bar|
            bar.title_widget = window_title
            bar.pack_start(cancel_selection_button)
            bar.pack_start(search_button)
            bar.pack_end(menu_button)
          end

          noshell_view.tap do |view|
            view.add_top_bar(noshell_header_bar)
            view.content = noshell_page
          end

          noshell_header_bar.title_widget = noshell_title
          noshell_page.child = discover_button

          search_bar.tap do |bar|
            bar.child = search_entry
            bar.key_capture_widget = window
          end

          selection_bar.pack_end(uninstall_button)

          connect_signals
          manager.connect

          window.present
        end

        install_app_actions
        install_accels
      end
    end

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the window and its contents are Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    def manager = @manager ||= Manager.new

    def settings = @settings ||= Settings.new

    def window
      @window ||= Adwaita::ApplicationWindow.new(app).tap do |win|
        win.title = TITLE
        win.width_request = 360
        win.height_request = 294
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    def main_stack
      @main_stack ||= Gtk::Stack.new.tap { |stack| stack.transition_type = :crossfade }
    end

    def app_view = @app_view ||= Adwaita::ToolbarView.new
    def noshell_view = @noshell_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.show_back_button = false }
    end

    def noshell_header_bar = @noshell_header_bar ||= Adwaita::HeaderBar.new

    def window_title = @window_title ||= Adwaita::WindowTitle.new(TITLE, '')
    def noshell_title = @noshell_title ||= Adwaita::WindowTitle.new(TITLE, '')

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

    def installed_page = @installed_page ||= InstalledPage.new(manager, settings)

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

    def quit_action
      @quit_action ||= Gio::SimpleAction.new('quit').tap do |action|
        action.signal_connect('activate') { app.quit }
      end
    end

    def about_action
      @about_action ||= Gio::SimpleAction.new('about').tap do |action|
        action.signal_connect('activate') { show_about }
      end
    end

    def logout_action
      @logout_action ||= Gio::SimpleAction.new('logout').tap do |action|
        action.signal_connect('activate') { request_logout }
      end
    end

    def shortcuts_action
      @shortcuts_action ||= Gio::SimpleAction.new('shortcuts').tap do |action|
        action.signal_connect('activate') { ShortcutsDialog.new.build.present(window) }
      end
    end

    # Upstream creates this one with g_settings_create_action, so the menu item
    # shows a check and the installed page follows the key. The stateful action
    # does the same here, writing the new value back to the settings.
    def sort_enabled_first_action
      @sort_enabled_first_action ||= Gio::SimpleAction.new(
        'sort-enabled-first',
        nil,
        GLib::Variant.new(settings['sort-enabled-first'] == true),
      ).tap do |action|
        action.signal_connect('activate') { toggle_sort_enabled_first(action) }
      end
    end

    def discover_gnome_action
      @discover_gnome_action ||= Gio::SimpleAction.new('discover-gnome').tap do |action|
        action.signal_connect('activate') { Gtk::UriLauncher.new(DISCOVER_URI).launch(window, nil) }
      end
    end

    # The "ext" group upstream installs on the window class, with the two
    # actions the extension rows reach for.
    def extension_actions
      @extension_actions ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(open_prefs_action)
        group.add_action(show_error_action)
      end
    end

    def open_prefs_action
      @open_prefs_action ||= Gio::SimpleAction.new(
        'open-prefs',
        GLib::VariantType.new('s'),
      ).tap do |action|
        action.signal_connect('activate') { |_action, parameter| open_prefs(parameter.get_string) }
      end
    end

    def show_error_action
      @show_error_action ||= Gio::SimpleAction.new(
        'show-error',
        GLib::VariantType.new('s'),
      ).tap do |action|
        action.signal_connect('activate') { |_action, parameter| show_error(parameter.get_string) }
      end
    end

    private

      def install_app_actions
        app.add_action(quit_action)
        app.add_action(about_action)
        app.add_action(logout_action)
        app.add_action(shortcuts_action)
        app.add_action(sort_enabled_first_action)
      end

      def install_accels
        app.set_accels_for_action('app.quit', ['<primary>q'])
        app.set_accels_for_action('window.close', ['<primary>w'])
      end

      def install_stylesheet
        Gtk::CssProvider.new.tap do |provider|
          provider.load(path: STYLESHEET)
          Gtk::StyleContext.add_provider_for_display(
            Gdk::Display.default,
            provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end
      end

      def connect_signals
        search_button.signal_connect('toggled') { on_search_toggled }
        search_bar.signal_connect('notify::search-mode-enabled') { on_search_mode_changed }
        search_entry.signal_connect('search-changed') { installed_page.search_query = search_entry.text }
        cancel_selection_button.signal_connect('clicked') { installed_page.selection_mode = false }
        uninstall_button.signal_connect('clicked') { on_uninstall_selected }
        installed_page.on_selection_changed { |count| on_selection_changed(count) }
        manager.on_error { |message| show_error_toast(message) }
        manager.on_supported_changed { |supported| sync_visible_page(supported) }
        window.signal_connect('close-request') do
          settings.store_from(window)
          false
        end
        sync_visible_page(manager.supported?)
      end

      def on_search_toggled
        search_bar.search_mode_enabled = search_button.active?
      end

      def on_search_mode_changed
        search_button.active = search_bar.search_mode_enabled?
        installed_page.search_mode_enabled = search_bar.search_mode_enabled?
      end

      # Upstream's selection_title_text and has_selection closures: the title
      # counts the selection and the uninstall button needs one.
      def on_selection_changed(count)
        selection_bar.revealed = installed_page.selection_mode?
        cancel_selection_button.visible = installed_page.selection_mode?
        uninstall_button.sensitive = count.positive?

        if !installed_page.selection_mode?
          window_title.title = TITLE
        elsif count.zero?
          window_title.title = 'Select Extensions'
        else
          # Translators: "%u" = number of selected extensions
          window_title.title = "#{count} Selected"
        end
      end

      def on_uninstall_selected
        ConfirmDialogs.remove_selected(window, installed_page.n_selected) do
          installed_page.uninstall_selected
          installed_page.selection_mode = false
        end
      end

      def sync_visible_page(supported)
        if supported
          main_stack.visible_child_name = 'app'
        else
          main_stack.visible_child_name = 'noshell'
        end
      end

      def open_prefs(uuid)
        manager.by_uuid(uuid).then { |extension| if extension then manager.open_prefs(extension) end }
      end

      def show_error(uuid)
        manager.by_uuid(uuid).then do |extension|
          if extension && !extension.error.to_s.empty?
            ExtensionErrorDialog.new(
              extension.name,
              extension.error,
              homepage_of(extension),
            ).build.present(window)
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

      # Upstream toasts "An Error Occurred" with a Details button; the details
      # window is not ported yet, so the toast carries the message itself.
      def show_error_toast(message)
        toast_overlay.add_toast(Adwaita::Toast.new(message))
      end

      def show_about
        Adwaita::AboutDialog.new.tap do |dialog|
          dialog.application_name = TITLE
          dialog.application_icon = APP_ID
          dialog.version = self.class.version
          dialog.comments = ABOUT_COMMENTS
          dialog.developers = ABOUT_DEVELOPERS
          # Translators: Use 'Name email@domain.com' or 'Name https://website.example'
          # (without single quotes). Do not delete existing names, write yours on a new line.
          dialog.translator_credits = 'translator-credits'
          dialog.copyright = ABOUT_COPYRIGHT
          dialog.license_type = Gtk::License::GPL_3_0
          dialog.present(window)
        end
      end

      # Upstream asks the GNOME Session Manager to log out, which is what
      # applies pending extension updates.
      def request_logout
        app.dbus_connection.then do |connection|
          if connection
            connection.call_sync(
              SESSION_MANAGER,
              SESSION_MANAGER_PATH,
              SESSION_MANAGER,
              'Logout',
              GLib::Variant.parse('(uint32 0,)'),
            )
          end
        end
      rescue GLib::Error => e
        warn "Could not log out: #{e.message}"
      end

      def toggle_sort_enabled_first(action)
        (action.state.get_boolean == false).then do |enabled|
          action.state = GLib::Variant.new(enabled)
          settings['sort-enabled-first'] = enabled
        end
      end
  end
end
