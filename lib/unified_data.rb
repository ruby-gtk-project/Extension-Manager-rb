# frozen_string_literal: true

require 'adwaita'
require_relative 'extension'
require_relative 'search_result'

# One extension, as the detail view needs it: whatever the website knows
# about it and whatever GNOME Shell knows about it, merged.
#
# Ported from upstream's src/exm-unified-data.c: every getter prefers the web
# data, falling back to the local data for the handful of fields both carry
# (name, uuid, description, homepage), and a few fields — the screenshot,
# creator, id, downloads and icon — exist only on the web side. Donation URLs
# are the one field the local side can supply that the web side cannot build
# straight from its own property: a local extension's `donations` hash maps a
# platform name to a list of handles, and upstream's
# exm_unified_data_get_donation_urls turns each into the platform's profile
# URL, exactly as upstream's add_local_donation_url does.
class UnifiedData < GLib::Object
  type_register

  # Known platform keys and the URL template upstream's known[] array builds
  # from each handle, bar "custom", whose handle is already a full URL.
  DONATION_URL_TEMPLATES = {
    'paypal'         => 'https://paypal.me/%s',
    'kofi'           => 'https://ko-fi.com/%s',
    'liberapay'      => 'https://liberapay.com/%s',
    'patreon'        => 'https://patreon.com/%s',
    'opencollective' => 'https://opencollective.com/%s',
    'buymeacoffee'   => 'https://buymeacoffee.com/%s',
    'github'         => 'https://github.com/sponsors/%s',
  }.freeze

  attr_reader :local_data, :web_data

  def initialize
    super()
    @local_data = nil
    @web_data = nil
  end

  def local_data=(extension)
    @local_data = extension
  end

  def web_data=(search_result)
    @web_data = search_result
  end

  def empty? = local_data.nil? && web_data.nil?

  def name
    if web_data
      web_data.name
    elsif local_data
      local_data.name
    end
  end

  def creator = web_data&.creator

  def creator_username = web_data&.creator_username

  def creator_id = web_data&.creator_id || 0

  def uuid
    if web_data
      web_data.uuid
    elsif local_data
      local_data.uuid
    end
  end

  def description
    if web_data
      web_data.description
    elsif local_data
      local_data.description
    end
  end

  def screenshot_uri = web_data&.screenshot

  def link = web_data&.link

  # The web side's "url" is its homepage; a local-only extension's url is
  # upstream's fallback, when it is not blank.
  def homepage
    if web_data
      web_data.url
    elsif local_data && !local_data.url.to_s.empty?
      local_data.url
    end
  end

  def id = web_data&.id || 0

  def downloads = web_data&.downloads || 0

  def icon_uri = web_data&.icon

  def session_modes
    if local_data
      Array(local_data.session_modes)
    else
      []
    end
  end

  # The web side's donation_urls are already full URLs; the local side's
  # donations hash is platform => [handles], turned into full URLs the same
  # way upstream's build_local_donation_urls does.
  def donation_urls
    if web_data && !Array(web_data.donation_urls).empty?
      Array(web_data.donation_urls)
    elsif local_data
      donation_urls_from_local(local_data.donations)
    else
      []
    end
  end

  private

    def donation_urls_from_local(donations)
      Hash(donations).flat_map { |platform, handles| Array(handles).filter_map { |handle| donation_url(platform, handle) } }
    end

    def donation_url(platform, handle)
      if handle.to_s.empty?
        nil
      elsif platform == 'custom'
        handle
      elsif DONATION_URL_TEMPLATES.key?(platform)
        format(DONATION_URL_TEMPLATES.fetch(platform), handle)
      end
    end
end
