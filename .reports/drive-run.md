# Extension Manager — drive run report

Produced with the `ruby-gtk-testing` skill in `.claude/skills/`, driving the
real app headlessly under `nix develop --command xvfb-run -a ruby test/drive_*.rb`.

## Result

All three drive scripts end in `DRIVE OK`:

- `test/drive_installed.rb` — 39 of 39 checks passed
- `test/drive_browse.rb` — 53 of 53 checks passed
- `test/drive_detail.rb` (new, written for this run) — 46 of 46 checks passed

138 checks total, zero failures, zero errored steps.

## What `test/drive_detail.rb` covers

Everything the other two drivers don't reach: `DetailView` (loaded through
`win.show-detail`, both the installed and web-only halves — reviews,
version row, location row, donation rows), `AuthorPage` (`win.show-author`),
`ScreenshotView` + `ZoomPicture` (`win.show-screenshot`, the three zoom
actions and their enabled/disabled state at the zoom limits), `VersionsDialog`,
`CommentDialog`, `PrimaryMenu`'s menu structure, and `Backtrace.format` /
`Backtrace.install`. `DataProvider`, `CommentProvider`, `VersionsProvider`,
`ProfileProvider` and `SearchProvider#query_by_creator` are fed canned JSON
in place of a real request, the same pattern `drive_browse.rb` already uses
for `SearchProvider#request`.

Combined, the three drivers now exercise every ported component in `lib/`
except:

- **`ShellDbusInterface`** — talks to a real `org.gnome.Shell` D-Bus service;
  there is no GNOME Shell in this sandbox to connect to, and no fake one was
  built. `Manager`'s own surface (the `extensions` list store, `by_uuid`,
  `installed_uuid?`) is exercised throughout by injecting `Extension` rows
  directly, which is what both the pilot app and this fork's existing drivers
  already do for the same reason.
- **`RequestHandler`'s own HTTP path** (the `Soup::Session` request, the
  30-second timeout, the status-code-to-message mapping, the response
  cache) — every provider's `#get`/`#query`/`#resolve` is stubbed in the
  drivers rather than hitting the real network, matching the testing skill's
  guidance to say plainly when something needs a real network service
  rather than fake a green check for it.
- **`AnimatedPaintable`** — real image decoding through glycin; the drivers
  stub `ImageResolver#resolve` to return `nil` rather than decode a real
  image file, so this class's frame-advance behaviour is unexercised.
- The **upgrade assistant** (`UpgradeResult`'s eventual UI) was never built —
  `lib/window.rb`'s own comment says so (`win.show-upgrade-assistant`, which
  still has no upgrade assistant to show) — so there is nothing to drive.

## Two real bugs found and fixed by actually running the app

Both were found only because the detail/screenshot-view path is exercised
end to end for the first time; `ruby -c` and `require` passed on both.

1. **`win.show-author` never fired.** `DetailView#on_author_link_activated`
   built its action parameter with
   `GLib::Variant.parse("(#{creator_id}, ...)")`. GVariant text format
   defaults a bare integer to `i` (int32), but the action is declared
   `(uss)` — `u` is uint32 — so every call raised a
   `g_simple_action_activate` type-mismatch assertion in GLib and the
   action silently never activated. Clicking an author's name in the running
   app did nothing. Fixed in `lib/detail_view.rb` by annotating the integer:
   `"(uint32 #{creator_id}, ...)"`.

2. **The three zoom actions and their enabled/disabled state never worked.**
   Two compounding bugs in `lib/window.rb` / `lib/screenshot_view.rb` /
   `lib/zoom_picture.rb`:
   - `Window` put `zoom-in`/`zoom-out`/`zoom-reset` in a separate
     `Gio::SimpleActionGroup` inserted with
     `insert_action_group('screenshot', ...)`. A minimal, from-scratch
     repro (no port code involved) shows that on a `Gtk::ApplicationWindow`
     specifically, neither `Widget#activate_action` nor a child button's
     `action-name` ever reaches an action group inserted this way —
     activating the *group* directly works, but nothing that goes through
     the widget's action-name resolution does. The identical group on a
     bare `Gtk::Window` resolves correctly, so this looks like a gap in how
     the `gtk4` gem's `GtkApplicationWindow` wrapper publishes
     widget-inserted action groups to the action-name muxer, not a mistake
     in how the port called the API — see the repro below. **Fixed** by
     moving the three actions onto the window's own action map (`add_action`,
     the same mechanism `show-detail` and friends already use successfully)
     and renaming them from `screenshot.zoom-*` to `win.zoom-*` throughout
     (`lib/window.rb`'s shortcuts, `lib/screenshot_view.rb`'s buttons).
   - Separately, `Window` tried to track the zoom level with
     `widget.signal_connect('notify::zoom-level')`, but `ZoomPicture#zoom_level`
     is a plain Ruby attribute, never registered as a GObject property with
     `install_property`, so `notify::zoom-level` is not a signal that exists
     on the type and the handler never fires — confirmed with a standalone
     repro connecting the same signal name on a bare `ZoomPicture` and
     setting `zoom_level=`. **Fixed** by giving `ZoomPicture` a plain Ruby
     callback (`on_zoom_changed`), called from the `zoom_level=` setter, and
     wiring `ScreenshotView` and `Window` through that instead of the
     nonexistent signal.

   Repro for the action-group gap (reproduces with no `lib/` code at all):

   ```ruby
   require 'gtk4'
   class TestWin < Gtk::ApplicationWindow
     def initialize(app)
       super(app)
       group = Gio::SimpleActionGroup.new
       action = Gio::SimpleAction.new('zoom-in')
       action.signal_connect('activate') { puts 'FIRED' } # never prints
       group.add_action(action)
       insert_action_group('screenshot', group)
     end
   end
   app = Gtk::Application.new('org.example.t', Gio::ApplicationFlags::DEFAULT_FLAGS)
   app.signal_connect('activate') do
     win = TestWin.new(app)
     win.present
     GLib::Timeout.add(300) do
       win.activate_action('screenshot.zoom-in', nil) # returns the window, action never fires
       app.quit
       false
     end
   end
   app.run([])
   ```

   The same group activated directly
   (`group.activate_action('zoom-in', nil)`) fires correctly; only the
   widget-name-based resolution through `Gtk::ApplicationWindow` fails. Both
   fixes change the port's own wiring (no upstream behaviour changes: the
   actions are still window-scoped, the buttons and Ctrl+Plus/Minus/0 still
   reach them, and `test/drive_detail.rb`'s "zoom actions disable themselves
   at the zoom limits" step proves the enabled-state tracking now actually
   works, which it provably did not before).

## Not run

- `bundle exec rubocop` — this sandbox's Nix store does not have `rubocop`
  installed into the dev shell's gem set (`can't find executable rubocop for
  gem rubocop`), independent of anything in this change.
- The RSpec suite the dev-shell banner names — `spec/spec_helper.rb` requires
  `kettle/test/rspec`, which is not present in this dev shell either, and
  there are no `*_spec.rb` files under `spec/` yet regardless.
