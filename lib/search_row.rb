# frozen_string_literal: true

require 'adwaita'
require_relative 'image_resolver'
require_relative 'install_button'
require_relative 'types'
require_relative 'utils'
require_relative 'versions_provider'

# One extensions.gnome.org search result, as a row.
#
# Ported from upstream's src/exm-search-row.blp and src/exm-search-row.c: the
# icon, the name, the creator, the first line of the description, the install
# button and the chevron, with the install button driving upstream's whole
# compatibility dance.
#
# That dance is upstream's, step for step. The first press asks the website
# for the extension's release history and looks for a release that supports
# the running shell; a release that does, a release list that runs out, and a
# failed request each land the button on a different state, and only then is
# `ext.install` activated with the uuid and whether the window should warn
# first. A second press skips the lookup and installs with whatever state the
# button already wears.
#
# Upstream makes `compact` a GObject property so the browse page's breakpoint
# can set it; a Ruby subclass has no such property, so the browse page calls
# #compact= from the breakpoint's apply and unapply signals instead.
#
# Not carried over: the blueprint's `described-by: description_label` accessible
# relation. Gtk::Accessible#update_relation is unusable from the Ruby bindings
# — every argument shape it accepts is rejected — so the relation cannot be set
# from here at all.
class SearchRow < Gtk::ListBoxRow
  def initialize(manager, search_result, show_icon: false, on_activated: nil)
    super()
    add_css_class('search-row')
    @manager = manager
    @search_result = search_result
    @show_icon = show_icon == true
    @show_creator = true
    @compact = false
    @install_attempt = false
    @on_activated = on_activated
    @install_callback = nil
    @version_request = nil
    @icon_request = nil
  end

  attr_reader :manager, :search_result

  def uuid = search_result.uuid.to_s

  def build
    tap do |row|
      row.child = header_box

      header_box.tap do |box|
        box.append(row_icon)

        title_box.tap do |inner|
          inner.append(title_label)
          inner.append(subtitle_label)
          inner.append(description_label)
        end

        box.append(title_box)
        box.append(install_button.build)
        box.append(next_icon)
      end

      install_button.signal_connect('clicked') { install_remote }
      row.activatable = !@on_activated.nil?

      install_button.state = supported_state
      sync_icon
    end
  end

  # Called by the browse page when the row is activated, which is how the
  # detail view is reached. Upstream points the row's action-name at
  # win.show-detail; the callback is passed in instead, so a page with no
  # detail view to show leaves the row unactivatable rather than pointing it
  # at an action that is not there.
  def activated
    @on_activated&.call(uuid)
  end

  # The narrow layout: the install button drops its label and shows only the
  # download icon.
  def compact=(value)
    @compact = value == true
    install_button.icon_only = @compact
  end

  def compact? = @compact

  def show_creator=(value)
    @show_creator = value == true
    subtitle_label.visible = @show_creator
  end

  def show_creator? = @show_creator

  # Setting this on is what starts the icon fetch, as upstream's
  # show-icon setter does.
  def show_icon=(value)
    @show_icon = value == true
    sync_icon
  end

  def show_icon? = @show_icon

  # Drops the two in-flight website requests, so a row that has scrolled out
  # of the list cannot have its widgets touched by a late answer. This is what
  # upstream's dispose does with its two GCancellables.
  def cancel_requests
    @version_request&.cancel
    @icon_request&.cancel
    unregister_install_callback
  end

  def header_box
    @header_box ||= Gtk::Box.new(:horizontal, 12).tap { |box| box.add_css_class('header') }
  end

  def title_box
    @title_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.add_css_class('title')
      box.hexpand = true
    end
  end

  def row_icon
    @row_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'puzzle-piece-symbolic'
      image.pixel_size = 32
      image.valign = :center
      image.visible = @show_icon
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new(search_result.name.to_s).tap do |label|
      label.add_css_class('title')
      label.ellipsize = :end
      label.lines = 2
      label.wrap = true
      label.wrap_mode = :word_char
      label.xalign = 0
    end
  end

  def subtitle_label
    @subtitle_label ||= Gtk::Label.new(search_result.creator.to_s).tap do |label|
      label.add_css_class('subtitle')
      label.ellipsize = :end
      label.wrap = true
      label.wrap_mode = :word_char
      label.xalign = 0
      label.visible = @show_creator
    end
  end

  def description_label
    @description_label ||= Gtk::Label.new(Utils.first_line(search_result.description)).tap do |label|
      label.add_css_class('dimmed')
      label.ellipsize = :end
      label.lines = 2
      label.margin_top = 6
      label.wrap = true
      label.wrap_mode = :word_char
      label.xalign = 0
    end
  end

  def install_button = @install_button ||= InstallButton.new(icon_only: @compact)

  # Hidden when there is nowhere to go: the chevron promises the detail view.
  def next_icon
    @next_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'go-next-symbolic'
      image.valign = :center
      image.visible = !@on_activated.nil?
    end
  end

  def versions_provider
    @versions_provider ||= VersionsProvider.new(shell_version: manager.shell_version)
  end

  def image_resolver = @image_resolver ||= ImageResolver.new

  private

    # The first press looks the extension up; every press after it installs
    # with the state the lookup settled on.
    def install_remote
      register_install_callback

      if @install_attempt
        install_extension(install_button.state)
      else
        @install_attempt = true
        install_button.state = Types::InstallButtonState::LOADING
        @version_request = versions_provider.query(uuid) do |results, error|
          on_version_loaded(results, error)
        end
      end
    end

    # A failed lookup is not a reason to refuse the install outright: upstream
    # shows the warning state and stops, leaving a second press to go ahead.
    def on_version_loaded(results, error)
      if error
        install_button.state = fallback_state
      else
        continue_version_search(results)
      end
    end

    def continue_version_search(results)
      if compatible_version?(results.model)
        install_extension(supported_state)
      elsif results.next_url
        @version_request = versions_provider.query_next(results.next_url) do |page, page_error|
          on_version_loaded(page, page_error)
        end
      else
        install_extension(fallback_state)
      end
    end

    def compatible_version?(model)
      each_version(model).any? { |version| version.supports_shell_version?(versions_provider.shell_version) }
    end

    def each_version(model)
      Enumerator.new do |yielder|
        model.n_items.times { |index| yielder << model.get_item(index) }
      end
    end

    def supported_state
      if manager.installed_uuid?(uuid)
        Types::InstallButtonState::INSTALLED
      else
        Types::InstallButtonState::DEFAULT
      end
    end

    def fallback_state
      if manager.installed_uuid?(uuid)
        Types::InstallButtonState::INSTALLED
      else
        Types::InstallButtonState::UNSUPPORTED
      end
    end

    # The window's ext.install action takes the uuid and whether to warn
    # first; the warning is for an extension no published release supports.
    def install_extension(state)
      install_button.state = Types::InstallButtonState::INSTALLING
      grab_focus
      activate_action('ext.install', install_target(state == Types::InstallButtonState::UNSUPPORTED))
    end

    # GLib::Variant.new cannot build a tuple of mixed types from the Ruby
    # bindings, so the "(sb)" target is written in GVariant text format and
    # parsed; the uuid goes in double-quoted, with backslashes and quotes
    # escaped the way that format reads them.
    def install_target(warn) = GLib::Variant.parse("(#{quote(uuid)}, #{warn})")

    def quote(text) = "\"#{text.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\""

    # Upstream connects to the manager's install-status for the duration of
    # one install and disconnects in the handler, so a row only hears about
    # the install it asked for.
    def register_install_callback
      if @install_callback.nil?
        @install_callback = proc { |state| on_install_status(state) }
        manager.on_install_status(&@install_callback)
      end
    end

    def unregister_install_callback
      if @install_callback
        manager.off_install_status(@install_callback)
        @install_callback = nil
      end
    end

    def on_install_status(state)
      install_button.state = state
      unregister_install_callback
    end

    def sync_icon
      row_icon.visible = @show_icon
      if @show_icon
        queue_resolve_icon
      end
    end

    def queue_resolve_icon
      @icon_request = image_resolver.resolve(search_result.icon) do |paintable, error|
        if error.nil?
          row_icon.set_from_paintable(paintable)
        end
      end
    end
end
