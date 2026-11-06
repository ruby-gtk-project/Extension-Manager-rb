# frozen_string_literal: true

require 'adwaita'
require_relative 'image_resolver'
require_relative 'profile_provider'
require_relative 'search_provider'
require_relative 'search_row'

# An extension author's profile: their avatar, name and every extension of
# theirs the website lists.
#
# Ported from upstream's src/exm-author-page.blp and src/exm-author-page.c:
# #load asks SearchProvider for every extension by username (a hundred per
# page is upstream's whole page), keeps only the ones whose creator-username
# matches exactly — the endpoint matches loosely — and asks ProfileProvider
# for the avatar in parallel. The avatar fetch is best-effort: upstream drops
# its error silently and leaves the initials showing, which is what
# `on_avatar_resolved` here does too.
class AuthorPage < Adwaita::NavigationPage
  EXTENSIONS_TITLE = 'Authored Extensions'
  EMPTY_TITLE = 'No Extensions Found'
  ERROR_TITLE = 'Connection Error'
  AVATAR_SIZE = 96

  attr_reader :manager

  def initialize
    super(content_bin, '')
    @manager = nil
    @username = nil
    @creator_id = 0
    @search_request = nil
    @avatar_request = nil
    @rows = []
  end

  def manager=(value)
    @manager = value
  end

  def build
    tap do |page|
      content_bin.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scroll_area
      end

      header_bar.title_widget = title_revealer
      title_revealer.child = window_title

      scroll_area.child = clamp
      clamp.child = content_box

      content_box.tap do |box|
        box.append(identity_box)
        box.append(stack)
      end

      identity_box.tap do |box|
        box.append(avatar)
        box.append(author_name)
      end

      stack.tap do |s|
        s.add_named(spinner, 'page_spinner')
        s.add_named(extensions_list, 'page_list')
        s.add_named(empty_box, 'page_empty')
        s.add_named(error_box, 'page_error')
        s.visible_child_name = 'page_spinner'
      end

      empty_box.tap do |box|
        box.append(empty_icon)
        box.append(empty_label)
      end

      error_box.tap do |box|
        box.append(error_icon)
        box.append(error_heading)
        box.append(error_label)
      end

      scroll_area.vadjustment.signal_connect('value-changed') { on_scroll_changed }
    end
  end

  # Ported from upstream's exm_author_page_load: resets the avatar to
  # initials-only, cancels whatever the last author asked for, and queries
  # both providers in parallel.
  def load(creator_id, username, display_name)
    @creator_id = creator_id
    @username = username.to_s

    self.title = display_name.to_s
    window_title.title = display_name.to_s
    author_name.label = display_name.to_s
    avatar.text = display_name.to_s
    avatar.custom_image = nil
    avatar.grab_focus

    stack.visible_child_name = 'page_spinner'

    @search_request&.cancel
    @avatar_request&.cancel

    @search_request = search_provider.query_by_creator(@username) do |results, error|
      on_extensions_loaded(results, error)
    end

    @avatar_request = profile_provider.get(creator_id) do |profile, error|
      on_profile_loaded(profile, error)
    end
  end

  def content_bin = @content_bin ||= Adwaita::Bin.new
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

  def scroll_area = @scroll_area ||= Gtk::ScrolledWindow.new.tap { |area| area.vexpand = true }
  def clamp = @clamp ||= Adwaita::Clamp.new

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
      box.margin_top = 24
      box.margin_bottom = 24
      box.margin_start = 12
      box.margin_end = 12
      box.valign = :center
    end
  end

  def identity_box = @identity_box ||= Gtk::Box.new(:vertical, 12).tap { |box| box.halign = :center }

  def avatar
    @avatar ||= Adwaita::Avatar.new(AVATAR_SIZE, nil, true).tap do |widget|
      widget.focusable = true
    end
  end

  def author_name
    @author_name ||= Gtk::Label.new.tap do |label|
      label.add_css_class('title-1')
      label.justify = :center
      label.wrap = true
      label.wrap_mode = :word_char
      label.selectable = true
    end
  end

  def stack = @stack ||= Gtk::Stack.new.tap { |s| s.vexpand = true }

  def spinner
    @spinner ||= Adwaita::Spinner.new.tap do |widget|
      widget.add_css_class('dimmed')
      widget.halign = :center
      widget.valign = :start
      widget.margin_top = 24
      widget.height_request = 48
      widget.width_request = 48
    end
  end

  def extensions_list
    @extensions_list ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.add_css_class('boxed-list')
      group.title = EXTENSIONS_TITLE
      group.valign = :center
    end
  end

  def empty_box
    @empty_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.margin_start = 12
      box.margin_end = 12
      box.margin_top = 36
      box.margin_bottom = 24
    end
  end

  def empty_icon
    @empty_icon ||= Gtk::Image.new.tap do |image|
      image.add_css_class('dimmed')
      image.icon_name = 'puzzle-piece-symbolic'
      image.halign = :center
      image.margin_bottom = 24
      image.pixel_size = 128
    end
  end

  def empty_label
    @empty_label ||= Gtk::Label.new(EMPTY_TITLE).tap do |label|
      label.add_css_class('title-1')
      label.wrap = true
      label.wrap_mode = :word_char
    end
  end

  def error_box
    @error_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.margin_start = 12
      box.margin_end = 12
      box.margin_top = 36
      box.margin_bottom = 24
    end
  end

  def error_icon
    @error_icon ||= Gtk::Image.new.tap do |image|
      image.add_css_class('dimmed')
      image.icon_name = 'offline-symbolic'
      image.halign = :center
      image.margin_bottom = 24
      image.pixel_size = 128
    end
  end

  def error_heading
    @error_heading ||= Gtk::Label.new(ERROR_TITLE).tap do |label|
      label.add_css_class('title-1')
      label.margin_bottom = 12
      label.wrap = true
      label.wrap_mode = :word_char
    end
  end

  def error_label
    @error_label ||= Gtk::Label.new.tap do |label|
      label.wrap = true
      label.wrap_mode = :word_char
    end
  end

  def search_provider = @search_provider ||= SearchProvider.new
  def profile_provider = @profile_provider ||= ProfileProvider.new
  def image_resolver = @image_resolver ||= ImageResolver.new

  private

    def on_scroll_changed
      title_revealer.reveal_child = scroll_area.vadjustment.value.positive?
    end

    # The endpoint matches loosely (by name), so upstream filters the results
    # down to the exact username before showing them.
    def on_extensions_loaded(results, error)
      if error
        error_label.label = error.message.to_s
        stack.visible_child_name = 'page_error'
      else
        matching = each_item(results.model).select { |result| result.creator_username == @username }
        populate(matching)
        if matching.empty?
          stack.visible_child_name = 'page_empty'
        else
          stack.visible_child_name = 'page_list'
        end
      end
    end

    # Reads every item out of the model in one pass before building any rows
    # from them. A Gio::ListStore holds only the GObject, and re-fetching an
    # item from it later, once its Ruby wrapper has been collected, hands
    # back a bare object with none of its fields set and crashes the
    # bindings outright (browse_page.rb documents the same bug).
    def each_item(model)
      Array.new(model.n_items) { |index| model.get_item(index) }
    end

    def populate(results)
      @rows.each { |row| extensions_list.remove(row) }
      @rows = results.map { |result| row_for(result) }
      @rows.each { |row| extensions_list.add(row) }
    end

    def row_for(result)
      SearchRow.new(manager, result, show_icon: true).build.tap do |row|
        row.show_creator = false
      end
    end

    def on_profile_loaded(profile, error)
      if error.nil? && profile&.avatar
        @avatar_request = image_resolver.resolve(profile.avatar) do |paintable, resolve_error|
          if resolve_error.nil?
            avatar.custom_image = paintable
          end
        end
      end
    end
end
