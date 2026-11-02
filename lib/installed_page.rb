# frozen_string_literal: true

require 'adwaita'
require_relative 'extension'
require_relative 'extension_row'
require_relative 'types'

# The Installed view.
#
# Ported from upstream's src/exm-installed-page.blp and
# src/exm-installed-page.c: a crossfading stack of four pages — the list, the
# search results, "No Results Found" and "No Extensions Installed" — with the
# updates banner, the global "Use Extensions" switch and the user-installed
# and system groups on the list page.
#
# The model chain is upstream's: the manager's list is sorted by name (by
# enabled first and then name when the setting says so), then filtered three
# ways — by the search text for the results group, and by is-user both ways
# round for the user and system groups. Upstream builds the sorters and
# filters from Gtk property expressions; this port uses custom sorters and
# filters over the same properties, which the Ruby bindings handle without the
# expression's ownership quirks.
class InstalledPage < Adwaita::Bin
  SEARCH_PLACEHOLDER_TITLE = 'No Results Found'
  SEARCH_PLACEHOLDER_DESCRIPTION = 'Try a different search or search online'
  EMPTY_TITLE = 'No Extensions Installed'
  EMPTY_DESCRIPTION = 'Search online to install extensions'
  GLOBAL_TOGGLE_TITLE = 'Use Extensions'
  GLOBAL_TOGGLE_SUBTITLE = 'Extensions can cause performance and stability issues'
  USER_GROUP_TITLE = 'User-Installed Extensions'
  SYSTEM_GROUP_TITLE = 'System Extensions'
  SELECT_TOOLTIP = 'Select Extensions'
  BANNER_DELAY_MS = 500

  attr_reader :manager, :search_query

  def initialize(manager, settings)
    super()
    @manager = manager
    @settings = settings
    @search_query = ''
    @search_mode_enabled = false
    @selection_mode = false
    @n_selected = 0
    @selection_callbacks = []
    @sort_enabled_first = settings['sort-enabled-first'] == true
  end

  def build
    tap do |page|
      page.child = stack

      stack.tap do |widget|
        widget.add_named(list_page, 'page_list')
        widget.add_named(results_page, 'page_results')
        widget.add_named(no_results_page, 'page_no_results')
        widget.add_named(empty_page, 'page_empty')
      end

      list_page.tap do |widget|
        widget.banner = updates_banner
        widget.add(global_group)
        widget.add(user_prefs_group)
        widget.add(system_prefs_group)
      end

      global_group.add(global_toggle)
      global_toggle.add_prefix(global_toggle_icon)

      results_page.add(search_prefs_group)

      user_prefs_group.header_suffix = select_button

      select_button.signal_connect('toggled') { self.selection_mode = select_button.active? }
      global_toggle.signal_connect('notify::active') { on_global_toggled }
      page.insert_action_group('page', action_group)

      bind_manager
      @settings.watch('sort-enabled-first') { |value| self.sort_enabled_first = value }
    end
  end

  # Fed by the window's search bar: the entry's text and whether the bar is
  # open, which together decide which of the four pages shows.
  def search_query=(query)
    @search_query = query.to_s
    search_filter.changed(:different)
    switch_page
  end

  def search_mode_enabled=(enabled)
    @search_mode_enabled = enabled == true
    switch_page
  end

  def sort_enabled_first=(enabled)
    @sort_enabled_first = enabled == true
    if @sort_enabled_first
      sorted_model.sorter = enabled_first_sorter
    else
      sorted_model.sorter = alphabetical_sorter
    end
  end

  # Selection mode belongs to the page; the window's header bar and action bar
  # follow it, and every selectable row is told so it can show its check
  # button.
  def selection_mode=(enabled)
    @selection_mode = enabled == true
    unless @selection_mode
      @n_selected = 0
      notify_selection
    end
    select_button.active = @selection_mode
    propagate_selection_mode
    update_system_group_visibility
  end

  def selection_mode? = @selection_mode
  def n_selected = @n_selected

  def on_selection_changed(&block) = @selection_callbacks << block

  # Upstream collects the selected rows' uuids first and only then asks the
  # manager to remove them, because removing rebuilds the groups underneath.
  def uninstall_selected
    selected_uuids.each do |uuid|
      manager.by_uuid(uuid).then { |extension| if extension then manager.remove_extension(extension) end }
    end
  end

  def stack
    @stack ||= Gtk::Stack.new.tap do |widget|
      widget.transition_type = :crossfade
      widget.vexpand = true
    end
  end

  def list_page = @list_page ||= Adwaita::PreferencesPage.new
  def results_page = @results_page ||= Adwaita::PreferencesPage.new

  def updates_banner
    @updates_banner ||= Adwaita::Banner.new('').tap do |banner|
      banner.button_label = '_Log Out…'
      banner.button_style = :suggested
      banner.action_name = 'app.logout'
    end
  end

  def global_group = @global_group ||= Adwaita::PreferencesGroup.new

  def global_toggle
    @global_toggle ||= Adwaita::SwitchRow.new.tap do |row|
      row.title = GLOBAL_TOGGLE_TITLE
      row.subtitle = GLOBAL_TOGGLE_SUBTITLE
    end
  end

  def global_toggle_icon
    @global_toggle_icon ||= Gtk::Image.new.tap { |image| image.icon_name = 'puzzle-piece-symbolic' }
  end

  def user_prefs_group
    @user_prefs_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = USER_GROUP_TITLE
    end
  end

  def system_prefs_group
    @system_prefs_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = SYSTEM_GROUP_TITLE
    end
  end

  def search_prefs_group = @search_prefs_group ||= Adwaita::PreferencesGroup.new

  def select_button
    @select_button ||= Gtk::ToggleButton.new.tap do |button|
      button.add_css_class('flat')
      button.valign = :center
      button.icon_name = 'check-round-outline-symbolic'
      # Translators: Tooltip of the Select button in the user-installed extensions group
      button.tooltip_text = SELECT_TOOLTIP
    end
  end

  def no_results_page
    @no_results_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'edit-find-symbolic'
      page.title = SEARCH_PLACEHOLDER_TITLE
      page.description = SEARCH_PLACEHOLDER_DESCRIPTION
      page.child = search_online_button
    end
  end

  def empty_page
    @empty_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'puzzle-piece-symbolic'
      page.title = EMPTY_TITLE
      page.description = EMPTY_DESCRIPTION
      page.child = empty_search_online_button
    end
  end

  def search_online_button = @search_online_button ||= search_online_button_widget
  def empty_search_online_button = @empty_search_online_button ||= search_online_button_widget

  # Sorting by name, or — when the setting is on — by whether the extension is
  # running and then by name, which is upstream's multi sorter over its
  # custom enabled comparison and its alphabetical one.
  #
  # The expression is assigned rather than passed to the constructor: a
  # Gtk expression is not a GObject, and handing one to these constructors
  # makes the bindings try to reference it, which prints a GObject critical.
  def alphabetical_sorter
    @alphabetical_sorter ||= Gtk::StringSorter.new(nil).tap do |sorter|
      sorter.expression = Gtk::PropertyExpression.new(Extension, nil, 'name')
    end
  end

  def enabled_sorter
    @enabled_sorter ||= Gtk::NumericSorter.new(nil).tap do |sorter|
      sorter.expression = Gtk::PropertyExpression.new(Extension, nil, 'sort-rank')
      sorter.sort_order = :ascending
    end
  end

  def enabled_first_sorter
    @enabled_first_sorter ||= Gtk::MultiSorter.new.tap do |sorter|
      sorter.append(enabled_sorter)
      sorter.append(alphabetical_sorter)
    end
  end

  def search_filter
    @search_filter ||= Gtk::CustomFilter.new do |extension|
      extension.name.to_s.downcase.include?(search_query.downcase)
    end
  end

  def user_filter = @user_filter ||= Gtk::CustomFilter.new { |extension| extension.is_user == true }
  def system_filter = @system_filter ||= Gtk::CustomFilter.new { |extension| extension.is_user != true }

  def sorted_model = @sorted_model ||= Gtk::SortListModel.new(manager.extensions, initial_sorter)
  def search_model = @search_model ||= Gtk::FilterListModel.new(sorted_model, search_filter)
  def user_model = @user_model ||= Gtk::FilterListModel.new(sorted_model, user_filter)
  def system_model = @system_model ||= Gtk::FilterListModel.new(sorted_model, system_filter)

  def action_group
    @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(selection_changed_action)
    end
  end

  def selection_changed_action
    @selection_changed_action ||= Gio::SimpleAction.new('selection-changed').tap do |action|
      action.signal_connect('activate') { on_page_selection_changed }
    end
  end

  private

    def search_online_button_widget
      Gtk::Button.new.tap do |button|
        button.add_css_class('pill')
        button.label = '_Search Online'
        button.use_underline = true
        button.halign = :center
        button.action_name = 'win.search-online'
      end
    end

    # Upstream's on_bind_manager: bind the models, follow the update count,
    # mirror the global switch, then ask the shell for updates — in that
    # order, so the answer is not missed.
    def bind_manager
      bind_groups
      manager.on_updates_available { |count| on_updates_available(count) }
      manager.on_extensions_enabled_changed { |enabled| global_toggle.active = enabled }
      manager.on_supported_changed { |supported| if supported then on_supported end }
      global_toggle.active = manager.extensions_enabled?
      switch_page

      if manager.supported?
        manager.check_for_updates
      end
    end

    def on_supported
      global_toggle.active = manager.extensions_enabled?
      switch_page
      manager.check_for_updates
    end

    def bind_groups
      bind_group(search_prefs_group, search_model)
      bind_group(user_prefs_group, user_model)
      bind_group(system_prefs_group, system_model)

      user_model.signal_connect('notify::n-items') { update_user_group_visibility }
      system_model.signal_connect('notify::n-items') { update_system_group_visibility }
      search_model.signal_connect('notify::n-items') { switch_page }
      manager.extensions.signal_connect('items-changed') { |_model, position, removed, added| on_extensions_changed(position, removed, added) }

      update_user_group_visibility
      update_system_group_visibility
    end

    def bind_group(group, model)
      group.bind_model(model) { |extension| row_for(extension) }
    end

    def row_for(extension)
      ExtensionRow.new(extension, manager).build.tap do |row|
        row.selection_mode = @selection_mode
      end
    end

    def initial_sorter
      if @sort_enabled_first
        enabled_first_sorter
      else
        alphabetical_sorter
      end
    end

    def switch_page
      if @search_mode_enabled && search_model.n_items.positive?
        stack.visible_child_name = 'page_results'
      elsif @search_mode_enabled
        stack.visible_child_name = 'page_no_results'
      elsif user_prefs_group.visible? || system_prefs_group.visible?
        stack.visible_child_name = 'page_list'
      else
        stack.visible_child_name = 'page_empty'
      end
    end

    def update_user_group_visibility
      user_prefs_group.visible = user_model.n_items.positive?
      switch_page
    end

    # The system group is hidden while selecting, because system extensions
    # cannot be uninstalled from here.
    def update_system_group_visibility
      system_prefs_group.visible = system_model.n_items.positive? && !@selection_mode
      switch_page
    end

    # Translators: '%d' = number of extensions that will be updated
    def on_updates_available(count)
      if count == 1
        updates_banner.title = '1 extension will be updated on next login'
      else
        updates_banner.title = "#{count} extensions will be updated on next login"
      end

      # Short delay to draw user attention
      GLib::Timeout.add(BANNER_DELAY_MS) do
        updates_banner.revealed = true
        GLib::Source::REMOVE
      end
    end

    def on_global_toggled
      if global_toggle.active? != manager.extensions_enabled?
        manager.extensions_enabled = global_toggle.active?
      end
    end

    # Upstream keeps keyboard focus on the row that just changed, which the
    # enabled-first sort would otherwise move out from under the user.
    def on_extensions_changed(position, removed, added)
      if @sort_enabled_first && !(removed.positive? && added.positive?)
        focus_changed_extension(position)
      end
    end

    def focus_changed_extension(position)
      if position < manager.extensions.n_items
        manager.extensions.get_item(position).then do |extension|
          if stack.visible_child_name == 'page_results'
            focus_matching(search_prefs_group, extension)
          else
            unless focus_matching(user_prefs_group, extension)
              focus_matching(system_prefs_group, extension)
            end
          end
        end
      end
    end

    def focus_matching(group, extension)
      each_row(group).find { |row| row.extension == extension }.then do |row|
        if row
          row.focus_toggle
          true
        else
          false
        end
      end
    end

    def propagate_selection_mode
      [user_prefs_group, search_prefs_group].each do |group|
        each_row(group).each { |row| row.selection_mode = @selection_mode }
      end
    end

    def on_page_selection_changed
      count_selected.then do |count|
        if count != @n_selected
          @n_selected = count
          notify_selection
        end
      end
    end

    def count_selected
      [user_prefs_group, search_prefs_group].sum do |group|
        each_row(group).count(&:selected?)
      end
    end

    def selected_uuids
      [user_prefs_group, search_prefs_group].flat_map do |group|
        each_row(group).select(&:selected?).map { |row| row.extension.uuid }
      end.uniq
    end

    # Adw.PreferencesGroup answers get_row(index) until it runs out of rows,
    # which is how upstream walks the rows it did not keep a handle on.
    def each_row(group)
      Enumerator.new do |yielder|
        index = 0
        row = group.get_row(index)
        while row
          yielder << row
          index += 1
          row = group.get_row(index)
        end
      end
    end

    def notify_selection
      @selection_callbacks.each { |callback| callback.call(@n_selected) }
    end
end
