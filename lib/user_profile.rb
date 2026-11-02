# frozen_string_literal: true

require 'adwaita'

# An extension author's profile on extensions.gnome.org.
#
# Ported from upstream's src/web/model/exm-user-profile.c, whose four
# properties are deserialized straight from the API's member names.
class UserProfile < GLib::Object
  type_register

  attr_accessor :id, :username, :display_name, :avatar

  def self.from_json(object)
    new.tap do |profile|
      profile.assign(object)
    end
  end

  def initialize
    super()
    @id = 0
  end

  def assign(object)
    @id = object.fetch('id', 0).to_i
    @username = object['username']
    @display_name = object['display_name']
    @avatar = object['avatar']
  end

  # The name to show: the display name when the author set one, the username
  # otherwise.
  def name
    if display_name.to_s.empty?
      username
    else
      display_name
    end
  end
end
