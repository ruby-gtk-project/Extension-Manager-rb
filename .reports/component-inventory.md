# Extension Manager — upstream component inventory

Survey step, re-run against the current `ruby` branch. No app code written. Produced with the `component-identification`
skill in `.claude/skills/`.

- Upstream ref: **`origin/master`** (not `origin/main` — that ref does not exist
  in this clone; `origin/HEAD` points at `origin/ruby`).
- Port branch: `ruby`.
- Upstream is C + GObject with **blueprint** (`.blp`) UI, libadwaita
  `>= 1.8.alpha`. 18 `.blp` files, 17 of which are `template` roots backed by a
  `.c` file; `src/exm-shortcuts-dialog.blp` is a standalone root with no backing
  source.
- Port `lib/` on `ruby` at `3671464` holds 26 Ruby files (~3.5k lines): the
  application and its inline window, the whole Installed view, and every model
  and backend. The Browse half of the app — Browse page, detail view, author
  page, screenshot viewer, comment and versions dialogs, upgrade assistant,
  crash reporter — is not written. See **Port status** below.

House shape is taken from the pilot at `../gnome-contacts-rb`: ported components
live flat as `lib/<thing>.rb` with top-level classes; only the application class
stays under `lib/extension_manager/`.

---

## Component map

A component is the union of one `.blp` and its `.c`. Below, "upstream file" names
the pair.

### The application and the main window

## src/exm-application.c — the application object

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` subclass | 1 | — | `activate`, `open`, `dbus_register`, `dbus_unregister` | `open` handles the `gnome-extensions://<uuid>` URI scheme and forwards to `win.show-detail` |
| `Adw.AboutDialog` | 1 | — | `app.about` | built from the metainfo appdata; sets version, comments, developers (Matthew Jakeman, Óscar Fernández Díaz), translator-credits, copyright; adds a `libbacktrace` legal section when built `WITH_BACKTRACE` |

Actions installed: `app.quit`, `app.about`, `app.logout` (D-Bus
`org.gnome.SessionManager.Logout`), `app.sort-enabled-first` (a
`g_settings_create_action` stateful toggle).
Accelerators: `app.quit` = `<primary>q`, `window.close` = `<primary>w`.
GSettings `width`/`height`/`is-maximized` are bound to the window.
Repeaters: none. Conditional: the legal section, the `.Devel` version suppression.

## src/exm-window.blp + src/exm-window.c — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template) | 1 | `devel` (added in code when the app id ends `.Devel`) | — | width/height-request 360×294 |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 400sp` → nulls `header_bar.title-widget`, reveals `switcher_bar` |
| `Adw.ToastOverlay` | 1 | — | — | hosts `_("An Error Occurred")` toast |
| `Gtk.Stack` `main_stack` | 1 | — | — | crossfade; pages `app`, `noshell` |
| `Adw.NavigationView` | 1 | — | — | `main` page (can-pop false) + `$ExmScreenshotView` |
| `Adw.ToolbarView` | 2 | — | — | one per stack page |
| `Adw.HeaderBar` | 2 | — | — | main one has `show-back-button: false` |
| `Gtk.Stack` (title) | 1 | — | — | crossfade between `switcher` / `selection`, driven by `installed_page.selection-mode` |
| `Adw.ViewSwitcher` `title` | 1 | — | — | policy wide, bound to `view_stack` |
| `Adw.WindowTitle` | 2 | — | — | selection count title; noshell title |
| `Gtk.Button` `cancel_selection_btn` | 1 | — | `clicked` → `on_cancel_selection_clicked` | `_("Cancel")`, visible with selection-mode |
| `Gtk.ToggleButton` `search_button` | 1 | — | — | `edit-find-symbolic`, tooltip `_("Search Installed Extensions")` |
| `Gtk.MenuButton` | 1 | — | `menu-model: primary_menu` | `open-menu-symbolic`, primary, tooltip `_("Main Menu")` |
| `Gtk.SearchBar` + `Gtk.SearchEntry` | 1 + 1 | — | bidirectional bind to `search_button.active` | placeholder `_("Search for installed extensions")`, max 35 chars |
| `Adw.ViewStack` `view_stack` | 1 | — | `notify::visible-child` → `on_visible_page_changed` | |
| `Adw.ViewStackPage` | 2 | — | — | `installed` (`_Installed`, `puzzle-piece-symbolic`), `browse` (`_Browse`, `globe-symbolic`) |
| `Gtk.ActionBar` | 1 | — | revealed with selection-mode | |
| `Gtk.Button` (uninstall) | 1 | `destructive-action` | `clicked` → `on_uninstall_selected_clicked` | `_("Uninstall…")`, sensitive on `n-selected > 0` |
| `Adw.ViewSwitcherBar` `switcher_bar` | 1 | — | — | revealed by the breakpoint |
| `Adw.StatusPage` (noshell) | 1 | — | — | `_("GNOME Shell Unavailable")` / `_("Log in to a GNOME session to manage extensions")` |
| `Gtk.Button` (discover) | 1 | `pill`, `suggested-action` | `win.discover-gnome` | `_("_Discover GNOME")`, tooltip `https://www.gnome.org`; opens a `Gtk.UriLauncher` |
| `Gtk.UriLauncher` | 1 | — | — | `https://www.gnome.org` |

**Menu** `primary_menu` — 2 sections, 4 items: `Sort _Enabled First` →
`app.sort-enabled-first`; `_Upgrade Assistant` → `win.show-upgrade-assistant`;
`_Keyboard Shortcuts` → `app.shortcuts`; `_About Extension Manager` → `app.about`.

**Alert dialogs** (three standalone `Adw.AlertDialog` roots in the same `.blp`):

| Dialog | Heading / body | Responses |
|---|---|---|
| `remove_dialog` | `_("Uninstall Extension?")` / "The extension's features and functionality will no longer be accessible…" | `no` `_("_No")`, `yes` `_("_Yes")` destructive |
| `select_remove_dialog` | `_("Uninstall Extensions?")`, body set in code with the selection count | same |
| `unsupported_dialog` | `_("Unsupported Extension")` / "This extension does not support your GNOME Shell version…" | `install` `_("_Install Anyway")` destructive, `back` `_("_Go Back")` suggested; `prefer-wide-layout` |

