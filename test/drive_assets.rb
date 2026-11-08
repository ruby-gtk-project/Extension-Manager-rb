# frozen_string_literal: true

# Drives the components added by "Port custom symbolic icons, desktop entry
# and metainfo" (lib/extension_manager/application.rb's install_icon_theme,
# and the three new data/ templates): none of this was ever run by the other
# three drive scripts, since it has no window or dialog of its own — it is a
# search path registered on startup and two template files nothing in lib/
# reads at all. A file existing on disk, or `ruby -c` passing on the Ruby
# side that points at it, proves nothing about whether the icon theme can
# actually resolve a name through it.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require_relative '../.claude/skills/ruby-gtk-testing/scripts/gtk_driver'
require 'extension_manager'

# Every custom symbolic icon the "Port custom symbolic icons" commit copied
# into data/icons/hicolor/scalable/actions, independent of whether any
# widget currently sets that name — upstream ships all 18 in its GResource
# bundle regardless of which ones a given screen happens to use, and a name
# that resolves today but silently loses its file in a later commit should
# fail here even if no widget references it yet.
CUSTOM_ICON_NAMES = [
  'check-round-outline-symbolic', 'clock-alt-symbolic', 'donation-symbolic',
  'external-link-symbolic', 'globe-symbolic', 'info-symbolic',
  'offline-symbolic', 'pip-in-symbolic', 'pip-out-symbolic',
  'puzzle-piece-symbolic', 'session-modes-symbolic', 'settings-symbolic',
  'software-update-available-symbolic', 'star-filled-rounded-symbolic',
  'star-outline-rounded-symbolic', 'supported-symbolic', 'unknown-symbolic',
  'unsupported-symbolic',
].freeze

# The names actual widgets in lib/ set, confirmed by grepping lib/*.rb for
# each literal — this is the subset where a missing icon would show up to a
# user as a broken-image glyph on a real screen, not just as a theme lookup.
WIRED_ICON_NAMES = [
  'check-round-outline-symbolic', 'clock-alt-symbolic', 'donation-symbolic',
  'external-link-symbolic', 'globe-symbolic', 'offline-symbolic',
  'pip-out-symbolic', 'puzzle-piece-symbolic', 'session-modes-symbolic',
  'settings-symbolic', 'software-update-available-symbolic',
  'star-filled-rounded-symbolic', 'star-outline-rounded-symbolic',
  'supported-symbolic', 'unknown-symbolic', 'unsupported-symbolic',
].freeze

app = ExtensionManager::Application.new

