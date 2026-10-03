Phase: Land (complete)

## Destination and criteria

Destination: selecting a month before the first available period is impossible.

1. `month_options` never offers a month earlier than the month of `first_available`.
2. A `first_available` older than twelve months leaves the thirteen-month window unchanged.
3. A `first_available` in a later month than `today`'s yields no options; one later in the same month still offers the current month (provisional — see doubt 1).

Size: small (one module, one function, no schema or contract change, fits one session).
Branch: `steer/selecting-month-before-first`, created from `main` (no `origin`; default resolved by fallback).
Ignore: `tmp/docs/` added to `.git/info/exclude`, not `.gitignore`, so the diff stays free of tooling lines.

Prime's reading (inline, small path): `CONTEXT.md` defines "first available period" as the earliest month with billing data, so criterion 1 compares against that month. `docs/adr/0001-calendar-months.md` requires whole calendar months, which also settles the granularity of criterion 3 as month-level (changed after review, see Land brief). Code region: `periods.py::month_options`. Prior art: `test_periods.py::test_returns_last_twelve_months_plus_current` (criterion 2 regression). Criterion 3: no prior art.

Agreed seams: `periods.month_options(first_available, today)`, tested through its return value, covering criteria 1, 2 and 3.

## Gates

| # | Criterion | Test | Command | Expected | Status |
| - | --------- | ---- | ------- | -------- | ------ |
| 1 | `month_options` never offers a month earlier than the month of `first_available` | `test_periods.py` — "criterion 1: months before the first available period are not offered" | `python3 -B -m unittest test_periods.MonthOptionsTest.test_criterion_1_months_before_first_available_are_not_offered` | `Ran 1 test`, `OK` | pass |
| 2 | A `first_available` older than twelve months leaves the thirteen-month window unchanged | `test_periods.py` — "criterion 2: a first available period older than twelve months leaves the window unchanged" | `python3 -B -m unittest test_periods.MonthOptionsTest.test_criterion_2_old_first_available_leaves_window_unchanged` | `Ran 1 test`, `OK` | pass |
| 3 | A `first_available` in a later month than `today`'s yields no options; one later in the same month still offers the current month (provisional — see doubt 1) | `test_periods.py` — "criterion 3: a first available period in a later month than today's yields no options" | `python3 -B -m unittest test_periods.MonthOptionsTest.test_criterion_3_first_available_in_later_month_yields_no_options` | `Ran 1 test`, `OK` | pass |
| - | full suite | all tests | `python3 -B -m unittest` | `Ran 4 tests`, `OK` | pass |

Baseline at steer/selecting-month-before-first@f5b578c: clean

Run log:
- 1, 2, full suite: first run by the Prove checking subagent (read-only), `Ran N test(s)` / `OK`; statuses written by the driver. Row 1 red first (failed before the fix); row 2 is a regression guard, green before the fix, and failed under a mutation widening the window start to three years.
- 3: reset to `unrun` after review changed the criterion wording and the test; rerun by the driver after the change, `Ran 1 test in 0.002s` / `OK`. Red first: failed before the fix. Full suite rerun by the driver: `Ran 4 tests in 0.000s` / `OK`.

## Doubt log

1. **Choice made:** a `first_available` in a later month than `today`'s returns an empty list rather than raising.
   **Why uncertain:** no caller exists to show what the picker expects; the ADR is silent.
   **What would settle it:** ask the picker's owner, or read the picker's caller once one exists.
   **Carried**

## Land brief

Review (read-only subagent, plain review because no `code-review` skill was installed): no correctness findings in `periods.py`, including the December to January rollover and `first_available` in the current month.

- Test strength, criterion 3 (low): did not pin whether "after today" is day- or month-level. Fixed: wording changed to month-level (per ADR 0001 and `CONTEXT.md`) and a same-month later-day assertion added.
- Scope (low): the `.gitignore` hunk existed only to hide this file. Fixed: removed, ignore line moved to `.git/info/exclude`.
- Not done: no rollover test for criterion 1 (first in December, today in January); the implementation handles it, the reviewer spot-checked it.

The diff is uncommitted on `steer/selecting-month-before-first`: `periods.py`, `test_periods.py`. The human is asked to review it and either commit, or answer doubt 1.
