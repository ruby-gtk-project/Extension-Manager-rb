# frozen_string_literal: true

require 'adwaita'
require_relative 'extension_toggle'
require_relative 'types'

# One installed extension's row.
#
# Ported from upstream's src/exm-extension-row.blp and
# src/exm-extension-row.c: an Adw.ActionRow titled with the extension's name
# and subtitled with its uuid, carrying — in upstream's order — the update
# icon, the out-of-date icon, the error button, the preferences button, the
# enable switch and the navigation chevron, plus the check button that appears
# in front of the row in selection mode.
#
# The row installs upstream's "row" action group with its open-prefs and
# show-error actions, which forward to the window's ext.open-prefs and
# ext.show-error. Activating the row shows the extension's detail page, or
# toggles its check button while the page is selecting.
class ExtensionRow < Adwaita::ActionRow
  UPDATE_TOOLTIP = 'A newer version of this extension is available'
  OUT_OF_DATE_TOOLTIP = 'This extension is incompatible with your current version of GNOME'
  ERROR_TOOLTIP = 'An error occurred while loading this extension'
  PREFS_TOOLTIP = 'Open extension preferences'

  attr_reader :extension, :manager

  def initialize(extension, manager)
    super()
    self.title_lines = 1
    self.subtitle_lines = 1
    self.use_markup = false
    self.activatable = true
    @extension = extension
    @manager = manager
    @selection_mode = false
  end

  def build
    tap do |row|
      row.title = extension.name.to_s
      row.subtitle = extension.uuid.to_s

      row.add_suffix(update_icon)
      row.add_suffix(out_of_date_icon)
      row.add_suffix(error_button)
      row.add_suffix(prefs_button)
      row.add_suffix(ext_toggle)
      row.add_suffix(nav_icon)

      row.insert_action_group('row', action_group)

      ext_toggle.signal_connect('state-set') do |toggle, state|
        ExtensionToggle.apply(
          manager,
          extension,
          toggle,
          state,
        )
      end

      select_check.signal_connect('toggled') { on_select_toggled }
      row.signal_connect('activated') { on_activated }

      extension.signal_connect('notify::state') { sync_state_icons }
      extension.signal_connect('notify::has-update') { sync_update_icon }
      extension.signal_connect('notify::name') { row.title = extension.name.to_s }

      ExtensionToggle.bind(extension, ext_toggle)
      sync_state_icons
      sync_update_icon
      row.selection_mode = false
    end
  end

  # Upstream hides a row that cannot be selected while the page is selecting,
  # because only user-installed extensions can be uninstalled; the check
  # button then takes the place of the row's controls.
  def selection_mode=(page_selection_mode)
    @selection_mode = page_selection_mode && selectable?
    self.visible = !page_selection_mode || selectable?

    if @selection_mode
      show_check
    else
      hide_check
    end

    prefs_button.visible = !@selection_mode && extension.has_prefs == true
    ext_toggle.visible = !@selection_mode
    nav_icon.visible = !@selection_mode
  end

  def selection_mode? = @selection_mode

  def selected? = select_check.active?

  # The installed page focuses the toggle of the row whose extension just
  # changed, so keyboard focus survives the list being re-sorted.
  def focus_toggle = ext_toggle.grab_focus

  def update_icon
    @update_icon ||= Gtk::Image.new.tap do |image|
      image.add_css_class('update')
      image.icon_name = 'software-update-available-symbolic'
      image.valign = :center
      image.halign = :center
      image.focusable = true
      image.margin_start = 9
      image.margin_end = 9
      # Translators: Icon's tooltip when an extension update is available
      image.tooltip_text = UPDATE_TOOLTIP
    end
  end

  def out_of_date_icon
    @out_of_date_icon ||= Gtk::Image.new.tap do |image|
      image.add_css_class('error')
      image.icon_name = 'clock-alt-symbolic'
      image.valign = :center
      image.halign = :center
      image.focusable = true
      image.margin_start = 9
      image.margin_end = 9
      # Translators: Icon's tooltip when an extension is incompatible
      image.tooltip_text = OUT_OF_DATE_TOOLTIP
    end
  end

  def error_button
    @error_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('flat')
      button.add_css_class('error')
      button.icon_name = 'dialog-error-symbolic'
      button.valign = :center
      button.action_name = 'row.show-error'
      # Translators: Button's tooltip to view an extension's error details
      button.tooltip_text = ERROR_TOOLTIP
    end
  end

  def prefs_button
    @prefs_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('flat')
      button.icon_name = 'settings-symbolic'
      button.valign = :center
      button.halign = :center
      button.action_name = 'row.open-prefs'
      # Translators: Button's tooltip to open extension's preferences dialog
      button.tooltip_text = PREFS_TOOLTIP
    end
  end

  def ext_toggle
    @ext_toggle ||= Gtk::Switch.new.tap do |toggle|
      toggle.valign = :center
      toggle.sensitive = extension.can_change == true
    end
  end

  def nav_icon
    @nav_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'go-next-symbolic'
      image.valign = :center
      image.halign = :center
    end
  end

  def select_check
    @select_check ||= Gtk::CheckButton.new.tap do |check|
      check.valign = :center
      check.add_css_class('selection-mode')
    end
  end

  def action_group
    @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(open_prefs_action)
      group.add_action(show_error_action)
    end
  end

  def open_prefs_action
    @open_prefs_action ||= Gio::SimpleAction.new('open-prefs').tap do |action|
      action.enabled = extension.has_prefs == true
      action.signal_connect('activate') { activate_action('ext.open-prefs', uuid_variant) }
    end
  end

  def show_error_action
    @show_error_action ||= Gio::SimpleAction.new('show-error').tap do |action|
      action.signal_connect('activate') { activate_action('ext.show-error', uuid_variant) }
    end
  end

  private

    def selectable? = extension.is_user == true

    def show_check
      unless select_check.parent
        add_prefix(select_check)
      end
      select_check.visible = true
    end

    def hide_check
      select_check.active = false
      select_check.visible = false
    end

    def sync_state_icons
      error_button.visible = extension.error?
      out_of_date_icon.visible = extension.out_of_date?
      ext_toggle.sensitive = extension.can_change == true
    end

    def sync_update_icon
      update_icon.visible = extension.has_update == true
    end

    def on_select_toggled
      if @selection_mode
        activate_action('page.selection-changed', nil)
      end
    end

    def on_activated
      if @selection_mode
        select_check.active = !select_check.active?
      else
        activate_action('win.show-detail', uuid_variant)
      end
    end

    def uuid_variant = GLib::Variant.new(extension.uuid.to_s)
end
