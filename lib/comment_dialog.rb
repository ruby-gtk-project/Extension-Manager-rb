# frozen_string_literal: true

require 'adwaita'
require_relative 'comment_provider'
require_relative 'comment_tile'

# The full list of an extension's reviews, as a dialog.
#
# Ported from upstream's src/exm-comment-dialog.blp and
# src/exm-comment-dialog.c: a spinner while the full list loads (the detail
# view's own request asked for only a handful; this one asks CommentProvider
# with `all: true`), a connection-error page on failure, and a preferences
# group bound to the result, one CommentTile per review.
class CommentDialog < Adwaita::Dialog
  TITLE = 'Reviews and Comments'
  LOADING_TITLE = 'Loading'
  ERROR_TITLE = 'Connection Error'

  def initialize(web_id)
    super()
    self.content_width = 600
    self.content_height = 600
    self.width_request = 360
    self.height_request = 294
    self.title = TITLE
    @web_id = web_id
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
        s.add_named(loading_status, 'page_spinner')
        s.add_named(error_status, 'page_error')
        s.add_named(preferences_page, 'page_comments')
        s.visible_child_name = 'page_spinner'
      end

      preferences_page.add(preferences_group)

      signal_connect('closed') { @request&.cancel }

      load_comments
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
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

  def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new
  def preferences_group = @preferences_group ||= Adwaita::PreferencesGroup.new

  def comment_provider = @comment_provider ||= CommentProvider.new

  private

    def load_comments
      @request = comment_provider.get_comments(@web_id, true) do |comments, error|
        on_comments_loaded(comments, error)
      end
    end

    def on_comments_loaded(comments, error)
      if error
        error_status.description = error.message.to_s
        stack.visible_child_name = 'page_error'
      else
        stack.visible_child_name = 'page_comments'
        # The Gio::ListStore holds only the GObject; re-fetching an item from
        # it later, after its Ruby wrapper has been collected, hands back a
        # bare object with none of its fields set and crashes the bindings
        # outright (browse_page.rb documents the same bug). Reading every
        # item out in one pass, right after the model arrives, is what keeps
        # a live Ruby reference to each one.
        each_item(comments).each { |comment| preferences_group.add(row_for(comment)) }
      end
    end

    def each_item(model)
      Array.new(model.n_items) { |index| model.get_item(index) }
    end

    def row_for(comment)
      Gtk::ListBoxRow.new.tap do |row|
        row.activatable = false
        row.child = CommentTile.new(comment).build
      end
    end
end
