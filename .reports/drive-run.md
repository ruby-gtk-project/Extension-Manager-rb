# Extension Manager — drive run report

Produced with the `ruby-gtk-testing` skill in `.claude/skills/`, driving the
real app headlessly under `nix develop --command xvfb-run -a ruby test/drive_*.rb`.

## Result (this run, after the upgrade-assistant/search-provider commit)

All four drive scripts end in `DRIVE OK`:

- `test/drive_installed.rb` — 39 of 39 checks passed
- `test/drive_browse.rb` — 53 of 53 checks passed
- `test/drive_detail.rb` — 46 of 46 checks passed
- `test/drive_upgrade.rb` (new, written for this run) — 50 of 50 checks passed

188 checks total, zero failures, zero errored steps.

### What `test/drive_upgrade.rb` covers

Everything added by the "Port the upgrade assistant dialog and the GNOME
Shell search provider" commit, which the three existing drivers never
reached: `UpgradeAssistant` end to end (`win.show-upgrade-assistant`, the
version drop-down and its guessed-newest-release selection, the "no
extensions installed" toast, a full compatibility check against canned
`VersionsProvider` data for five extensions covering all three outcomes —
supported, unsupported, and unknown/unlisted — the user/system group split,
the progress bar and summary text, the clipboard report, and that a second
run starts from a brand-new dialog instance) and `GnomeShellSearchProvider`'s
own logic (`matching_uuids`' case-folded, has-prefs-gated, every-term-must-
match search over name/description/uuid, `GetInitialResultSet`,
`GetSubsearchResultSet`, `GetResultMetas`, `ActivateResult` including the
unknown-uuid no-op case, and `LaunchSearch`).

### Three real bugs found and fixed by actually running this code

All three were invisible to `ruby -c`/`require` and were only found by
exercising the dialog/provider logic end to end for the first time.

1. **`UpgradeAssistant#alphabetical_sorter`'s `Gtk::PropertyExpression.new
   (UpgradeResult, nil, 'name')` crashed** with `Gtk-CRITICAL: Type
   UpgradeResult does not have a property named 'name'`, because
   `UpgradeResult#name` was a plain Ruby method, not a registered GObject
   property — `Gtk::PropertyExpression` introspects the type's property
   list, it does not call the Ruby method directly. Upstream's
   `exm-upgrade-result.c` registers `name` as a real
   `g_param_spec_string(..., G_PARAM_READABLE)` property with a
   `get_property` vfunc computing it from the local/web data; this port had
   dropped the registration while keeping the computed method. **Fixed** in
   `lib/upgrade_result.rb` by adding `install_property(GLib::Param::String
   .new('name', ..., GLib::Param::READABLE))` alongside the existing
   `#name` method — confirmed with a standalone repro that the Ruby
   bindings resolve a declared-but-unbacked-by-ivar property by calling the
   same-named Ruby method, so no `get_property` override was needed.
2. **`UpgradeAssistant#copy_to_clipboard` crashed on every use** with
   `undefined method 'set_text' for an instance of GdkX11Clipboard` —
   `Gdk::Clipboard` has no `#set_text` in the Ruby bindings; the method is
   `#set`, which takes the value directly (confirmed by reading
   `Gdk::Clipboard.instance_methods(false)` and a standalone repro). **Fixed**
   in `lib/upgrade_assistant.rb` by calling `.set(report_text)` instead.
3. **`GnomeShellSearchProvider#launch_search` never actually switched the
   window to the installed search**, because it called
   `window.activate_action('win.search-installed', ...)` — `Window` is an
   `Adwaita::ApplicationWindow`, and (confirmed with a standalone repro)
   `Widget#activate_action` resolving a `"win."`-prefixed name against one
   silently does nothing, while the identical call with the bare action name
   fires correctly. Every other caller in this codebase already activates
   window actions by the bare name (`search-online`, `show-upgrade-
   assistant`, etc.); this was the one caller that had drifted from that
   convention. **Fixed** in `lib/gnome_shell_search_provider.rb` by dropping
   the `"win."` prefix.

### A real binding gap, not a port bug

`GLib::Variant#value` raises `NotImplementedError: TODO: GVariant({sv}) ->
Ruby` for any variant containing an `a{sv}`/`{sv}` member — which is exactly
what `GetResultMetas` returns. The provider's own `gnome_shell_search_provider.rb`
already documents working around the write side of this gap (building the
GVariant from printed text instead of constructing it as Ruby objects);
there is no corresponding read-side decoder at all, in either direction, for
a dict-of-variants. `test/drive_upgrade.rb`'s `GetResultMetas` checks work
around this by asserting against the GVariant's printed (`.to_s`) text form
instead of decoding it, which is a test-side accommodation, not a change to
what the provider sends over the bus.

### Still not run

- The real `org.gnome.Shell.SearchProvider2` D-Bus path itself
  (`GnomeShellSearchProvider#export`/`handle_method_call` reached through an
  actual `Gio::DBusConnection`) — there is no GNOME Shell, and no guaranteed
  D-Bus session bus, in this sandbox. `test/drive_upgrade.rb` instead calls
  `matching_uuids`, `initial_result_set`, `subsearch_result_set`,
  `result_metas`, `activate_result` and `launch_search` directly with plain
  Ruby arrays in place of GDBus-decoded parameter tuples (every one of those
  methods only ever calls `#to_a` on its `parameters` argument, which a
  plain Array already answers), exercising every line of the provider's own
  logic without a bus. The commit's own message records that a real
  `dbus-run-session` + `gdbus call` round trip against
  `--gapplication-service` was done separately and all five methods replied
  with correctly-typed D-Bus values.
- `bundle exec rubocop` and the RSpec suite — unchanged from the previous
  run: this sandbox's dev shell has neither `rubocop` nor `kettle/test/rspec`
  installed, independent of anything in this change.

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
