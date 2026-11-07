# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative '../gnome_shell_search_provider'
require_relative '../manager'
require_relative '../settings'
require_relative '../shortcuts_dialog'
require_relative '../window'

module ExtensionManager
  # The application.
  #
  # Ported from upstream's src/exm-application.c: it owns the manager every
  # window shares, installs the app.quit, app.about, app.logout and
  # app.sort-enabled-first actions, binds <primary>q and <primary>w, loads the
  # stylesheet and opens the window.
  #
  # app.shortcuts is installed here too. Upstream gets it from AdwApplication,
  # which finds src/exm-shortcuts-dialog.blp in the resource bundle on its own;
  # the Ruby bindings cannot use Adwaita::Application, so the action presents
  # ShortcutsDialog itself.
  class Application
    APP_ID = 'com.mattjakeman.ExtensionManager'
    TITLE = 'Extension Manager'
    STYLESHEET = File.expand_path('../style.css', __dir__)
    SESSION_MANAGER = 'org.gnome.SessionManager'
    SESSION_MANAGER_PATH = '/org/gnome/SessionManager'

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
        app.signal_connect('startup') { export_search_provider }
        app.signal_connect('shutdown') { search_provider.unexport }
        # GApplication emits 'activate' every time the app is asked to come
        # to the foreground, including a second time from the shell search
        # provider's win.launch-search while the window already exists —
        # upstream's own activate handler is the same single-shot build, run
        # once and then just re-presenting the existing window after.
        app.signal_connect('activate') do
          if @window_built
            window.present
          else
            @window_built = true
            install_stylesheet
            app.add_window(window)
            window.build
            manager.connect
            window.present
          end
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

    def search_provider = @search_provider ||= GnomeShellSearchProvider.new(app, manager)

    def window
      @window ||= Window.new(
        app,
        manager,
        settings,
        version: self.class.version,
      )
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

      # Upstream's exm_application_dbus_register override, which exports the
      # search provider on the connection GApplication itself establishes.
      # The Ruby bindings cannot override that vfunc, but 'startup' fires
      # right after that same registration happens, which is where upstream's
      # own class_init point lands too.
      def export_search_provider
        app.dbus_connection&.then do |connection|
          search_provider.export(connection, "#{app.dbus_object_path}/SearchProvider")
        end
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
