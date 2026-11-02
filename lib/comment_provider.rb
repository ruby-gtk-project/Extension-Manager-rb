# frozen_string_literal: true

require_relative 'comment'
require_relative 'request_handler'

# Fetches an extension's reviews.
#
# Ported from upstream's src/web/exm-comment-provider.c: the endpoint is
# /comments/all/?pk={id}&all={bool} and the response is a bare array of
# comment objects. `all` is false for the handful the detail view shows and
# true for the comment dialog's full list.
class CommentProvider < RequestHandler
  ENDPOINT = 'https://extensions.gnome.org/comments/all/'

  def get_comments(extension_id, retrieve_all, &block)
    request("#{ENDPOINT}?pk=#{extension_id.to_i}&all=#{retrieve_all == true}", &block)
  end

  def handle_response(bytes)
    Gio::ListStore.new(Comment).tap do |store|
      parse_json(bytes).each { |comment| store.append(Comment.from_json(comment)) }
    end
  end
end
