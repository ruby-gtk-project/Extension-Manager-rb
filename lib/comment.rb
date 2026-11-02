# frozen_string_literal: true

require 'adwaita'

# One review on extensions.gnome.org.
#
# Ported from upstream's src/web/model/exm-comment.c, including its
# JsonSerializable override: the website nests the author in an object with a
# "username" member and the date in one with a "timestamp" member, and
# upstream's exm_comment_deserialize_property lifts both out.
class Comment < GLib::Object
  type_register

  attr_accessor :is_extension_creator, :comment, :author, :rating, :date

  def self.from_json(object)
    new.tap do |comment|
      comment.assign(object)
    end
  end

  def initialize
    super()
    @is_extension_creator = false
    @rating = 0
  end

  def assign(object)
    @is_extension_creator = object.fetch('is_extension_creator', false) == true
    @comment = object['comment']
    @rating = object.fetch('rating', 0).to_i
    @author = author_from(object['author'])
    @date = date_from(object['date'])
  end

  private

    def author_from(author)
      case author
      when Hash then author['username']
      else author
      end
    end

    def date_from(date)
      case date
      when Hash then date['timestamp']
      else date
      end
    end
end
