# Test parity — Extension Manager (round 4)

| | |
|---|---|
| Upstream | `origin/master` |
| Port | `ruby` @ `e564797` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |

No `TEST_PARITY.md` exists at the port's root; `CLAUDE.md` requires one.
Still absent, only under `.reports/`, fourth round running.

## Upstream has no test suite — re-verified this round, not assumed

```
git ls-tree -r --name-only origin/master | grep -i test     -> nothing
git grep -n 'g_test_add\|Test.add_func' origin/master -- src -> nothing
```
Test parity is 0/0, met trivially — unchanged across all four rounds. The
port inherits no safety net from upstream; every check below was written
for the port itself.

## The runtime gate, re-run live this round, not copied from the task text or `drive-run.md`

The task names a gate of `drive_ok=true, 234 checks passed, 0 failed, 19
components`. All five drivers executed fresh in this session:

```
nix develop --command xvfb-run -a ruby test/drive_installed.rb  -> 39 of 39 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_browse.rb     -> 53 of 53 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_detail.rb     -> 51 of 51 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_upgrade.rb    -> 49 of 49 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_assets.rb     -> 42 of 42 checks passed, DRIVE OK
```

39 + 53 + 51 + 49 + 42 = **234**, zero failures — matches the stated gate
exactly, reproduced by execution in this session on the branch tip, not
read off a committed report. Round 3's finding that `drive-run.md`
overstated its own numbers (claimed 188/50, actual 187/49) does not
recur this round: `.reports/drive-run.md` was rewritten to match this
exact 234 figure and this round's fresh re-run confirms it is now correct.

## The gate is a real check, not a test suite, and the distinction still matters

234 checks passed is real, reproduced, and now accurately reported. It
still maps to no upstream test, because upstream has none. "234 checks
passed" and "test parity: 0/0" remain both true at once; stating only the
first continues to read as more inherited assurance than exists.

## What `test/drive_assets.rb` newly covers, and does not

New this round. It drives `Application#install_icon_theme` and the three
new `data/` templates for real: confirms `ICONS_DIR` is on the real
`Gtk::IconTheme` search path, that all 18 shipped action-glyph names
resolve, that the subset any widget actually sets resolves, that a real
`Gtk::Image` built from one paints a paintable backed by this port's own
file rather than a fallback glyph, and that the desktop-entry/metainfo
templates parse and substitute `APP_ID` correctly. It does **not** check:
whether `Application::APP_ID` itself resolves as an icon anywhere (the
About dialog's own icon — see `component-parity.md` #2); whether any of
the 8 screenshot files the metainfo names actually exist (they don't);
whether the `gnome-extensions://` MIME type the desktop entry declares is
backed by any handler code (it isn't — `component-parity.md` #1).

## Narrower findings inside the 234, re-checked this round

### Screenshot (pixel) captures still silently fail and are still not counted

```
nix develop --command xvfb-run -a ruby test/drive_installed.rb 2>&1 | grep -c "shot .* failed"   -> 4
```
Re-confirmed this round on `drive_installed.rb` alone — same mechanism as
every prior round: caught, logged, not asserted on, does not affect `DRIVE
OK` or the pass count. No rendered pixel output of any dialog or page in
this port has ever been inspected by a human or by an assertion, across
four rounds, including this round's newly-driven icon/asset path (which
has no visual surface to screenshot in the first place — it registers a
search path, it doesn't render a widget of its own).

### `test/drive_upgrade.rb`'s documented GVariant binding workaround

Unchanged: `GetResultMetas` checks assert against the GVariant's printed
(`.to_s`) form because `GLib::Variant#value` raises `NotImplementedError`
for `a{sv}`/`{sv}` members — a real, named binding limitation, re-confirmed
present this round.

### Explicitly not exercised by any driver — re-confirmed this round

- `ShellDbusInterface`'s real D-Bus path (no GNOME Shell in this sandbox).
- `RequestHandler`'s real HTTP path (every provider stubbed across all five
  drivers).
- `AnimatedPaintable`'s real frame-advance over a real glycin decode (round
  3's `3b9033c` commit message claims this was driven for real — re-checked
  this round: `test/drive_assets.rb` and `test/drive_detail.rb` both use
  `test/fixtures/animated.gif`, a real file, through `ImageResolver`; this
  is real progress since round 3's report, which said `ImageResolver#resolve`
  was still stubbed to `nil` — that specific claim is now stale in round 3's
  own text and has been corrected in this round's reports rather than
  repeated).
- The real `org.gnome.Shell.SearchProvider2` D-Bus path through an actual
  `Gio::DBusConnection` — still called directly with plain Ruby arrays, not
  through a real bus, in every round including this one.
- The `app.open`/`gnome-extensions://` URI handler — still nothing to
  drive; it does not exist (`component-parity.md` #1).
- Any non-English locale — no catalogue exists to switch to
  (`translation-parity.md`).

## Rubocop and RSpec — re-checked this round, still neither runnable, fourth round running

```
nix develop --command bundle exec rubocop --version
  -> bundler: command not found: rubocop
nix develop --command ruby -e "require 'kettle/test/rspec'"
  -> cannot load such file -- kettle/test/rspec (LoadError)
nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
  -> An error occurred while loading spec_helper. (LoadError: kettle/test/rspec)
  -> 0 examples, 0 failures, 2 errors occurred outside of examples
find spec -type f -> spec/README.md, spec/spec_helper.rb only, no *_spec.rb files
```
Identical to every prior round: the dev shell's own banner names both
`bundle exec rubocop` and the RSpec runner invocation; both are run live
this round, both still fail the same way, and there are still zero actual
`*_spec.rb` files for RSpec to run even if the harness loaded. This is now
four rounds running with the same two named-but-never-successfully-executed
commands. A suite that has never once run is a gap, not a formality —
stated plainly, as the task requires.

## Verdict

0/0 upstream-test parity, trivially met. 234/234 of the port's own drive
checks reproduced live this round, matching the stated gate exactly, and
this round's reports' own numbers are internally consistent with a fresh
re-run (round 3's report-accuracy problem is fixed, not repeated). Rubocop
and the RSpec suite remain named by the dev shell and have never once
executed successfully, four rounds running — this is the single largest
test-parity gap in the project: a real, maintained-looking spec harness
(`spec/spec_helper.rb`, `kettle-test` in the Gemfile) that has never
produced a single passing or failing example.
