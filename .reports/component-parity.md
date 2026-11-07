# Component parity — Extension Manager (round 3)

| | |
|---|---|
| Upstream | `origin/master` (`origin/main` does not exist in this clone) |
| Port | `ruby` @ `f9d640c` |
| Units with parity | not all — see below |

No `COMPONENT_PARITY.md` exists at the port's root. `CLAUDE.md` names that
file as where this is supposed to be "recorded" for the port to be
considered done; it still is not there, only under `.reports/`. Flagged again
here and in `accountability-ensurance.md`.

## Previous round's two top gaps: now closed

1. **`win.show-upgrade-assistant` now works.** `lib/window.rb:384-386`
   installs the action and connects it to `show_upgrade_assistant`
   (`lib/window.rb:695`), which builds a fresh `UpgradeAssistant` dialog each
   time, matching upstream's `show_upgrade_assistant_cb`. Verified by
   `test/drive_upgrade.rb`'s dialog-construction, version-dropdown,
   compatibility-check and clipboard-report checks, re-run this round (49 of
   49 pass).
2. **The GNOME Shell search provider is now exported.**
   `lib/extension_manager/application.rb` installs `dbus_register`/
   `dbus_unregister`-equivalent hooks (`startup`/`shutdown` signal handlers
   calling `export_search_provider`/`search_provider.unexport`,
   `lib/extension_manager/application.rb:46-47, 147-149`), and
   `lib/gnome_shell_search_provider.rb` implements `matching_uuids`,
   `GetInitialResultSet`, `GetSubsearchResultSet`, `GetResultMetas`,
   `ActivateResult` and `LaunchSearch`. Verified by `test/drive_upgrade.rb`.

## Gaps still open, re-verified this round

### 1. `app.open` / the `gnome-extensions://` URI scheme — unchanged, still absent

`grep -n "def open\b" lib/extension_manager/application.rb` and `grep -rn
"gnome-extensions" lib/ exe/` both still return nothing. Upstream's
`exm_application_open` override is the thing that lets any system link of
the form `gnome-extensions://<uuid>` open this app directly to that
extension's detail page (`win.show-detail`); the search-provider commit
added the D-Bus export path but did not touch this. The search provider's
own `ActivateResult`/`LaunchSearch` go through the window's actions
directly rather than through `open`, so the search provider working does
not imply this does. This is unchanged from last round and is a distinct,
still-open gap.

### 2. Settings diverge from GSettings to a JSON file — unchanged correspondence

`lib/settings.rb` still keeps upstream's four keys (`width`, `height`,
`is-maximized`, `sort-enabled-first`) and defaults, backed by a JSON file
under `XDG_CONFIG_HOME` instead of a compiled GSettings schema. Filed as a
correspondence, not a fresh gap, per the previous round's reasoning — but
the underlying `.gschema.xml.in` file is still unported (see
`component-identification.md`), so `gsettings` CLI/GNOME Settings
integration against this app's keys still does not work.

### 3. The `data/` tree is 28 of 30 files short — unchanged, worse than previously stated

Last round's report said "no `data/` tree at all," which undercounted: two
files (`search-provider.ini.in`, `service.in`) now exist, added for the
search-provider commit. Still missing, re-confirmed this round: the desktop
entry, the metainfo, the GSettings schema, both meson.build files, and —
not named with this specificity before — **all 16 icon files**, including
the application's own icon. `install_stylesheet` in
`lib/extension_manager/application.rb` loads `lib/style.css` directly from
the gem's source tree rather than any resource bundle, so the app has a
stylesheet; it has no icon of its own at all. Running the app
(`test/drive_*.rb` builds real widgets) does not surface this because none
of the drivers check that an icon name actually resolves to pixels — a
`Gtk::Image` with an unresolvable icon name degrades silently. See
`component-identification.md`'s new finding naming the five specific icon
names the port's own code (`upgrade_assistant.rb`, `detail_view.rb`,
`extension_row.rb`, `versions_dialog.rb`) references that this port supplies
none of the backing files for.

### 4. Translation catalogue — unchanged, still 0/149

See `translation-parity.md`. No change this round.

## A new, narrower finding this round: `drive-run.md` overstates its own check count

`.reports/drive-run.md` (committed, not re-verified by a fresh execution
until this round) claims `test/drive_upgrade.rb` passes "50 of 50 checks" and
that the four drivers together total "188 checks". Actually re-running all
four drivers this round:

```
test/drive_installed.rb -> 39 of 39 checks passed, DRIVE OK
test/drive_browse.rb    -> 53 of 53 checks passed, DRIVE OK
test/drive_detail.rb    -> 46 of 46 checks passed, DRIVE OK
test/drive_upgrade.rb   -> 49 of 49 checks passed, DRIVE OK   (drive-run.md claims 50)
```
39 + 53 + 46 + 49 = **187**, matching this round's stated runtime gate
(187 checks, 14 components) exactly — not the 188 `drive-run.md` claims. The
discrepancy is a stale/miscounted number in a committed report, not a
regression in the app: the app's actual behaviour (187/187, `DRIVE OK`) is
fine. But a report that states a check count one higher than what the
script, run today on the same code, actually produces is exactly the kind of
unverified green claim `accountability-ensurance.md` is supposed to catch.
Flagged there as well.

## What this pass did **not** check (said plainly, not implied)

- No GIR-backed per-widget count/style/behaviour/text table was built against
  the ten files added in the two most recent commits
  (`upgrade_assistant.rb`, `gnome_shell_search_provider.rb`, plus the earlier
  detail-view batch). The drive scripts exercise behaviour, which is
  evidence, but is not a widget-by-widget count audit.
- The stylesheet diff (`src/style.css` vs `lib/style.css`) was not run this
  round either.
- Icon-name resolution was checked by grep for reference, not by actually
  loading each referenced icon name through a `Gtk::IconTheme` lookup at
  runtime — the "degrades silently" claim above is from reading GTK's
  documented fallback behaviour for unresolvable themed icon names, not from
  observing a broken-image render in this sandbox.

## Verdict

**Not clean.** The two gaps closed this round (`upgrade_assistant`, the
search provider) are real and verified by driving them. Four gaps remain
open and unchanged in substance: `app.open`/URI scheme, the GSettings→JSON
correspondence (filed, not excused, but still a real divergence), the
`data/` tree (28 of 30 files, including every icon), and the entire
translation catalogue. One new finding: a committed report
(`drive-run.md`) overstates the drive suite's own check count by one check
and one driver-total digit, caught only by re-running the suite rather than
trusting the file.
