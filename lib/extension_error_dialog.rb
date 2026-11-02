# frozen_string_literal: true

require 'adwaita'

# The dialog that shows why an extension failed to load.
#
# Ported from upstream's src/exm-extension-error-dialog.blp and
# src/exm-extension-error-dialog.c: a 500×500 Adw.Dialog with the extension's
# name in a title label, the error trace in a monospace text view inside a
# card, a copy button in the group header that toasts "Copied", and a report
# button that opens the extension's homepage — shown only when the extension
# has one.
class ExtensionErrorDialog < Adwaita::Dialog
  COPY_TOOLTIP = 'Copy to Clipboard'

  def initialize(extension_name, error_text, homepage = nil)
    super()
    self.content_width = 500
    self.content_height = 500
    self.width_request = 360
    self.height_request = 294
    self.title = 'Extension Error'
    @extension_name = extension_name
    @error_text = error_text.to_s
    @homepage = homepage
  end

  def build
    tap do |dialog|
      dialog.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = toast_overlay
      end

      toast_overlay.child = preferences_page

      preferences_page.tap do |page|
        page.add(title_group)
        page.add(trace_group)
      end

      title_group.add(title_label)

      trace_group.tap do |group|
        group.header_suffix = copy_button
        group.add(scrolled_window)
        group.add(report_button)
      end

      scrolled_window.child = text_view

      copy_button.signal_connect('clicked') { on_copy_clicked }
      report_button.signal_connect('clicked') { on_report_clicked }
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new
  def title_group = @title_group ||= Adwaita::PreferencesGroup.new
  def trace_group = @trace_group ||= Adwaita::PreferencesGroup.new

  # Translators: "%s" = the extension's name
  def title_label
    @title_label ||= Gtk::Label.new(heading).tap do |label|
      label.add_css_class('title-4')
      label.justify = :center
      label.wrap = true
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
      view.buffer.text = @error_text
    end
  end

  def report_button
    @report_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('pill')
      button.can_shrink = true
      button.halign = :center
      # Translators: Button to report an extension error to its developer
      button.label = '_Report Issue'
      button.margin_top = 12
      button.use_underline = true
      button.visible = !@homepage.nil?
      button.tooltip_text = @homepage
    end
  end

  private

    def heading
      if @extension_name.nil?
        'Extension Failed to Load'
      else
        "“#{@extension_name}” Failed to Load"
      end
    end

    def on_copy_clicked
      Gdk::Display.default.clipboard.set_text(@error_text)
      toast_overlay.add_toast(Adwaita::Toast.new('Copied'))
    end

    def on_report_clicked
      @homepage.then do |homepage|
        if homepage
          Gtk::UriLauncher.new(homepage).launch(root, nil)
        end
      end
    end
end
