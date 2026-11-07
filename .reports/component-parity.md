# Component parity — Extension Manager

| | |
|---|---|
| Upstream | `origin/master` (no `COMPONENT_PARITY.md` existed before this audit — this is the first) |
| Port | `ruby` @ `64c7398` |
| Units with parity | not all — see below |

No `COMPONENT_PARITY.md` exists at the port's root yet, so this round starts
the ledger rather than updating one. This document is the first pass; it does
not claim the per-widget four-axis table (count / style / behaviour / text)
has been run over every one of the 45 existing component files — that is a
multi-day job on its own for a ~7,200-line port and was not completed at this
effort level. What follows are the concrete, verified gaps found, plus an
honest statement of what was **not** checked, so neither is mistaken for the
other.

## Verified gaps

### 1. `win.show-upgrade-assistant` is a dead menu item

`lib/primary_menu.rb:20` builds `['_Upgrade Assistant', 'win.show-upgrade-assistant']`
— the menu item exists, with upstream's exact label and action name. But
`lib/window.rb` never installs `show-upgrade-assistant` as an action (its own
top-of-file comment says so: "Every action upstream installs on the window
class is installed here now bar win.show-upgrade-assistant, which still has no
upgrade assistant to show"), and there is no `lib/upgrade_assistant.rb` at
all. Clicking "Upgrade Assistant" in the running app's primary menu does
nothing — no error, no dialog, silent failure. This is worse than an absent
menu item: upstream's menu entry is faithfully reproduced and then wired to
nothing, which is a user-visible regression a screenshot of the menu will not
show.

**Behaviour owed:** the whole upgrade-assistant dialog — `Adw.Dialog`
400×600, the GNOME-version drop-down, "Check Compatibility", the per-extension
compatibility results list with the dynamic status icons, and "Copy to
Clipboard" — per `src/exm-upgrade-assistant.blp` + `.c`. `lib/upgrade_result.rb`
(the row model) is already ported and unused by anything.

### 2. The GNOME Shell search provider is not exported, and the hook it needs doesn't exist either

`src/exm-gnome-shell-search-provider.c` has no port file. Checked further than
that: `lib/extension_manager/application.rb` has no `dbus_register` /
`dbus_unregister` override at all, so even if the search-provider class were
written there is currently no application-level mechanism to export it on.
Same application file has no `open` override, so upstream's
`gnome-extensions://<uuid>` URI-scheme handling (`exm_application_open`) is
also entirely absent — not stubbed, not partially done, just not present.

**Behaviour owed:** GNOME Shell's overview search surfacing installed
extensions (the `SearchProvider2` D-Bus interface), and a `gnome-extensions://`
link anywhere on the system opening this app to that extension's detail page.

### 3. Settings diverge from GSettings to a JSON file — a correspondence, flagged for visibility

`lib/settings.rb` keeps upstream's four keys (`width`, `height`,
`is-maximized`, `sort-enabled-first`) and their defaults, bound to the window
the same way, but backs them with a JSON file under `XDG_CONFIG_HOME` instead
of compiled GSettings schema + dconf. The file's own comment states the
reason (avoiding a schema-install step to run from a checkout) — this is
stated as a plain fact about the substitution, not phrased as an excuse, so it
is not an `accountability-ensurance` hit. It is still a real divergence worth
recording here: `gsettings get com.mattjakeman.ExtensionManager
sort-enabled-first` and any other GSettings-based tooling or GNOME Settings
integration no longer works against this app. Filed as a correspondence per
the skill's rules (same keys, same defaults, same binding semantics,
different mechanism), not a gap — but the data/gschema.xml.in file itself is
still unported (see `component-identification.md`), which is the part of this
that *is* a plain gap.

### 4. No `data/` tree at all

No `.desktop.in.in`, no `.metainfo.xml.in.in`, no `.gschema.xml.in`, no
bundled icons directory exists under the port. The About dialog
(`lib/extension_manager/application.rb:139`) is built with no appdata source
behind it — whatever version/developer/comments strings it shows are
hand-written in the Ruby rather than read from metainfo, so they can drift
from what upstream's `.metainfo.xml.in.in` says without anything catching it.

## What this pass did **not** check (said plainly, not implied)

- **No GIR-backed symbol table was built and no `component-scan.sh` run
  against both trees.** The widget/CSS/signal/action counts in
  `.reports/component-identification.md` (carried over from the previous
  round) were produced by reading the `.blp`/`.c` files directly, which is
  sound, but no automated per-file diff against the port's Ruby was run this
  round for the ten newly-ported files (`detail_view.rb`, `author_page.rb`,
  `screenshot_view.rb`, `zoom_picture.rb`, `animated_paintable.rb`,
  `comment_dialog.rb`, `versions_dialog.rb`, `backtrace.rb`, `unified_data.rb`,
  `screenshot.rb`). The drive scripts exercise their behaviour at runtime
  (see `test-parity.md`) but that is not the same as a count-by-count widget
  audit.
- **The stylesheet diff was not run.** `diff` between `src/style.css`
  (upstream) and `lib/style.css` (port) was not performed in this pass.
- **The text axis was not run per-component.** `translation-parity.md` covers
  the catalogue as a whole (0/149 messages — see that report) but no
  per-widget msgid mapping was produced here.

Treat the four items above as open, not as "checked and clean" — a check that
was not run is not a check that passed.

## Verdict

**Not clean.** Two dead/absent user-facing destinations (`upgrade_assistant`,
`gnome_shell_search_provider`/`app.open`), a missing `data/` tree, and an
unverified (not merely unexamined-and-fine, genuinely not run) four-axis
comparison across most of the 45 existing component files.
