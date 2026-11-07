# Component inventory — Extension Manager (Ruby port)

Surveyed `ruby` branch (HEAD at the time of this report) against upstream
`origin/master`. Scope: every user-facing component — windows, dialogs,
pages, rows, menus, keyboard shortcuts, settings, actions, empty/error
states — plus the declarative-UI-equivalent assets (upstream's `.blp`,
GSettings schema, GResource manifest, `po/` catalogue).

Legend: **exists** = Yes (file present and appears to implement the
upstream behaviour), Partial (file present but a piece of upstream behaviour
looks unported), No (nothing on `ruby` corresponds).

## Windows / top-level

| Upstream file(s) | `lib/` path | Kind | Exists |
|---|---|---|---|
| `src/exm-window.blp` + `src/exm-window.c` | `lib/window.rb` | window | Yes |
| `src/exm-application.c` | `lib/extension_manager/application.rb` | app class (actions, accels, stylesheet, About dialog, logout, search-provider export) | Yes |
| `src/main.c` | `exe/extension-manager` | entrypoint | Yes |
| `src/exm-shortcuts-dialog.blp` (no `.c`) | `lib/shortcuts_dialog.rb` | shortcuts window | Yes |

## Pages

| Upstream file(s) | `lib/` path | Kind | Exists |
|---|---|---|---|
| `src/exm-browse-page.blp` + `.c` | `lib/browse_page.rb` | page (search entry, sort dropdown, result stack, empty/error states) | Yes |
| `src/exm-installed-page.blp` + `.c` | `lib/installed_page.rb` | page (list, global toggle, search, empty state) | Yes |
| `src/exm-detail-view.blp` + `.c` | `lib/detail_view.rb` | page (extension detail, screenshots, versions, comments, uninstall) | Yes |
| `src/exm-author-page.blp` + `.c` | `lib/author_page.rb` | page (author's other extensions / offline state) | Yes |
| `src/exm-upgrade-assistant.blp` + `.c` | `lib/upgrade_assistant.rb` | page (per-shell-version upgrade support list) | Yes |

## Dialogs

| Upstream file(s) | `lib/` path | Kind | Exists |
|---|---|---|---|
| `src/exm-comment-dialog.blp` + `.c` | `lib/comment_dialog.rb` | dialog (extension reviews) | Yes |
| `src/exm-error-dialog.blp` + `.c` | `lib/error_dialog.rb` | dialog (D-Bus/network error detail + copy) | Yes |
| `src/exm-extension-error-dialog.blp` + `.c` | `lib/extension_error_dialog.rb` | dialog (extension's own error log + copy) | Yes |
| `src/exm-versions-dialog.blp` + `.c` | `lib/versions_dialog.rb` | dialog (supported shell versions list) | Yes |
| Inline `AdwAlertDialog`s in `src/exm-window.c` (`remove_dialog`, `unsupported_dialog`, `select_remove_dialog`) and `src/exm-detail-view.c` (`on_uninstall_confirm_response`) | `lib/confirm_dialogs.rb` | confirm/alert dialogs, no single upstream file | Yes |
| `app.about` action in `src/exm-application.c` | `lib/extension_manager/application.rb` (`ABOUT_*` constants + about action) | About dialog | Yes |

## Rows / tiles / small widgets

| Upstream file(s) | `lib/` path | Kind | Exists |
|---|---|---|---|
| `src/exm-extension-row.blp` + `.c` | `lib/extension_row.rb` | row (installed extension) | Yes |
| `src/exm-search-row.blp` + `.c` | `lib/search_row.rb` | row (browse search result) | Yes |
| `src/exm-comment-tile.blp` + `.c` | `lib/comment_tile.rb` | tile (one review) | Yes |
| `src/exm-install-button.blp` + `.c` | `lib/install_button.rb` | widget (install/installed/update split button) | Yes |
| `src/exm-extension-toggle.c` (no `.blp`) | `lib/extension_toggle.rb` | widget (enable switch, handles the unsupported-confirm flow) | Yes |
| `src/exm-rating.blp` + `.c` | `lib/rating.rb` | widget (star rating display) | Yes |
| `src/exm-screenshot.blp` + `.c` | `lib/screenshot.rb` | widget (one screenshot thumbnail) | Yes |
| `src/exm-screenshot-view.blp` + `.c` | `lib/screenshot_view.rb` | widget (screenshot carousel/lightbox) | Yes |
| `src/exm-zoom-picture.c` (no `.blp`) | `lib/zoom_picture.rb` | widget (pinch/scroll zoom picture used by screenshot view) | Yes |
| `src/exm-animated-paintable.c` (no `.blp`) | `lib/animated_paintable.rb` | paintable (animated GIF/WebP screenshot playback) | Yes |
| Menu `primary_menu` in `src/exm-window.blp` | `lib/primary_menu.rb` | menu model | Yes |

## Non-widget support classes (models, providers, D-Bus, settings)

| Upstream file(s) | `lib/` path | Kind | Exists |
|---|---|---|---|
| `src/local/exm-manager.c` + `.h` | `lib/manager.rb` | GNOME Shell D-Bus manager | Yes |
| `src/local/exm-extension.c` + `.h` | `lib/extension.rb` | extension model | Yes |
| `src/local/shell-dbus-interface.c`/`.h` (+ `org.gnome.Shell.Extensions.xml`) | `lib/shell_dbus_interface.rb` | generated D-Bus proxy interface | Yes |
| `src/exm-gnome-shell-search-provider.c` + `.h` (+ `org.gnome.Shell.SearchProvider2.xml`) | `lib/gnome_shell_search_provider.rb` | search provider (exports over D-Bus) | Yes |
| `src/exm-backtrace.c` | `lib/backtrace.rb` | crash/backtrace capture used by error dialogs | Yes |
| `src/exm-unified-data.c` | `lib/unified_data.rb` | model unifying installed + remote extension data | Yes |
| `src/exm-upgrade-result.c` | `lib/upgrade_result.rb` | model (per-extension upgrade-assistant result) | Yes |
| `src/exm-utils.c` | `lib/utils.rb` | misc helpers | Yes |
| `src/exm-types.h` | `lib/types.rb` | shared enums | Yes |
| `src/web/exm-data-provider.c`/`.h` | `lib/data_provider.rb` | extensions.gnome.org API client | Yes |
| `src/web/exm-comment-provider.c`/`.h` | `lib/comment_provider.rb` | reviews API client | Yes |
| `src/web/exm-image-resolver.c`/`.h` | `lib/image_resolver.rb` | remote image loader (uses `Gly`/`GlyGtk4`) | Yes |
| `src/web/exm-profile-provider.c`/`.h` | `lib/profile_provider.rb` | user profile API client | Yes |
| `src/web/exm-request-handler.c`/`.h` | `lib/request_handler.rb` | HTTP layer (uses `Soup`) | Yes |
| `src/web/exm-search-provider.c`/`.h` | `lib/search_provider.rb` | browse search API client | Yes |
| `src/web/exm-versions-provider.c`/`.h` | `lib/versions_provider.rb` | shell-versions API client | Yes |
| `src/web/model/exm-comment.c`/`.h` | `lib/comment.rb` | model | Yes |
| `src/web/model/exm-search-result.c`/`.h` | `lib/search_result.rb` | model | Yes |
| `src/web/model/exm-shell-versions.c`/`.h` | `lib/shell_versions.rb` | model | Yes |
| `src/web/model/exm-user-profile.c`/`.h` | `lib/user_profile.rb` | model | Yes |
| `src/web/model/exm-version-result.c`/`.h` | `lib/version_result.rb` | model | Yes |
| `data/com.mattjakeman.ExtensionManager.gschema.xml.in` (4 keys: width, height, is-maximized, sort-enabled-first) | `lib/settings.rb` | settings store (documented as JSON-backed substitute for GSettings) | Yes |
| `src/res/suggestions.txt` | `lib/res/suggestions.txt` | data asset (search placeholder suggestions) | Yes |
| `src/style.css` | `lib/style.css` | stylesheet | Yes |

## Gaps found

| Upstream asset | Status on `ruby` | Why it matters |
|---|---|---|
| `data/icons/hicolor/scalable/actions/*.svg` (18 custom symbolic icons: `puzzle-piece-symbolic`, `offline-symbolic`, `clock-alt-symbolic`, `check-round-outline-symbolic`, `supported-symbolic`, `unsupported-symbolic`, `unknown-symbolic`, `pip-in-symbolic`, `pip-out-symbolic`, `session-modes-symbolic`, `star-filled-rounded-symbolic`, `star-outline-rounded-symbolic`, `donation-symbolic`, `globe-symbolic`, `info-symbolic`, `external-link-symbolic` is also custom, `settings-symbolic`, `software-update-available-symbolic`) | **No.** `lib/` has no `data/icons` directory and no file registers an icon-theme search path (`Gtk::IconTheme#add_search_path`/`add_resource_path`) anywhere under `lib/`. These names are set as `icon_name =` all over `window.rb`, `extension_row.rb`, `search_row.rb`, `installed_page.rb`, `detail_view.rb`, `upgrade_assistant.rb`, `versions_dialog.rb`, `author_page.rb`, `comment_dialog.rb` — including `puzzle-piece-symbolic`, the app's own glyph, used as the default extension icon and the installed-page empty-state icon. | Without the icon files and a search path, every one of those icons falls back to the broken-image glyph. This is a real, user-visible gap even though the Ruby code that *sets* the icon names already exists; it was not caught by reading `lib/*.rb` alone because the code looks complete. |
| `data/com.mattjakeman.ExtensionManager.desktop.in.in` | Not present under `ruby`'s `data/` (only the search-provider `.ini.in` and D-Bus `.service.in` are). | No `.desktop` launcher entry is shipped; app discoverability in a shell/activities overview is upstream behaviour not yet replicated. Lower priority than the icons (the gem's `exe/extension-manager` already runs the app directly), but still a parity gap. |
| `data/com.mattjakeman.ExtensionManager.metainfo.xml.in.in` | Not present. | Feeds AppStream (release notes, screenshots metadata) — not consumed by any `lib/` file (no About-dialog release-notes use found), so lower priority, but worth tracking since full parity includes it. |
| `po/*.po` + `po/extension-manager.pot` (72 locales) | Not assessed in this pass beyond noting upstream has them; `ruby` has no `po/` directory. Translation parity is explicitly out of scope for this inventory (covered by the `translation-parity` skill in a separate pass). | Flagging only so it isn't silently dropped from the overall parity picture. |

## Wiring check (binding gems) — confirmed intact, not regressed

- `glycin` (`Gly::`) is required and called in `lib/image_resolver.rb` (`Gly::Loader.new(...).load`).
- `libglycin-gtk4` (`require 'libglycin_gtk4'`, `GlyGtk4::`) is required in `lib/image_resolver.rb` and `lib/animated_paintable.rb`.
- `soup3` (`Soup::`) is required and called in `lib/request_handler.rb` (`Soup::Message.new`, `Soup::Session.new`).
- Gemspec declares `glib2`, `gtk4`, `adwaita`, `glycin`, `libglycin-gtk4`, `soup3` as runtime dependencies; all six are `require`d somewhere under `lib/`.
- No hand-rolled substitute for any of these three namespaces was found (no raw `Gio::DBusProxy` image fetch, no shelling out for HTTP, no `/proc` reads standing in for glycin).

This pass did not re-drive the gems live (no app code was written or run, per
the task's "do not write app code" instruction); the check above is static
(require + call-site grep) only. A future pass that runs the drive script
should still assert on a real `Gly`/`Soup` result per the task's warning about
calls that never execute.

## Bottom line

The `ruby` branch already has a `lib/*.rb` (or `lib/res/*`, `lib/style.css`)
counterpart for every upstream `src/` and `src/web/` source file, including
the four non-widget D-Bus/search-provider classes and the five web API
models — 45 of 45 source-backed components map 1:1, all present. The
remaining work for full parity is not missing widget code but missing
**data assets**: the custom symbolic icon set (highest priority — those
icons are on nearly every screen and currently have no file to resolve to),
the `.desktop` launcher entry, the AppStream metainfo, and (tracked
separately) the `po/` translation catalogue.