**Actions installed** (`gtk_widget_class_install_action`, 18):
`ext.install` `(sb)`, `ext.remove` `s`, `ext.open-prefs` `s`, `ext.show-error` `s`,
`win.show-detail` `s`, `win.show-author` `(uss)`, `win.show-main`,
`win.show-screenshot`, `win.show-upgrade-assistant`, `win.show-page` `s`,
`win.show-error` `s`, `win.show-error-dialog` `s`, `win.search-online`,
`win.search-installed` `s`, `win.discover-gnome`, `screenshot.zoom-in`,
`screenshot.zoom-out`, `screenshot.zoom-reset`.

**Keyboard bindings** (`gtk_widget_class_add_binding_action`):
`<Alt>1` → `win.show-page "installed"`, `<Alt>2` → `win.show-page "browse"`,
`<Control>plus` → zoom-in, `<Control>minus` → zoom-out, `<Control>0` → zoom-reset.

## src/exm-shortcuts-dialog.blp — keyboard shortcuts window

Standalone `Adw.ShortcutsDialog` root, no backing `.c`; nothing in `src/*.c`
references it, so it is picked up from the GResource by the `app.shortcuts`
convention. 3 sections, 9 items.

| Section | Items |
|---|---|
| Views | Switch to Installed `<Alt>1`; Switch to Browse `<Alt>2` |
| Screenshot View | Zoom In `<Control>plus`; Zoom Out `<Control>minus`; Reset Zoom `<Control>0` |
| App | Toggle Search `<Control>F`; Keyboard Shortcuts → `app.shortcuts`; Close Window → `window.close`; Quit → `app.quit` |

### The Installed view

## src/exm-installed-page.blp + .c — the installed-extensions page

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` (template) | 1 | — | `notify::manager` → `on_bind_manager` | properties `selection-mode`, `n-selected`, `search-mode-enabled`, `search-query` |
| `Gtk.Stack` | 1 | — | — | crossfade; pages `page_list`, `page_results`, `page_no_results`, `page_empty` |
| `Adw.PreferencesPage` | 2 | — | — | list page, search-results page |
| `Adw.Banner` `updates_banner` | 1 | — | `app.logout`, `button-style: suggested` | `_("_Log Out…")` |
| `Adw.SwitchRow` `global_toggle` | 1 | — | — | `_("Use Extensions")` / `_("Extensions can cause performance and stability issues")`, prefix `puzzle-piece-symbolic` |
| `Adw.PreferencesGroup` | 4 | — | `notify::visible` → `on_visible_stack_changed` (user + system) | unnamed, `user_prefs_group` `_("User-Installed Extensions")`, `system_prefs_group` `_("System Extensions")`, `search_prefs_group` |
| `Gtk.ToggleButton` `select_btn` | 1 | `flat` | bidirectional bind to `selection-mode` | `check-round-outline-symbolic`, tooltip `_("Select Extensions")` |
| `Adw.StatusPage` | 2 | — | — | `_("No Results Found")`/`_("Try a different search or search online")`; `_("No Extensions Installed")`/`_("Search online to install extensions")` |
| `Gtk.Button` (search online) | 2 | `pill` | `win.search-online` | `_("_Search Online")` |

**Repeaters:** `$ExmExtensionRow` per extension, into `user_prefs_group`,
`system_prefs_group` and `search_prefs_group` — driven by
`Gtk.SortListModel` / `Gtk.FilterListModel` chains built in code
(`Gtk.PropertyExpression` on `name`, `Gtk.StringSorter`, a
`Gtk.CustomSorter compare_enabled` added only when `sort-enabled-first` is set,
`Gtk.MultiSorter`, `Gtk.StringFilter` for search, `Gtk.BoolFilter` on `is-user`).
Action installed in code: `selection-changed` (`Gio.SimpleAction`).

## src/exm-extension-row.blp + .c — one installed extension row

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` (template) | 1 | — | `activated` → `on_row_activated` | title/subtitle bound to extension `name`/`uuid`, 1 line each, `use-markup: false` |
| `Gtk.Image` `update_icon` | 1 | `update` | — | `software-update-available-symbolic`, visible on `has-update`, tooltip "A newer version of this extension is available" |
| `Gtk.Image` `out_of_date_icon` | 1 | `error` | — | `clock-alt-symbolic`, visible when state is out-of-date, tooltip "This extension is incompatible with your current version of GNOME" |
| `Gtk.Button` `error_btn` | 1 | `flat`, `error` | `row.show-error` | `dialog-error-symbolic`, visible when state is error |
| `Gtk.Button` `prefs_btn` | 1 | `flat` | `row.open-prefs` | `settings-symbolic`, visible on `has-prefs` |
| `Gtk.Switch` `ext_toggle` | 1 | — | `state-set` → `on_state_changed` | active/sensitive bound to `enabled`/`can-change` |
| `Gtk.Image` `nav_icon` | 1 | — | — | `go-next-symbolic` |

Actions installed in code: `row.open-prefs`, `row.show-error`.
Also gains a selection check-button in selection mode (driven from the page).

## src/exm-extension-toggle.c — switch ⇄ extension-state binding helper

No `.blp`, no GObject type (`G_DECLARE_*` absent). Keeps a `Gtk.Switch`'s state
in sync with an extension's `enabled`, guarding against feedback loops. **Not a
widget** — behaviour used by `exm-extension-row` and `exm-detail-view`. Port as a
small helper, not a widget class.

### The Browse view

