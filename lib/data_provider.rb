# frozen_string_literal: true

require_relative 'request_handler'
require_relative 'search_result'

# Fetches one extension's record from extensions.gnome.org.
#
# Ported from upstream's src/web/exm-data-provider.c: the endpoint is
# /api/v1/extensions/{uuid}/, the response is a single extension object, and
# responses are cached for an hour.
class DataProvider < RequestHandler
  ENDPOINT = 'https://extensions.gnome.org/api/v1/extensions/%s/'

  def cache_ttl_seconds = 3600

  def get(uuid, &block) = request(format(ENDPOINT, uuid), &block)

  def handle_response(bytes) = SearchResult.from_json(parse_json(bytes))
end
