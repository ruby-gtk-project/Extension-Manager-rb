# Component parity — Extension Manager (round 4)

| | |
|---|---|
| Upstream | `origin/master` |
| Port | `ruby` @ `e564797` |
| Units with parity | not all — see below |

No `COMPONENT_PARITY.md` exists at the port's root. `CLAUDE.md` names that
file as where the port's component parity is "recorded" for the port to be
considered done; it still is not there, only under `.reports/`. Carried
again into `accountability-ensurance.md` — this is now its fourth
consecutive round open.

## Since round 3: icon theme, desktop entry and metainfo ported, and driven

`c5fc5b0` ported `Application#install_icon_theme` plus
`data/*.desktop.in.in`/`*.metainfo.xml.in.in` and 18 symbolic SVGs;
`e564797` added `test/drive_assets.rb` to actually exercise them. Re-run
live this round, not trusted from the commit message:

```
nix develop --command xvfb-run -a ruby test/drive_assets.rb
  -> 42 of 42 checks passed, DRIVE OK
```

The driver confirms, against the real `Gtk::IconTheme`: the icons directory
is really on the search path; all 18 shipped action-glyph names resolve;
the 16 of those names any widget in `lib/` actually sets are a subset of
what resolves; a real `Gtk::Image` built from one of them (`puzzle-piece-
symbolic`) paints a paintable backed by the port's own file, not a system
fallback; the desktop-entry and metainfo templates parse with the right
shape and substitute the real `APP_ID` correctly. This is a genuine,
non-trivial parity gain — the previous two rounds' "no icon of any kind"
finding is now **mostly** closed, not just file-present.

## Gaps still open, re-verified this round (not copied from round 3's text)

### 1. `app.open` / the `gnome-extensions://` URI scheme — still absent, now contradicted by the port's own shipped desktop entry

`grep -n "def open\b" lib/extension_manager/application.rb` and `grep -rn
"gnome-extensions" lib/ exe/` both still return nothing — unchanged from
every prior round. But the desktop-entry template this round's commit
shipped (`data/com.mattjakeman.ExtensionManager.desktop.in.in`) declares
`MimeType=x-scheme-handler/gnome-extensions;`, and `test/drive_assets.rb`
checks and confirms that line is present. So the port's own packaging
metadata now asserts it is the default handler for `gnome-extensions://`
links, while the application code that would do anything when the desktop
environment hands it such a URI (`exm_application_open` upstream,
`win.show-detail` downstream of it) still does not exist anywhere in
`lib/` or `exe/`. This is a new and sharper form of the same long-standing
gap: a real user double-clicking a `gnome-extensions://<uuid>` link on a
system where this desktop file is installed would have the link routed to
this app (because the `.desktop` file says to) and then nothing would
happen, because there is no handler.

### 2. The application's own icon is unshippable, unported, and untested — new finding this round

`lib/extension_manager/application.rb:176` sets `dialog.application_icon =
APP_ID` (`com.mattjakeman.ExtensionManager`) for the About dialog. Upstream
ships that icon as `data/icons/com.mattjakeman.ExtensionManager.svg` (plus
`.Devel.svg`, `.Source.svg`, `-symbolic.svg` variants) at the top level of
`data/icons/`, separately from the 18 action glyphs under
`data/icons/hicolor/scalable/actions/` this round actually ported. None of
the four app-icon files exist in the port (`find data/icons -maxdepth 1
-type f` — nothing). `Application::ICONS_DIR` is added to the icon theme's
search path, so if the file existed there it would very likely resolve the
same way the 18 action glyphs now do — but it doesn't exist, so it can't.
`test/drive_assets.rb`'s icon-resolution checks only cover the 18 action
names (`CUSTOM_ICON_NAMES`/`WIRED_ICON_NAMES`); `APP_ID` is referenced in
the same file only as the string substituted into the desktop entry and
metainfo, never as an icon-theme lookup target. The About dialog's own
application icon is a real, untested, user-visible gap that the new driver
does not catch because it was not asked to.

### 3. GSettings schema — unchanged correspondence, unchanged gap

`lib/settings.rb` still keeps upstream's four keys (`width`, `height`,
`is-maximized`, `sort-enabled-first`) and defaults, backed by a hand-rolled
JSON file under `XDG_CONFIG_HOME` rather than a compiled GSettings schema.
`data/com.mattjakeman.ExtensionManager.gschema.xml.in` is still unported
(`find data -iname "*gschema*"` — nothing), so `gsettings` CLI / GNOME
Settings integration against this app's keys still does not work, exactly
as every prior round found.

### 4. `data/` tree — improved from 2/37 to 22/37, two meson.build files and 8 screenshots still absent

Beyond items 2 and 3 above: upstream's two `meson.build` files under
`data/` (not meaningful for a Bundler/RubyGems port, carried for
completeness) and all 8 screenshot PNGs the metainfo's `<screenshot>`
elements and the README reference are still absent. `test/drive_assets.rb`
checks that the metainfo template *names* at least one `<screenshot>`
element; it does not — and could not, since none exist — check that the
referenced image resolves to a real file.

### 5. Translation catalogue — unchanged, still 0/149

See `translation-parity.md`. No change this round; the two components
ported since round 3 (icon theme, desktop entry, metainfo) add zero
gettext markers, same pattern as `upgrade_assistant.rb` and
`gnome_shell_search_provider.rb` before them.

## A check on round 3's flagged report-accuracy problem: fixed this round

Round 3 found `drive-run.md` overstated `drive_upgrade.rb`'s count (claimed
50/50, actually 49/49) and the four-driver total (claimed 188, actually
187). This round's `.reports/drive-run.md` has been rewritten and now
states 39+53+51+49+42 = 234, matching this round's own fresh re-run of all
five drivers exactly (see below and `test-parity.md`). The false-green
report problem round 3 found is corrected, not merely re-asserted.

```
nix develop --command xvfb-run -a ruby test/drive_installed.rb  -> 39 of 39, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_browse.rb     -> 53 of 53, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_detail.rb     -> 51 of 51, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_upgrade.rb    -> 49 of 49, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_assets.rb     -> 42 of 42, DRIVE OK
```
39+53+51+49+42 = 234, zero failures — matches this round's stated runtime
gate exactly, reproduced by execution in this session, not read off a
committed file.

## Verdict

Real progress this round: the icon theme, desktop entry and metainfo are
now ported and driven, and the previous round's report-accuracy problem is
fixed. Five gaps remain open, two of them (the About dialog's own app icon,
and the desktop entry now claiming a URI-scheme handler the app still
doesn't implement) newly sharpened by this round's own work rather than
unchanged holdovers. None of these five gaps is exercised by any passing
check in the 234-check gate — the gate's shape is "what was driven passed,"
not "nothing is missing."
