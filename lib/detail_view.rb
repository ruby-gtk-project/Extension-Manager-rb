# frozen_string_literal: true

require 'adwaita'
require 'uri'
require_relative 'comment_provider'
require_relative 'comment_dialog'
require_relative 'comment_tile'
require_relative 'data_provider'
require_relative 'extension_error_dialog'
require_relative 'extension_toggle'
require_relative 'image_resolver'
require_relative 'install_button'
require_relative 'screenshot'
require_relative 'types'
require_relative 'unified_data'
require_relative 'utils'
require_relative 'versions_dialog'
require_relative 'versions_provider'

# One extension's full detail page.
#
# Ported from upstream's src/exm-detail-view.blp and src/exm-detail-view.c:
# the merged web/local record (UnifiedData) behind the icon, title, author
# link, install button or installed controls, screenshot, description,
# downloads, version row, session modes, install location, links and
# reviews. #load_for_uuid is upstream's: it seeds the local half of the data
# immediately, asks DataProvider for the web half, and only then resolves the
# icon, the screenshot and the compatible release.
class DetailView < Adwaita::NavigationPage
  LOADING_TITLE = 'Loading Details'
  ERROR_TITLE = 'Connection Error'
  EMPTY_TITLE = 'An Error Occurred'
  EMPTY_DESCRIPTION = 'No extension details available'
  BANNER_TITLE = 'This extension has an error'
  BANNER_BUTTON = '_View Details'
  DESCRIPTION_HEADING = 'Description'
  DOWNLOADS_TITLE = 'Downloads'
  VERSION_TITLE = 'Version'
  SESSION_MODES_TITLE = 'Session Modes'
  LOCATION_TITLE = 'Location'
  LINKS_TITLE = 'Links'
  HOMEPAGE_TITLE = 'Homepage'
  DONATE_TITLE = 'Donate'
  VIEW_ON_EXTENSIONS_TITLE = 'View on Extensions'
  REVIEWS_TITLE = 'Reviews and Comments'
  REVIEWS_DISABLED = 'Reviews and comments are disabled for this extension'
  REVIEWS_EMPTY = 'There are no reviews or comments'
  SHOW_ALL_LABEL = '_Show All'
  UNKNOWN_VERSION = 'Unknown'
  UNSUPPORTED_VERSION = 'Unsupported'
  LOADING_VERSION = 'Loading'
  UPDATE_TOOLTIP = 'A newer version of this extension is available'
  OUT_OF_DATE_TOOLTIP = 'This extension is incompatible with your current version of GNOME'
  REMOVE_TOOLTIP = 'Remove Extension'
  PREFS_TOOLTIP = 'Open extension preferences'
  TOGGLE_TOOLTIP = 'Toggle Extension'
  POPOUT_TOOLTIP = 'Enlarge Image'
  COPIED_TOAST = 'Copied'
  SESSION_MODE_LABELS = { 'unlock-dialog' => 'Unlock Dialog', 'gdm' => 'GDM' }.freeze
  COMMENT_FEW_THRESHOLD = 5

  attr_reader :data, :manager, :screenshot

  def initialize
    super(toolbar_view, '')
    insert_action_group('detail', detail_actions)
    insert_action_group('page', page_actions)
    @data = nil
    @manager = nil
    @shell_version = nil
    @uuid = nil
    @version_state = Types::InstallButtonState::LOADING
    @error_text = nil
    @uri_extensions = nil
    @uri_donations = []
    @comments_request = nil
    @icon_request = nil
    @screenshot_request = nil
    @versions_request = nil
    @versions_next_url = nil
  end

  def manager=(value)
    @manager = value
    value.on_install_status { |state| install_button.state = state }
    value.extensions.signal_connect('items-changed') { update }
  end

  # Read live rather than cached at assignment time: the manager does not
  # know its shell version until its D-Bus proxy connects, which happens
  # after this page's manager= setter runs.
  def shell_version = manager&.shell_version

  def build
    tap do |page|
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = toast_overlay
      end

      header_bar.title_widget = title_revealer
      title_revealer.child = window_title

      toast_overlay.child = stack

      stack.tap do |s|
        s.add_named(loading_status, 'page_spinner')
        s.add_named(error_status, 'page_error')
        s.add_named(empty_status, 'page_empty')
        s.add_named(detail_box, 'page_detail')
        s.visible_child_name = 'page_spinner'
      end

      detail_box.tap do |box|
        box.append(error_banner)
        box.append(scroll_area)
      end

      scroll_area.child = clamp
      clamp.child = content_box

      content_box.tap do |box|
        box.append(header)
        box.append(screenshot_container)
        box.append(description_box)
        box.append(details_group)
        box.append(links_group)
        box.append(comments_section)
      end

      header.tap do |box|
        box.append(ext_icon)
        box.append(header_suffix)
      end

      header_suffix.tap do |box|
        box.append(title_box)
        box.append(tools_stack)
      end

      title_box.tap do |box|
        box.append(ext_title)
        box.append(ext_author)
      end

      tools_stack.tap do |s|
        s.add_named(install_button.build.tap { |btn| btn.signal_connect('clicked') { install_remote } }, 'uninstalled-tools-page')
        s.add_named(installed_tools_box, 'installed-tools-page')
      end

      installed_tools_box.tap do |box|
        box.append(installed_buttons_box)
        box.append(ext_toggle)
      end

      installed_buttons_box.tap do |box|
        box.append(remove_btn)
        box.append(prefs_btn)
      end

      screenshot_container.tap do |overlay|
        overlay.child = ext_screenshot.build
        overlay.add_overlay(ext_screenshot_popout_button)
      end

      description_box.tap do |box|
        box.append(description_heading)
        box.append(ext_description)
      end

      details_group.tap do |group|
        group.add(downloads_row)
        group.add(version_row)
        group.add(session_modes_row)
        group.add(location_row)
      end

      links_group.tap do |group|
        group.add(link_homepage)
        group.add(link_donation)
        group.add(links_donations)
        group.add(link_extensions)
      end

      comments_section.tap do |box|
        box.append(comments_heading)
        box.append(comment_stack)
      end

      comment_stack.tap do |s|
        s.add_named(comment_spinner, 'page_spinner')
        s.add_named(comment_disabled_label, 'page_disabled')
        s.add_named(comment_error_box, 'page_error')
        s.add_named(comment_empty_label, 'page_empty')
        s.add_named(comment_page, 'page_comments')
      end

      comment_error_box.tap do |box|
        box.append(comment_error_heading)
        box.append(comment_error_label)
      end

      comment_page.tap do |box|
        box.append(comment_box)
        box.append(show_more_btn)
      end

      scroll_area.vadjustment.signal_connect('value-changed') { on_scroll_changed }
      ext_author.signal_connect('activate-link') { |_label, uri| on_author_link_activated(uri) }
      ext_toggle.signal_connect('state-set') { |_switch, state| on_toggle_changed(state) }
      show_more_btn.signal_connect('clicked') { show_more_comments }
    end
  end

  # Ported from upstream's exm_detail_view_load_for_uuid: seeds the local
  # half immediately, resets every transient bit of state, and asks
  # DataProvider for the web half.
  def load_for_uuid(uuid)
    unless uuid == @uuid && @data && !@data.web_data.nil?
      @uuid = uuid
      @version_state = Types::InstallButtonState::LOADING
      update_icon.visible = false
      out_of_date_icon.visible = false
      error_banner.revealed = false
      version_label.label = LOADING_VERSION
      update_session_modes_row(nil)

      @data = UnifiedData.new
      local_info = manager.by_uuid(uuid)
      if local_info
        @data.local_data = local_info
      end

      if local_info
        stack.visible_child_name = 'page_detail'
      else
        stack.visible_child_name = 'page_spinner'
      end

      update

      @icon_request&.cancel
      @screenshot_request&.cancel
      @versions_request&.cancel
      @comments_request&.cancel

      ext_icon.icon_name = 'puzzle-piece-symbolic'
      ext_screenshot.set_paintable(nil)
      ext_screenshot.reset
      ext_screenshot_popout_button.visible = false
      comment_box.remove_all
      comment_stack.visible_child_name = 'page_spinner'
      link_extensions.subtitle = ''

      downloads_row.visible = true
      comments_section.visible = true
      links_group.visible = true
      link_extensions.visible = true
      version_row.activatable = true

      @data_request = data_provider.get(uuid) { |result, error| on_data_loaded(result, error) }
    end
  end

  def update
    if @uuid
      if manager.installed_uuid?(@uuid)
        install_button.state = Types::InstallButtonState::INSTALLED
      else
        install_button.state = @version_state
      end
      update_tools_stack
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.overflow = :hidden }

  def title_revealer
    @title_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.transition_type = :slide_up
      revealer.transition_duration = 500
      revealer.overflow = :visible
    end
  end

  def window_title = @window_title ||= Adwaita::WindowTitle.new('', '')

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def stack = @stack ||= Gtk::Stack.new

  def loading_status
    @loading_status ||= Adwaita::StatusPage.new.tap { |page| page.title = LOADING_TITLE }
  end

  def error_status
    @error_status ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'offline-symbolic'
      page.title = ERROR_TITLE
    end
  end

  def empty_status
    @empty_status ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'dialog-question-symbolic'
      page.title = EMPTY_TITLE
      page.description = EMPTY_DESCRIPTION
    end
  end

  def detail_box = @detail_box ||= Gtk::Box.new(:vertical, 0)

  def error_banner
    @error_banner ||= Adwaita::Banner.new(BANNER_TITLE).tap do |banner|
      banner.button_label = BANNER_BUTTON
      banner.action_name = 'detail.show-error'
    end
  end

  def scroll_area = @scroll_area ||= Gtk::ScrolledWindow.new.tap { |area| area.vexpand = true }
  def clamp = @clamp ||= Adwaita::Clamp.new.tap { |c| c.maximum_size = 800 }

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 24).tap { |box| box.add_css_class('detail') }
  end

  def header = @header ||= Gtk::Box.new(:horizontal, 24)

  def ext_icon
    @ext_icon ||= Gtk::Image.new.tap do |image|
      image.focusable = true
      image.halign = :center
      image.valign = :center
      image.pixel_size = 64
      image.icon_name = 'puzzle-piece-symbolic'
    end
  end

  def header_suffix = @header_suffix ||= Gtk::Box.new(:horizontal, 24)

  def title_box
    @title_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.hexpand = true
      box.valign = :center
    end
  end

  def ext_title
    @ext_title ||= Gtk::Label.new.tap do |label|
      label.add_css_class('title-1')
      label.ellipsize = :end
      label.lines = 2
      label.selectable = true
      label.wrap = true
      label.wrap_mode = :word_char
      label.xalign = 0
    end
  end

  def ext_author
    @ext_author ||= Gtk::Label.new.tap do |label|
      label.add_css_class('author-link')
      label.use_markup = true
      label.xalign = 0
      label.ellipsize = :end
      label.selectable = true
    end
  end

  def tools_stack = @tools_stack ||= Gtk::Stack.new

  def install_button = @install_button ||= InstallButton.new

  def installed_tools_box = @installed_tools_box ||= Gtk::Box.new(:horizontal, 16)
  def installed_buttons_box = @installed_buttons_box ||= Gtk::Box.new(:horizontal, 6)

  def remove_btn
    @remove_btn ||= Gtk::Button.new.tap do |button|
      button.add_css_class('circular')
      button.add_css_class('destructive-action')
      button.icon_name = 'user-trash-symbolic'
      button.valign = :center
      button.tooltip_text = REMOVE_TOOLTIP
      button.action_name = 'page.remove'
    end
  end

  def prefs_btn
    @prefs_btn ||= Gtk::Button.new.tap do |button|
      button.add_css_class('circular')
      button.icon_name = 'settings-symbolic'
      button.valign = :center
      button.tooltip_text = PREFS_TOOLTIP
      button.action_name = 'page.open-prefs'
    end
  end

  def ext_toggle
    @ext_toggle ||= Gtk::Switch.new.tap do |switch|
      switch.valign = :center
      switch.tooltip_text = TOGGLE_TOOLTIP
    end
  end

  def screenshot_container = @screenshot_container ||= Gtk::Overlay.new

  def ext_screenshot_popout_button
    @ext_screenshot_popout_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('osd')
      button.add_css_class('circular')
      button.icon_name = 'pip-out-symbolic'
      button.halign = :end
      button.valign = :end
      button.margin_top = 8
      button.margin_bottom = 8
      button.margin_start = 8
      button.margin_end = 8
      button.tooltip_text = POPOUT_TOOLTIP
      button.action_name = 'win.show-screenshot'
      button.visible = false
    end
  end

  def ext_screenshot = @ext_screenshot ||= Screenshot.new.tap { |widget| widget.focusable = true }

  def description_box = @description_box ||= Gtk::Box.new(:vertical, 0)

  def description_heading
    @description_heading ||= Gtk::Label.new(DESCRIPTION_HEADING).tap do |label|
      label.add_css_class('title-4')
      label.add_css_class('detail-heading')
      label.xalign = 0
    end
  end

  def ext_description
    @ext_description ||= Gtk::Label.new.tap do |label|
      label.add_css_class('multiline')
      label.xalign = 0
      label.wrap = true
      label.wrap_mode = :word_char
      label.selectable = true
    end
  end

  def details_group = @details_group ||= Adwaita::PreferencesGroup.new

  def downloads_row
    @downloads_row ||= Adwaita::ActionRow.new.tap do |row|
      row.add_prefix(row_icon('folder-download-symbolic'))
      row.title = DOWNLOADS_TITLE
      row.add_suffix(downloads_label)
    end
  end

  def downloads_label = @downloads_label ||= Gtk::Label.new.tap { |label| label.add_css_class('numeric') }

  def version_row
    @version_row ||= Adwaita::ActionRow.new.tap do |row|
      row.add_prefix(row_icon('system-software-install-symbolic'))
      row.action_name = 'detail.show-versions'
      row.activatable = true
      row.title = VERSION_TITLE
      row.add_suffix(version_row_box)
    end
  end

  def version_row_box
    @version_row_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.append(update_icon)
      box.append(out_of_date_icon)
      box.append(version_label)
      box.append(Gtk::Image.new.tap { |image| image.icon_name = 'go-next-symbolic' })
    end
  end

  def update_icon
    @update_icon ||= Gtk::Image.new.tap do |image|
      image.add_css_class('update')
      image.icon_name = 'software-update-available-symbolic'
      image.valign = :center
      image.margin_start = 9
      image.margin_end = 9
      image.visible = false
      image.tooltip_text = UPDATE_TOOLTIP
    end
  end

  def out_of_date_icon
    @out_of_date_icon ||= Gtk::Image.new.tap do |image|
      image.add_css_class('error')
      image.icon_name = 'clock-alt-symbolic'
      image.valign = :center
      image.margin_start = 9
      image.margin_end = 9
      image.visible = false
      image.tooltip_text = OUT_OF_DATE_TOOLTIP
    end
  end

  def version_label = @version_label ||= Gtk::Label.new.tap { |label| label.add_css_class('numeric') }

  def session_modes_row
    @session_modes_row ||= Adwaita::ActionRow.new.tap do |row|
      row.add_prefix(row_icon('session-modes-symbolic'))
      row.title = SESSION_MODES_TITLE
      row.visible = false
      row.add_suffix(session_modes_label)
    end
  end

  def session_modes_label = @session_modes_label ||= Gtk::Label.new

  def location_row
    @location_row ||= Adwaita::ActionRow.new.tap do |row|
      row.add_prefix(row_icon('system-file-manager-symbolic'))
      row.action_name = 'detail.show-files-or-copy-path'
      row.activatable = true
      row.title = LOCATION_TITLE
      row.add_suffix(location_row_folder_icon)
      row.add_suffix(location_row_copy_icon)
      row.visible = false
    end
  end

  def location_row_folder_icon = @location_row_folder_icon ||= Gtk::Image.new.tap { |i| i.icon_name = 'folder-open-symbolic' }
  def location_row_copy_icon = @location_row_copy_icon ||= Gtk::Image.new.tap { |i| i.icon_name = 'edit-copy-symbolic' }

  def links_group = @links_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = LINKS_TITLE }

  def link_homepage
    @link_homepage ||= Adwaita::ActionRow.new.tap do |row|
      row.add_prefix(row_icon('go-home-symbolic'))
      row.action_name = 'detail.open-homepage'
      row.activatable = true
      row.title = HOMEPAGE_TITLE
      row.add_suffix(Gtk::Image.new.tap { |i| i.icon_name = 'external-link-symbolic' })
      row.visible = false
    end
  end

  def link_donation
    @link_donation ||= Adwaita::ActionRow.new.tap do |row|
      row.add_prefix(row_icon('donation-symbolic'))
      row.title = DONATE_TITLE
      row.activatable = true
      row.add_suffix(Gtk::Image.new.tap { |i| i.icon_name = 'external-link-symbolic' })
      row.visible = false
      row.action_name = 'detail.open-donation'
    end
  end

  def links_donations
    @links_donations ||= Adwaita::ExpanderRow.new.tap do |row|
      row.add_prefix(row_icon('donation-symbolic'))
      row.title = DONATE_TITLE
      row.visible = false
    end
  end

  def link_extensions
    @link_extensions ||= Adwaita::ActionRow.new.tap do |row|
      row.add_prefix(row_icon('web-browser-symbolic'))
      row.action_name = 'detail.open-extensions'
      row.activatable = true
      row.title = VIEW_ON_EXTENSIONS_TITLE
      row.add_suffix(Gtk::Image.new.tap { |i| i.icon_name = 'external-link-symbolic' })
    end
  end

  def comments_section = @comments_section ||= Gtk::Box.new(:vertical, 0)

  def comments_heading
    @comments_heading ||= Gtk::Label.new(REVIEWS_TITLE).tap do |label|
      label.add_css_class('title-4')
      label.add_css_class('detail-heading')
      label.selectable = true
      label.xalign = 0
    end
  end

  def comment_stack = @comment_stack ||= Gtk::Stack.new.tap { |s| s.vexpand = true }

  def comment_spinner
    @comment_spinner ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'content-loading-symbolic'
      image.icon_size = :large
      image.valign = :center
    end
  end

  def comment_disabled_label
    @comment_disabled_label ||= wrapping_label(REVIEWS_DISABLED)
  end

  def comment_error_box = @comment_error_box ||= Gtk::Box.new(:vertical, 6)

  def comment_error_heading
    @comment_error_heading ||= Gtk::Label.new(ERROR_TITLE).tap do |label|
      label.add_css_class('heading')
      label.selectable = true
      label.valign = :start
      label.xalign = 0
    end
  end

  def comment_error_label
    @comment_error_label ||= Gtk::Label.new.tap do |label|
      label.add_css_class('body')
      label.selectable = true
      label.use_markup = true
      label.valign = :start
      label.xalign = 0
    end
  end

  def comment_empty_label = @comment_empty_label ||= wrapping_label(REVIEWS_EMPTY)

  def comment_page = @comment_page ||= Gtk::Box.new(:vertical, 12)

  def comment_box
    @comment_box ||= Adwaita::WrapBox.new.tap do |box|
      box.orientation = :vertical
      box.child_spacing = 12
      box.line_homogeneous = true
      box.line_spacing = 12
    end
  end

  def show_more_btn
    @show_more_btn ||= Gtk::Button.new.tap do |button|
      button.add_css_class('pill')
      button.can_shrink = true
      button.halign = :center
      button.label = SHOW_ALL_LABEL
      button.use_underline = true
    end
  end

  def comment_provider = @comment_provider ||= CommentProvider.new
  def versions_provider = @versions_provider ||= VersionsProvider.new
  def image_resolver = @image_resolver ||= ImageResolver.new
  def data_provider = @data_provider ||= DataProvider.new

  private

    def row_icon(icon_name) = Gtk::Image.new.tap { |image| image.icon_name = icon_name }

    def wrapping_label(text)
      Gtk::Label.new(text).tap do |label|
        label.selectable = true
        label.valign = :start
        label.wrap = true
        label.xalign = 0
      end
    end

    def detail_actions
      @detail_actions ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(simple_action('show-versions') { show_versions })
        group.add_action(simple_action('show-error') { show_error_details })
        group.add_action(simple_action('show-files-or-copy-path') { show_files_or_copy_path })
        group.add_action(simple_action('open-homepage') { open_homepage })
        group.add_action(simple_action('open-donation') { open_uri(@uri_donations.first) })
        group.add_action(donation_action)
        group.add_action(simple_action('open-extensions') { open_uri(@uri_extensions) })
      end
    end

    def page_actions
      @page_actions ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(simple_action('remove') { page_remove })
        group.add_action(simple_action('open-prefs') { page_open_prefs })
      end
    end

    def donation_action
      Gio::SimpleAction.new('open-donations', GLib::VariantType.new('i')).tap do |action|
        action.signal_connect('activate') { |_action, parameter| open_uri(@uri_donations[parameter.to_i]) }
      end
    end

    def simple_action(name, &block)
      Gio::SimpleAction.new(name).tap { |action| action.signal_connect('activate') { block.call } }
    end

    def open_uri(uri)
      unless uri.to_s.empty?
        Gtk::UriLauncher.new(uri.to_s).launch(root, nil)
      end
    end

    def on_scroll_changed
      title_revealer.reveal_child = scroll_area.vadjustment.value.positive?
    end

    def on_author_link_activated(_uri)
      username = @data&.creator_username.to_s
      if username.empty?
        false
      else
        ext_icon.grab_focus
        activate_action(
          'win.show-author',
          GLib::Variant.parse("(#{@data.creator_id.to_i}, \"#{username}\", \"#{@data.creator.to_s.gsub('"', '\\"')}\")"),
        )
        true
      end
    end

    def install_remote
      warn = install_button.state == Types::InstallButtonState::UNSUPPORTED
      install_button.state = Types::InstallButtonState::INSTALLING
      ext_author.grab_focus
      activate_action('ext.install', GLib::Variant.parse("(\"#{@uuid}\", #{warn})"))
    end

    def on_toggle_changed(state)
      extension = manager.by_uuid(@uuid)
      if extension.nil?
        false
      else
        ExtensionToggle.apply(
          manager,
          extension,
          ext_toggle,
          state,
        )
      end
    end

    def show_versions = versions_dialog.present(root)

    def versions_dialog
      VersionsDialog.new(@uuid, shell_version: shell_version, installed_version: installed_version).tap do |dialog|
        dialog.build
      end
    end

    def installed_version = manager.by_uuid(@uuid)&.version.to_i

    def show_error_details
      if @error_text
        ExtensionErrorDialog.new(@data&.name, @error_text, @data&.homepage).build.present(root)
      end
    end

    def show_files_or_copy_path
      extension = manager.by_uuid(@uuid)
      if extension
        if extension.is_user
          Gtk::FileLauncher.new(Gio::File.new_for_path(extension.path)).launch(root, nil)
        else
          Gdk::Display.default.clipboard.set(extension.path.to_s)
          toast_overlay.add_toast(Adwaita::Toast.new(COPIED_TOAST))
        end
      end
    end

    def open_homepage = open_uri(@data&.homepage)

    def page_remove
      extension = manager.by_uuid(@uuid)
      if extension
        manager.remove_extension(extension)
      end
    end

    def page_open_prefs
      extension = manager.by_uuid(@uuid)
      if extension
        manager.open_prefs(extension)
      end
    end

    def update_tools_stack
      installed = manager.installed_uuid?(@uuid)
      if installed
        tools_stack.visible_child_name = 'installed-tools-page'
      else
        tools_stack.visible_child_name = 'uninstalled-tools-page'
      end
      if installed
        update_installed_tools(manager.by_uuid(@uuid))
      else
        update_icon.visible = false
        out_of_date_icon.visible = false
        error_banner.revealed = false
        location_row.visible = false
      end
    end

    def update_installed_tools(extension)
      prefs_btn.visible = extension.has_prefs == true
      remove_btn.visible = extension.is_user == true
      update_icon.visible = extension.has_update == true
      out_of_date_icon.visible = extension.state == Types::ExtensionState::OUT_OF_DATE
      location_row.subtitle = extension.path.to_s
      location_row.visible = true
      location_row_folder_icon.visible = extension.is_user == true
      location_row_copy_icon.visible = extension.is_user != true
      if extension.error.to_s.empty?
        @error_text = nil
      else
        @error_text = extension.error
      end
      error_banner.revealed = !@error_text.nil?
      ExtensionToggle.bind(extension, ext_toggle)
    end

    def update_session_modes_row(session_modes)
      label = format_session_modes(session_modes)
      session_modes_row.visible = !label.to_s.empty?
      if label
        session_modes_label.label = label.to_s
      end
    end

    def format_session_modes(session_modes)
      Array(session_modes).filter_map { |mode| SESSION_MODE_LABELS[mode] }.join(', ')
    end

    def show_more_comments = CommentDialog.new(@data.id.to_i).build.present(root)

    def on_data_loaded(result, error)
      if error
        on_data_error(error)
      else
        on_data_ready(result)
      end
    end

    def on_data_error(error)
      if !manager.installed_uuid?(@uuid)
        if error.respond_to?(:status_code) && error.status_code == 404
          stack.visible_child_name = 'page_empty'
        else
          error_status.description = error.message.to_s
          stack.visible_child_name = 'page_error'
        end
      else
        populate_local_only
      end
    end

    def populate_local_only
      ext_icon.icon_name = 'puzzle-piece-symbolic'
      extension = manager.by_uuid(@uuid)
      if extension
        version_label.label = local_version_label(extension)
        update_session_modes_row(extension.session_modes)
      end

      version_row.activatable = false
      downloads_row.visible = false
      screenshot_container.visible = false
      link_extensions.visible = false
      comments_section.visible = false

      update_donation_rows(@data.donation_urls)
      links_group.visible = link_homepage.visible || link_donation.visible || links_donations.visible

      update_tools_stack
      update
    end

    def local_version_label(extension)
      if !extension.version_name.to_s.empty?
        extension.version_name
      elsif !extension.version.to_s.empty?
        extension.version
      else
        UNKNOWN_VERSION
      end
    end

    def on_data_ready(result)
      @data.web_data = result
      self.title = result.name.to_s
      window_title.title = result.name.to_s
      window_title.subtitle = result.uuid.to_s

      ext_icon.icon_name = 'puzzle-piece-symbolic'
      ext_icon.tooltip_text = "#{result.name} Icon"
      ext_title.label = result.name.to_s
      ext_author.label = Utils.format_author_link(result.creator, result.creator_username)

      @icon_request&.cancel
      @icon_request = image_resolver.resolve(result.icon) do |paintable, err|
        unless err
          ext_icon.set_from_paintable(paintable)
        end
      end

      load_screenshot(result)

      @versions_request&.cancel
      @versions_next_url = nil
      @versions_request = versions_provider.query(result.uuid) { |page, err| on_versions_loaded(page, err) }

      update_donation_rows(result.donation_urls)

      @uri_extensions = URI.join('https://extensions.gnome.org/', result.link.to_s).to_s
      link_extensions.subtitle = @uri_extensions
      link_extensions.visible = true

      ext_description.label = result.description.to_s
      downloads_label.label = Utils.format_downloads(result.downloads)
      downloads_row.visible = true

      @comments_request&.cancel
      comment_stack.visible_child_name = 'page_spinner'
      @comments_request = comment_provider.get_comments(result.id, false) { |comments, err| on_comments_loaded(comments, err) }

      update_tools_stack
      ext_icon.grab_focus
      scroll_area.vadjustment.value = 0
      stack.visible_child_name = 'page_detail'
    end

    def load_screenshot(result)
      if result.screenshot.to_s.empty?
        screenshot_container.visible = false
      else
        ext_screenshot.set_paintable(nil)
        ext_screenshot.reset
        screenshot_container.visible = true
        ext_screenshot_popout_button.visible = false

        @screenshot_request&.cancel
        @screenshot_request = image_resolver.resolve(result.screenshot) do |paintable, err|
          unless err
            @screenshot = paintable
            ext_screenshot.set_paintable(paintable)
            ext_screenshot.display
            ext_screenshot_popout_button.visible = true
          end
        end
      end
    end

    def on_versions_loaded(page, error)
      if error
        on_versions_unsupported
      else
        on_versions_page(page)
      end
    end

    def on_versions_unsupported
      installed = manager.installed_uuid?(@uuid)
      if installed
        @version_state = Types::InstallButtonState::INSTALLED
      else
        @version_state = Types::InstallButtonState::UNSUPPORTED
      end
      version_label.label = UNSUPPORTED_VERSION
      update_session_modes_row(manager.by_uuid(@uuid)&.session_modes)
      update
    end

    def on_versions_page(page)
      compatible = each_item(page.model).find { |item| item.supports_shell_version?(shell_version) }
      if compatible
        apply_compatible_version(compatible)
      elsif page.next_url
        @versions_request = versions_provider.query_next(page.next_url) { |next_page, err| on_versions_loaded(next_page, err) }
      else
        on_versions_unsupported
      end
    end

    def apply_compatible_version(result)
      installed = manager.installed_uuid?(@uuid)
      if installed
        @version_state = Types::InstallButtonState::INSTALLED
      else
        @version_state = Types::InstallButtonState::DEFAULT
      end
      if result.version_name.to_s.empty?
        version_label.label = result.version.to_s
      else
        version_label.label = result.version_name
      end
      update_session_modes_row(result.session_modes)
      update
    end

    # Reads every item out of the model in one pass and keeps them in a plain
    # Ruby Array. A Gio::ListStore holds only the GObject; calling #get_item
    # again later, once the Ruby wrapper it handed back the first time has
    # been collected, hands back a bare object with none of its fields set
    # and crashes the bindings outright (browse_page.rb documents the same
    # bug for its own search results). Reading the whole model right away is
    # what keeps a live reference to every wrapper for as long as this method
    # needs them.
    def each_item(model)
      Array.new(model.n_items) { |index| model.get_item(index) }
    end

    def update_donation_rows(donation_urls)
      link_donation.visible = false
      links_donations.visible = false
      remove_donation_rows

      urls = Array(donation_urls)
      @uri_donations = urls

      if urls.length == 1
        link_donation.subtitle = urls.first
        link_donation.visible = true
      elsif urls.length > 1
        urls.each_with_index { |_url, index| links_donations.add_row(donation_row(index)) }
        links_donations.expanded = false
        links_donations.visible = true
      end
    end

    def remove_donation_rows
      (@donation_rows || []).each { |row| links_donations.remove(row) }
      @donation_rows = []
    end

    def donation_row(index)
      Adwaita::ActionRow.new.tap do |row|
        row.title = @uri_donations[index]
        row.activatable = true
        row.action_name = 'detail.open-donations'
        row.action_target_value = GLib::Variant.new(index, 'i')
        row.add_suffix(Gtk::Image.new.tap { |i| i.icon_name = 'external-link-symbolic' })
        (@donation_rows ||= []) << row
      end
    end

    def on_comments_loaded(comments, error)
      if error
        on_comments_error(error)
      else
        on_comments_ready(comments)
      end
    end

    def on_comments_error(error)
      if error.respond_to?(:status_code) && error.status_code == 403
        comment_stack.visible_child_name = 'page_disabled'
      else
        comment_error_label.label = error.message.to_s
        comment_stack.visible_child_name = 'page_error'
      end
    end

    def on_comments_ready(comments)
      count = comments.n_items
      if count.zero?
        comment_stack.visible_child_name = 'page_empty'
      else
        show_more_btn.visible = count >= COMMENT_FEW_THRESHOLD
        comment_stack.visible_child_name = 'page_comments'
      end

      comment_box.remove_all
      each_item(comments).each do |comment|
        comment_box.append(CommentTile.new(comment).build.tap { |tile| tile.add_css_class('card') })
      end
    end
end
