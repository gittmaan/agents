---
name: steer
description: The spine for writing software end to end: frame the destination, prime on the codebase's own documents, design, build at agreed seams, prove each success criterion with a test, and land a reviewed diff. Use when starting a feature, a fix, or any change worth doing in phases.
disable-model-invocation: true
---

You **steer** the work through six phases, from a loose idea to a diff someone can merge. Each phase ends on a **brief**; the human is asked to decide only when a **doubt** would change the shape of what gets built. This skill holds the order, the routing, the checkpoints, and the criterion-to-test gate, and nothing else: every phase hands its craft to the skill that owns it.

## The artifact

Every run writes one file. **Never write it into a tracked directory silently**: whichever step below hits, if the directory is not covered by `.gitignore`, say so and name the line you are adding before you write.

Resolve the directory in this order, first hit wins:

1. `.vscode/docs/`, if that directory exists.
2. `.settings/docs/`, if that directory exists.
3. Otherwise create the first of `.vscode/docs/`, `tmp/docs/`, `.temp/docs/` whose path is already ignored. Test each with `git check-ignore -q <dir>/` (exit 0 means ignored; it works before the directory exists). If none is ignored, create `tmp/docs/` and append `tmp/docs/` to `.git/info/exclude`, not to `.gitignore`: that line is local tooling, and a `.gitignore` edit would land in the diff Land hands over. Name the line before you write it. Edit `.gitignore` only when the human asks.

The file is `<task-slug>.md`: the ticket id when one exists, then the first four words of the destination's opening sentence, in order, kebab-cased, dropping only `a`, `an`, `the`, `of`, `to`, `for`, `and`, `is`, `be`. A hyphenated term counts as one word; where fewer than four remain, use what there is. Strip apostrophes, and replace any other run of non-alphanumeric characters with a single hyphen. Worked twice, sentence first:

- `Selecting a period before the first available month is impossible.` on BRPP-15849 → `brpp-15849-selecting-period-before-first.md`
- `The household name filter rejects an empty value.` with no ticket → `household-name-filter-rejects.md`

It holds three sections, appended to across the run, plus the Land brief that Land appends at the end:

- `## Destination and criteria`
- `## Gates`
- `## Doubt log`
- `## Land brief` (written by Land only)

One file per task, never one per phase. A later session picks the work up by reading it.

**Status line.** The first line of the file, above the three sections, is `Phase: <name> (<complete | unfinished>)`, rewritten at every phase boundary. It is the only line that is rewritten rather than appended to; it is how a later session or another agent finds where the run stands without inferring it.

## Phases

### Frame

Inline, with the human.

Name the **destination** in one or two lines. Write the success criteria as a numbered list: a measurable target where a metric exists (`p95 under 200ms`, `bundle under 250kB`), a binary observable otherwise (`selecting a month before the first available period is impossible`). State the boundary of each criterion: the unit (day or month, count or percentage) and whether the edge is inclusive. "After today" is not observable until you say whether a date later in the same month counts; read the repo's documents to settle it before asking. A criterion you cannot state observably is not yet a criterion: sharpen it with the human, or drop it and note the drop and its reason under `## Destination and criteria`. Frame does not complete carrying one.

Then **classify the work**. It is **large** if any of these hold:

- it touches more than one **module** — a directory or feature folder whose files change together;
- a design question survives this conversation with the human unanswered;
- it changes a schema, a wire contract, or an interface consumed outside the module that owns it;
- it plainly exceeds one session's context.

Otherwise it is **small**. Ambiguity in the *request* is resolved here, in this conversation, before you classify; only a question still open once the human has answered counts toward largeness.

Then **check the branch**. Run `git rev-parse --abbrev-ref HEAD`. Stop and ask the human to branch if it returns `HEAD` (detached), or the repo's default branch — take that from the last path segment of `git symbolic-ref --short refs/remotes/origin/HEAD` (which prints `origin/main`, so compare against `main`), falling back to `main` or `master` when that command errors. Land hands over an uncommitted diff on the current branch, and neither trunk nor a detached HEAD is a place to leave one. Write no artifact file until the branch is sound.

The human may authorize the branch in advance: asking for the run on trunk, or answering the stop, counts. When authorized, create `steer/<task-slug>` from the current commit with `git switch -c`, carry any uncommitted work onto it, and say so in the brief. When nobody can answer (see Agent protocol), stop; do not branch unasked.

