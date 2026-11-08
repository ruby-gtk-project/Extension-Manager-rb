# Test parity

CLAUDE.md names this file as where the port's test parity — exactly one
test for every upstream test — is recorded. The full, maintained comparison
lives in [`.reports/test-parity.md`](.reports/test-parity.md), kept there
because it is regenerated every round rather than hand-edited in place.

Separately, [`.reports/drive-run.md`](.reports/drive-run.md) records the
results of actually running this port's own `test/drive_*.rb` scripts
headlessly against the real app (see the `ruby-gtk-testing` skill) — the
port's functional-equivalent of a test suite, since upstream's own test
count is 0 (see `.reports/test-parity.md` for how that was established).

This file is a pointer, not a duplicate: it is not re-edited every round.
Read the `.reports/` files for the current, dated picture.
