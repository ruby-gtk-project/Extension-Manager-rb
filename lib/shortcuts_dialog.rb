# frozen_string_literal: true

require 'adwaita'

# The keyboard shortcuts window.
#
# A direct port of upstream's src/exm-shortcuts-dialog.blp, which has no
# backing .c file: three Adw.ShortcutsSections — Views, Screenshot View and
# App — with the nine items below. Four of them name an action rather than an
# accelerator, which is how Adw.ShortcutsItem picks up whatever accelerator
# the application bound to it.
class ShortcutsDialog < Adwaita::ShortcutsDialog
  # Translators: section titles and item titles of the shortcuts dialog
  SECTIONS = {
    'Views'           => [
      ['Switch to Installed', '<Alt>1'],
      ['Switch to Browse', '<Alt>2'],
    ],
    'Screenshot View' => [
      ['Zoom In', '<Control>plus'],
      ['Zoom Out', '<Control>minus'],
      ['Reset Zoom', '<Control>0'],
    ],
    'App'             => [
      ['Toggle Search', '<Control>F'],
      ['Keyboard Shortcuts', 'app.shortcuts'],
      ['Close Window', 'window.close'],
      ['Quit', 'app.quit'],
    ],
  }.freeze

  # An item's second element is an action name rather than an accelerator when
  # it looks like one: "app.quit", not "<Control>q".
  ACTION_PATTERN = /\A[a-z]+\.[a-z-]+\z/

  def initialize
    super()
    self.title = 'Keyboard Shortcuts'
  end

  def build
    tap do |dialog|
      SECTIONS.each { |title, items| dialog.add(section(title, items)) }
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |label, accelerator| section.add(item(label, accelerator)) }
      end
    end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8".
    def item(label, accelerator)
      if ACTION_PATTERN.match?(accelerator)
        Adwaita::ShortcutsItem.new(label, '').tap { |shortcut| shortcut.action_name = accelerator }
      else
        Adwaita::ShortcutsItem.new(label, accelerator)
      end
    end
end
