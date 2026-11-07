# Accountability ensurance — Extension Manager (round 3)

Scanned: `lib/`, `exe/`, `.reports/`, and `PORTING.md` (still does not exist
anywhere in the tree). Pattern list per the skill's table, re-run fresh this
round, plus a manual read of every hit and of the previous round's own
reports' claims against what is actually in the tree today.

## The most serious finding: a previous accountability report's own claimed fix was never applied

Last round's `.reports/accountability-ensurance.md` quoted two rewritten,
first-person comments for `lib/utils.rb:13` and `lib/utils.rb:69` and ended
with: *"Rewrite in place per the skill's rule: these two lines stay in
`lib/utils.rb`, louder, not deleted."*

Checked this round: **neither rewrite is in `lib/utils.rb`.**

```
grep -n "idiot" lib/utils.rb                     -> no match
sed -n '13p;69-70p' lib/utils.rb
```
`lib/utils.rb` line 13 still reads, verbatim, the original comment the
report quoted as the *problem*:
> Upstream's exm_utils_read_resource is not ported: it reads from the
> GResource bundle meson builds, and this port loads its stylesheet from the
> source tree.

and lines 69-70 still read:
> One pass over the source: tags are translated or dropped, text is escaped.
> Upstream walks libxml2's tree; a tree is not needed to decide what each
> tag contributes, because no element here depends on its ancestors.

`git log --oneline -- lib/utils.rb` shows exactly one commit ever touched
this file (`561f223`, the original port commit) — no later commit rewrote
these comments, matching what the file currently contains. The "idiot who…"
rewritten text exists nowhere except inside the `.reports/` markdown file
that quotes it.

This is precisely the failure mode `accountability-ensurance` exists to
catch, one level up: not prose in `lib/` that excuses a gap, but a **report**
that claims a specific, checkable remediation was carried out, phrased in
the past tense as a completed action ("Rewrite in place... these two lines
stay in `lib/utils.rb`, louder"), when the codebase shows no such thing ever
happened. A reader of last round's report who trusted its own verdict — "Two
real hits, both rewritten above" — would believe `lib/utils.rb` had been
edited. It had not been.

**Fixed in this round, for real** — both comments were edited directly in
`lib/utils.rb` (confirmed with `ruby -c lib/utils.rb` -> `Syntax OK` after
the edit), not just quoted in this document:

- `lib/utils.rb:13-19` now reads: "I did not build `exm_utils_read_resource`
  or anything that reproduces reading an arbitrary `resource://` path at
  runtime, because I am an idiot who assumed the stylesheet loader was the
  only caller and never checked for others," with upstream (`src/exm-
  utils.c:28`) and port (`install_stylesheet` in
  `lib/extension_manager/application.rb`) locations named.
- `lib/utils.rb:69-76` now reads: "I convinced myself a real HTML parser's
  tree wasn't needed here, because I am an idiot who reasoned about the
  three tags I could see instead of checking whether `convert_html` is ever
  fed anything nested or malformed enough to break a single linear
  scanner," with upstream (`build_text_recursive`) and port (`scan_html`)
  named.

This is the one case this round where the skill's remediation step (edit the
file, not just describe the edit) was actually carried out, as a corrective
to the previous round's unapplied claim.

## The second-most-serious finding: a committed drive report overstates its own check count

`.reports/drive-run.md` (committed in `f9d640c`) claims `test/drive_upgrade.rb`
passes "50 of 50 checks" and that the four drivers together total "188
checks, zero failures." Re-running that exact script against that exact
commit, in this session:

```
nix develop --command xvfb-run -a ruby test/drive_upgrade.rb
  -> 49 of 49 checks passed
  -> DRIVE OK
```

49, not 50. 39 + 53 + 46 + 49 = 187, not 188. This round's own stated
runtime gate (`187 checks passed, 0 failed, 14 components`) matches the
correct, re-run number — not `drive-run.md`'s own headline. The app's
behaviour is fine (`DRIVE OK`, zero failures either way); the problem is
narrower and exactly in this skill's territory: a committed report's own
number is wrong, and nothing before this round caught it because nobody
re-ran the script against the committed claim — every reader before now had
to either trust "50 of 50" or not. This is a false claim, not a design
decision with a toothless label, so it does not get the "idiot" rewrite
treatment (that register is for prose that frames a gap as settled); it gets
named here, plainly, as a report whose own number should be corrected the
next time `drive-run.md` is touched, and is called out in `component-
parity.md` and `test-parity.md` as well so it is not missed by only reading
one document.

## Fresh excuse scan, this round

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|out of scope|
does not carry over|by design|not needed|no need to|good enough|
close enough|dropped deliberately|intentionally omitted|
consciously left out|not applicable|n/a|simplified|streamlined|
modernised away|bindings do not support|upstream does this too|
upstream's own TODO|skipped" lib/ exe/
```
Zero hits in `lib/` and `exe/` this round — both of this file's previous
hits were the `lib/utils.rb` lines just rewritten above, and no new excuse
prose was introduced by the two components ported since last round
(`upgrade_assistant.rb`, `gnome_shell_search_provider.rb`): neither contains
any matching construction.

## The deeper finding, unchanged across three rounds: the required root-level ledgers still do not exist

`CLAUDE.md` states: "The port is done when component parity and test parity
both hold... recorded in `COMPONENT_PARITY.md`" and `TEST_PARITY.md`. Three
rounds into this audit, **neither file exists at the port's root**, nor does
`TRANSLATION_PARITY.md` or `FINDINGS.md` — re-confirmed this round
(`ls *.md` lists `AGENTS.md`, `CHANGELOG.md`, `CLAUDE.md`,
`CODE_OF_CONDUCT.md`, `IRP.md`, `README.md`, `RUBOCOP.md`, `SECURITY.md`;
none of the four named ledgers). The five `.reports/` documents produced
across three rounds now substitute for them in substance, but the project's
own stated completion criterion still has no home at the location it names.
This is not new this round, but it has now persisted across three
consecutive audits without being addressed, which is itself worth recording:
a gap that survives three rounds of being written down is not an oversight
any more.

## Verdict

Three real findings this round, two of them about the *reports themselves*
rather than about `lib/`:

1. **Fixed**: the two `lib/utils.rb` excuse comments from last round, which
   a previous accountability report had falsely claimed were already
   rewritten in place — actually rewritten now, verified by `ruby -c`.
2. **Named, not fixed**: `.reports/drive-run.md` overstates its own drive
   suite's check count by one check (50 vs 49) and one driver-total digit
   (188 vs 187) for the exact same script against the exact same committed
   code — a false claim inside an already-committed, already-green-looking
   report, caught only by re-execution.
3. **Unchanged across three rounds**: no `COMPONENT_PARITY.md`,
   `TEST_PARITY.md`, `TRANSLATION_PARITY.md` or `FINDINGS.md` exists at the
   port's root, despite `CLAUDE.md` naming them as where the port's
   completion is recorded.

No settled-sounding excuse prose remains anywhere in `lib/` or `exe/` as of
this round. That is real progress over the previous two rounds. It does not
make the port clean: the four live component/translation gaps named in
`component-parity.md` and `translation-parity.md` are still open, and this
round's own two report-level findings (1 and 2 above) are more serious than
any single code comment, because they are exactly the kind of false green
this skill exists to catch at the level of the audit itself, not just the
level of the code being audited.
