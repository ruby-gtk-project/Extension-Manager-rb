# frozen_string_literal: true

# Drives Application#on_open: the override wired to GApplication's 'open'
# vfunc so a gnome-extensions://<uuid> URI (xdg-open, or the "Install" button
# on extensions.gnome.org) lands on the window's detail page for that
# extension, exactly as upstream's exm_application_open does.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require_relative '../.claude/skills/ruby-gtk-testing/scripts/gtk_driver'
require 'extension_manager'
require 'types'
require 'data_provider'
require 'comment_provider'
require 'versions_provider'
require 'profile_provider'
require 'search_provider'
require 'image_resolver'
require 'request_handler'

class FakeRequest
  def cancel = nil
  def cancelled? = false
end

# The driver runs offline: every website client answers from canned data.
class DataProvider
  def get(uuid, &block)
    block.call(
      SearchResult.from_json(
        {
          'id'          => 1,
          'uuid'        => uuid,
          'name'        => 'Blur My Shell',
          'description' => 'Blurs things.',
          'creator'     => { 'username' => 'ada', 'display_name' => 'Ada Lovelace', 'id' => 7 },
          'icon'        => '/static/icon.png',
        },
      ),
      nil,
    )
    FakeRequest.new
  end
end

class CommentProvider
  def get_comments(_extension_id, _retrieve_all, &block)
    block.call(Gio::ListStore.new(Comment), nil)
    FakeRequest.new
  end
end

class VersionsProvider
  def query(_uuid, &block)
    block.call(VersionsProvider::Results.new(model: Gio::ListStore.new(VersionResult), next_url: nil), nil)
    FakeRequest.new
  end
end

class ImageResolver
  def resolve(_rel_path) = nil
end

application = ExtensionManager::Application.new

GtkDriver.drive(application, shots: 'tmp/shots') do |d, app|
  d.window { app.window }

  d.step('open a gnome-extensions:// URI') do
    # Ruby's bindings cannot marshal an array of GFile into a direct
    # `Gio::Application#open` call or a `signal_emit('open', ...)` (the
    # first raises NotImplementedError, the second segfaults — see
    # adwaita-quirks.md). xdg-open calling into the real GApplication vfunc
    # from C works fine; only driving it from Ruby is broken, so this
    # exercises Application#on_open directly with a real Gio::File.
    file = Gio::File.new_for_uri('gnome-extensions://blur-my-shell%40aunetx')
    app.send(:on_open, [file])

    window = app.window
    d.check('window built') { !window.nil? }
    d.check('detail view is the visible page') { window.navigation_view.visible_page == window.detail_view }
    d.check('uuid decoded from the URI host') { window.detail_view.instance_variable_get(:@uuid) == 'blur-my-shell@aunetx' }
  end

  d.step('an unknown scheme is rejected without touching the window') do
    window = app.window
    window.navigation_view.pop
    file = Gio::File.new_for_uri('http://example.com/not-an-extension')
    app.send(:on_open, [file])
    d.check('main page still showing') { window.navigation_view.visible_page == window.main_page }
  end
end
