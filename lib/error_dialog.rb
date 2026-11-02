# frozen_string_literal: true

require 'adwaita'

# The crash reporter.
#
# Ported from upstream's src/exm-error-dialog.blp and src/exm-error-dialog.c:
# a 500×500 Adw.Window titled "Error Report", with the error text under a
# generated support log in a monospace card, a copy button in the group header
# that toasts "Copied", and a "New Issue" button.
#
# The support log's fields are upstream's, in upstream's order. Three of them
# come from meson options there: the version, the package format and whether
# this is an official build. A gem built from this source tree is not an
# official build, so the log says so and — exactly as upstream does for a
# third-party build — the "New Issue" button is hidden and the group asks the
# reporter to contact the distributor first.
class ErrorDialog < Adwaita::Window
  TITLE = 'Error Report'
  HEADING = 'An unexpected error occurred in Extension Manager'
  COPY_TOOLTIP = 'Copy to Clipboard'
  COPIED = 'Copied'
  ISSUES_URI = 'https://github.com/mjakeman/extension-manager/issues'
  PACKAGE_FORMAT = 'gem'
  OFFICIAL = false
  DISTRIBUTOR = 'the extension-manager-rb gem'
  OFFICIAL_DESCRIPTION = 'Please open a new issue and attach the following information:'

  # Translators: '%s' = Name of Distributor (e.g. "Packager123")
  THIRD_PARTY_DESCRIPTION =
    'You are using a third-party build of Extension Manager. Please ' \
    "<span weight=\"bold\">contact the package distributor (#{DISTRIBUTOR}) first</span> " \
    'before filing an issue. Be sure to attach the following information:'

  def initialize(error_text, version:)
    super()
    self.title = TITLE
    self.default_width = 500
    self.default_height = 500
    @error_text = error_text.to_s
    @version = version
  end

  # The whole text the copy button puts on the clipboard: the support log
  # followed by the error itself.
  def support_log
    @support_log ||= [
      'Support Log',
      '----',
      "Version: #{@version}",
      "Package Format: #{PACKAGE_FORMAT}",
      "Status: #{status}",
      "OS: #{os_name} #{os_version}",
      "GTK: #{Gtk::Version::MAJOR}.#{Gtk::Version::MINOR}.#{Gtk::Version::MICRO}",
      "Libadwaita: #{Adwaita::MAJOR_VERSION}.#{Adwaita::MINOR_VERSION}.#{Adwaita::MICRO_VERSION}",
      '----',
      @error_text,
    ].join("\n")
  end

  def build
    tap do |dialog|
      dialog.content = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = toast_overlay
      end

      toast_overlay.child = preferences_page

      preferences_page.tap do |page|
        page.add(heading_group)
        page.add(instructions_group)
      end

      heading_group.add(heading_label)

      instructions_group.tap do |group|
        group.header_suffix = copy_button
        group.add(scrolled_window)
        group.add(new_issue_button)
      end

      scrolled_window.child = text_view
      text_view.buffer.text = support_log

      copy_button.signal_connect('clicked') { on_copy_clicked }
      new_issue_button.signal_connect('clicked') { on_new_issue_clicked }
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new
  def heading_group = @heading_group ||= Adwaita::PreferencesGroup.new

  def heading_label
    @heading_label ||= Gtk::Label.new(HEADING).tap do |label|
      label.add_css_class('title-4')
      label.justify = :center
      label.selectable = true
      label.wrap = true
    end
  end

  def instructions_group
    @instructions_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.description = description
    end
  end

  def copy_button
    @copy_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('flat')
      button.icon_name = 'edit-copy-symbolic'
      button.tooltip_text = COPY_TOOLTIP
      button.valign = :center
    end
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.add_css_class('card')
      window.overflow = :hidden
      window.vexpand = true
    end
  end

  def text_view
    @text_view ||= Gtk::TextView.new.tap do |view|
      view.add_css_class('inline')
      view.bottom_margin = 12
      view.editable = false
      view.left_margin = 12
      view.monospace = true
      view.right_margin = 12
      view.top_margin = 12
      view.vexpand = true
      view.wrap_mode = :word_char
    end
  end

  def new_issue_button
    @new_issue_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('pill')
      button.add_css_class('suggested-action')
      button.can_shrink = true
      button.halign = :center
      button.label = '_New Issue'
      button.margin_top = 12
      button.use_underline = true
      button.visible = OFFICIAL
    end
  end

  private

    def status
      if OFFICIAL
        'Official'
      else
        'Third Party'
      end
    end

    def description
      if OFFICIAL
        OFFICIAL_DESCRIPTION
      else
        THIRD_PARTY_DESCRIPTION
      end
    end

    # GLib's g_get_os_info has no Ruby binding, so the two fields it would
    # supply are read from the file it reads them from.
    def os_release
      @os_release ||= parse_os_release
    end

    def parse_os_release
      {}.tap do |fields|
        File.readlines('/etc/os-release', chomp: true).each do |line|
          line.split('=', 2).then do |key, value|
            if value
              fields[key] = value.delete_prefix('"').delete_suffix('"')
            end
          end
        end
      end
    rescue SystemCallError
      {}
    end

    def os_name = os_release.fetch('NAME', 'Unknown')
    def os_version = os_release.fetch('VERSION', '')

    # Upstream copies the error on its own, not the support log the text view
    # shows around it.
    def on_copy_clicked
      Gdk::Display.default&.clipboard&.set_text(@error_text)
      toast_overlay.add_toast(Adwaita::Toast.new(COPIED))
    end

    def on_new_issue_clicked
      Gtk::UriLauncher.new(ISSUES_URI).launch(self, nil)
    end
end
