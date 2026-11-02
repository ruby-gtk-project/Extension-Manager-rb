# frozen_string_literal: true

require_relative 'request_handler'
require_relative 'user_profile'

# Fetches an extension author's profile.
#
# Ported from upstream's src/web/exm-profile-provider.c: the endpoint is
# /api/v1/profile/{user_id}/ and responses are cached for an hour.
class ProfileProvider < RequestHandler
  ENDPOINT = 'https://extensions.gnome.org/api/v1/profile/%u/'

  def cache_ttl_seconds = 3600

  def get(user_id, &block) = request(format(ENDPOINT, user_id.to_i), &block)

  def handle_response(bytes) = UserProfile.from_json(parse_json(bytes))
end
