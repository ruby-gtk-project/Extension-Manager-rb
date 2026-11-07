# Translation parity — Extension Manager

| | |
|---|---|
| Upstream | `origin/master` |
| Port | `ruby` @ `64c7398` |
| Domain | `extension-manager` (from `po/extension-manager.pot`'s filename; not independently confirmed against `meson.project_name()` or `GETTEXT_PACKAGE` at this effort level — flagged as unconfirmed) |
| Upstream messages | 149 (`grep -c '^msgid "' po/extension-manager.pot`, header row excluded by the pattern) |
| Ported | 0 |
| Gaps | 149 |
| Extra (untranslated) | 0 |
| Upstream languages | 45 `.po` files (`po/LINGUAS`) |
| Languages shipped by the port | 0 |
| Build command | none — the port has no `po/` and no gettext dependency |

No `TRANSLATION_PARITY.md` existed at the port's root before this audit; this
is that ledger's first entry, at 0/149.

## Verified, not assumed

```
git show origin/master:po/extension-manager.pot | grep -c '^msgid "'   -> 149
git show origin/master:po/LINGUAS | tr ' ' '\n' | grep -c .            -> 45
find . -iname po -maxdepth 2                                            -> (nothing)
grep -rln "gettext\|_(\"" lib/ exe/                                     -> (nothing)
grep -i gettext Gemfile Gemfile.lock extension-manager-rb.gemspec      -> (nothing)
```

The port has:

- no `po/` directory of any kind,
- no dependency on the `gettext` gem (or any i18n gem) in `Gemfile`,
  `Gemfile.lock` or the gemspec,
- **zero** call sites of `_()`, `n_()`, `C_()` or any other gettext marker
  anywhere in `lib/` or `exe/`.

Every one of the ~149 strings this app shows a user — menu items, button
labels, status-page headings and bodies, tooltips, dialog titles, the
shortcuts window, the toast messages — is a bare Ruby string literal in the
port. This is translation parity's worst case, the same shape the skill's own
worked example (`gnome-contacts-rb`) describes: a port that may well read
correctly in English and carries zero of the 45 languages upstream already
has translated.

## This is not a scope question

Per the skill: "English-only for now" is not a state, it is a gap count, and
the 45 languages exist today, upstream, in the same repository. Nothing about
this port's Ruby-vs-C language choice prevents `require 'gettext'` and
`bindtextdomain` — `ruby-gettext` is a normal gem, and other ports in this org
(per the skills' own references) wire it. This is 149 messages and 45
languages of donated translator work that the port currently discards in
full, not a feature the port "hasn't reached".

## What was not done at this effort level

- **No byte-level census of the port's would-be messages against upstream's
  149**, because there are zero marked strings in the port to census — the
  gap is total, and a per-message table of 149 rows all reading `gap` adds no
  information beyond the header above. Per the skill's own guidance for the
  zero-tests case, this ledger does not pad an empty table.
- **The `.pot`'s freshness against upstream's current `HEAD` was not checked**
  (`grep -m1 POT-Creation-Date` / `git log -1 --format=%cs` comparison) — the
  149 is taken from the committed `.pot` as the best available source but is
  not independently verified as current. Flagged as unconfirmed rather than
  silently trusted.
- **The three non-code message sources the skill specifically calls out**
  (`.desktop.in.in`, metainfo, gschema) could not be censused on the upstream
  side separately from the `.pot`, because this pass relied on the committed
  `.pot` count rather than re-running `msgid-census.sh`. Per
  `component-identification.md`, none of those three files exist on the port
  side regardless, so their strings are unported twice over: once as
  messages, once as the files that would carry them.

## Verdict

0/149 messages, 0/45 languages. Not a partial gap, not an "i18n not wired up
yet" footnote — the entire translator-donated catalogue is absent, and
nothing in the port's dependency list or source makes it reachable without
new work. This is carried into `accountability-ensurance.md` only to the
extent that any *prose* presents it as settled; no such prose was found for
this specific gap (no comment in `lib/` claims i18n is unneeded or deferred —
the gap is simply unaddressed, which this report is what states it, for the
first time, in writing).
