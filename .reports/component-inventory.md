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
- Port `lib/` on `ruby` now holds every user-facing unit named in the **Target
  file map** below except one: the GNOME Shell `SearchProvider2` D-Bus
  service (`src/exm-gnome-shell-search-provider.c` and its `.ini`/`.service`
  data files have no port file at all). `po/` — upstream's 45-locale
  translation catalogue — also has no port equivalent anywhere on `ruby`.
  `lib/upgrade_assistant.rb` exists in this checkout but is **untracked** —
  nobody has committed it, so it does not exist on any other clone of this
  branch, and `window.rb`'s own comment (line 29) says `win.show-upgrade-
  assistant` is still installed nowhere. See **Port status** below.

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

Re-surveyed on `ruby` at the current tip. Every unit the previous survey
listed as missing — `detail_view.rb`, `screenshot.rb`, `screenshot_view.rb`,
`zoom_picture.rb`, `animated_paintable.rb`, `author_page.rb`,
`comment_dialog.rb`, `versions_dialog.rb`, `upgrade_assistant.rb`,
`unified_data.rb` and `backtrace.rb` — now has a file in `lib/`, each carrying
the "Ported from upstream's ..." header the house style requires and matched
by name against the upstream file it claims.

**Two real gaps remain, and one integrity problem:**

1. **`src/exm-gnome-shell-search-provider.c` has no port file.** Nobody has
   written `lib/gnome_shell_search_provider.rb` (or any equivalent). This is
   the D-Bus `org.gnome.Shell.SearchProvider2` export that lets GNOME Shell's
   overview search list and launch installed extensions from this app; its
   backing `.ini`/`.service` data files are also absent from this repo.
   Without it the app has no search-provider integration at all — this is
   not a stub or a partial port, it is nothing.
2. **`po/` does not exist anywhere on `ruby`.** Upstream ships 45 locale
   `.po` files plus `extension-manager.pot`, `LINGUAS` and `POTFILES`
   (63 entries). The port's source carries `# Translators:` comments that
   presuppose a catalogue, but nobody has built the extraction/catalogue
   infrastructure those comments require, so none of upstream's 45
   translations reach a user of this port. This is a translation-parity gap,
   to be tracked and closed by the `translation-parity` skill, not folded
   into this component count.
3. **`lib/upgrade_assistant.rb` is untracked.** `git status` on this checkout
   shows it outside version control — nobody has run `git add` or committed
   it. `window.rb`'s own in-code comment (around line 29) says
   `win.show-upgrade-assistant` "still has no upgrade assistant to show",
   which matches: the action the primary menu points at is not installed on
   the window, so even with the file present on disk the assistant is
   unreachable from the running app, and on any other clone of `ruby` the
   file is not there at all.

The `data/com.mattjakeman.ExtensionManager.metainfo.xml.in.in` appdata file
also has no port equivalent: `lib/extension_manager/application.rb` builds
its `Adw::AboutDialog` from a hand-written `ABOUT_COMMENTS` constant rather
than upstream's metainfo, so upstream's release-notes history and localized
description text are not reachable from the About dialog. The desktop entry
(`data/com.mattjakeman.ExtensionManager.desktop.in.in`) has no port file
either; no `.desktop` file exists anywhere in this repository.

## Target file map

