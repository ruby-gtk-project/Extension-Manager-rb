# Translation parity

CLAUDE.md names this file as where the port's translation parity is
recorded. The full, maintained comparison lives in
[`.reports/translation-parity.md`](.reports/translation-parity.md), kept
there because it is regenerated every round rather than hand-edited in
place.

As of the round that added this pointer file, translation is a known,
named gap, not a silent one: 0 of upstream's 149 msgids and 0 of its 45
languages are ported, there is no `po/` directory, no gettext dependency,
and no `_()`/`n_()`/`C_()` call sites in `lib/` or `exe/` (counts
independently re-verified via `git ls-tree` and `po/LINGUAS`, not copied
from an earlier report — see `.reports/accountability-ensurance.md` for a
prior instance of a stale count going unchecked). It is out of scope for
the round that added this pointer file specifically; see `remaining` in
that round's own task output for the explicit call-out.

This file is a pointer, not a duplicate: it is not re-edited every round.
Read `.reports/translation-parity.md` for the current, dated picture.