## src/exm-browse-page.blp + .c — search extensions.gnome.org

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` (template) | 1 | — | `notify::manager` → `on_bind_manager` | |
| `Adw.BreakpointBin` + `Adw.Breakpoint` | 1 + 1 | — | — | `max-width: 400sp` |
| `Adw.StatusPage` `status_page` | 1 | — | — | `_("Search for Extensions")` / "Enter a keyword to search 'extensions.gnome.org'…" |
| `Gtk.Box` (linked) | 1 | `linked` | — | search controls |
| `Gtk.SearchEntry` | 1 | — | `realize`, `search-changed` → `on_search_changed`, `changed` → grab-focus | `search-delay: 750`, labelled-by the status page |
| `Gtk.Button` `order_btn` | 1 | — | `clicked` → `on_order_button_clicked` | `view-sort-descending-symbolic`, tooltip `_("Descending Order")`, initially hidden |
| `Gtk.DropDown` `search_dropdown` | 1 | — | `notify::selected` → `on_search_changed` | `Gtk.StringList` of 5: None, Popularity, Downloads, Updated, Created (order matches `ExmSearchSort`) |
| `Gtk.Stack` `search_stack` | 1 | — | — | `page_spinner`, `page_results`, `page_empty`, `page_error` |
| `Adw.Spinner` | 1 | `dimmed` | — | 64×64 |
| `Gtk.ListBox` `search_results` | 1 | `boxed-list` | selection none | |
| `Gtk.ListBox` `more_results_list` | 1 | `boxed-list` | selection none | |
| `Adw.ButtonRow` `more_results_btn` | 1 | — | `activated` → `on_load_more_results` | `view-more-symbolic`, `_("_Load More Results")` |
| `Gtk.Image` + `Gtk.Label`×2 (empty) | 1 + 2 | `dimmed` on image, `title-1` on first label | — | `edit-find-symbolic`, `_("No Results Found")`, `_("Try a different search")` |
| `Gtk.Image` + `Gtk.Label`×2 (error) | 1 + 2 | `dimmed`, `title-1` | — | `offline-symbolic`, `_("Connection Error")`, `error_label` |

Repeaters: `$ExmSearchRow` per search result into `search_results`.
Built in code: a `Gtk.StringList` of suggestions from `src/res/suggestions.txt`.

## src/exm-search-row.blp + .c — one search result row

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (template) | 1 | `search-row` | `win.show-detail` | activatable; properties `show-icon`, `show-creator`, `compact`; described-by the description label |
| `Gtk.Box` | 2 | `header`, `title` | — | |
| `Gtk.Image` `row_icon` | 1 | — | — | `puzzle-piece-symbolic`, 32px, visible on `show-icon` |
| `Gtk.Label` `title` | 1 | `title` | — | bound to result `name`, 2 lines, ellipsize end |
| `Gtk.Label` `subtitle` | 1 | `subtitle` | — | bound to `creator`, visible on `show-creator` |
| `Gtk.Label` `description_label` | 1 | `dimmed` | — | `$first_line(description)`, 2 lines |
| `$ExmInstallButton` `install_btn` | 1 | — | `clicked` → `install_remote` | `icon-only` bound to `compact` |
| `Gtk.Image` | 1 | — | — | `go-next-symbolic` |

## src/exm-install-button.blp + .c — the install button

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Button` (template) | 1 | — | — | properties `icon-only`, `can-shrink` |
| `Gtk.Stack` | 1 | — | — | crossfade, `hhomogeneous: false`, `interpolate-size: true` |
| `Gtk.Label` `label` | 1 | — | — | label page |
| `Gtk.Image` `icon` | 1 | — | — | `folder-download-symbolic` |

### The Detail view

## src/exm-detail-view.blp + .c — one extension's detail page

