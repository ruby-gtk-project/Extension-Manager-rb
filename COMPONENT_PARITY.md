# Component parity

CLAUDE.md names this file as where the port's component parity is recorded.
The full, maintained comparison lives in two files under `.reports/`, kept
there because they are regenerated and extended every round rather than
hand-edited in place:

- [`.reports/component-identification.md`](.reports/component-identification.md)
  — the inventory of upstream's UI surface (widgets, CSS classes, signals,
  actions) this port is measured against.
- [`.reports/component-parity.md`](.reports/component-parity.md) — the
  per-component comparison itself: what the port builds, what it is still
  missing, and what changed since the previous round.

`.reports/component-inventory.md` is an earlier-round snapshot, now
superseded by the two files above (it says so at its own top) — use it only
as a historical record, not as the current state.

This file is a pointer, not a duplicate: it is not re-edited every round.
Read the `.reports/` files for the current, dated picture.
