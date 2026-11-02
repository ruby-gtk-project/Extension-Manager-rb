# frozen_string_literal: true

require 'adwaita'
require_relative 'rating'
require_relative 'utils'

# One review, as shown in the detail view and the comment dialog.
#
# Ported from upstream's src/exm-comment-tile.blp and
# src/exm-comment-tile.c: the author's name, an "Author" badge when the
# reviewer wrote the extension, the star rating when they gave one, the review
# body as markup, and the date through upstream's format_comment_date closure.
#
# Upstream is a Gtk.Widget with the CSS element name "comment-tile"; a Ruby
# subclass cannot set a CSS element name, so the box carries the matching
# style class, which lib/style.css matches.
class CommentTile < Gtk::Box
  attr_reader :comment

  def initialize(comment)
    super(:vertical, 6)
    add_css_class('comment-tile')
    self.focusable = true
    @comment = comment
  end

  def build
    tap do |tile|
      header.tap do |box|
        box.append(author_label)
        box.append(author_badge)
        box.append(rating.build)
      end

      tile.append(header)
      tile.append(body_label)
      tile.append(date_label)
    end
  end

  def header = @header ||= Gtk::Box.new(:horizontal, 0)

  def author_label
    @author_label ||= Gtk::Label.new(comment.author.to_s).tap do |label|
      label.add_css_class('heading')
      label.max_width_chars = 20
      label.wrap = true
      label.wrap_mode = :word
      label.xalign = 0
    end
  end

  def author_badge
    @author_badge ||= Gtk::Label.new('Author').tap do |label|
      label.add_css_class('author-badge')
      label.valign = :center
      label.visible = comment.is_extension_creator == true
    end
  end

  def rating
    @rating ||= Rating.new(rating: comment.rating.to_i).tap do |widget|
      widget.halign = :end
      widget.hexpand = true
      widget.visible = comment.rating.to_i.positive?
    end
  end

  def body_label
    @body_label ||= Gtk::Label.new(comment.comment.to_s).tap do |label|
      label.add_css_class('multiline')
      label.use_markup = true
      label.wrap = true
      label.wrap_mode = :word_char
      label.xalign = 0
      label.max_width_chars = 30
    end
  end

  def date_label
    @date_label ||= Gtk::Label.new(Utils.format_comment_date(comment.date)).tap do |label|
      label.add_css_class('dimmed')
      label.xalign = 0
    end
  end
end