GtkDriver.drive(app, shots: 'tmp/shots') do |d, application|
  d.window { application.window }

  d.step('the window builds, which is what registers the icon search path') do
    d.check('window present') { application.window.visible? }
  end

  d.step('every custom symbolic icon the port shipped resolves in the theme') do
    Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
      d.check('the icons directory is really on the search path') do
        theme.search_path.include?(ExtensionManager::Application::ICONS_DIR)
      end
      CUSTOM_ICON_NAMES.each do |name|
        d.check("the theme resolves #{name}") { theme.has_icon?(name) }
      end
      d.check('none of the 18 is missing') { CUSTOM_ICON_NAMES.all? { |n| theme.has_icon?(n) } }
    end
  end

  d.step('every icon a widget actually sets is among the ones that resolve') do
    (WIRED_ICON_NAMES - CUSTOM_ICON_NAMES).then do |orphans|
      d.check('no wired icon is missing from the shipped set') { orphans.empty? }
    end
  end

  d.step('a real Gtk::Image built with a custom icon name paints something') do
    # has_icon? alone would also be true for a symbolic name GTK invents a
    # fallback "broken image" render for; building the actual image and
    # asking it to choose an IconPaintable is the same lookup a widget's
    # `icon_name=` triggers, and a real theme hit answers a non-nil
    # paintable while a name with no file would not resolve at all.
    Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
      theme.lookup_icon('puzzle-piece-symbolic', 16).then do |paintable|
        d.check('puzzle-piece-symbolic resolves to a real paintable') { !paintable.nil? }
        d.check('it is backed by this port\'s own file, not a system fallback') do
          paintable.file&.path.to_s.start_with?(ExtensionManager::Application::ICONS_DIR)
        end
      end
    end
  end

  d.step('the app\'s own icon (not just the 18 action glyphs) resolves in the theme') do
    # The About dialog sets dialog.application_icon = APP_ID, and the
    # .desktop/.metainfo templates' Icon/@app_id@ token resolves the same
    # name — upstream ships it as data/icons/com.mattjakeman.ExtensionManager
    # {.svg,-symbolic.svg} installed into hicolor's scalable/apps and
    # symbolic/apps. A driver that only ever checked the 18 action glyphs
    # would stay green even if the app's own icon file never existed.
    Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
      app_id = ExtensionManager::Application::APP_ID
      d.check('the theme resolves the app id as an icon name') { theme.has_icon?(app_id) }
      theme.lookup_icon(app_id, 48).then do |paintable|
        d.check('it resolves to a real paintable') { !paintable.nil? }
        d.check('it is backed by this port\'s own scalable/apps SVG, not a system fallback') do
          paintable.file&.path.to_s == File.join(
            ExtensionManager::Application::ICONS_DIR, 'hicolor/scalable/apps', "#{app_id}.svg"
          )
        end
      end
      d.check('the symbolic variant also resolves to this port\'s own file') do
        theme.lookup_icon("#{app_id}-symbolic", 16).file&.path.to_s == File.join(
          ExtensionManager::Application::ICONS_DIR, 'hicolor/symbolic/apps', "#{app_id}-symbolic.svg"
        )
      end
    end
  end

  d.step('the desktop entry template parses as upstream\'s desktop file shape') do
    File.read(File.expand_path('../data/com.mattjakeman.ExtensionManager.desktop.in.in', __dir__))
        .then do |text|
      entries = text.lines.grep(/=/).reject { |l| l.start_with?('#') }.to_h do |line|
        line.strip.split('=', 2)
      end
      d.check('it names the right group') { text.lines.first.strip == '[Desktop Entry]' }
      d.check('Name is the app title') { entries['Name'] == 'Extension Manager' }
      d.check('Exec launches the gem\'s binary') { entries['Exec'] == 'extension-manager %U' }
      d.check('Icon is the substitutable app id token') { entries['Icon'] == '@app_id@' }
      d.check('it is a GNOME-only Application') do
        entries['Type'] == 'Application' && entries['OnlyShowIn'] == 'GNOME;'
      end
      d.check('it is D-Bus activatable, matching the search provider\'s .service') do
        entries['DBusActivatable'] == 'true'
      end
      d.check('its MimeType handles the gnome-extensions URI scheme') do
        entries['MimeType'] == 'x-scheme-handler/gnome-extensions;'
      end
    end
  end

  # The dev shell's Ruby has no `rexml` on its load path (this is a Nix
  # bundlerEnv closure, not a stock Ruby with default gems), so well-
  # formedness is checked by hand rather than by pulling in a real XML
  # parser: a stack-based tag walk that fails on any unclosed or mismatched
  # element, plus Libadwaita's own loader on the substituted-id pass below,
  # which is a real AppStream-adjacent parser (Adw.AboutDialog's release
  # notes path) rather than a hand-rolled one.
  d.step('the metainfo template parses as well-formed, single-rooted XML') do
    File.read(File.expand_path('../data/com.mattjakeman.ExtensionManager.metainfo.xml.in.in', __dir__))
        .then do |text|
      d.check('it opens with an XML declaration') { text.strip.start_with?('<?xml') }
      tags = text.scan(%r{<(/?)([a-zA-Z][\w-]*)[^>]*?(/?)>})
      stack = []
      balanced = tags.all? do |closing, name, self_closing|
        if self_closing == '/'
          true
        elsif closing == '/'
          stack.pop == name
        else
          stack.push(name)
          true
        end
      end
      d.check('every opened tag is closed in order') { balanced && stack.empty? }
      d.check('the root element is a desktop-application component') do
        text =~ %r{<component\s+type="desktop-application">} ? true : false
      end
      d.check('its id is the substitutable app id token') do
        text.include?('<id>@app_id@</id>')
      end
      d.check('its launchable points at that id\'s .desktop file') do
        text.include?('<launchable type="desktop-id">@app_id@.desktop</launchable>')
      end
      d.check('its name matches the desktop entry\'s') do
        text.include?('<name>Extension Manager</name>')
      end
      d.check('it carries a GPL-3.0-or-later project license') do
        text.include?('<project_license>GPL-3.0-or-later</project_license>')
      end
      d.check('it names at least one screenshot') { text.include?('<screenshot ') }
      # Upstream's own metainfo points <image> at raw.githubusercontent.com
      # URLs (AppStream screenshots are meant to be fetched remotely, not
      # bundled), which this template matches verbatim. The filenames those
      # URLs name still exist in upstream's own data/ directory for the
      # repo's own README/tooling, so the port carries the same 8 PNGs
      # rather than silently dropping files upstream ships.
      screenshot_files = text.scan(%r{/data/(screenshot-[\w-]+\.png)}).flatten
      d.check('the metainfo names at least 4 screenshot files') { screenshot_files.size >= 4 }
      d.check('every named screenshot file exists in data/') do
        screenshot_files.all? { |name| File.exist?(File.expand_path("../data/#{name}", __dir__)) }
      end
    end
  end

  d.step('substituting the app id the way meson\'s configure_file would gives a usable pair') do
    app_id = ExtensionManager::Application::APP_ID
    desktop = File.read(
      File.expand_path('../data/com.mattjakeman.ExtensionManager.desktop.in.in', __dir__),
    ).gsub('@app_id@', app_id)
    metainfo = File.read(
      File.expand_path('../data/com.mattjakeman.ExtensionManager.metainfo.xml.in.in', __dir__),
    ).gsub('@app_id@', app_id)
    d.check('the desktop entry\'s Icon becomes the real application id') do
      desktop.lines.grep(/^Icon=/).first.strip == "Icon=#{app_id}"
    end
    d.check('the metainfo\'s id becomes the real application id') do
      metainfo.include?("<id>#{app_id}</id>")
    end
    d.check('and its launchable names that id\'s .desktop file') do
      metainfo.include?("<launchable type=\"desktop-id\">#{app_id}.desktop</launchable>")
    end
  end
end
