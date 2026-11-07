# Test parity — Extension Manager

| | |
|---|---|
| Upstream | `origin/master` |
| Port | `ruby` @ `64c7398` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |

## Upstream has no test suite

Verified three ways, not assumed:

- `git ls-tree -r --name-only origin/master | grep -i test` returns nothing —
  no `tests/` directory anywhere in the tree.
- `meson.build` and `src/meson.build` have no `test(...)` target and no
  `subdir('tests')`.
- `git grep -n 'g_test_add\|Test.add_func' origin/master -- src` returns
  nothing — no `GLib.Test` usage anywhere in the C source.

So test parity is **0/0, met trivially**, per the skill's own worked example
for an upstream with no tests. **The port therefore inherits no safety net —
every check it has was written for the port and pins nothing upstream
considered worth pinning.** This is the finding, stated plainly rather than
left as an implication of the 0/0.

No `TEST_PARITY.md` existed at the port's root before this audit; this
document plus the header above is that ledger's first entry.

## The runtime gate, checked by actually running it (not taken on faith)

The task names a gate of `drive_ok=true, 138 checks passed, 0 failed, 24
components`. Rather than trust that number, each of the three drivers was run
for real this round:

```
nix develop --command xvfb-run -a ruby test/drive_installed.rb   -> 39 of 39 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_browse.rb      -> 53 of 53 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_detail.rb      -> 46 of 46 checks passed, DRIVE OK
```

39 + 53 + 46 = **138**, zero failures, matching the claimed gate exactly. This
is not a false green: the number was reproduced by execution in this session,
not copied from `.reports/drive-run.md`.

## But the gate is a real check, not a test suite, and the distinction matters here

The 138 checks are `## Extra` work per this skill's own framing — real,
useful, and run — but they map to **no upstream test** because there is no
upstream test to map to. "138 checks passed" and "test parity: 0/0" are both
true at once, and reporting only the first number (as the runtime gate
description does) reads as more assurance than it is: it says the port's own
invented checks pass, not that the port reproduces any specific behaviour
upstream's authors found worth pinning down.

### A narrower finding inside the 138: screenshot captures silently fail and are not counted

All three drive runs print lines like:

```
shot 03-selection failed: RuntimeError: widget produced no render node (not realised yet?)
```

Eleven such failures were observed across the three runs (`drive_installed.rb`:
4, `drive_browse.rb`: 3, `drive_detail.rb`: 4). None of them decrement the
pass count or flip `DRIVE OK` to failed — they are caught and logged, not
asserted on. That is a reasonable design for a headless Xvfb environment where
render-node capture is known to be flaky, but it means the "138 checks" number
excludes a real class of thing the drivers attempted and could not confirm:
nobody has actually looked at a screenshot of the selection UI, the error
dialog, the shortcuts dialog, the confirm dialog, the browse empty/error
states, the error-report window, the detail view, the versions dialog, the
comments dialog, the author page, or the screenshot view, in this port, ever.
Visual/style parity (CSS axis, `component-parity.md` item 4's open status) is
unverified by the drivers for exactly the components that most need a look —
the ones with conditional styling and layout. This is not counted as a
"failed" check anywhere in the 138/0, and it should be read as unverified, not
as passing.

### Explicitly not exercised by any driver (stated by `.reports/drive-run.md` and re-confirmed by reading the drivers)

- `ShellDbusInterface`'s real D-Bus path — no GNOME Shell exists in this
  sandbox to connect to.
- `RequestHandler`'s real HTTP path — every provider's network call is
  stubbed with canned JSON across all three drivers; `Soup::Session`'s 30s
  timeout and status-code mapping are never exercised for real.
- `AnimatedPaintable`'s frame-advance behaviour — `ImageResolver#resolve` is
  stubbed to `nil`, so no real glycin decode ever runs.
- The upgrade assistant — there is nothing to drive; see `component-parity.md`
  item 1.
- The search provider / `app.open` URI handler — there is nothing to drive;
  see `component-parity.md` item 2.
- Nothing under a non-English locale (`LANGUAGE=de` etc.) — see
  `translation-parity.md`; there is no catalogue to switch to.

## Rubocop and RSpec, named by the dev shell, neither run

Per `.reports/drive-run.md` and re-confirmed: `bundle exec rubocop` fails
(`can't find executable rubocop` in this Nix store's gem set) and the RSpec
suite's `spec_helper.rb` requires `kettle/test/rspec`, also absent, and there
are no `*_spec.rb` files under `spec/` regardless. Both are unrun checks, not
passed ones, and are named here rather than silently skipped.

## Verdict

0/0 upstream-test parity, trivially met, no inherited safety net. 138/138 of
the port's own drive checks reproduced live. Both of those are real and both
are narrower than the headline "138 checks passed" suggests once the 11 silent
screenshot failures, the never-exercised D-Bus/HTTP/image-decode paths, and
the two entirely-unbuilt destinations are accounted for.
