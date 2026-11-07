# Extension Manager — component identification (re-run)

Upstream ref confirmed: **`origin/master`** (there is no `origin/main` in this
clone — `git ls-tree origin/main` fails with `fatal: Not a valid object name`;
`origin/HEAD` points at `origin/ruby`). Every later report in this round
treats `origin/main` as a mistaken name for `origin/master`.

Port branch: `ruby` @ `64c7398` (`Drive the detail view, author page and
screenshot zoom end to end`).

This supersedes `.reports/component-inventory.md`, which was written against
`f848dc2` — two commits and ~2,900 lines of `lib/` ago (`e92c19c` ported the
detail view, screenshot viewer, author page and crash reporter; `64c7398`
drove them). That document's "Port status" and "Target file map" sections are
now stale: they list `detail_view.rb`, `screenshot.rb`, `screenshot_view.rb`,
`zoom_picture.rb`, `animated_paintable.rb`, `author_page.rb`,
`comment_dialog.rb`, `versions_dialog.rb`, `backtrace.rb` and `unified_data.rb`
as **not** existing. All ten now exist in `lib/`. Its component-level tables
(widget/CSS/signal rows for each `.blp`+`.c` pair) are unaffected and still the
correct upstream-side record — only the "what's missing" accounting at the
bottom needed re-running.

## Current file-existence census (re-run against `lib/` at `64c7398`)

34 `.rb` component files in `lib/` (plus `style.css`, `res/suggestions.txt`,
and the gem-scaffold `extension_manager.rb` / `extension/manager/rb/version.rb`,
excluded from this count as before).

Of the 48 rows in the inventory's Target file map, **45 now exist, 3 do not**:

| Upstream | Port file | Exists |
|---|---|---|
| `src/exm-upgrade-assistant.blp` + `.c` | `lib/upgrade_assistant.rb` | **no** |
| `src/exm-gnome-shell-search-provider.c` | `lib/gnome_shell_search_provider.rb` | **no** |
| `po/*` | `po/` | **no** |

Every other row in that map (the application, window, Installed view, Browse
view, Detail view, screenshot viewer, author page, comment/versions dialogs,
all models and backends, the crash reporter and its capture) now has a port
file. This file-existence count is **necessary, not sufficient** — see
`.reports/component-parity.md` for whether the files that do exist reproduce
upstream's widgets, CSS, signals and text.

## Three further things with no port file at all, outside the Target file map

The original inventory's component map and "Non-widget support" table name
these; none has a port counterpart and none is in the 48-row map because they
live under `data/`, not `src/`:

| Upstream | What it is | Port |
|---|---|---|
| `data/com.mattjakeman.ExtensionManager.desktop.in.in` | desktop entry; registers the `gnome-extensions://<uuid>` URI scheme that `exm_application_open` handles | absent — `find . -iname '*.desktop*'` returns nothing |
| `data/com.mattjakeman.ExtensionManager.metainfo.xml.in.in` | appdata the About dialog's version/comments/developer list is built from | absent — `lib/extension_manager/application.rb:139` builds `Adwaita::AboutDialog` with no metainfo source |
| `data/com.mattjakeman.ExtensionManager.gschema.xml.in` | GSettings schema for `width`/`height`/`is-maximized`/`sort-enabled-first` | absent — `lib/settings.rb` substitutes a JSON file under `XDG_CONFIG_HOME` instead of GSettings (same four keys and defaults, different mechanism — flagged in `component-parity.md`) |

Confirmed by reading `lib/extension_manager/application.rb`: it has no `open`
override and no `dbus_register`/`dbus_unregister` override. Upstream's
`exm_application_open` (the URI-scheme handler) and its D-Bus service
registration (behind which the search provider is exported) have **no code at
all** in the port, not even a stub — this is a bigger gap than "the search
provider class is unported": the application-level hook it would be exported
through doesn't exist either.

## Verdict

File-level coverage improved from 35/48 (last round) to 45/48. The three
remaining gaps — `upgrade_assistant.rb`, `gnome_shell_search_provider.rb`,
`po/` — plus the `data/` triad and the missing `app.open`/D-Bus-registration
hooks are carried forward as open items into `component-parity.md`,
`translation-parity.md` and `accountability-ensurance.md`.
