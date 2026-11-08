# Accountability ensurance — Extension Manager (round 4)

Scope per the skill: grep `lib/`, `exe/`, `.reports/` and any root-level
porting ledger for excuse prose that turns a missing feature into a settled
decision, and for green claims resting on something never executed. No
`PORTING.md` exists in this repository (`find . -maxdepth 1 -iname
PORTING.md` — nothing); `AGENTS.md`/`CLAUDE.md` (a symlink to it) serve
that role here and were read in full this round.

## Excuse-prose scan of `lib/` and `exe/` — zero hits, re-confirmed this round

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|out of scope|
does not carry over|by design|not needed|no need to|good enough|
close enough|dropped deliberately|intentionally omitted|
consciously left out|not applicable|n/a|simplified|streamlined|
modernised away|bindings do not support|upstream does this too|
upstream's own TODO|skipped" lib/ exe/
```
Zero hits, same as round 3. The two components ported since round 3 (the
icon theme in `lib/extension_manager/application.rb`'s
`install_icon_theme`, and the desktop-entry/metainfo templates — not Ruby,
so not in scope for this grep but checked by eye) introduce no new excuse
construction either.

## Finding 1: a factual error in a committed report, found by cross-checking it against another committed report — new this round

`.reports/component-inventory.md:95` states:

> `po/*.po` + `po/extension-manager.pot` (**72 locales**) | Not assessed...

`.reports/translation-parity.md` (every round, including this one,
re-verified live) states **45** languages, sourced from
`git show origin/master:po/LINGUAS`. Re-counted directly this round:

```
git ls-tree -r --name-only origin/master -- po/ | grep -c '\.po$'   -> 45
git show origin/master:po/LINGUAS | tr ' ' '\n' | grep -c .          -> 45
```

Both independent counts agree on 45. `component-inventory.md`'s "72
locales" does not match either count and is not sourced to any command in
that file — no `git` invocation anywhere near that line produces 72 from
this repository's `po/` tree. This is a plain factual error in a committed
report, not a judgment call or a stale-but-was-once-true number like round
3's `drive-run.md` finding. It was caught only by reading two committed
`.reports/` files side by side and noticing they disagree about a number
neither one treats as uncertain — which is exactly the failure mode this
skill exists to catch: a number that looks precise and confident
(`72 locales`) that nobody had re-run against the repository it describes.
Left in place rather than silently corrected, so the audit trail shows it
was found, not erased; `translation-parity.md`'s 45-language figure is the
one re-verified live every round and is the one to trust.

## Finding 2: `component-inventory.md`'s icon-theme row is now stale, not wrong when written

The same file's row 92 ("No. `lib/` has no `data/icons` directory and no
file registers an icon-theme search path... every one of those icons falls
back to the broken-image glyph") was accurate when `component-inventory.md`
was written (round 3, before `c5fc5b0`/`e564797`) and is now **contradicted
by `test/drive_assets.rb`'s own passing checks** this round: the icons
directory is on the search path, and all 18 named icons resolve through
the real `Gtk::IconTheme`. This is not a false claim at the time it was
made — it is a committed report that was never revisited after the code it
describes changed underneath it, so a reader opening only
`component-inventory.md` today (rather than the newer, dated reports) would
be told something false about the current state of the port. Flagged here
rather than silently rewritten, for the same audit-trail reason as Finding
1: `component-identification.md` and `component-parity.md`, both dated this
round, carry the current, correct status.

## Finding 3: round 3's own flagged false-green report is now fixed — checked, not assumed

Round 3's accountability report's top finding was that `.reports/drive-
run.md` claimed `drive_upgrade.rb` passed "50 of 50" and a four-driver
total of "188," when a live re-run produced 49/49 and 187. Re-checked this
round: `.reports/drive-run.md` has been rewritten and its stated numbers
(39+53+51+49+42 = 234) now match this round's own fresh re-run of all five
drivers exactly (`test-parity.md`, `component-parity.md`). This is a real
fix, not a restated problem — recorded here so the fix is on the record
alongside the two new findings above, and so a future round does not have
to re-discover that this particular gap closed.

## The deeper finding, unchanged across four rounds: the required root-level ledgers still do not exist

`CLAUDE.md` states the port is "done when component parity and test parity
both hold... recorded in `COMPONENT_PARITY.md`" and `TEST_PARITY.md`. Four
rounds into this audit, **neither file exists at the port's root**, nor do
`TRANSLATION_PARITY.md` or `FINDINGS.md` — re-confirmed this round (`ls
*.md` lists `AGENTS.md`, `CHANGELOG.md`, `CLAUDE.md`, `CODE_OF_CONDUCT.md`,
`IRP.md`, `README.md`, `RUBOCOP.md`, `SECURITY.md`; none of the four named
ledgers). The `.reports/` documents substitute for them in substance across
four rounds now, but the project's own stated completion criterion still
has no home at the location it names. A gap that survives four consecutive
audits without being addressed is a pattern, not an oversight.

## Live gaps this round's other four reports name, carried here for completeness

- `app.open`/`gnome-extensions://` handler: still absent, and since this
  round's commit, contradicted by the port's own shipped desktop entry,
  which now claims to handle that URI scheme (`component-parity.md` #1).
- The About dialog's own application icon (`APP_ID`) has no backing file
  anywhere in the port and is untested by the new icon driver
  (`component-parity.md` #2, `component-identification.md`).
- GSettings schema: still a JSON-file substitute, `.gschema.xml.in` still
  unported (`component-parity.md` #3).
- 8 screenshot PNGs and 2 `meson.build` files under `data/`: still absent
  (`component-parity.md` #4).
- Translation catalogue: still 0/149 messages, 0/45 languages, and two more
  translatable-string-only files (the desktop entry, the metainfo) ported
  this round with zero gettext markers of their own
  (`translation-parity.md`).
- Rubocop and the RSpec suite (`kettle-test`): both named by the dev
  shell's own banner, both re-run live this round, both still fail outright
  — rubocop's executable is missing from the bundle, and the RSpec runner
  cannot even load `spec_helper.rb`. Zero `*_spec.rb` files exist regardless.
  Four rounds running with the same two never-successfully-executed
  commands (`test-parity.md`).

## Verdict

Two new report-level findings this round, both about `.reports/
component-inventory.md` specifically (a factually wrong "72 locales" figure
that disagrees with every other count in this round's and prior rounds'
reports, and a stale "no icon theme" row the current code has since
outgrown) — neither silently corrected, both named here so the discrepancy
is on the record. One prior finding (round 3's `drive-run.md` miscount) is
confirmed fixed, not merely re-asserted as fixed. No excuse prose exists in
`lib/` or `exe/`. The required root-level ledgers (`COMPONENT_PARITY.md`,
`TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md`) remain absent for
a fourth consecutive round, and the never-executed rubocop/RSpec commands
remain never executed for a fourth consecutive round. The port is not
clean: five live component/translation/test gaps are open across the other
four reports, and this report's own job — catching false or stale green
claims inside the audit's own paper trail — found two of them this round.
