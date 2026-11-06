# frozen_string_literal: true

require 'adwaita'
require 'time'
require_relative 'versions_provider'

# An extension's full release history.
#
# Ported from upstream's src/exm-versions-dialog.blp and
# src/exm-versions-dialog.c: a spinner while the first page loads, "No
# Version History" for an extension with none, and otherwise a boxed list of
# releases — newest first — each row showing the release name (or bare
# version number when it has none), the date, the shell versions it supports
# as a wrapped row of pills, and a check mark on the row matching the
# installed version. "Load More Versions" fetches the next page and appends
# to the same list, exactly as upstream's load-more signal does.
class VersionsDialog < Adwaita::Dialog
  TITLE = 'Version History'
  LOADING_TITLE = 'Loading Versions'
  EMPTY_TITLE = 'No Version History'
  LOAD_MORE_TITLE = '_Load More Versions'
  INSTALLED_TOOLTIP = 'Installed Version'

  # A row that remembers the release version it was built for, which is what
  # the list's sort function and the installed-version lookup both need. A
  # bare Adw.ActionRow has nowhere the Ruby bindings can stash that; upstream
  # keeps it with g_object_set_data on the same row instead.
  class VersionRow < Gtk::ListBoxRow
    attr_accessor :version
  end

  def initialize(uuid, shell_version: nil, installed_version: 0)
    super()
    self.content_width = 600
    self.content_height = 600
    self.width_request = 360
    self.height_request = 294
    self.title = TITLE
    @uuid = uuid
    @installed_version = installed_version.to_i
    @current_key = current_key_for(shell_version)
    @next_url = nil
    @request = nil
  end

  def build
    tap do |dialog|
      dialog.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(Adwaita::HeaderBar.new)
        view.content = stack
      end

      stack.tap do |s|
        s.add_named(loading_status, 'loading')
        s.add_named(empty_status, 'empty')
        s.add_named(scrolled_window, 'list')
        s.visible_child_name = 'loading'
      end

      scrolled_window.child = clamp
      clamp.child = content_box

      content_box.tap do |box|
        box.append(version_list)
        box.append(more_list)
      end

      more_list.append(more_button)
      more_button.signal_connect('activated') { on_load_more }

      signal_connect('closed') { @request&.cancel }

      load_first_page
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def stack = @stack ||= Gtk::Stack.new

  def loading_status
    @loading_status ||= Adwaita::StatusPage.new.tap { |page| page.title = LOADING_TITLE }
  end

  def empty_status
    @empty_status ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'dialog-question-symbolic'
      page.title = EMPTY_TITLE
    end
  end

  def scrolled_window = @scrolled_window ||= Gtk::ScrolledWindow.new

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |c|
      c.maximum_size = 600
      c.margin_top = 12
      c.margin_bottom = 12
      c.margin_start = 12
      c.margin_end = 12
    end
  end

  def content_box = @content_box ||= Gtk::Box.new(:vertical, 12)

  def version_list
    @version_list ||= Gtk::ListBox.new.tap do |list|
      list.add_css_class('boxed-list')
      list.selection_mode = :none
      list.set_sort_func { |a, b| b.version <=> a.version }
    end
  end

  def more_list
    @more_list ||= Gtk::ListBox.new.tap do |list|
      list.add_css_class('boxed-list')
      list.selection_mode = :none
      list.visible = false
    end
  end

  def more_button
    @more_button ||= Adwaita::ButtonRow.new.tap do |row|
      row.start_icon_name = 'view-more-symbolic'
      row.title = LOAD_MORE_TITLE
      row.use_underline = true
    end
  end

  def versions_provider = @versions_provider ||= VersionsProvider.new(shell_version: nil)

  private

    def current_key_for(shell_version)
      shell_version.to_s.split('.', 2).then do |parts|
        if parts.empty? || parts.first.to_s.empty?
          -1
        else
          major = parts.fetch(0).to_i
          minor = parts.fetch(1, '0').to_i
          normalized_key(major, minor)
        end
      end
    end

    def normalized_key(major, minor)
      (major >= 40 ? 0 : minor).then { |min| (major * 1000) + min }
    end

    def load_first_page
      @request = versions_provider.query(@uuid) { |results, error| on_page_loaded(results, error) }
    end

    def on_load_more
      more_button.sensitive = false
      @request = versions_provider.query_next(@next_url) { |results, error| on_page_loaded(results, error) }
    end

    def on_page_loaded(results, error)
      if error.nil?
        @next_url = results.next_url
        add_releases(results.model)
      end
      finish_loading
    end

    # Upstream's exm_versions_dialog_finish: a list with nothing in it falls
    # back to the empty page, and "Load More" shows only while there is a
    # further page to fetch.
    def finish_loading
      if stack.visible_child_name != 'list'
        stack.visible_child_name = 'empty'
      end
      more_list.visible = !@next_url.to_s.empty?
      more_button.sensitive = true
    end

    # Read every item out in one pass before building any rows from them.
    # A Gio::ListStore holds only the GObject, and re-fetching an item from
    # it later, once its Ruby wrapper has been collected, hands back a bare
    # object with none of its fields set and crashes the bindings outright
    # (browse_page.rb documents the same bug for its own search results).
    def add_releases(model)
      Array.new(model.n_items) { |index| model.get_item(index) }.each { |result| add_release(result) }
    end

    def add_release(result)
      version_list.append(row_for(result))
      stack.visible_child_name = 'list'
    end

    def row_for(result)
      VersionRow.new.tap do |row|
        row.version = result.version
        row.activatable = false
        row.child = action_row_for(result)
      end
    end

    def action_row_for(result)
      Adwaita::ActionRow.new.tap do |row|
        row.title = title_for(result)
        subtitle_for(result).then do |subtitle|
          if subtitle
            row.subtitle = subtitle
          end
        end
        if result.version == @installed_version
          row.add_prefix(installed_icon)
        end
        row.add_suffix(shell_versions_box(result.shell_versions))
      end
    end

    def title_for(result)
      if result.version_name.to_s.empty?
        result.version.to_s
      else
        result.version_name
      end
    end

    def subtitle_for(result)
      date = format_date(result.created)
      if !result.version_name.to_s.empty? && date
        "v#{result.version} · #{date}"
      elsif !result.version_name.to_s.empty?
        "v#{result.version}"
      else
        date
      end
    end

    def format_date(created)
      Time.iso8601(created.to_s).getutc.strftime('%x')
    rescue ArgumentError, TypeError
      Time.iso8601("#{created.to_s[0, 10]}T00:00:00Z").getutc.strftime('%x')
    rescue ArgumentError, TypeError
      nil
    end

    def installed_icon
      Gtk::Image.new.tap do |icon|
        icon.icon_name = 'supported-symbolic'
        icon.valign = :center
        icon.add_css_class('accent')
        icon.tooltip_text = INSTALLED_TOOLTIP
      end
    end

    def shell_versions_box(shell_versions)
      Adwaita::WrapBox.new.tap do |box|
        box.child_spacing = 4
        box.line_spacing = 4
        box.valign = :center
        box.margin_start = 8
        each_shell_version(shell_versions).each { |label| box.append(label) }
      end
    end

    def each_shell_version(shell_versions)
      seen = {}
      Array(shell_versions&.versions).filter_map do |entry|
        key = normalized_key(entry.major, entry.minor)
        unless seen[key]
          seen[key] = true
          shell_version_label(entry.major, entry.minor, key)
        end
      end
    end

    def shell_version_label(major, minor, key)
      Gtk::Label.new(format_version(major, minor)).tap do |label|
        label.add_css_class('version-label')
        if key == @current_key
          label.add_css_class('current')
        end
      end
    end

    def format_version(major, minor)
      if major >= 40
        major.to_s
      else
        "#{major}.#{minor}"
      end
    end
end