**Completion**: destination named, every criterion observable, size classified, branch confirmed, artifact file written with `## Destination and criteria`, and — on the small path only — Prime's reading done and the agreed seams recorded beside the criteria, covering every criterion.

**Path selection**:

- **large** runs all six phases.
- **small** runs Frame → Build → Prove → Land. Frame owes what the skipped phases would have produced: Prime's reading, narrowed to the criteria in hand, and the seams agreed with the human. Both are in Frame's completion above. Frame does the reading inline on this path; it does not dispatch Prime's subagent.

### Prime

Dispatch a read-only research subagent.

It reads the repo's own documents before any code is written: `CONTEXT.md` (following `CONTEXT-MAP.md` when the repo has more than one), the ADRs under `docs/adr/`, the prior art nearest each criterion, and any external contract the change touches — API shape, schema, third-party provider setup. It returns a compressed brief naming, per criterion, the code region and the prior art that bears on it, plus any ADR the intended change would contradict.

**Completion**: every criterion has a named code region and prior art, or an explicit "no prior art" against that criterion.

### Design

Inline. This is where the human is in the loop.

Always call the Skill tool twice, for "grilling" and "domain-modeling". Add "codebase-design" when the module's shape, depth, or interface is itself in question. Add "prototype" when the open question is how it should look or behave. Call the Skill tool with "to-spec" **only** when Frame classified the work large; that publishes to the issue tracker, and the artifact file then references the published item by name and URL. For small work the criteria in the artifact file are the spec. If the work is large and no issue tracker is configured, keep the spec in `<task-slug>.md` and say so in the boundary brief rather than stalling.

Design ends by agreeing the **seams** under test with the human, because `tdd` writes no test at an unconfirmed seam. Record the agreed seams in the artifact file.

**Completion**: no open design question remains, and the seams are written down and confirmed, covering every criterion.

### Build

Entry condition: the agreed seams are in the artifact file — put there by Design on the large path, by Frame on the small one — and they cover every criterion. Build does not open without them. Build also writes the gates skeleton first: one `unrun` row per criterion, plus the mandatory full-suite row and the baseline of what already fails at the branch point (format in [GATES.md](GATES.md)).

Inline. Call the Skill tool with "tdd" and work at the agreed seams; implement directly everywhere else. Work in vertical slices. Typecheck and run single test files as you go; the full suite belongs to Prove. Write each test red first and keep the red output. A criterion whose test is already green before the change is a **regression guard**: say so in the gates run log, and prove the test can fail by breaking the code under test on purpose, running the test, and restoring it.

**Completion**: every criterion is defended by at least one passing test at an agreed seam.

### Prove

Dispatch a read-only checking subagent.

Fill in the gates table Build skeletoned (format in [GATES.md](GATES.md)), run every command in it, and record each result. A criterion with no test mapped to it is a **failed gate**, not an omission. Run each command fresh: if a result contradicts the code on disk, suspect a stale cache or build output before suspecting the code, clear it, and rerun before recording anything. Prove leaves `## Gates` complete in the artifact file. A criterion or test that changes after a row ran resets that row to `unrun`.

**Completion**: every criterion has a row, every row has been run, and every row passes or is waived explicitly by the human.

### Land

Dispatch a subagent that calls the Skill tool with "code-review". Tell it to check, besides correctness, that each test would fail if its criterion were violated, and to flag anything in the diff that no criterion needs.

A finding that changes code, tests or criteria sends the run back to Prove for the affected rows; Land completes only when every gate is green on the final diff. Re-run the rows, then write the brief.

Then write the **Land brief** into the artifact file under `## Land brief`: the gates table with its pass/fail, the doubt log, and the review findings, each marked fixed or not done. Leave the diff uncommitted and hand it over, saying plainly what the human is being asked to do.

**Completion**: the review has run, the Land brief is written, the working tree is left as it is.

## Checkpoints

Every phase boundary produces a **brief** (format in [BRIEF.md](BRIEF.md)), and no phase is complete until its brief exists. **Push right**: do the maximal work of the phase before involving the human.

A doubt is **load-bearing** when either holds:

- the answer would change *what* gets built, not merely how;
- you cannot reach the answer yourself, and work ahead would be built on the guess.