The largest component in the app (~1500 lines of C, ~560 lines of blueprint).

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` (template) | 1 | — | — | property `data` (`$ExmUnifiedData`) |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 1 / 1 | — | — | header `overflow: hidden` |
| `Gtk.Revealer` `title_revealer` + `Adw.WindowTitle` | 1 + 1 | — | — | slide-up 500ms; title/subtitle = name/uuid; revealed on scroll |
| `Adw.ToastOverlay` | 1 | — | — | shows `_("Copied")` |
| `Adw.BreakpointBin` + `Adw.Breakpoint` | 1 + 1 | — | `apply`/`unapply` → `breakpoint_apply_cb`/`breakpoint_unapply_cb` | at `400sp`: `header_suffix` → vertical, `ext_install.halign: start`, `ext_title` swaps `title-1` ↔ `title-2` in code |
| `Gtk.Stack` `stack` | 1 | — | — | `page_spinner`, `page_error`, `page_empty`, `page_detail` |
| `Adw.SpinnerPaintable` + `Adw.StatusPage` `loading_status` | 1 + 1 | — | — | `_("Loading Details")` |
| `Adw.StatusPage` `error_status` | 1 | — | — | `offline-symbolic`, `_("Connection Error")` |
| `Adw.StatusPage` (empty) | 1 | — | — | `dialog-question-symbolic`, `_("An Error Occurred")` / `_("No extension details available")` |
| `Adw.Banner` `error_banner` | 1 | — | `detail.show-error` | `_("This extension has an error")`, button `_("_View Details")` |
| `Gtk.ScrolledWindow` + `Adw.Clamp` | 1 + 1 | — | — | max 800 |
| `Gtk.Box` (detail) | 1 | `detail` | — | |
| `Gtk.Image` `ext_icon` | 1 | — | — | 64px, focusable |
| `Gtk.Label` `ext_title` | 1 | `title-1` / `title-2` (swapped at breakpoint) | — | selectable, 2 lines |
| `Gtk.Label` `ext_author` | 1 | `author-link` | `activate-link` → `on_author_link_activated` | `$format_author_link(creator, creator-username)`, markup |
| `Gtk.Stack` `tools_stack` | 1 | — | — | `uninstalled-tools-page` / `installed-tools-page` |
| `$ExmInstallButton` `ext_install` | 1 | — | `clicked` → `install_remote` | can-shrink |
| `Gtk.Button` `remove_btn` | 1 | `circular`, `destructive-action` | `page.remove` | `user-trash-symbolic`, tooltip `_("Remove Extension")` |
| `Gtk.Button` `prefs_btn` | 1 | `circular` | `page.open-prefs` | `settings-symbolic`, tooltip `_("Open extension preferences")` |
| `Gtk.Switch` `ext_toggle` | 1 | — | `state-set` → `on_toggle_changed` | tooltip `_("Toggle Extension")` |
| `Gtk.Overlay` `ext_screenshot_container` | 1 | — | — | |
| `Gtk.Button` `ext_screenshot_popout_button` | 1 | `osd`, `circular` | `win.show-screenshot` | `pip-out-symbolic`, tooltip `_("Enlarge Image")` |
| `$ExmScreenshot` `ext_screenshot` | 1 | — | — | focusable |
| `Gtk.Label` `description` / `ext_description` | 1 / 1 | `title-4` + `detail-heading` / `multiline` | — | `_("Description")`; body selectable, labelled-by the heading |
| `Adw.PreferencesGroup` (facts) | 1 | — | — | |
| `Adw.ActionRow` `downloads_row` | 1 | — | — | `folder-download-symbolic`, `C_("Number of downloads", "Downloads")`, suffix `downloads_label` (`numeric`) |
| `Adw.ActionRow` `version_row` | 1 | — | `detail.show-versions`, activatable | `system-software-install-symbolic`, `_("Version")`; suffixes `update_icon` (`update`, hidden), `out_of_date_icon` (`error`, hidden), `version_label` (`numeric`), `version_row_go_next` (`go-next-symbolic`) |
| `Adw.ActionRow` `session_modes_row` | 1 | — | — | `session-modes-symbolic`, `_("Session Modes")`, hidden by default, suffix `session_modes_label` |
| `Adw.ActionRow` `location_row` | 1 | — | `detail.show-files-or-copy-path`, activatable | `system-file-manager-symbolic`, `_("Location")`; suffix icons `folder-open-symbolic` / `edit-copy-symbolic` swapped by whether the path can be opened |
| `Adw.PreferencesGroup` `links_group` | 1 | — | — | `_("Links")` |
| `Adw.ActionRow` `link_homepage` | 1 | — | `detail.open-homepage`, activatable | `go-home-symbolic`, `_("Homepage")`, subtitle = homepage, visible on `$has_homepage`, suffix `external-link-symbolic` |
| `Adw.ActionRow` `link_donation` | 1 | — | `detail.open-donation`, activatable | `donation-symbolic`, `_("Donate")` — the single-donation case |
| `Adw.ExpanderRow` `links_donations` | 1 | — | — | `donation-symbolic`, `_("Donate")` — the multi-donation case |
| `Adw.ActionRow` `link_extensions` | 1 | — | `detail.open-extensions`, activatable | `web-browser-symbolic`, `_("View on Extensions")`, suffix `external-link-symbolic` |
| `Gtk.Box` `comments_section` + heading label | 1 + 1 | `title-4`, `detail-heading` | — | `_("Reviews and Comments")` |
| `Gtk.Stack` `comment_stack` | 1 | — | — | `page_spinner`, `page_disabled`, `page_error`, `page_empty`, `page_comments` |
| `Gtk.Image` (comment spinner) | 1 | — | — | `content-loading-symbolic`, large |
| `Gtk.Label` (disabled) | 1 | — | — | `_("Reviews and comments are disabled for this extension")` |
| `Gtk.Label`×2 (comment error) | 2 | `heading`, `body` | — | `_("Connection Error")` + `error_label` |
| `Gtk.Label` (comment empty) | 1 | — | — | `_("There are no reviews or comments")` |
| `Adw.WrapBox` `comment_box` | 1 | — | — | vertical, line-homogeneous, 12px spacing |
| `Gtk.Button` `show_more_btn` | 1 | `pill` | opens `ExmCommentDialog` | `_("_Show All")` |

**Repeaters:** `$ExmCommentTile` per comment into `comment_box`, each wrapped
with the `card` CSS class added in code (line 317); one `Adw.ActionRow` built in
code per donation platform into `links_donations` (line 382), each targeting
`detail.open-donations` with an `i` index.
**Launchers:** `Gtk.FileLauncher` (reveal the extension folder),
`Gtk.UriLauncher` (extensions.gnome.org, homepage, donation URLs).
**Actions installed:** `detail.show-versions`, `detail.show-error`,
`detail.show-files-or-copy-path`, `detail.open-extensions`,
`detail.open-homepage`, `detail.open-donations` `i`, `detail.open-donation`,
plus `Gio.SimpleAction`s `page.open-prefs` and `page.remove`.

## src/exm-screenshot.blp + .c — the inline screenshot

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` (template) | 1 | — | — | |
| `Gtk.Stack` | 1 | — | — | crossfade; `page_spinner`, `page_picture` |
| `Gtk.Image` | 1 | — | — | `image-loading-symbolic`, large |
| `Gtk.Picture` `picture` | 1 | — | — | fill/fill |

## src/exm-screenshot-view.blp + .c — the full-screen screenshot page

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` (template) | 1 | `tint` | — | tag `screenshot-view` |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 1 / 1 | — | — | |
| `Gtk.Overlay` ×2 | 2 | — | — | outer + `image_overlay` |
| `Gtk.Button` (zoom out) | 1 | `osd`, `circular` | `screenshot.zoom-out` | `zoom-out-symbolic`, tooltip `_("Zoom Out")`, 42×42 |
| `Gtk.Button` (zoom in) | 1 | `osd`, `circular` | `screenshot.zoom-in` | `zoom-in-symbolic`, tooltip `_("Zoom In")`, 42×42 |
| `Adw.Bin` | 1 | — | — | |
| `$ExmZoomPicture` `overlay_screenshot` | 1 | — | `notify::zoom-level` → `notify_zoom` | buttons' sensitivity follows the zoom level |

## src/exm-zoom-picture.c — a pannable, zoomable picture

No `.blp`; a `GtkWidget` subclass that measures, allocates and snapshots a
paintable itself, with `zoom-level`, `min-zoom`, `max-zoom` properties and
scroll/drag gestures. **Custom-drawn widget** — the one component whose port
needs real `measure`/`size_allocate`/`snapshot` work rather than composition.

## src/exm-animated-paintable.c — `GdkPaintable` for animated images

A `GObject` implementing `GdkPaintable` over a glycin animation frame source.
Not a widget; behaviour behind `ExmScreenshot`/`ExmZoomPicture`.

## src/exm-rating.blp + .c — the five-star rating strip

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` (template) | 1 | `rating` (element name, styled in `style.css`) | — | property `rating` |
| `Gtk.Box` | 1 | — | — | horizontal |
| `Gtk.Image` `star_one`…`star_five` | 5 | — | — | icons swapped between `star-filled-rounded-symbolic` / `star-outline-rounded-symbolic` by the rating |

