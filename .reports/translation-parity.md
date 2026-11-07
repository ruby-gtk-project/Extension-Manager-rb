# Translation parity — Extension Manager (round 3)

| | |
|---|---|
| Upstream | `origin/master` |
| Port | `ruby` @ `f9d640c` |
| Domain | `extension-manager` (from `po/extension-manager.pot`'s filename; still not independently confirmed against `meson.project_name()`/`GETTEXT_PACKAGE`) |
| Upstream messages | 149 |
| Ported | 0 |
| Gaps | 149 |
| Extra (untranslated) | 0 |
| Upstream languages | 45 |
| Languages shipped by the port | 0 |
| Build command | none — no `po/`, no gettext dependency |

No `TRANSLATION_PARITY.md` exists at the port's root; `CLAUDE.md`-adjacent
expectations aside, it is still only under `.reports/`.

## Re-verified this round, not assumed from last round's numbers

```
git show origin/master:po/extension-manager.pot | grep -c '^msgid "'   -> 149
git show origin/master:po/LINGUAS | tr ' ' '\n' | grep -c .            -> 45
find . -iname po -maxdepth 2                                            -> nothing
grep -rln "gettext\|_(\"" lib/ exe/                                     -> nothing
grep -i gettext Gemfile Gemfile.lock *.gemspec                         -> nothing
```

Identical counts to last round, re-run fresh against this round's `HEAD`
(`f9d640c`). The two components ported since last round —
`lib/upgrade_assistant.rb` and `lib/gnome_shell_search_provider.rb` — add
more hard-coded English strings to the pile with zero gettext markers of
their own: spot-checked `lib/upgrade_assistant.rb` for `_("`/`gettext(` —
none found, confirming the gap grew rather than shrank in absolute string
count even though the percentage (0/149 message *keys*, since upstream's
`.pot` is unchanged) stays the same.

```
grep -c '"' lib/upgrade_assistant.rb lib/gnome_shell_search_provider.rb
```
(both files contain multiple user-facing literal strings — dialog titles,
button labels, toast text — none behind a translation call.)

## Unchanged from last round

Everything in the previous `translation-parity.md` applies verbatim: no
`po/` directory, no gettext gem dependency, zero `_()`/`n_()`/`C_()` call
sites anywhere in `lib/` or `exe/`. This is not a scope question — the 45
languages and 149 messages exist today, upstream, in the same repository,
and nothing about the Ruby port prevents wiring `ruby-gettext`. Two more
commits have landed since the gap was first measured and the gap has not
moved by a single message or a single language.

## What was not done at this effort level (unchanged)

- No byte-level 149-row census, because there are zero marked strings on the
  port side to census against it.
- The `.pot`'s freshness against upstream's current tip was not independently
  re-verified (`POT-Creation-Date` vs upstream's last commit date).
- The three non-code message sources (`.desktop.in.in`, metainfo, gschema)
  remain unported on the port side regardless of the `.pot` count
  (`component-identification.md`), so those strings are unported twice over.

## Verdict

0/149 messages, 0/45 languages — unchanged across two further commits since
the last audit. Not a partial gap and not a "not reached yet" footnote: the
entire translator-donated catalogue is absent, exactly as it was last round,
and the two newest ported components (`upgrade_assistant.rb`,
`gnome_shell_search_provider.rb`) were written with zero translation markers,
confirming this gap is not closing as the port grows — it is being carried
forward unchanged into every new file.
