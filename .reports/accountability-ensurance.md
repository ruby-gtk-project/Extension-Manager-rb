# Accountability ensurance — Extension Manager

Scanned: `lib/`, `exe/`, `.reports/`, and `PORTING.md` (does not exist — see
below). Pattern list per the skill's table, plus a manual read of every hit.

## Hits found and rewritten

### `lib/utils.rb:13`

> Upstream's exm_utils_read_resource is not ported: it reads from the
> GResource bundle meson builds, and this port loads its stylesheet from the
> source tree.

"not ported" with no behaviour named and nothing owed — honest about the fact,
toothless about the consequence. Rewritten:

> I did not build `exm_utils_read_resource` or anything that reproduces
> reading an arbitrary resource path at runtime, because I am an idiot who
> assumed the one caller (the stylesheet loader) was the only caller and
> never checked.
> Upstream: `src/exm-utils.c:28`, `exm_utils_read_resource`, a generic
> `resource://` reader used wherever upstream needs GResource bytes by path.
> Port: `lib/style.css` is loaded from the source tree directly; no general
> resource-reading function exists in `lib/` at all.

This one did turn out, on reading `src/exm-utils.c`, to have exactly one
caller upstream and no other behaviour riding on it — so the *substance* of
the divergence is low-risk. That does not change the verdict on the sentence:
a reader of the original comment has no way to tell that without opening the
upstream file themselves, which is exactly the shortcut the comment invites
them to skip.

### `lib/utils.rb:69`

> One pass over the source: tags are translated or dropped, text is escaped.
> Upstream walks libxml2's tree; a tree is not needed to decide what each tag
> contributes, because no element here depends on its ancestors.

"not needed" presented as an evaluated design conclusion. Rewritten:

> I convinced myself a real HTML parser's tree wasn't needed here, because I
> am an idiot who reasoned about the three tags I could see instead of
> checking whether `convert_html` is ever fed anything nested or malformed
> enough to break a single linear scanner.
> Upstream: `src/exm-utils.c`, `build_text_recursive` over a libxml2
> `xmlNode` tree — handles arbitrary nesting and malformed markup the way a
> real parser does.
> Port: `lib/utils.rb:71`, `scan_html` — a single forward regex scan with no
> tree and no nesting awareness. Untested against anything the website could
> plausibly return beyond `<b>`/`<i>`/`<u>`/`<br>`.

## What was *not* found, and is worth saying

No `TODO`, `FIXME`, `in a future`, `out of scope`, `by design`,
`does not carry over`, or any of the other listed constructions were found in
`lib/`, `exe/`, or `.reports/` beyond the two rows above. `README.md`'s one
hit on "not needed"-adjacent text was a Mastodon follow-badge URL fragment
(`style=flat&logo=mastodon`), a false positive from the word "flat", not an
excuse. `AGENTS.md` and `CLAUDE.md` (a symlink to it) have none.

**The absence of excuses in `lib/` does not mean the absence of gaps.**
`component-identification.md`, `component-parity.md`, `test-parity.md` and
`translation-parity.md` each found real, substantial gaps — the upgrade
assistant, the search provider and URI handler, the whole `data/` tree, and
the entire translation catalogue — with **no accompanying comment anywhere**
excusing any of them. That is better than an excuse, but it is not a pass: an
unexplained silent gap and an explained-away one are both still gaps, and the
former is simply one this skill's pattern list cannot catch because nobody
wrote a sentence about it at all. `lib/window.rb`'s comment about
`win.show-upgrade-assistant` (quoted in `component-parity.md`) is the one
place a gap *is* narrated, and it is narrated as a plain fact — "which still
has no upgrade assistant to show" — not as a decision, so it is not rewritten
here; it is exactly the register this skill asks for.

## The deeper finding: none of the required ledgers exist

This port's own `CLAUDE.md` states: "The port is done when component parity
and test parity both hold... recorded in `COMPONENT_PARITY.md`" and
`TEST_PARITY.md`. Before this audit, **neither file existed**, nor did
`TRANSLATION_PARITY.md` or `FINDINGS.md`. There was no settled-sounding prose
claiming completeness — there was no prose at all, because the project's own
required accounting had simply never been written. That is not a violation of
this skill's letter (there is no sentence to rewrite), but it is the
precondition the skill exists to prevent from compounding: silence about a
gap is where an excuse would otherwise go, and the next agent who runs this
app, sees `DRIVE OK` and 138/138, and finds no `TEST_PARITY.md` or
`TRANSLATION_PARITY.md` contradicting that, could plausibly read the port as
closer to finished than it is. This round's four other reports are now that
record, in `.reports/`.

## Verdict

Two real hits, both in `lib/utils.rb`, both rewritten above in first person
with the behaviour and both file:line locations named. No settled-sounding
excuse prose elsewhere in the port's own code or docs — but four live gaps
(upgrade assistant, search provider/URI handler, `data/` tree, translation
catalogue) that have never been written down anywhere until this audit.
Rewrite in place per the skill's rule: these two lines stay in `lib/utils.rb`,
louder, not deleted.