## src/exm-comment-tile.blp + .c — one review/comment tile

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` (template) | 1 | `comment-tile` element name; `card` added by the detail view | — | focusable; property `comment` |
| `Gtk.Box` | 2 | — | — | vertical outer, horizontal header |
| `Gtk.Label` `author` | 1 | `heading` | — | 20 chars max, wraps |
| `Gtk.Label` `author_badge` | 1 | `author-badge` | — | `_("Author")`, visible on `is_extension_creator` |
| `$ExmRating` `rating` | 1 | — | — | visible when rating is non-zero |
| `Gtk.Label` (body) | 1 | `multiline` | — | markup, 30 chars max |
| `Gtk.Label` `date` | 1 | `dimmed` | — | `$format_comment_date(date)` |

## src/exm-comment-dialog.blp + .c — all reviews and comments

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template) | 1 | — | — | 600×600, min 360×294, `_("Reviews and Comments")` |
| `Adw.SpinnerPaintable` | 1 | — | — | bound to `loading_status` |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 1 / 1 | — | — | |
| `Gtk.Stack` | 1 | — | — | `page_spinner`, `page_error`, `page_comments` |
| `Adw.StatusPage` `loading_status` | 1 | — | — | `_("Loading")` |
| `Adw.StatusPage` `error_status` | 1 | — | — | `offline-symbolic`, `_("Connection Error")` |
| `Adw.PreferencesPage` + `Adw.PreferencesGroup` `prefs_group` | 1 + 1 | — | — | |

**Repeater:** a `Gtk.ListBoxRow` built per comment in code (line 146), wrapping
an `$ExmCommentTile`, appended to `prefs_group`.

## src/exm-versions-dialog.blp + .c — version history

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template) | 1 | — | — | 600×600, min 360×294, `_("Version History")` |
| `Adw.SpinnerPaintable` | 1 | — | — | |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 1 / 1 | — | — | |
| `Gtk.Stack` | 1 | — | — | `loading`, `empty`, `list` |
| `Adw.StatusPage` `loading_status` | 1 | — | — | `_("Loading Versions")` |
| `Adw.StatusPage` (empty) | 1 | — | — | `dialog-question-symbolic`, `_("No Version History")` |
| `Gtk.ScrolledWindow` + `Adw.Clamp` | 1 + 1 | — | — | max 600 |
| `Gtk.ListBox` `version_list` | 1 | `boxed-list` | selection none | |
| `Gtk.ListBox` `more_list` | 1 | `boxed-list` | selection none | hidden until there is more |
| `Adw.ButtonRow` `more_btn` | 1 | — | `activated` → `on_more_btn_activated` | `view-more-symbolic`, `_("_Load More Versions")` |

**Repeater:** one row per version built in code — `Adw.ActionRow` +
`Adw.WrapBox` of `Gtk.Label`s with CSS `version-label`, plus `version-label
current` on the installed version, and a `Gtk.Image` with the `accent` class.

### Dialogs and assistants

## src/exm-upgrade-assistant.blp + .c — the upgrade assistant

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template) | 1 | — | `notify::manager` → `on_bind_manager` | 400×600, `_("Upgrade Assistant")` |
| `Adw.SpinnerPaintable` | 1 | — | — | bound to `counter` |
| `Adw.ToastOverlay` | 1 | — | — | toasts `_("Copied")`, `_("No Extensions Installed")` |
| `Adw.NavigationView` | 1 | — | — | intro page + `results` page (`hidden` → `on_hidden_results`) |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 2 / 2 | — | — | |
| `Adw.Clamp` | 1 | — | — | |
| `Gtk.Box` (intro) | 1 | `detail` | — | |
| `Gtk.Image` | 1 | — | — | `software-update-available-symbolic`, large, labelled-by `description` |
| `Gtk.Label` `description` | 1 | — | — | wraps |
| `Adw.PreferencesGroup` | 4 | — | — | intro group; summary group; `user_prefs_group` `_("User-Installed Extensions")`; `system_prefs_group` `_("System Extensions")`; plus a button group |
| `Adw.ComboRow` `drop_down` | 1 | — | — | title `GNOME`; model is a `Gtk.StringList` of shell versions built in code |
| `Gtk.Button` `run_button` | 1 | `pill`, `suggested-action` | `clicked` → `do_compatibility_check` | `_("_Check Compatibility")` |
| `Gtk.Stack` | 1 | — | — | `waiting`, `error`, `results` |
| `Adw.StatusPage` `counter` | 1 | — | — | spinner paintable, progress text set in code |
| `Adw.StatusPage` `error_status` | 1 | — | — | `offline-symbolic`, `_("Connection Error")` |
| `Adw.PreferencesPage` `prefs_page` | 1 | — | — | |
| `Gtk.Label` `summary_top` / `summary_bottom` | 2 | — | — | wrap |
| `Gtk.ProgressBar` `progress_bar` | 1 | `success` / `warning` / `error` (dynamic, by outcome) | — | show-text, focusable, labelled-by `summary_top`; `progressbar text` is styled in `style.css` |
| `Adw.ButtonRow` `copy_details` | 1 | — | `activated` → `copy_to_clipboard` | `edit-copy-symbolic`, `_("_Copy to Clipboard")` |

**Repeater:** one `Adw.ActionRow` per `ExmUpgradeResult` built in code (line 557)
into the user/system groups, each with a status `Gtk.Image` carrying a dynamic
`success` / `error` / `warning` class; sorted by a
`Gtk.SortListModel` + `Gtk.StringSorter` on `name`.

## src/exm-extension-error-dialog.blp + .c — an extension's error trace

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template) | 1 | — | — | 500×500, min 360×294, `_("Extension Error")` |
| `Adw.ToolbarView` / `Adw.HeaderBar` / `Adw.ToastOverlay` | 1 each | — | — | |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | title group; `trace_group` |
| `Gtk.Label` `title_label` | 1 | `title-4` | — | set in code |
| `Gtk.Button` `copy_button` | 1 | `flat` | `clicked` → `on_copy_button_clicked` | `edit-copy-symbolic`, tooltip `_("Copy to Clipboard")`, in the group's header-suffix |
| `Gtk.ScrolledWindow` | 1 | `card` | — | overflow hidden |
| `Gtk.TextView` `text_view` | 1 | `inline` | — | monospace, read-only, 12px margins, labelled-by `trace_group` |
| `Gtk.Button` `report_btn` | 1 | `pill` | `clicked` → `on_report_button_clicked` | `_("_Report Issue")` |

## src/exm-error-dialog.blp + .c — the app's own crash reporter

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Window` (template) | 1 | — | — | 500×500, `_("Error Report")` |
| `Adw.ToolbarView` / `Adw.HeaderBar` / `Adw.ToastOverlay` | 1 each | — | — | toasts `_("Copied")` |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | message group; `instructions` |
| `Gtk.Label` | 1 | `title-4` | — | `_("An unexpected error occurred in Extension Manager")` |
| `Gtk.Button` `copy_button` | 1 | `flat` | `clicked` → `on_copy_button_clicked` | `edit-copy-symbolic`, tooltip `_("Copy to Clipboard")` |
| `Gtk.ScrolledWindow` | 1 | `card` | — | overflow hidden |
| `Gtk.TextView` `text_view` | 1 | `inline` | — | monospace, read-only, labelled-by `instructions` |
| `Gtk.Button` `new_issue_button` | 1 | `pill`, `suggested-action` | `clicked` → `on_new_issue_button_clicked` | `_("_New Issue")`; `Gtk.UriLauncher` to `github.com/mjakeman/extension-manager/issues` |

