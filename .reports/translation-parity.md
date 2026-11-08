# Translation parity — Extension Manager (round 4)

| | |
|---|---|
| Upstream | `origin/master` |
| Port | `ruby` @ `e564797` |
| Domain | `extension-manager` (from `po/extension-manager.pot`'s filename; still not independently confirmed against `meson.project_name()`/`GETTEXT_PACKAGE`) |
| Upstream messages | 149 |
| Ported | 0 |
| Gaps | 149 |
| Extra (untranslated) | 0 |
| Upstream languages | 45 |
| Languages shipped by the port | 0 |
| Build command | none — no `po/`, no gettext dependency |

No `TRANSLATION_PARITY.md` exists at the port's root; still only under
`.reports/`, fourth round running.

## Re-verified this round, not assumed from any prior round's numbers

```
git show origin/master:po/extension-manager.pot | grep -c '^msgid "'   -> 149
git show origin/master:po/LINGUAS | tr ' ' '\n' | grep -c .            -> 45
find . -iname po -maxdepth 2                                            -> nothing
grep -rln "gettext\|_(\"" lib/ exe/                                     -> nothing
grep -i gettext Gemfile *.gemspec                                      -> nothing
```
Identical counts to every prior round, re-run fresh against this round's
`HEAD` (`e564797`).

## Two more components ported since round 3 — gap grew in absolute string count, not just held steady

`c5fc5b0`/`e564797` ported the icon theme, the desktop-entry template and
the metainfo template since the last translation audit. None of them add
any gettext marker:

```
grep -c '"' data/com.mattjakeman.ExtensionManager.metainfo.xml.in.in   -> 60 quoted strings
grep -c '"' data/com.mattjakeman.ExtensionManager.desktop.in.in        -> 0 (key=value format, no quoting)
```
Upstream's real `.desktop.in.in` and `.metainfo.xml.in.in` mark their
translatable fields with `_Name=`/`_Comment=`/`_Summary=` style gettext
prefixes (the standard desktop-file/appstream translation convention) and
upstream's `po/POTFILES` includes both files as message sources. The
port's two templates were re-checked this round for any `_`-prefixed key
or `<_name>`/`<_summary>` style element — none found; every field is a
plain, non-translatable literal. This is a **new** instance of the same
gap: two more upstream translation sources ported with zero of their
translation markers carried over, on top of the 149 `.pot` messages and 45
languages that were already 0/149 and 0/45 in every prior round.

```
grep -c '"' lib/upgrade_assistant.rb lib/gnome_shell_search_provider.rb
  -> 17, 14 (both contain multiple user-facing literal strings — dialog
     titles, labels, toast text — none behind a translation call; unchanged
     from round 3's finding, re-confirmed this round rather than retired)
```

## Unchanged from every prior round

No `po/` directory, no gettext gem dependency, zero `_()`/`n_()`/`C_()`
call sites anywhere in `lib/` or `exe/`. The 45 languages and 149 messages
exist today, upstream, in the same repository; nothing about the Ruby port
prevents wiring `ruby-gettext`. Four rounds and five more components
(`upgrade_assistant.rb`, `gnome_shell_search_provider.rb`, the icon theme,
the desktop entry, the metainfo) have landed since this gap was first
measured, and it has not moved by a single message, a single language, or
a single newly-marked string in the newly-ported files.

## What was not done at this effort level (unchanged)

- No byte-level 149-row census, because there are zero marked strings on
  the port side to census against it.
- The `.pot`'s freshness against upstream's current tip was not
  independently re-verified.
- The three non-code message sources (`.desktop.in.in`, metainfo,
  gschema) are now 2/3 present as files on the port side
  (`component-identification.md`) but 0/3 as translation sources — being
  present as an untranslated template is not translation parity, it is the
  same gap with more surface area.

## Verdict

0/149 messages, 0/45 languages — unchanged across four rounds and five
newly-ported components. This is not a partial gap and not a "not reached
yet" footnote: the entire translator-donated catalogue is absent, exactly
as every prior round found, and every component ported since the gap was
first measured — code and data templates alike — has been written with
zero translation markers. The gap is not closing as the port grows; it is
being carried forward unchanged, and in the templates' case, carried
forward into files whose only content *is* translatable strings in
upstream.
