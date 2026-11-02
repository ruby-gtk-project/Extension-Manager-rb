# frozen_string_literal: true

require_relative 'request_handler'
require_relative 'version_result'

# Fetches an extension's release history.
#
# Ported from upstream's src/web/exm-versions-provider.c: the first page comes
# from /api/v1/extensions/{uuid}/versions/?page=1&page_size=100 and the "next"
# member of the response is the URL of the page after it, which is what the
# versions dialog's "Load More" row follows.
class VersionsProvider < RequestHandler
  ENDPOINT = 'https://extensions.gnome.org/api/v1/extensions/%s/versions/'

  Results = Data.define(:model, :next_url)

  # Upstream's init hardcodes a shell version until the manager supplies one;
  # here the caller sets it, which is what the upgrade assistant does.
  attr_accessor :shell_version

  def initialize(shell_version: nil)
    super()
    @shell_version = shell_version
  end

  def query(uuid, &block) = request("#{format(ENDPOINT, uuid)}?page=1&page_size=100", &block)

  def query_next(url, &block) = request(url, &block)

  def handle_response(bytes)
    parse_json(bytes).then do |root|
      Results.new(
        model:    store_of(root.fetch('results', [])),
        next_url: root['next'],
      )
    end
  end

  private

    def store_of(results)
      Gio::ListStore.new(VersionResult).tap do |store|
        results.each { |result| store.append(VersionResult.from_json(result)) }
      end
    end
end
