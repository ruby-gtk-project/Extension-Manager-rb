# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'net/http'
require 'uri'

# The base class every extensions.gnome.org client shares.
#
# Ported from upstream's src/web/exm-request-handler.c: one HTTP GET with a
# 30 second timeout, an optional response cache with a per-subclass TTL, the
# two error messages upstream distinguishes by status code, and a
# `handle_response` the subclass overrides to turn bytes into a model.
#
# libsoup has no Ruby binding, so the request runs on a Ruby thread and the
# answer is handed back on the main loop through GLib::Idle — the same
# main-thread contract g_task gives upstream's callbacks, which is what makes
# it safe for a callback to touch widgets.
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
  # no-op: upstream relies on the GCancellable for exactly that, so a search
  # whose query has moved on cannot overwrite the newer results.
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
  # GCancellable.
  class Request
    def initialize
      @cancelled = false
    end

    def cancel = @cancelled = true
    def cancelled? = @cancelled
  end

  private

    def fetch(request, url, &block)
      Thread.new do
        begin
          bytes = http_get(url)
          store(url, bytes)
          deliver(request, bytes, &block)
        rescue StandardError => e
          deliver_error(request, e, &block)
        end
      end
    end

    def http_get(url)
      URI.parse(url).then do |uri|
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl:      uri.scheme == 'https',
          open_timeout: TIMEOUT_SECONDS,
          read_timeout: TIMEOUT_SECONDS,
        ) do |http|
          read_response(http.request(Net::HTTP::Get.new(uri)))
        end
      end
    end

    def read_response(response)
      status = response.code.to_i
      if status >= 500
        raise RequestError.new(status, SERVER_ERROR_MESSAGE)
      elsif status >= 400
        raise RequestError.new(status, CLIENT_ERROR_MESSAGE)
      else
        response.body
      end
    end

    # Parsing happens on the main loop, not on the worker thread: the models
    # are GObjects and building them off the main thread is not safe.
    def deliver(request, bytes, &block)
      GLib::Idle.add do
        unless request.cancelled?
          begin
            block&.call(handle_response(bytes), nil)
          rescue StandardError => e
            block&.call(nil, e)
          end
        end
        GLib::Source::REMOVE
      end
    end

    def deliver_error(request, error, &block)
      GLib::Idle.add do
        unless request.cancelled?
          block&.call(nil, error)
        end
        GLib::Source::REMOVE
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