Everything else is **carried**, and the run continues without it. A doubt is carried when a wrong guess is cheap to undo and you can name the default you took: ask what it costs if the guess is wrong, not whether the question feels important.

Settle it yourself before you classify it. A doubt you can close with a read, a grep, or a command is not a doubt; push right and close it. Only what survives that gets written down.

Every surviving doubt is numbered and appended to `## Doubt log` in the artifact file, carrying the same four fields the brief gives it, so the log and the brief never disagree. Carried and load-bearing alike are logged: a later session resumes from this log, and the doubts that changed what got built are the ones it most needs. When a load-bearing doubt is answered, record the answer against its number and carry on. A load-bearing doubt stops the run at the next brief.

When a load-bearing doubt threatens the criteria themselves, still complete the phase and write them, marked `(provisional — see doubt N)` against that doubt's number. Committing a provisional criterion is cheap; a phase that cannot complete has nothing to show the human.

A doubt that surfaces mid-phase does not interrupt it: carry on to the boundary and raise it in that brief. Hard-stop mid-phase only when the doubt blocks the rest of the phase outright, and when it does, emit a brief in the same format naming the phase as unfinished.

## Handoff

At any boundary where the work still ahead exceeds the context still available, call the Skill tool with "handoff" (or "claude-handoff" to launch the continuation immediately). Write the handoff document into the artifact directory beside `<task-slug>.md`, not to the OS temp directory, so the whole task is one directory to hand over. The handoff document references `<task-slug>.md` rather than restating it.

## Entering mid-flight

Invoked with code already written and no Frame ever run: run Frame first against what exists. Reconstruct the destination and criteria from the diff and the conversation, classify, check the branch, write the artifact file, then resume at the phase matching the state of the work. Prove has nothing to bind tests to without this.

## Subagents

Describe the role, never a harness-specific agent type: this skill runs under several harnesses. Prime dispatches "a read-only research subagent", Prove "a read-only checking subagent", Land "a review subagent". Each dispatch carries the artifact file path and the criteria it is working against, and each returns a brief, not a transcript.

## Agent protocol

Rules for an agent running this skill, whether it drives the run or is dispatched inside it. They add no phases and change no completion condition; they make the existing ones checkable by something that is not the agent that did the work.

**Resuming.** On entry, if the artifact directory already holds a file for this task, read it before anything else: the `Phase:` line says where the run stands, `## Doubt log` says what is answered, `## Gates` says what has been proved. Resume at the first phase whose completion does not hold. Never restart Frame over an existing file, and never trust the `Phase:` line over the evidence below it; if they disagree, believe the evidence and correct the line.

**No human present.** When nothing can answer (a headless run, a scheduled task, a dispatched subagent), every load-bearing doubt is a hard stop: write the brief, write the doubt, end the turn. Never answer a load-bearing doubt yourself to keep moving, and never reach Land on a guess.

**Dispatch contract.** A dispatch to a subagent carries, in this order: the role in one line; the artifact file path; the criteria, numbered, verbatim; the boundary of what it may touch (read-only roles may write nothing, including the artifact file, which the driving agent updates from their brief); and the exact brief it must return. A subagent that cannot be given the tools its role needs says so in its brief instead of improvising. When the harness has no subagent capability, the driving agent runs the role inline, then states in the brief that the check was not independent.

**Skills that are not installed.** Every craft this skill hands off to (`grilling`, `domain-modeling`, `codebase-design`, `prototype`, `to-spec`, `tdd`, `code-review`, `handoff`) is a separate skill. If the Skill tool does not offer one, do not pretend it ran: say which is missing in the boundary brief, do the work plainly to the same completion condition, and log a carried doubt that the craft was approximated.

**Evidence over assertion.** A gate is `pass` only when its command has been run in this session and its `Expected` output observed. Record the observed line, not a paraphrase. Never edit a test, an expected value, or a criterion to turn a row green; a criterion that must change is changed in `## Destination and criteria`, with the reason, and its row reset to `unrun`. A red row is read against the baseline before it is called drift or inherited.

**Scope discipline.** Touch only what a criterion needs. Anything else noticed on the way goes in the doubt log as carried, not into the diff.

**Reporting.** Briefs point at files and never paste them. Keep each brief short enough to read at a glance; the artifact file is where the detail lives.
