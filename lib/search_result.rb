# frozen_string_literal: true

require 'adwaita'

# One extension as extensions.gnome.org describes it.
#
# Ported from upstream's src/web/model/exm-search-result.c, including its
# JsonSerializable override: the website nests the author inside a "creator"
# object, so the display name, username and id are lifted out of it the way
# upstream's exm_search_result_deserialize_property does.
#
# A GLib::Object subclass rather than a plain Ruby one because these live in a
# Gio::ListStore, which stores GObjects of a declared type.
class SearchResult < GLib::Object
  type_register

  attr_accessor :id,
    :uuid,
    :name,
    :creator,
    :creator_username,
    :creator_id,
    :description,
    :created,
    :updated,
    :downloads,
    :popularity,
    :screenshot,
    :icon,
    :rating,
    :rated,
    :url,
    :donation_urls,
    :link

  def self.from_json(object)
    new.tap do |result|
      result.assign(object)
    end
  end

  def initialize
    super()
    @id = 0
    @creator_id = 0
    @downloads = 0
    @popularity = 0
    @rating = 0.0
    @rated = 0
    @donation_urls = []
  end

  # The website's field names are the property names upstream declares, so the
  # assignment is a straight copy bar the creator object and the shell version
  # map, which arrives as an object keyed by version string.
  def assign(object)
    @id = object.fetch('id', 0).to_i
    @uuid = object['uuid']
    @name = object['name']
    @description = object['description']
    @created = object['created']
    @updated = object['updated']
    @downloads = object.fetch('downloads', 0).to_i
    @popularity = object.fetch('popularity', 0).to_i
    @screenshot = object['screenshot']
    @icon = object['icon']
    @rating = object.fetch('rating', 0).to_f
    @rated = object.fetch('rated', 0).to_i
    @url = object['url']
    @link = object['link']
    @donation_urls = Array(object['donation_urls'])
    assign_creator(object['creator'])
  end

  # Upstream prefers the creator's display name and falls back to the username,
  # while keeping the username and id for the author page to look up.
  def assign_creator(creator)
    case creator
    when Hash
      @creator_username = creator['username']
      @creator_id = creator.fetch('id', 0).to_i
      @creator = creator['display_name'] || creator['username']
    when String
      @creator = creator
    end
  end
end