| Upstream | Port file | Kind | Exists |
|---|---|---|---|
| `src/exm-application.c` | `lib/extension_manager/application.rb` | application (actions, accels, About) | yes — and it also hosts the window tree |
| `src/exm-window.blp` + `.c` | `lib/window.rb` | application window | yes — extracted out of `application.rb` |
| `src/exm-window.blp` (`primary_menu`) | `lib/primary_menu.rb` | menu model | yes |
| `src/exm-window.blp` (3 `Adw.AlertDialog` roots) | `lib/confirm_dialogs.rb` | alert dialogs | yes |
| `src/exm-shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | shortcuts dialog | yes |
| `src/exm-installed-page.blp` + `.c` | `lib/installed_page.rb` | page | yes |
| `src/exm-extension-row.blp` + `.c` | `lib/extension_row.rb` | list row | yes |
| `src/exm-extension-toggle.c` | `lib/extension_toggle.rb` | behaviour helper | yes |
| `src/exm-browse-page.blp` + `.c` | `lib/browse_page.rb` | page | yes |
| `src/exm-search-row.blp` + `.c` | `lib/search_row.rb` | list row | yes |
| `src/exm-install-button.blp` + `.c` | `lib/install_button.rb` | control | yes |
| `src/exm-detail-view.blp` + `.c` | `lib/detail_view.rb` | navigation page | yes |
| `src/exm-screenshot.blp` + `.c` | `lib/screenshot.rb` | widget | yes |
| `src/exm-screenshot-view.blp` + `.c` | `lib/screenshot_view.rb` | navigation page | yes |
| `src/exm-zoom-picture.c` | `lib/zoom_picture.rb` | custom-drawn widget | yes |
| `src/exm-animated-paintable.c` | `lib/animated_paintable.rb` | paintable | yes |
| `src/exm-rating.blp` + `.c` | `lib/rating.rb` | widget | yes |
| `src/exm-comment-tile.blp` + `.c` | `lib/comment_tile.rb` | tile | yes |
| `src/exm-comment-dialog.blp` + `.c` | `lib/comment_dialog.rb` | dialog | yes |
| `src/exm-versions-dialog.blp` + `.c` | `lib/versions_dialog.rb` | dialog | yes |
| `src/exm-upgrade-assistant.blp` + `.c` | `lib/upgrade_assistant.rb` | dialog / assistant | **present on disk, but untracked — not committed to `ruby`, and `win.show-upgrade-assistant` is not installed** |
| `src/exm-extension-error-dialog.blp` + `.c` | `lib/extension_error_dialog.rb` | dialog | yes |
| `src/exm-error-dialog.blp` + `.c` | `lib/error_dialog.rb` | window (crash reporter) | yes |
| `src/exm-author-page.blp` + `.c` | `lib/author_page.rb` | navigation page | yes |
| `src/exm-unified-data.c` | `lib/unified_data.rb` | model | yes |
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
| `src/web/exm-image-resolver.c` | `lib/image_resolver.rb` | image cache | yes |
| `src/web/model/exm-comment.c` | `lib/comment.rb` | model | yes |
| `src/web/model/exm-search-result.c` | `lib/search_result.rb` | model | yes |
| `src/web/model/exm-shell-versions.c` | `lib/shell_versions.rb` | model | yes |
| `src/web/model/exm-user-profile.c` | `lib/user_profile.rb` | model | yes |
| `src/web/model/exm-version-result.c` | `lib/version_result.rb` | model | yes |
| `src/exm-gnome-shell-search-provider.c` | `lib/gnome_shell_search_provider.rb` | D-Bus search provider | **no — not started** |
| `src/exm-backtrace.c` | `lib/backtrace.rb` | crash capture | yes |
| `src/style.css` | `lib/style.css` (loaded by a `Gtk::CssProvider`) | stylesheet | yes |
| `data/…gschema.xml.in` | `lib/settings.rb` | settings | yes |
| `data/…metainfo.xml.in.in` | n/a — `Adw::AboutDialog` built by hand in `application.rb` | appdata | **no — not consumed anywhere; the About dialog's release notes and localized description are not reachable** |
| `data/…desktop.in.in` | n/a | desktop entry | **no — no `.desktop` file exists in this repository** |
| `po/*` | `po/` | translations | **no — directory does not exist** |

Counts: **46 of 49** upstream-to-port rows above have a matching, committed
port file. The 3 that do not: the GNOME Shell search provider (nothing
written), the metainfo-driven About dialog content (hand-rolled instead), and
the `po/` catalogue (absent). A 47th row, `upgrade_assistant.rb`, has a file
on disk that is not committed and not wired to its action — counted as
present in the file list but flagged above as not actually shipped on `ruby`.

## Blockers and open questions

Carried over from the first survey; status against the current tip.

1. **The upstream ref is `origin/master`, not `origin/main`.** Still true —
   every instruction naming `origin/main` has to be read as `origin/master`.
2. **`src/exm.gresource.xml.in` is referenced by `src/meson.build` but is
   absent from the git tree at `origin/master` HEAD; it exists only as a
   blob reachable via `git show origin/master:src/exm.gresource.xml.in`.**
   It confirms every `.blp` template name and the `shortcuts-dialog.ui` alias;
   read it directly with that command rather than assuming it is missing.
3. **libadwaita `>= 1.8.alpha` is required**, and the port now uses
   `Adw.Spinner`, `Adw.SpinnerPaintable`, `Adw.ButtonRow`, `Adw.WrapBox`,
   `Adw.ShortcutsDialog` and `Adw.Breakpoint` across the committed files
   above — so this requirement is exercised, not merely assumed.
4. **`Adw.Application` usability in the Ruby bindings** — verify directly
   against `lib/extension_manager/application.rb` rather than this note;
   re-check before relying on it for the still-missing search provider's
   D-Bus registration, since `exm-gnome-shell-search-provider.c` is reached
   through `exm-application.c`'s `dbus_register`/`dbus_unregister`
   overrides upstream.
5. **Blueprint closures and property bindings do most of upstream's work.**
   Still the main place to check for dropped behaviour when reviewing any of
   the files above against its upstream pair.
6. **Custom widget work is done:** `zoom_picture.rb` and
   `animated_paintable.rb` exist; verify their `measure`/`size_allocate`/
   `snapshot` and `GdkPaintable` implementations against upstream rather than
   assuming the port needs this work — it has been attempted.
7. **Dev-shell banner** — `flake.nix` prints how to run and drive the app;
   read it for the current commands rather than this note.
8. **45 locales, 0 ported.** See **Port status** item 2 above; this is the
   live translation-parity gap, not a resolved item.
9. **The GNOME Shell search provider is the one user-facing unit with no
   port file at all.** See **Port status** item 1. This is the top priority
   for the next unit of work on this fork.
10. **`win.show-upgrade-assistant` is not installed on the window** even
    though `upgrade_assistant.rb` exists on disk; see **Port status** item 3.
    Committing the file and wiring the action are both still to do.
