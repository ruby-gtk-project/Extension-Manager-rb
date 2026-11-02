# frozen_string_literal: true

require 'adwaita'

# The five-star strip beside a review.
#
# Ported from upstream's src/exm-rating.blp and src/exm-rating.c: five images
# in a horizontal box, filled left to right up to the rating, with the star
# count as the tooltip.
#
# Upstream is a Gtk.Widget with a bin layout wrapping that box and the CSS
# element name "rating"; a Ruby subclass cannot set a CSS element name, so the
# box is the widget and it carries the "rating" style class instead, which
# lib/style.css matches.
class Rating < Gtk::Box
  FILLED_ICON_NAME = 'star-filled-rounded-symbolic'
  EMPTY_ICON_NAME = 'star-outline-rounded-symbolic'
  STAR_COUNT = 5

  attr_reader :rating

  def initialize(rating: 0)
    super(:horizontal, 0)
    add_css_class('rating')
    @rating = rating
  end

  def build
    tap do |widget|
      stars.each { |star| widget.append(star) }
      widget.rating = @rating
    end
  end

  # Upstream resets every star to the outline and then fills the first
  # `rating` of them, so the strip never shows a stale fill.
  def rating=(value)
    @rating = value.to_i
    stars.each_with_index do |star, index|
      if index < @rating
        star.set_from_icon_name(FILLED_ICON_NAME)
      else
        star.set_from_icon_name(EMPTY_ICON_NAME)
      end
    end
    self.tooltip_text = tooltip_for(@rating)
  end

  def stars = @stars ||= Array.new(STAR_COUNT) { Gtk::Image.new }

  private

    # Translators: "%i" = the number of stars this review awarded
    def tooltip_for(count)
      if count == 1
        '1 Star'
      else
        "#{count} Stars"
      end
    end
end
