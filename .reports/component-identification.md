# Extension Manager — component identification (re-run, round 3)

Upstream ref: **`origin/master`**. `origin/main` does **not exist** in this
clone (`git ls-remote origin main` returns nothing; `git ls-tree origin/main`
fails with `fatal: Not a valid object name`). `origin/HEAD` points at
`origin/ruby`. Confirmed again this round, not taken on faith from the
previous report. Every report in this round treats `origin/main` as a
mistaken name for `origin/master`; the task description's `origin/main`
instruction cannot be followed literally in this repo.

Port branch: `ruby` @ `f9d640c` (`Drive the upgrade assistant and GNOME Shell
search provider end to end`).

This supersedes `.reports/component-identification.md`'s previous version
(written against `64c7398`, before the upgrade-assistant/search-provider
commit) and the original `.reports/component-inventory.md` (written against
`f848dc2`). Both of this round's two former gaps are now file-level present:

| Upstream | Port file | Exists now |
|---|---|---|
| `src/exm-upgrade-assistant.blp` + `.c` | `lib/upgrade_assistant.rb` | **yes** |
| `src/exm-gnome-shell-search-provider.c` | `lib/gnome_shell_search_provider.rb` | **yes** |
| `po/*` | `po/` | **no — unchanged** |

35 `.rb` component files in `lib/` now (up from 34), plus `style.css`,
`res/suggestions.txt`, and the gem scaffold files.

## Remaining file-level gaps, re-verified this round

### `po/` — still completely absent

```
find . -iname po -maxdepth 2   -> nothing
```

Upstream: `po/extension-manager.pot` (149 msgids, re-counted this round —
`git show origin/master:po/extension-manager.pot | grep -c '^msgid "'` = 149)
and `po/LINGUAS` (45 languages, re-counted — `git show
origin/master:po/LINGUAS | tr ' ' '\n' | grep -c .` = 45). See
`translation-parity.md`.

### `data/` — present but only 2 of 30 upstream files

```
git ls-tree -r --name-only origin/master -- data/
```
lists 30 files: the desktop entry, the metainfo, the GSettings schema, the
search-provider `.ini.in`, the D-Bus `.service.in`, two meson.build files,
16 icon files under `data/icons/` (including the three app-icon variants and
the symbolic icon), and 8 screenshot PNGs used by the metainfo/README.

The port's `data/` has exactly:
```
data/com.mattjakeman.ExtensionManager.search-provider.ini.in
data/com.mattjakeman.ExtensionManager.service.in
```
— the two files the search-provider commit needed to get `export_search_
provider` working, and nothing else. Re-confirmed absent this round:

- `com.mattjakeman.ExtensionManager.desktop.in.in` — the desktop entry that
  registers the `gnome-extensions://<uuid>` URI scheme and the app's
  launcher metadata (`Exec=`, `Icon=`, `Categories=`, `X-GNOME-UsesNotifications`).
- `com.mattjakeman.ExtensionManager.metainfo.xml.in.in` — the About dialog's
  real data source (version history, screenshots, developer/translator
  credits).
- `com.mattjakeman.ExtensionManager.gschema.xml.in` — the GSettings schema;
  `lib/settings.rb` still substitutes a hand-rolled JSON file (same four
  keys/defaults, different mechanism — see `component-parity.md`).
- All 16 files under `data/icons/` — **the port ships no icon of any kind**,
  including the application icon itself (`.svg`, `.Devel.svg`, `.Source.svg`,
  `-symbolic.svg`) and the 12 action-glyph symbolic icons
  (`check-round-outline-symbolic`, `clock-alt-symbolic`,
  `donation-symbolic`, `external-link-symbolic`, `pip-in-symbolic`,
  `pip-out-symbolic`, `session-modes-symbolic`, `software-update-available-
  symbolic`, `star-filled/outline-rounded-symbolic`, `supported-symbolic`,
  `unknown-symbolic`, `unsupported-symbolic`). Several of these names
  (`supported-symbolic`, `unsupported-symbolic`, `unknown-symbolic`,
  `pip-in`/`pip-out-symbolic`) are exactly the glyphs
  `upgrade_result.rb`/`extension_toggle.rb`/`extension_row.rb` need for their
  status icons — if the port references these icon names via GTK's themed
  icon lookup (not bundled), whether they render is dependent on the host
  icon theme shipping names with the same spelling, which was **not**
  checked this round; grep below.

```
grep -rn "symbolic" lib/*.rb | grep -iE "supported|unsupported|unknown|pip-in|pip-out|session-modes|software-update"
```
This grep (run this round) confirms `lib/upgrade_assistant.rb` (3 hits:
`software-update-available-symbolic`, `supported-symbolic`,
`unsupported-symbolic`, `unknown-symbolic`), `lib/detail_view.rb`
(`pip-out-symbolic`, `software-update-available-symbolic`,
`session-modes-symbolic`), `lib/extension_row.rb`
(`software-update-available-symbolic`) and `lib/versions_dialog.rb`
(`supported-symbolic`) all set `icon_name =` to these exact strings — i.e.
the port depends on these icons existing *somewhere* findable by GTK's icon
theme at runtime, and the port itself supplies none of them. On a system
theme without them, the icons silently fall back to the GTK "broken image"
glyph or nothing. This was not previously called out this specifically; it
sharpens the existing "no icons" line into a named runtime risk.

### The application-level `open` override — still absent

```
grep -n "def open\b" lib/extension_manager/application.rb   -> no match
grep -rn "gnome-extensions" lib/ exe/                        -> no match
```
Re-confirmed this round. `exm_application_open` (upstream's
`gnome-extensions://<uuid>` URI-scheme handler, which forwards to
`win.show-detail`) has no port code at all, stub or otherwise. This is
separate from and unaffected by the search-provider commit, which added
`dbus_register`/`dbus_unregister` (for the search provider) but not `open`.

## Verdict

File-level coverage is now 46/48 against the original inventory's Target file
map (both of the previous round's two component gaps closed), but the wider
census — `data/` (28 of 30 files missing, including every icon), `po/` (all
of it), and the `open`/URI-scheme hook — remains exactly as open as before.
Carried into `component-parity.md`, `translation-parity.md` and
`accountability-ensurance.md`.
