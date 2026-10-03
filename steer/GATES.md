# The gates table

One row per success criterion, so every criterion is traceable to the test that defends it. Build skeletons it into the artifact file's `## Gates` section; Prove fills it in.

```markdown
| # | Criterion | Test | Command | Expected | Status |
| - | --------- | ---- | ------- | -------- | ------ |
| 1 | Selecting a month before the first available period is impossible | `src/helpers/periods/period-options.test.ts` — "criterion 1: months before the first available period are not offered" | `npx jest --runInBand src/helpers/periods/period-options.test.ts` | `Tests: 6 passed` | pass |
```

Columns:

- **#** — the criterion's number from `## Destination and criteria`. The mandatory full-suite row has no criterion, so its `#` is `-` and its `Criterion` cell reads `full suite`.
- **Criterion** — the criterion text, verbatim.
- **Test** — the test file path and the test title.
- **Command** — the exact command that runs it, ready to paste.
- **Expected** — the exact observable output that means pass: a count line, an assertion, a measured number against the target.
- **Status** — one of:
  - `unrun` — the row exists but Prove has not reached it. The only legal status before Prove.
  - `pass`, `fail (<reason>)`, or `waived (<reason>)` — set at Prove. When Prove runs in a read-only subagent, the subagent reports the observed output and the driving agent writes the status; nothing else sets one.

In the skeleton Build writes, `Test`, `Command`, and `Expected` may read `unassigned` on a row whose test does not exist yet; every one of them is filled by the time Prove runs a row.

## Rules

- Every criterion gets a row. At Prove, a criterion with no test is `fail (no test mapped)`, and the run does not reach Land with it unresolved unless the human waives it explicitly. Before Prove that same row is `unrun`, not `fail`: a skeleton written early must not spend the signal `fail` carries later.
- Test titles quote the criterion by its number and its words, so a failure at the test site names the criterion it defends without anyone opening this table.
- Commands are scoped to the tests that matter, plus one full-suite row. Cap verbose output the way the repo already asks (on Windows/PowerShell repos, `| Select-Object -Last 50`). Inside a markdown table cell a pipe must be written `\|`, or the row breaks; when the output is short, skip the cap.
- Commands must be cache-safe, so a read-only checker can run them without clearing anything: use the runner's no-cache or no-bytecode flag (`python3 -B`, `jest --no-cache`, `go test -count=1`). A stale cache can make a correct file look broken, or the reverse.
- A criterion that changes, or a test that changes, after its row ran resets that row to `unrun`. Reset it in the same edit.
- `pass` is written only after the command was run in the current session and the `Expected` output was observed. A status carried over from an earlier session is `unrun` until it is run again.
- A `waived` row names who waived it, in the reason: `waived (human: <why>)`. An agent never waives a row.

## Baseline

Written below the table by Build, before the first test is written. One line per check that already fails at the branch point, naming the command and the failure, so a red run later is read as drift or as inherited breakage without guessing.

```markdown
Baseline at <branch>@<short-sha>:
- `npx tsc --noEmit` — fails: TS2345 in src/legacy/export.ts:88 (pre-existing)
- `npx jest --runInBand` — 2 failed: billing/invoice.test.ts (pre-existing)
```

When nothing fails at the branch point, the line reads `Baseline at <branch>@<short-sha>: clean`.

## Run log

Written below the baseline, one line per row, because the table has no room for evidence. It carries three things per row: the observed output lines, who ran them (the driving agent or a named read-only subagent), and how the test earned trust.

```markdown
Run log:
- 1: `Ran 1 test in 0.000s` / `OK`. Red first: failed before the fix (2 failures of 4).
- 2: `Ran 1 test in 0.000s` / `OK`. Regression guard, green before the fix; mutation check: widening the window start made it fail.
```

A test earns trust one of two ways: **red first** (it failed before the change and passes after), or, when it was green before the change, a **mutation check** (breaking the code under test on purpose makes it fail, and the code is then restored). A row with neither stays `unrun`, or is `waived` by the human.