Fed by `src/exm-backtrace.c` (libbacktrace symbolisation, optional at build time).

### The Author page

## src/exm-author-page.blp + .c — one author's extensions

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` (template) | 1 | — | — | |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 1 / 1 | — | — | header `overflow: hidden` |
| `Gtk.Revealer` `title_revealer` + `Adw.WindowTitle` | 1 + 1 | — | — | slide-up 500ms |
| `Adw.BreakpointBin` + `Adw.Breakpoint` | 1 + 1 | — | `apply`/`unapply` → `breakpoint_apply_cb`/`breakpoint_unapply_cb` | at `400sp` swaps `author_name` `title-1` ↔ `title-2` |
| `Gtk.ScrolledWindow` + `Adw.Clamp` | 1 + 1 | — | — | |
| `Adw.Avatar` `avatar` | 1 | — | — | 96px, show-initials, focusable |
| `Gtk.Label` `author_name` | 1 | `title-1` / `title-2` (dynamic) | — | selectable, wraps |
| `Gtk.Stack` `stack` | 1 | — | — | `page_spinner`, `page_list`, `page_empty`, `page_error` |
| `Adw.Spinner` | 1 | `dimmed` | — | 48×48 |
| `Adw.PreferencesGroup` `extensions_list` | 1 | `boxed-list` | — | `_("Authored Extensions")` |
| `Gtk.Image` + `Gtk.Label` (empty) | 1 + 1 | `dimmed`, `title-1` | — | `puzzle-piece-symbolic`, `_("No Extensions Found")` |
| `Gtk.Image` + `Gtk.Label`×2 (error) | 1 + 2 | `dimmed`, `title-1` | — | `offline-symbolic`, `_("Connection Error")`, `error_label` |

**Repeater:** `$ExmSearchRow` per authored extension into `extensions_list`.

### Non-widget support that the UI needs

| Upstream | What it is |
|---|---|
| `src/exm-unified-data.c` | `GObject` merging a local `ExmExtension` and a remote `ExmSearchResult` into the one object the detail view binds to |
| `src/exm-upgrade-result.c` | `GObject` row model for the upgrade assistant |
| `src/exm-utils.c` | `$format_downloads`, `$first_line`, `$format_comment_date`, `$format_author_link`, `$has_homepage` and friends — all referenced from blueprint closures |
| `src/exm-types.h` | enums: extension type (system / per-user), extension state, search sort |
| `src/local/exm-manager.c`, `src/local/exm-extension.c`, `src/local/shell-dbus-interface.c`, `src/local/org.gnome.Shell.Extensions.xml` | the GNOME Shell D-Bus client: install, uninstall, enable, open prefs, the `user-extensions-enabled` global toggle |
| `src/web/*` (`exm-request-handler.c` + data / search / comment / versions / profile providers, `exm-image-resolver.c`) | the extensions.gnome.org HTTP client and its 5 model objects |
| `src/exm-gnome-shell-search-provider.c`, `src/org.gnome.Shell.SearchProvider2.xml`, `data/…search-provider.ini.in` | the GNOME Shell search provider (D-Bus `SearchProvider2`) |
| `src/exm-backtrace.c` | crash backtrace capture behind the error dialog |
| `src/style.css` | 13 app classes: `detail`, `multiline`, `tint`, `search-row`, `version-label`, `version-label.current`, `update`, `detail-heading`, `author-link link`, `author-badge`, plus element selectors `comment-tile`, `rating`, `progressbar text` |
| `data/com.mattjakeman.ExtensionManager.gschema.xml.in` | GSettings: `width` (800), `height` (600), `is-maximized` (false), `sort-enabled-first` (false) |
| `data/icons/hicolor/scalable/actions/*.svg` | 14 bundled symbolic icons the UI names: `check-round-outline`, `clock-alt`, `donation`, `external-link`, `globe`, `info`, `offline`, `pip-in`, `pip-out`, `puzzle-piece`, `session-modes`, `settings`, `software-update-available`, `star-filled-rounded`, `star-outline-rounded`, `supported`, `unknown`, `unsupported` |
| `po/` | 45 locales in `LINGUAS`, `extension-manager.pot`, 63 entries in `POTFILES` |
| `data/…desktop.in.in`, `…metainfo.xml.in.in`, `…service.in` | desktop entry (the `gnome-extensions://` URI handler), appdata the About dialog is built from, D-Bus service file |

---

## Port status

Re-surveyed on `ruby` at `3671464` (after `561f223 Port the models, the shell and
web backends and the Installed view`). The generated placeholder is gone.

**What exists (26 files, ~3.5k lines in `lib/`):**

- the application class, with `app.quit`, `app.about`, `app.logout`,
  `app.sort-enabled-first`, `app.shortcuts`, the `<primary>q` / `<primary>w`
  accels and the geometry/settings binding;
- the main window, but **built inline inside `lib/extension_manager/application.rb`**
  rather than in its own `lib/window.rb` — the header bar, search bar,
  selection action bar, `main_stack` and the "GNOME Shell Unavailable" page all
  live there;
- the Installed view end to end: `installed_page.rb`, `extension_row.rb`,
  `extension_toggle.rb`, `install_button.rb`, `rating.rb`, `comment_tile.rb`,
  `extension_error_dialog.rb`, `confirm_dialogs.rb`, `primary_menu.rb`,
  `shortcuts_dialog.rb`;
- every model and backend: `manager.rb`, `extension.rb`,
  `shell_dbus_interface.rb`, `request_handler.rb` and the five web providers,
  the five web models, `types.rb`, `utils.rb`, `upgrade_result.rb`,
  `settings.rb`, `style.css`.

**What is still missing (16 units):** the Browse half of the app and everything
it reaches —

| Missing | Why it matters |
|---|---|
| `lib/browse_page.rb`, `lib/search_row.rb` | the `browse` `Adw.ViewStackPage` has no content at all; `win.search-online` is unreachable |
| `lib/detail_view.rb` | the extension detail navigation page — the app's largest single component |
| `lib/screenshot.rb`, `lib/screenshot_view.rb`, `lib/zoom_picture.rb`, `lib/animated_paintable.rb` | the screenshot viewer and its three zoom actions / three key bindings |
| `lib/author_page.rb` | `win.show-author` |
| `lib/comment_dialog.rb`, `lib/versions_dialog.rb` | reached from the detail view |
| `lib/upgrade_assistant.rb` | `win.show-upgrade-assistant`, which the primary menu already points at |
| `lib/error_dialog.rb`, `lib/backtrace.rb` | the app's own crash reporter |
| `lib/unified_data.rb` | the object the detail view binds to; local + remote merged |
| `lib/image_resolver.rb` | icons and screenshots are not fetched yet |
| `lib/gnome_shell_search_provider.rb` | the GNOME Shell `SearchProvider2` export |
| `lib/window.rb` | an extraction, not new behaviour — the window tree is in `application.rb` today |
| `po/` | no catalogue in the port; upstream ships 45 locales |

Counts: **22 user-facing component units upstream**, of which **10 exist** (the
application, the window-inside-the-application, the primary menu, the three
alert dialogs, the shortcuts dialog, the installed page, the extension row, the
install button, the rating, the comment tile, the extension error dialog) and
**12 do not**. On the support side, **18 of 22** non-widget files are ported.

## Target file map

| Upstream | Port file | Kind | Exists |
|---|---|---|---|
| `src/exm-application.c` | `lib/extension_manager/application.rb` | application (actions, accels, About) | yes — and it also hosts the window tree |
| `src/exm-window.blp` + `.c` | `lib/window.rb` | application window | no — the window is built inline in `application.rb`; extract it here |
| `src/exm-window.blp` (`primary_menu`) | `lib/primary_menu.rb` | menu model | yes |
| `src/exm-window.blp` (3 `Adw.AlertDialog` roots) | `lib/confirm_dialogs.rb` | alert dialogs | yes |
| `src/exm-shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | shortcuts dialog | yes |
| `src/exm-installed-page.blp` + `.c` | `lib/installed_page.rb` | page | yes |
| `src/exm-extension-row.blp` + `.c` | `lib/extension_row.rb` | list row | yes |
| `src/exm-extension-toggle.c` | `lib/extension_toggle.rb` | behaviour helper | yes |
| `src/exm-browse-page.blp` + `.c` | `lib/browse_page.rb` | page | no |
| `src/exm-search-row.blp` + `.c` | `lib/search_row.rb` | list row | no |
| `src/exm-install-button.blp` + `.c` | `lib/install_button.rb` | control | yes |
| `src/exm-detail-view.blp` + `.c` | `lib/detail_view.rb` | navigation page | no |
| `src/exm-screenshot.blp` + `.c` | `lib/screenshot.rb` | widget | no |
| `src/exm-screenshot-view.blp` + `.c` | `lib/screenshot_view.rb` | navigation page | no |
| `src/exm-zoom-picture.c` | `lib/zoom_picture.rb` | custom-drawn widget | no |
| `src/exm-animated-paintable.c` | `lib/animated_paintable.rb` | paintable | no |
| `src/exm-rating.blp` + `.c` | `lib/rating.rb` | widget | yes |
| `src/exm-comment-tile.blp` + `.c` | `lib/comment_tile.rb` | tile | yes |
| `src/exm-comment-dialog.blp` + `.c` | `lib/comment_dialog.rb` | dialog | no |
| `src/exm-versions-dialog.blp` + `.c` | `lib/versions_dialog.rb` | dialog | no |
| `src/exm-upgrade-assistant.blp` + `.c` | `lib/upgrade_assistant.rb` | dialog / assistant | no |
| `src/exm-extension-error-dialog.blp` + `.c` | `lib/extension_error_dialog.rb` | dialog | yes |
| `src/exm-error-dialog.blp` + `.c` | `lib/error_dialog.rb` | window (crash reporter) | no |
| `src/exm-author-page.blp` + `.c` | `lib/author_page.rb` | navigation page | no |
| `src/exm-unified-data.c` | `lib/unified_data.rb` | model | no |
| `src/exm-upgrade-result.c` | `lib/upgrade_result.rb` | model | yes |
| `src/exm-utils.c` | `lib/utils.rb` | formatters | yes |
| `src/exm-types.h` | `lib/types.rb` | enums | yes |
| `src/local/exm-manager.c` | `lib/manager.rb` | D-Bus shell client | yes |
| `src/local/exm-extension.c` | `lib/extension.rb` | model | yes |
| `src/local/shell-dbus-interface.c` | `lib/shell_dbus_interface.rb` | D-Bus proxy | yes |
| `src/web/exm-request-handler.c` | `lib/request_handler.rb` | HTTP base | yes |
| `src/web/exm-data-provider.c` | `lib/data_provider.rb` | HTTP provider | yes |
| `src/web/exm-search-provider.c` | `lib/search_provider.rb` | HTTP provider | yes |
| `src/web/exm-comment-provider.c` | `lib/comment_provider.rb` | HTTP provider | yes |
| `src/web/exm-versions-provider.c` | `lib/versions_provider.rb` | HTTP provider | yes |
| `src/web/exm-profile-provider.c` | `lib/profile_provider.rb` | HTTP provider | yes |
| `src/web/exm-image-resolver.c` | `lib/image_resolver.rb` | image cache | no |
| `src/web/model/exm-comment.c` | `lib/comment.rb` | model | yes |
| `src/web/model/exm-search-result.c` | `lib/search_result.rb` | model | yes |
| `src/web/model/exm-shell-versions.c` | `lib/shell_versions.rb` | model | yes |
| `src/web/model/exm-user-profile.c` | `lib/user_profile.rb` | model | yes |
| `src/web/model/exm-version-result.c` | `lib/version_result.rb` | model | yes |
| `src/exm-gnome-shell-search-provider.c` | `lib/gnome_shell_search_provider.rb` | D-Bus search provider | no |
| `src/exm-backtrace.c` | `lib/backtrace.rb` | crash capture | no |
| `src/style.css` | `lib/style.css` (loaded by a `Gtk::CssProvider`) | stylesheet | yes |
| `data/…gschema.xml.in` | `lib/settings.rb` | settings | yes |
| `po/*` | `po/` | translations | no |

## Blockers and open questions

Carried over from the first survey, with what the last port commit settled.

1. **The upstream ref is `origin/master`, not `origin/main`.** Every instruction
   naming `origin/main` has to be read as `origin/master`; `origin/HEAD` points
   at `origin/ruby`, the port branch.
2. **`src/exm.gresource.xml.in` is referenced by `src/meson.build` but absent
   from the tree**, so the resource paths — in particular how
   `exm-shortcuts-dialog.ui` reaches the `app.shortcuts` convention — cannot be
   read off upstream. No `.c` file mentions `shortcuts`, so the dialog is
   assumed to be auto-loaded by libadwaita from the resource path. Confirm in
   the Ruby port by registering the action explicitly.
3. **libadwaita `>= 1.8.alpha` is required.** (Partly answered: the ported
   Installed view and shortcuts dialog work in the dev shell, so
   `Adw.ShortcutsDialog`, `Adw.SwitchRow` and `dimmed` are available. Still
   unverified for `Adw.SpinnerPaintable`, `Adw.ButtonRow` and `Adw.WrapBox`,
   which only the unported assistant and detail view use.) The UI uses `Adw.Spinner`,
   `Adw.SpinnerPaintable`, `Adw.ButtonRow`, `Adw.WrapBox`, `Adw.ShortcutsDialog`,
   `Adw.ShortcutsSection`, `Adw.ShortcutsItem`, `Adw.Breakpoint` setters, the
   `dimmed` style class and `var(--accent-color)` CSS. Whether the Ruby
   bindings in this fork's dev shell expose all of these is unverified — check
   before planning `shortcuts_dialog`, `upgrade_assistant` and `detail_view`.
4. **`Adw.Application` is unusable in the Ruby bindings** (the placeholder
   already says so and uses `Gtk::Application`). Upstream's `ExmApplication`
   subclasses `AdwApplication` and overrides `open`, `dbus_register` and
   `dbus_unregister`; the port needs another route to the URI handler and the
   exported search provider.
5. **Blueprint closures and property bindings do most of upstream's work.**
   Roughly 40 `bind` expressions and 8 `$closure()` calls have no Ruby
   equivalent in the house style — each becomes an explicit
   `signal_connect("notify::…")` plus a setter, which is where a port most
   easily loses behaviour.
6. **Custom widget work:** `ExmZoomPicture` (measure/allocate/snapshot plus
   scroll and drag gestures) and `ExmAnimatedPaintable` (a `GdkPaintable`
   implementation over glycin) both need GObject subclassing from Ruby, which
   the bindings support unevenly. Upstream also depends on `glycin-2` /
   `glycin-gtk4-2`, `libsoup-3`, `json-glib` and `libxml2`; the Ruby
   equivalents (`net/http`, `json`, `nokogiri`, `GdkPixbuf`) are not in the
   dev shell yet.
7. ~~No dev-shell banner~~ — **resolved.** `flake.nix:208` now has a
   `shellHook` printing: run the app `xvfb-run ruby exe/extension-manager`,
   drive it `xvfb-run ruby test/drive_*.rb` (one driver exists,
   `test/drive_installed.rb`), specs through
   `RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])`.
   It also exports `RUBYLIB=$PWD/lib` and points `GSETTINGS_SCHEMA_DIR` at
   `data/schemas` — a directory the port does not have yet, so `settings.rb`
   must tolerate a missing schema.
8. **45 locales.** Translation parity is a separate exercise; `po/POTFILES`
   lists 63 upstream files whose strings must all be reachable from the port.

9. **The window has no file of its own.** Every remaining view is reached
   through a `win.*` action installed on the window, so the next unit either
   extends `application.rb` further or extracts `lib/window.rb` first. The
   house shape (one upstream file → one `lib/<thing>.rb`) says extract, and
   `src/exm-window.blp` + `.c` is 1 upstream unit; doing it before Browse keeps
   the diff honest.
10. **`lib/image_resolver.rb` gates three units.** Browse tiles, the detail
   view and the screenshot view all need resolved remote images, so it is the
   first thing to port in the Browse half, not the last.
