# frozen_string_literal: true

require_relative 'request_handler'
require_relative 'search_result'
require_relative 'types'

# Searches extensions.gnome.org.
#
# Ported from upstream's src/web/exm-search-provider.c. The two endpoints and
# their query strings are upstream's: an empty query lists extensions ordered
# by the chosen sort (falling back to -popularity) and filtered to status=3,
# while a query goes through /search/{query}/. Both ask for ten per page, and
# the page count is the reported total rounded up to the next ten.
#
# Results arrive as a Gio::ListStore of SearchResult plus that page count,
# which is what the browse page needs to decide whether to show "Load More".
class SearchProvider < RequestHandler
  PAGE_SIZE = 10
  LIST_ENDPOINT = 'https://extensions.gnome.org/api/v1/extensions/'
  SEARCH_ENDPOINT = 'https://extensions.gnome.org/api/v1/extensions/search/%s/'

  Results = Data.define(:model, :num_pages)

  def query(query, page, sort_type, &block)
    request(query_url(query, page, sort_type), &block)
  end

  # The author page's query: every extension by one creator, by name, in one
  # page of a hundred.
  def query_by_creator(username, &block)
    request("#{format(SEARCH_ENDPOINT, escape(username))}?ordering=name&page_size=100", &block)
  end

  def handle_response(bytes)
    parse_json(bytes).then do |root|
      Results.new(
        model:     store_of(root.fetch('results', [])),
        num_pages: page_count(root.fetch('count', 0).to_i),
      )
    end
  end

  private

    def query_url(query, page, sort_type)
      if query.to_s.empty?
        "#{LIST_ENDPOINT}?#{list_ordering(sort_type)}page=#{page}&page_size=#{PAGE_SIZE}&status=3"
      else
        "#{format(SEARCH_ENDPOINT, escape(query))}?#{ordering(sort_type)}page=#{page}&page_size=#{PAGE_SIZE}"
      end
    end

    def ordering(sort_type)
      Types::SearchSort.ordering(sort_type).then do |sort|
        if sort.empty?
          ''
        else
          "ordering=#{sort}&"
        end
      end
    end

    # With no query there is no relevance to sort by, so upstream falls back
    # to the most popular first.
    def list_ordering(sort_type)
      ordering(sort_type).then do |printed|
        if printed.empty?
          'ordering=-popularity&'
        else
          printed
        end
      end
    end

    def store_of(results)
      Gio::ListStore.new(SearchResult).tap do |store|
        results.each { |result| store.append(SearchResult.from_json(result)) }
      end
    end

    def page_count(count) = ((count + PAGE_SIZE - 1) / PAGE_SIZE)

    def escape(text) = URI.encode_www_form_component(text.to_s)
end
