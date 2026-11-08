# Extension Manager — component identification (round 4)

Upstream ref: **`origin/master`**. `origin/main` does not exist in this
clone (`git ls-remote origin main` returns nothing); `origin/HEAD` points at
`origin/ruby`. Every report in this round treats `origin/main` in the task
text as a mistaken name for `origin/master`.

Port branch: `ruby` @ `e564797` (`Drive the icon theme, desktop entry and
metainfo templates end to end`).

This supersedes the round-3 version of this file (written against
`f9d640c`). Since round 3, two more commits landed:
`c5fc5b0` (port custom symbolic icons, desktop entry, metainfo) and
`e564797` (drive them). Re-verified every claim below live, not carried
over from round 3's text.

## File-level census, re-run this round

```
find lib exe -type f | wc -l        -> 51 (46 lib/*.rb files, lib/style.css,
                                            lib/res/suggestions.txt,
                                            exe/extension-manager,
                                            lib/extension/manager/rb/version.rb
                                            counted among the 46)
git ls-tree -r --name-only origin/master -- src/ | wc -l   -> 112 (not 1:1 —
  upstream pairs most components as a .blp + a .c + a .h; the port is one
  .rb per component, so a raw file-count comparison is not meaningful)
```
`.reports/component-inventory.md` (written this branch, round 3) maps every
upstream `src/` window, page, dialog, row, widget and support class onto a
`lib/*.rb` file 1:1 and marks all of them "Yes". Spot-re-checked this round
for the two newest ones (`lib/upgrade_assistant.rb`,
`lib/gnome_shell_search_provider.rb`) plus the icon-theme work — all still
hold. Code-level component coverage (windows/pages/dialogs/rows/widgets/
models) is complete at the file-existence level.

## Round 3's two former gaps: unchanged, still closed (re-verified, not assumed)

| Upstream | Port file | Exists |
|---|---|---|
| `src/exm-upgrade-assistant.blp` + `.c` | `lib/upgrade_assistant.rb` | yes |
| `src/exm-gnome-shell-search-provider.c` | `lib/gnome_shell_search_provider.rb` | yes |

## `data/` — improved this round, still well short of upstream

```
git ls-tree -r --name-only origin/master -- data/   -> 37 files
find data -type f                                     -> 22 files
```

Upstream's 37 `data/` files break down as: 5 top-level templates
(`.desktop.in.in`, `.gschema.xml.in`, `.metainfo.xml.in.in`,
`.search-provider.ini.in`, `.service.in`), 4 top-level app-icon SVGs
(`com.mattjakeman.ExtensionManager.svg`, `.Devel.svg`, `.Source.svg`,
`-symbolic.svg`), 18 action-glyph SVGs under
`data/icons/hicolor/scalable/actions/`, 2 `meson.build` files, and 8
screenshot PNGs.

The port now ships, re-confirmed by `find` this round:

- 4 of 5 top-level templates (`desktop.in.in`, `metainfo.xml.in.in`,
  `search-provider.ini.in`, `service.in` — all present; **`.gschema.xml.in`
  is still missing**, re-confirmed: `find data -iname "*gschema*"` is
  empty).
- **All 18** action-glyph SVGs, name-for-name identical to upstream's list
  (diffed by hand against `git ls-tree origin/master -- data/icons/hicolor`;
  no name differs).
- **0 of 4** top-level app-icon SVGs. `find data/icons -maxdepth 1 -type f`
  returns nothing — `com.mattjakeman.ExtensionManager.svg`, `.Devel.svg`,
  `.Source.svg` and `-symbolic.svg` are all still absent. This matters
  beyond file-completeness: `lib/extension_manager/application.rb:176` sets
  `dialog.application_icon = APP_ID` (`com.mattjakeman.ExtensionManager`) in
  the About dialog, and nothing in the port's shipped icon set, nor any
  system theme in this sandbox, has a file by that name. The About dialog's
  own icon is unresolvable. `test/drive_assets.rb` (new this round) checks
  that the 18 *action* icons resolve through the real `Gtk::IconTheme` but
  does not check `APP_ID` itself — this gap is real and untested by the new
  driver, not merely unexercised.
- **0 of 2** `meson.build` files (not meaningful on a Ruby/Bundler port, but
  still literally absent from the inventory).
- **0 of 8** screenshot PNGs (used by the metainfo's `<screenshot>`
  elements and by the README; `test/drive_assets.rb` checks the metainfo
  template *names* at least one screenshot element but never checks that
  the referenced image file exists on disk, because it doesn't).

## `po/` — still completely absent, re-confirmed this round

```
find . -iname po -maxdepth 2          -> nothing
git show origin/master:po/extension-manager.pot | grep -c '^msgid "'  -> 149
git show origin/master:po/LINGUAS | tr ' ' '\n' | grep -c .            -> 45
```
Unchanged across four rounds. See `translation-parity.md`.

## The application-level `open` override — still absent, re-confirmed this round

```
grep -n "def open\b" lib/extension_manager/application.rb   -> no match
grep -rn "gnome-extensions" lib/ exe/                        -> no match
```
`exm_application_open` (upstream's `gnome-extensions://<uuid>` URI-scheme
handler, forwarding to `win.show-detail`) still has no port code, stub or
otherwise. The desktop-entry template the port now ships
(`data/com.mattjakeman.ExtensionManager.desktop.in.in`) declares
`MimeType=x-scheme-handler/gnome-extensions;` (checked live by
`test/drive_assets.rb`'s "its MimeType handles the gnome-extensions URI
scheme" check) — so the port now *advertises* that it handles this URI
scheme via its desktop file, while the actual handler code to do anything
with an incoming URI still does not exist. This is a sharper form of the
gap than round 3's: before this round, nothing claimed the capability;
now the (unshipped, template-only) desktop entry claims it and the app
itself still cannot honor it.

## Verdict

Every upstream window, page, dialog, row, widget and support class in
`component-inventory.md`'s table maps onto a `lib/*.rb` file and is marked
present; spot-checks this round found nothing to contradict that.
`data/` moved from 2/37 (round 3) to 22/37 this round — real progress, but
the two most user-visible pieces of what's left (the app's own icon, and
honoring the `gnome-extensions://` scheme its own desktop entry now claims
to register) are still open. `po/` remains 0/37-ish files, exactly as every
prior round. Carried into `component-parity.md`, `translation-parity.md`
and `accountability-ensurance.md`.
