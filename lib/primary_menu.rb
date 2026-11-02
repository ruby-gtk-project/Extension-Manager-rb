# frozen_string_literal: true

require 'adwaita'

# The main menu behind the header bar's hamburger button.
#
# Ported from the `menu primary_menu` block at the end of upstream's
# src/exm-window.blp: two sections, the first with the sort toggle and the
# second with the upgrade assistant, the shortcuts window and the about
# dialog. The mnemonics are upstream's, including its note that the
# underscored letter must not repeat within the menu.
class PrimaryMenu
  SECTIONS = [
    [
      # Translators: the character preceded by "_" should not be the same
      # as others in the same menu
      ['Sort _Enabled First', 'app.sort-enabled-first'],
    ],
    [
      ['_Upgrade Assistant', 'win.show-upgrade-assistant'],
      ['_Keyboard Shortcuts', 'app.shortcuts'],
      ['_About Extension Manager', 'app.about'],
    ],
  ].freeze

  def build
    Gio::Menu.new.tap do |menu|
      SECTIONS.each { |items| menu.append_section(nil, section(items)) }
    end
  end

  private

    def section(items)
      Gio::Menu.new.tap do |menu|
        items.each { |label, action| menu.append_item(Gio::MenuItem.new(label, action)) }
      end
    end
end
