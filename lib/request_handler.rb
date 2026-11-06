# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'soup3'

# The base class every extensions.gnome.org client shares.
#
# Ported from upstream's src/web/exm-request-handler.c: one HTTP GET with a
# 30 second timeout, an optional response cache with a per-subclass TTL, the
# two error messages upstream distinguishes by status code, and a
# `handle_response` the subclass overrides to turn bytes into a model.
#
# Upstream builds this on libsoup; so does this port, through the `soup3` gem
# — a thin GObject-Introspection binding over the same library, not a
# hand-rolled HTTP client. The request runs through
# `Soup::Session#send_and_read_async`, so it is libsoup's own GTask doing the
# work, dispatched back to this same GLib main loop — never a Ruby Thread.
# That matters here specifically: the gobject-introspection loader's
# repository and typelib caches are not safe to touch from two native threads
# at once, so a Soup call (or any other GI call) belongs on the thread the
# main loop runs on, which is exactly where the async API delivers it.
class RequestHandler
  TIMEOUT_SECONDS = 30

  # Upstream's two messages, chosen by status code, with the markup it uses.
  SERVER_ERROR_MESSAGE =
    "Check <a href='https://status.gnome.org/'>GNOME infrastructure status</a> and try again later"
  CLIENT_ERROR_MESSAGE = 'Check your network status and try again'

  # Raised for a non-2xx response, carrying the status code upstream puts in
  # its GError.
  class RequestError < StandardError
    attr_reader :status_code

    def initialize(status_code, message)
      super(message)
      @status_code = status_code
    end
  end

  # How long this handler's responses stay cached. Zero, upstream's default,
  # means no caching at all.
  def cache_ttl_seconds = 0

  def initialize
    @cache = {}
  end

  # Fetches `url` and yields the parsed model, or the error, on the main loop.
  # The returned object answers #cancel, which makes the pending answer a
  # no-op and cancels the underlying GCancellable, so a search whose query
  # has moved on cannot overwrite the newer results and the request itself
  # stops rather than finishing unread.
  def request(url, &block)
    Request.new.tap do |request|
      cached(url).then do |bytes|
        if bytes
          deliver(request, bytes, &block)
        else
          fetch(request, url, &block)
        end
      end
    end
  end

  # Subclasses override this to parse the response body. The base class
  # refuses to guess, as upstream's default_handle_response does.
  def handle_response(_bytes)
    raise NotImplementedError, "#{self.class} must override #handle_response"
  end

  # A handle on one in-flight request, standing in for upstream's
  # GCancellable — because it is one.
  class Request
    def initialize
      @cancellable = Gio::Cancellable.new
    end

    def cancel = @cancellable.cancel
    def cancelled? = @cancellable.cancelled?
    def cancellable = @cancellable
  end

  private

    def fetch(request, url, &block)
      message = Soup::Message.new('GET', url)
      session.send_and_read_async(message, GLib::PRIORITY_DEFAULT, request.cancellable) do |_source, result, _token|
        on_response(
          request,
          url,
          message,
          result,
          &block
        )
      end
    end

    def on_response(request, url, message, result, &block)
      status_checked(message, session.send_and_read_finish(result).to_s).then do |body|
        store(url, body)
        deliver(request, body, &block)
      end
    rescue GLib::Error, RequestError => e
      deliver_error(request, e, &block)
    end

    # One Session per handler: Soup::Session pools its own connections, so
    # reusing it across requests is how upstream's single ExmRequestHandler
    # session behaves too.
    def session
      @session ||= Soup::Session.new.tap do |session|
        session.timeout = TIMEOUT_SECONDS
      end
    end

    def status_checked(message, bytes)
      status = message.status_code.to_i
      if status >= 500
        raise RequestError.new(status, SERVER_ERROR_MESSAGE)
      elsif status >= 400
        raise RequestError.new(status, CLIENT_ERROR_MESSAGE)
      else
        bytes
      end
    end

    # Already on the main loop — the async callback delivers here directly —
    # so this only has to guard against a request that moved on and run the
    # subclass's parsing.
    def deliver(request, bytes, &block)
      unless request.cancelled?
        begin
          block&.call(handle_response(bytes), nil)
        rescue StandardError => e
          block&.call(nil, e)
        end
      end
    end

    def deliver_error(request, error, &block)
      unless request.cancelled?
        block&.call(nil, error)
      end
    end

    def cached(url)
      if cache_ttl_seconds.positive?
        purge_expired
        @cache[url]&.fetch(:bytes)
      end
    end

    def store(url, bytes)
      if cache_ttl_seconds.positive?
        @cache[url] = { bytes: bytes, expires_at: monotonic_now + cache_ttl_seconds }
      end
    end

    def purge_expired
      monotonic_now.then do |now|
        @cache.delete_if { |_url, entry| entry.fetch(:expires_at) <= now }
      end
    end

    def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Every provider parses JSON; the raw body is kept out of the subclasses.
    def parse_json(bytes) = JSON.parse(bytes)
end
