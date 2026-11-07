# Test parity — Extension Manager (round 3)

| | |
|---|---|
| Upstream | `origin/master` |
| Port | `ruby` @ `f9d640c` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |

No `TEST_PARITY.md` exists at the port's root; `CLAUDE.md` requires one for
the port to be considered done. Still absent, only under `.reports/`.

## Upstream has no test suite — re-verified this round, not assumed from last round's report

```
git ls-tree -r --name-only origin/master | grep -i test        -> nothing
grep -n "test(" origin/master's meson.build / src/meson.build    -> nothing
git grep -n 'g_test_add\|Test.add_func' origin/master -- src    -> nothing
```
Test parity is 0/0, met trivially, same as last round. **The port inherits
no safety net from upstream** — every check below was written for the port
itself and pins nothing upstream's own authors considered worth pinning.

## The runtime gate, re-run for real this round, not copied from the task text or from `drive-run.md`

The task names a gate of `drive_ok=true, 187 checks passed, 0 failed, 14
components`. Each of the four drivers was executed fresh in this session:

```
nix develop --command xvfb-run -a ruby test/drive_installed.rb  -> 39 of 39 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_browse.rb     -> 53 of 53 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_detail.rb     -> 46 of 46 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_upgrade.rb    -> 49 of 49 checks passed, DRIVE OK
```

39 + 53 + 46 + 49 = **187**, zero failures — matching the stated gate
exactly, reproduced by execution in this session.

**This does not match `.reports/drive-run.md`**, the committed report from
the commit that added `test/drive_upgrade.rb`: it claims that driver passes
"50 of 50" and the four-driver total is "188". Running the exact same
script against the exact same committed code, today, produces 49/49, not
50/50. This is called out in detail in `component-parity.md` and again in
`accountability-ensurance.md` as the most serious finding of this round: a
committed, green-looking report whose own headline number does not match
what the script it describes actually outputs.

## The gate is a real check, not a test suite, and the distinction still matters

187 checks passed is real, useful, and reproduced — but it maps to no
upstream test, because upstream has none. "187 checks passed" and "test
parity: 0/0" are both true simultaneously; reporting only the first reads as
more inherited assurance than exists.

## Narrower findings inside the 187, re-checked this round

### Screenshot captures still silently fail and are still not counted

```
nix develop --command xvfb-run -a ruby test/drive_installed.rb 2>&1 | grep -c "shot .* failed"   -> 4
```
Re-confirmed this round on `drive_installed.rb` alone (4 of the same
render-node failures as last round); the mechanism is unchanged — caught,
logged, not asserted on, does not affect `DRIVE OK` or the pass count.
Nobody has looked at an actual rendered screenshot of any dialog or page in
this port, ever, including the two newly-driven surfaces this round
(`UpgradeAssistant`'s dialog, any visual output of the search provider —
though the latter has no visible UI to screenshot by nature).

### `test/drive_upgrade.rb`'s own documented accommodation for a binding gap

`drive_upgrade.rb`'s `GetResultMetas` checks assert against the GVariant's
printed (`.to_s`) text form rather than decoding it, because
`GLib::Variant#value` raises `NotImplementedError` for any `a{sv}`/`{sv}`
member. This is a real binding limitation, documented as such (not excused),
and re-confirmed present this round — the drive script still works around
it the same way.

### Explicitly not exercised by any driver — re-confirmed this round, unchanged

- `ShellDbusInterface`'s real D-Bus path (no GNOME Shell in this sandbox).
- `RequestHandler`'s real HTTP path (every provider stubbed with canned
  JSON/data across all four drivers; `Soup::Session`'s timeout and
  status-code mapping never exercised for real).
- `AnimatedPaintable`'s frame-advance behaviour (`ImageResolver#resolve`
  stubbed to `nil`; no real glycin decode ever runs).
- The real `org.gnome.Shell.SearchProvider2` D-Bus path through an actual
  `Gio::DBusConnection` — `drive_upgrade.rb` calls the provider's methods
  directly with plain Ruby arrays, not through a real bus. `drive-run.md`
  states a separate manual `dbus-run-session`/`gdbus call` round trip was
  done outside this reproducible suite; that claim was **not** independently
  re-verified this round (no D-Bus session bus is available in this
  sandbox to attempt it), so it is carried forward as an unverified claim,
  not re-confirmed.
- The `app.open`/`gnome-extensions://` URI handler — still nothing to drive;
  it does not exist (`component-parity.md` item 1).
- Any non-English locale — no catalogue exists to switch to
  (`translation-parity.md`).

## Rubocop and RSpec — re-checked this round, still neither runnable

```
nix develop --command bundle exec rubocop --version
  -> bundler: command not found: rubocop
nix develop --command ruby -e "require 'kettle/test/rspec'"
  -> cannot load such file -- kettle/test/rspec (LoadError)
find spec -type f -> spec/README.md, spec/spec_helper.rb only, no *_spec.rb files
```
Identical to last round: the dev shell's own banner names both commands, and
neither has ever actually run against this code, in any round so far. This
is now two rounds in a row with the same two named-but-never-executed
commands.

## Verdict

0/0 upstream-test parity, trivially met. 187/187 of the port's own drive
checks reproduced live this round, matching the stated gate. That number is
real. What is not real is `drive-run.md`'s own "50 of 50"/"188 total" claim
for the exact same script against the exact same committed code — a false
green inside an already-committed report, surfaced only by re-running the
suite instead of trusting the file. Rubocop and the RSpec suite remain named
by the dev shell and never executed, two rounds running.
