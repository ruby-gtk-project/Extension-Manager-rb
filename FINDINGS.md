# Findings

CLAUDE.md names this file as the home for accountability findings about the
port's own claims — prose that turns a missing feature into a settled
decision, a stale figure copied forward without re-checking, or a check
that looks green without having actually exercised anything. The full,
maintained record lives in
[`.reports/accountability-ensurance.md`](.reports/accountability-ensurance.md),
kept there because it is regenerated every round rather than hand-edited in
place.

Notable findings fixed in the round that added this pointer file:

- `.reports/component-inventory.md` claimed "72 locales" for `po/`, which
  disagreed with the independently and repeatedly verified count of 45
  (`git ls-tree` and `po/LINGUAS` agree) — now date-stamped as a historical,
  superseded snapshot rather than left to be read as current.
- `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md` and this
  file did not exist at the port's root across four prior rounds, despite
  CLAUDE.md naming them as where the port's completion must be recorded —
  added as pointers into the fuller `.reports/*.md` documents.

This file is a pointer, not a duplicate: it is not re-edited every round.
Read `.reports/accountability-ensurance.md` for the current, dated record.
