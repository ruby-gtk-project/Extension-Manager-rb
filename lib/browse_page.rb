# frozen_string_literal: true

require 'adwaita'
require_relative 'search_provider'
require_relative 'search_row'
require_relative 'types'

# The Browse view.
#
# Ported from upstream's src/exm-browse-page.blp and src/exm-browse-page.c: a
# status page holding the search entry, the sort drop-down and the ascending/
# descending toggle, over a crossfading stack of a spinner, the results, "No
# Results Found" and "Connection Error".
#
# The search behaviour is upstream's. The entry's 750 ms delay is what keeps a
# keystroke from becoming a request; realising the entry picks a random
# suggestion for the placeholder and fires the default search, which is the
# most popular extensions with no query at all; the drop-down's order follows
# the SearchSort enumeration so its index *is* the sort; and the order button
# only appears once a sort other than "None" is chosen, flipping that sort
# between its descending and ascending halves.
#
# "Load More Results" asks for the next page and appends it to the model the
# list is bound to, keeping the scroll position and moving focus to the first
# of the new rows, and the row disappears on the last page.
class BrowsePage < Adwaita::Bin
  STATUS_TITLE = 'Search for Extensions'
  STATUS_DESCRIPTION = "Enter a keyword to search 'extensions.gnome.org' for GNOME Shell Extensions"
  SEARCH_DELAY_MS = 750
  DESCENDING_ICON = 'view-sort-descending-symbolic'
  ASCENDING_ICON = 'view-sort-ascending-symbolic'
  DESCENDING_TOOLTIP = 'Descending Order'
  ASCENDING_TOOLTIP = 'Ascending Order'
  SORT_TOOLTIP = 'Sort search results'
  LOAD_MORE_TITLE = '_Load More Results'
  NO_RESULTS_TITLE = 'No Results Found'
  NO_RESULTS_DESCRIPTION = 'Try a different search'
  ERROR_TITLE = 'Connection Error'

  # The drop-down's items, in the order of Types::SearchSort's descending
  # values, so the selected index is the sort itself.
  #
  # Translators: dropdown items for sorting search results
  SORT_LABELS = ['None', 'Popularity', 'Downloads', 'Updated', 'Created'].freeze

  # Upstream reads these from src/res/suggestions.txt in its resource bundle;
  # this port ships the same file beside its stylesheet.
  SUGGESTIONS_FILE = File.expand_path('res/suggestions.txt', __dir__)
  FALLBACK_SUGGESTION = 'Blur my Shell'

  # Upstream's narrow breakpoint, which the rows read as "drop the install
  # button's label".
  NARROW_CONDITION = 'max-width: 400sp'

  # The ascending half of each sort, which the order button switches to.
  ASCENDING_OF = {
    Types::SearchSort::CREATED_DES    => Types::SearchSort::CREATED_ASC,
    Types::SearchSort::DOWNLOADS_DES  => Types::SearchSort::DOWNLOADS_ASC,
    Types::SearchSort::POPULARITY_DES => Types::SearchSort::POPULARITY_ASC,
    Types::SearchSort::UPDATED_DES    => Types::SearchSort::UPDATED_ASC,
  }.freeze

  attr_reader :manager

  def initialize(manager, on_show_detail: nil)
    super()
    @manager = manager
    @on_show_detail = on_show_detail
    @results_model = nil
    @current_page = 1
    @max_pages = 1
    @request = nil
    @rows = []
    @results = []
  end

  def build
    tap do |page|
      page.child = breakpoint_bin

      breakpoint_bin.tap do |bin|
        bin.add_breakpoint(narrow_breakpoint)
        bin.child = status_page
      end

      status_page.child = clamp
      clamp.child = content_box

      content_box.tap do |box|
        entry_box.tap do |inner|
          inner.append(search_entry)
          inner.append(order_button)
          inner.append(search_dropdown)
        end

        box.append(entry_box)
        box.append(search_stack)
      end

      search_stack.tap do |stack|
        stack.add_named(spinner, 'page_spinner')
        stack.add_named(results_box, 'page_results')
        stack.add_named(empty_box, 'page_empty')
        stack.add_named(error_box, 'page_error')
      end

      results_box.tap do |box|
        box.append(search_results)
        box.append(more_results_list)
      end

      more_results_list.append(more_results_button)

      empty_box.tap do |box|
        box.append(empty_icon)
        box.append(empty_title_label)
        box.append(empty_description_label)
      end

      error_box.tap do |box|
        box.append(error_icon)
        box.append(error_title_label)
        box.append(error_label)
      end

      connect_signals
      search_entry.key_capture_widget = page
    end
  end

  # The window's "Search Online" button and its win.search-online action put
  # the installed-search text here; setting the entry's text is what starts
  # the search, exactly as upstream's exm_browse_page_search does.
  def search(query)
    search_entry.text = query.to_s
  end

  def focus_entry
    search_entry.grab_focus
  end

  # Drops the request in flight, so an answer that is no longer wanted cannot
  # land on the page. Upstream cancels its GCancellable for the same reason.
  def cancel_requests
    @request&.cancel
    @rows.each(&:cancel_requests)
  end

  def breakpoint_bin
    @breakpoint_bin ||= Adwaita::BreakpointBin.new.tap do |bin|
      bin.width_request = 360
      bin.height_request = 294
    end
  end

  def narrow_breakpoint
    @narrow_breakpoint ||= Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(NARROW_CONDITION))
  end

  def status_page
    @status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.title = STATUS_TITLE
      page.description = STATUS_DESCRIPTION
      page.valign = :start
      page.vexpand = true
    end
  end

  def clamp = @clamp ||= Adwaita::Clamp.new
  def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

  def entry_box
    @entry_box ||= Gtk::Box.new(:horizontal, 0).tap { |box| box.add_css_class('linked') }
  end

  def search_entry
    @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
      entry.hexpand = true
      entry.search_delay = SEARCH_DELAY_MS
    end
  end

  def order_button
    @order_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = DESCENDING_ICON
      button.tooltip_text = DESCENDING_TOOLTIP
      button.visible = false
    end
  end

  def search_dropdown
    @search_dropdown ||= Gtk::DropDown.new(sort_model, nil).tap do |dropdown|
      dropdown.tooltip_text = SORT_TOOLTIP
    end
  end

  def sort_model = @sort_model ||= Gtk::StringList.new(SORT_LABELS)

  def search_stack = @search_stack ||= Gtk::Stack.new

  def spinner
    @spinner ||= Adwaita::Spinner.new.tap do |widget|
      widget.add_css_class('dimmed')
      widget.margin_top = 30
      widget.halign = :center
      widget.valign = :start
      widget.height_request = 64
      widget.width_request = 64
    end
  end

  def results_box = @results_box ||= Gtk::Box.new(:vertical, 12)

  def search_results
    @search_results ||= Gtk::ListBox.new.tap do |list|
      list.add_css_class('boxed-list')
      list.selection_mode = :none
    end
  end

  def more_results_list
    @more_results_list ||= Gtk::ListBox.new.tap do |list|
      list.add_css_class('boxed-list')
      list.selection_mode = :none
      list.visible = false
    end
  end

  def more_results_button
    @more_results_button ||= Adwaita::ButtonRow.new.tap do |row|
      row.start_icon_name = 'view-more-symbolic'
      row.title = LOAD_MORE_TITLE
      row.use_underline = true
    end
  end

  def empty_box = @empty_box ||= message_box
  def error_box = @error_box ||= message_box

  def empty_icon = @empty_icon ||= message_icon('edit-find-symbolic')
  def error_icon = @error_icon ||= message_icon('offline-symbolic')

  def empty_title_label = @empty_title_label ||= message_title(NO_RESULTS_TITLE)
  def error_title_label = @error_title_label ||= message_title(ERROR_TITLE)

  def empty_description_label = @empty_description_label ||= message_label(NO_RESULTS_DESCRIPTION)

  # The server's own message, which carries the markup upstream's two error
  # strings are written in.
  def error_label
    @error_label ||= message_label('').tap { |label| label.use_markup = true }
  end

  def search_provider = @search_provider ||= SearchProvider.new

  # The suggestions the placeholder is drawn from. A missing file leaves the
  # one hardcoded fallback upstream falls back to.
  def suggestions
    @suggestions ||= read_suggestions
  end

  def results_model = @results_model

  private

    def message_box
      Gtk::Box.new(:vertical, 0).tap do |box|
        box.margin_start = 12
        box.margin_end = 12
        box.margin_top = 36
        box.margin_bottom = 24
      end
    end

    def message_icon(icon_name)
      Gtk::Image.new.tap do |image|
        image.add_css_class('dimmed')
        image.icon_name = icon_name
        image.halign = :center
        image.margin_bottom = 24
        image.pixel_size = 128
      end
    end

    def message_title(text)
      Gtk::Label.new(text).tap do |label|
        label.add_css_class('title-1')
        label.margin_bottom = 12
        label.wrap = true
        label.wrap_mode = :word_char
      end
    end

    def message_label(text)
      Gtk::Label.new(text).tap do |label|
        label.margin_bottom = 12
        label.wrap = true
        label.wrap_mode = :word_char
      end
    end

    def connect_signals
      search_entry.signal_connect('realize') { on_search_entry_realize }
      search_entry.signal_connect('search-changed') { on_search_changed }
      search_entry.signal_connect('changed') { search_entry.grab_focus }
      search_dropdown.signal_connect('notify::selected') { on_search_changed }
      order_button.signal_connect('clicked') { on_order_button_clicked }
      more_results_button.signal_connect('activated') { on_load_more_results }
      search_results.signal_connect('row-activated') { |_list, row| row.activated }
      narrow_breakpoint.signal_connect('apply') { apply_compact(true) }
      narrow_breakpoint.signal_connect('unapply') { apply_compact(false) }
      manager.extensions.signal_connect('items-changed') { refresh_search }
    end

    def read_suggestions
      File.readlines(SUGGESTIONS_FILE, chomp: true).reject(&:empty?)
    rescue SystemCallError
      [FALLBACK_SUGGESTION]
    end

    # Realising the entry is upstream's cue to show a suggestion and run the
    # default search, so the view is never empty on first sight.
    def on_search_entry_realize
      search_entry.placeholder_text = suggestions.sample
      run_search('', Types::SearchSort::POPULARITY_DES)
    end

    # The drop-down's index is the descending half of the sort; the order
    # button, when it is showing ascending, moves it to the ascending half.
    def on_search_changed
      if search_entry.realized?
        selected_sort.then do |sort|
          order_button.visible = sort != Types::SearchSort::NONE
          run_search(search_entry.text, directed_sort(sort))
        end
      end
    end

    def selected_sort = search_dropdown.selected

    def directed_sort(sort)
      if order_button.icon_name == ASCENDING_ICON
        ASCENDING_OF.fetch(sort, Types::SearchSort::NONE)
      else
        sort
      end
    end

    def on_order_button_clicked
      if order_button.icon_name == DESCENDING_ICON
        order_button.icon_name = ASCENDING_ICON
        order_button.tooltip_text = ASCENDING_TOOLTIP
      else
        order_button.icon_name = DESCENDING_ICON
        order_button.tooltip_text = DESCENDING_TOOLTIP
      end

      on_search_changed
    end

    # A fresh search drops whatever was in flight, so the older answer cannot
    # overwrite the newer one — upstream's cancellable, by another name.
    def run_search(query, sort)
      search_stack.visible_child_name = 'page_spinner'
      @current_page = 1
      @results_model = nil
      @results = []
      @request&.cancel
      @request = search_provider.query(query, 1, sort) do |results, error|
        on_first_page_result(results, error)
      end
    end

    def on_first_page_result(results, error)
      if error
        show_error(error)
      else
        @max_pages = results.num_pages
        adopt_results(results.model)
        refresh_search
        update_load_more_button
      end
    end

    def show_error(error)
      error_label.label = error.message.to_s
      search_stack.visible_child_name = 'page_error'
    end

    # Binding the list box to the model is also what rebuilds every row, which
    # is how an install elsewhere in the app updates the buttons here: the
    # manager's list changing re-runs this.
    def refresh_search
      if @results_model.nil? || @results_model.n_items.zero?
        search_stack.visible_child_name = 'page_empty'
      else
        bind_results
        search_stack.visible_child_name = 'page_results'
      end
    end

    # The results are kept in a Ruby array as well as in the store. The store
    # holds only a GObject reference, and a result whose Ruby wrapper has been
    # collected comes back out of the store as a bare object with none of its
    # fields — recreating a wrapper inside the list box's widget function is
    # also what crashes the bindings outright. Holding the results here keeps
    # the wrappers the store hands back the ones that were put in.
    def adopt_results(model)
      @results_model = model
      @results = each_item(model)
    end

    def each_item(model)
      [].tap { |items| model.n_items.times { |index| items << model.get_item(index) } }
    end

    def bind_results
      @rows.each(&:cancel_requests)
      @rows = []
      search_results.bind_model(@results_model) { |result| row_for(result) }
    end

    def row_for(result)
      SearchRow.new(manager, result, show_icon: true, on_activated: @on_show_detail).build.tap do |row|
        row.compact = compact?
        @rows << row
      end
    end

    def compact? = !breakpoint_bin.current_breakpoint.nil?

    def apply_compact(compact)
      @rows.each { |row| row.compact = compact }
    end

    # The row goes once the last page is on screen, and comes back clickable
    # for every page before it.
    def update_load_more_button
      more_results_list.visible = @current_page != @max_pages
      more_results_button.sensitive = true
    end

    def on_load_more_results
      more_results_button.sensitive = false
      @current_page += 1
      @request&.cancel
      @request = search_provider.query(search_entry.text, @current_page, directed_sort(selected_sort)) do |results, error|
        on_next_page_result(results, error)
      end
    end

    # The scroll position is saved and put back, because appending to the
    # model grows the list under the scrolled window.
    def on_next_page_result(results, error)
      if error.nil?
        @max_pages = results.num_pages
        scroll_position.then do |position|
          append_results(results.model)
          restore_scroll(position)
        end
        update_load_more_button
      end
    end

    # Focus moves to the first of the new rows, which is what upstream grabs
    # as the list's last child right after appending the first of them.
    def append_results(model)
      @results_model.n_items.then do |first_new|
        each_item(model).then do |items|
          items.each { |item| @results_model.append(item) }
          @results.concat(items)
          search_results.get_row_at_index(first_new)&.grab_focus
        end
      end
    end

    # Adw.StatusPage wraps its child in a scrolled window, which is the one
    # upstream reaches for as the status page's first child.
    def scrolled_window
      status_page.first_child.then do |child|
        if child.is_a?(Gtk::ScrolledWindow)
          child
        end
      end
    end

    def scroll_position = scrolled_window&.vadjustment&.value

    def restore_scroll(position)
      if position
        scrolled_window&.vadjustment&.value = position
      end
    end
end
