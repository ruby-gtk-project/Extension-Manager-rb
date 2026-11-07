# frozen_string_literal: true

require 'adwaita'
require_relative 'types'
require_relative 'upgrade_result'
require_relative 'versions_provider'

# The "will my extensions survive a GNOME upgrade" dialog, opened from the
# primary menu's _Upgrade Assistant item.
#
# Ported from upstream's src/exm-upgrade-assistant.blp and
# src/exm-upgrade-assistant.c: a select page (the current-shell-version
# description, a GNOME version drop-down and a "Check Compatibility" button)
# that pushes a results page — a spinner while every installed extension's
# release history is fetched, an error page if the network fails outright,
# and otherwise a progress bar plus a sorted, boxed-list breakdown of
# user-installed and system extensions, with a "Copy to Clipboard" report at
# the bottom.
class UpgradeAssistant < Adwaita::Dialog
  TITLE = 'Upgrade Assistant'
  CHECK_LABEL = '_Check Compatibility'
  CONNECTION_ERROR_TITLE = 'Connection Error'
  USER_GROUP_TITLE = 'User-Installed Extensions'
  SYSTEM_GROUP_TITLE = 'System Extensions'
  COPY_LABEL = '_Copy to Clipboard'
  COPIED_TOAST = 'Copied'
  NO_EXTENSIONS_TOAST = 'No Extensions Installed'
  SUPPORTED_TOOLTIP = 'A compatible version of the extension exists'
  UNSUPPORTED_TOOLTIP = 'No compatible version of the extension exists'
  UNKNOWN_TOOLTIP = 'This extension is not hosted on extensions.gnome.org. Its compatibility cannot be determined.'

  # GNOME 40 came out in March 2021 and a new release ships every March and
  # September since, exactly as upstream's populate_drop_down guesses.
  BASE_VERSION = 40
  BASE_YEAR = 2021
  MINIMUM_VERSION = 43

  attr_accessor :manager

  def initialize
    super()
    self.content_width = 400
    self.content_height = 600
    self.title = TITLE
    @target_shell_version = nil
    @total_extensions = 0
    @number_checked = 0
    @number_supported = 0
    @waiting_on_tasks = false
    @requests = []
  end

  def build
    tap do |dialog|
      dialog.child = toast_overlay
      toast_overlay.child = navigation_view
      navigation_view.add(select_page)
      navigation_view.add(results_page)
      populate_versions

      select_body.tap do |box|
        box.append(select_icon)
        box.append(select_fields)
        box.append(run_button)
      end

      select_fields.tap do |box|
        box.append(description)
        box.append(version_group)
      end

      version_group.add(drop_down)

      stack.tap do |s|
        s.add_named(waiting_status, 'waiting')
        s.add_named(error_status, 'error')
        s.add_named(results_prefs_page, 'results')
      end

      results_prefs_page.tap do |page|
        page.add(summary_group)
        page.add(user_prefs_group)
        page.add(system_prefs_group)
        page.add(copy_group)
      end

      summary_group.add(summary_box)

      summary_box.tap do |box|
        box.append(summary_top)
        box.append(progress_bar)
        box.append(summary_bottom)
      end

      copy_group.add(copy_row)

      run_button.signal_connect('clicked') { do_compatibility_check }
      copy_row.signal_connect('activated') { copy_to_clipboard }
      results_page.signal_connect('hidden') { cancel_requests }
    end
  end

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def navigation_view = @navigation_view ||= Adwaita::NavigationView.new

  def select_page
    @select_page ||= Adwaita::NavigationPage.new(select_toolbar, TITLE).tap { |page| page.can_pop = false }
  end

  def select_toolbar
    @select_toolbar ||= Adwaita::ToolbarView.new.tap do |view|
      view.add_top_bar(Adwaita::HeaderBar.new)
      view.content = select_clamp
    end
  end

  def select_clamp = @select_clamp ||= Adwaita::Clamp.new.tap { |clamp| clamp.child = select_body }

  def select_body
    @select_body ||= Gtk::Box.new(:vertical, 18).tap do |box|
      box.add_css_class('detail')
      box.vexpand = true
    end
  end

  def select_icon
    @select_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'software-update-available-symbolic'
      image.icon_size = :large
      image.focusable = true
    end
  end

  def select_fields
    @select_fields ||= Gtk::Box.new(:vertical, 24).tap { |box| box.vexpand = true }
  end

  def description
    @description ||= Gtk::Label.new.tap { |label| label.wrap = true }
  end

  def version_group = @version_group ||= Adwaita::PreferencesGroup.new

  def drop_down
    @drop_down ||= Adwaita::ComboRow.new.tap { |row| row.title = 'GNOME' }
  end

  def run_button
    @run_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class('pill')
      button.add_css_class('suggested-action')
      button.label = CHECK_LABEL
      button.halign = :center
      button.valign = :end
      button.use_underline = true
    end
  end

  def results_page
    @results_page ||= Adwaita::NavigationPage.new(results_toolbar, TITLE)
  end

  def results_toolbar
    @results_toolbar ||= Adwaita::ToolbarView.new.tap do |view|
      view.add_top_bar(Adwaita::HeaderBar.new)
      view.content = stack
    end
  end

  def stack = @stack ||= Gtk::Stack.new

  def waiting_status
    @waiting_status ||= Adwaita::StatusPage.new.tap { |page| page.title = checked_count_title }
  end

  def error_status
    @error_status ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'offline-symbolic'
      page.title = CONNECTION_ERROR_TITLE
    end
  end

  def results_prefs_page = @results_prefs_page ||= Adwaita::PreferencesPage.new

  def summary_group = @summary_group ||= Adwaita::PreferencesGroup.new
  def summary_box = @summary_box ||= Gtk::Box.new(:vertical, 24)
  def summary_top = @summary_top ||= Gtk::Label.new.tap { |label| label.wrap = true }

  def progress_bar
    @progress_bar ||= Gtk::ProgressBar.new.tap do |bar|
      bar.show_text = true
      bar.margin_start = 24
      bar.margin_end = 24
      bar.focusable = true
    end
  end

  def summary_bottom = @summary_bottom ||= Gtk::Label.new.tap { |label| label.wrap = true }

  def user_prefs_group
    @user_prefs_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = USER_GROUP_TITLE }
  end

  def system_prefs_group
    @system_prefs_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = SYSTEM_GROUP_TITLE }
  end

  def copy_group = @copy_group ||= Adwaita::PreferencesGroup.new

  def copy_row
    @copy_row ||= Adwaita::ButtonRow.new.tap do |row|
      row.start_icon_name = 'edit-copy-symbolic'
      row.title = COPY_LABEL
      row.use_underline = true
    end
  end

  def user_results_store = @user_results_store ||= Gio::ListStore.new(UpgradeResult)
  def system_results_store = @system_results_store ||= Gio::ListStore.new(UpgradeResult)

  def versions_provider = @versions_provider ||= VersionsProvider.new

  private

    def alphabetical_sorter
      Gtk::StringSorter.new(nil).tap do |sorter|
        sorter.expression = Gtk::PropertyExpression.new(UpgradeResult, nil, 'name')
      end
    end

    def sorted_user_results = Gtk::SortListModel.new(user_results_store, alphabetical_sorter)
    def sorted_system_results = Gtk::SortListModel.new(system_results_store, alphabetical_sorter)

    def bind_result_groups
      user_prefs_group.bind_model(sorted_user_results) { |result| row_for(result) }
      system_prefs_group.bind_model(sorted_system_results) { |result| row_for(result) }
    end

    def row_for(result)
      Adwaita::ActionRow.new.tap do |row|
        row.title = result.name.to_s
        row.subtitle = result.local_data&.uuid.to_s
        row.add_suffix(status_icon_for(result))
      end
    end

    def status_icon_for(result)
      status = support_status(result)
      Gtk::Image.new.tap do |image|
        image.pixel_size = 24
        image.focusable = true
        case status
        when :supported
          image.icon_name = 'supported-symbolic'
          image.add_css_class('success')
          image.tooltip_text = SUPPORTED_TOOLTIP
        when :unsupported
          image.icon_name = 'unsupported-symbolic'
          image.add_css_class('error')
          image.tooltip_text = UNSUPPORTED_TOOLTIP
        else
          image.icon_name = 'unknown-symbolic'
          image.add_css_class('warning')
          image.tooltip_text = UNKNOWN_TOOLTIP
        end
      end
    end

    def support_status(result)
      web_data = result.web_data
      if web_data.nil?
        :unknown
      elsif web_data.supports_shell_version?(@target_shell_version)
        :supported
      else
        :unsupported
      end
    end

    def populate_versions
      Gtk::StringList.new(available_versions.map(&:to_s)).then do |list|
        drop_down.model = list
        drop_down.selected = list.n_items - 1
      end
    end

    # Guesses the newest released GNOME version from today's date, the way
    # upstream's populate_drop_down does: two releases a year, March and
    # September.
    def available_versions
      now = Time.now.utc
      current = BASE_VERSION + ((now.year - BASE_YEAR) * 2)
      current -= 1 if now.month < 3
      current += 1 if now.month >= 9
      current = [MINIMUM_VERSION, current].max
      (BASE_VERSION..current).to_a
    end

    def checked_count_title = "Checked #{@number_checked}/#{@total_extensions} Extensions"

    def do_compatibility_check
      selected_version.then do |version|
        if version
          @target_shell_version = version
          start_compatibility_check
        end
      end
    end

    def selected_version
      drop_down.model&.then { |list| list.get_string(drop_down.selected) if drop_down.selected >= 0 }
    end

    def start_compatibility_check
      extensions = Array.new(manager.extensions.n_items) { |index| manager.extensions.get_item(index) }
      if extensions.empty?
        toast_overlay.add_toast(Adwaita::Toast.new(NO_EXTENSIONS_TOAST))
      else
        run_compatibility_check(extensions)
      end
    end

    def run_compatibility_check(extensions)
      stack.visible_child_name = 'waiting'
      navigation_view.push(results_page)
      reset_counters(extensions.size)
      bind_result_groups

      extensions.each { |extension| check_extension(extension) }
      @waiting_on_tasks = true
    end

    def reset_counters(total)
      @total_extensions = total
      @number_checked = 0
      @number_supported = 0
      @waiting_on_tasks = false
      waiting_status.title = checked_count_title
      user_results_store.remove_all
      system_results_store.remove_all
    end

    def check_extension(extension)
      @requests << versions_provider.query(extension.uuid) do |results, error|
        on_versions_loaded(extension, results, error)
      end
    end

    def on_versions_loaded(extension, results, error)
      if error
        show_error(error)
      else
        web_version, compatible_version = pick_versions(results.model)
        if compatible_version.nil? && results.next_url
          @requests << versions_provider.query_next(results.next_url) do |more, more_error|
            on_versions_loaded(extension, more, more_error)
          end
        else
          finish_extension(extension, web_version, compatible_version)
        end
      end
    end

    def pick_versions(model)
      items = Array.new(model.n_items) { |index| model.get_item(index) }
      web_version = items.first
      compatible_version = items.find { |item| item.supports_shell_version?(@target_shell_version) }
      [web_version, compatible_version]
    end

    def finish_extension(extension, web_version, compatible_version)
      @number_checked += 1
      waiting_status.title = checked_count_title

      UpgradeResult.new.tap do |result|
        result.local_data = extension
        result.web_data = compatible_version || web_version
        @number_supported += 1 if support_status(result) == :supported
        store_for(extension).append(result)
      end

      display_results if @waiting_on_tasks && @number_checked == @total_extensions
    end

    def store_for(extension)
      if extension.is_user
        user_results_store
      else
        system_results_store
      end
    end

    def show_error(error)
      error_status.description = error.message
      stack.visible_child_name = 'error'
    end

    def display_results
      fraction = @total_extensions.zero? ? 0.0 : (@number_supported.to_f / @total_extensions)
      progress_bar.fraction = fraction
      progress_bar.text = "#{(fraction * 100).to_i}% Compatible"
      recolor_progress_bar(fraction)

      summary_top.markup =
        "<b>#{@number_supported} out of #{@total_extensions}</b> extensions currently installed " \
        "on this system have been marked as supporting <b>GNOME #{@target_shell_version}</b>"
      summary_bottom.markup = summary_bottom_text

      stack.visible_child_name = 'results'
    end

    def summary_bottom_text
      unsupported = @total_extensions - @number_supported
      if unsupported.zero?
        "If you switch to GNOME #{@target_shell_version} now, all of your extensions should work"
      else
        "If you switch to GNOME #{@target_shell_version} now, #{unsupported} of your extensions might not work"
      end
    end

    def recolor_progress_bar(fraction)
      progress_bar.remove_css_class('success')
      progress_bar.remove_css_class('warning')
      progress_bar.remove_css_class('error')

      if fraction >= 1.0
        progress_bar.add_css_class('success')
      elsif fraction > 0.3
        progress_bar.add_css_class('warning')
      else
        progress_bar.add_css_class('error')
      end
    end

    def copy_to_clipboard
      Gdk::Display.default.clipboard.set_text(report_text)
      toast_overlay.add_toast(Adwaita::Toast.new(COPIED_TOAST))
    end

    def report_text
      fraction = @total_extensions.zero? ? 0.0 : (@number_supported.to_f / @total_extensions)
      [].tap do |lines|
        lines << "Extension Manager - Upgrade Assistant Report\n"
        lines << "Currently on: GNOME #{manager.shell_version}"
        lines << "Upgrading to: GNOME #{@target_shell_version}\n"
        lines << "On upgrading to GNOME #{@target_shell_version}, #{@number_supported} out of " \
          "#{@total_extensions} currently\ninstalled extensions will be compatible (#{(fraction * 100).to_i}%).\n"
        append_report_section(lines, 'User-Installed Extensions:', user_results_store)
        append_report_section(lines, 'System Extensions:', system_results_store)
      end.join("\n")
    end

    def append_report_section(lines, heading, store)
      if store.n_items.positive?
        lines << heading
        lines << ''
        Array.new(store.n_items) { |index| store.get_item(index) }.each { |result| append_report_result(lines, result) }
      end
    end

    def append_report_result(lines, result)
      lines << result.name.to_s
      lines << "Extension ID: #{result.local_data&.uuid}"
      lines << "Supported: #{report_support_text(result)}\n"
    end

    def report_support_text(result)
      case support_status(result)
      when :supported then 'Yes'
      when :unsupported then 'No'
      else 'Unknown'
      end
    end

    def cancel_requests
      @requests.each(&:cancel)
      @requests = []
    end
end
