# The checkpoint brief

What the human reads at a phase boundary. Decision-ready and short: a brief, never a draft, and never the raw output. All four headings appear on every brief, in this order.

## What happened

One or two lines: the phase that just ended and what it produced. If the phase stopped short, say so here.

## Where it is

The path to the artifact file, plus paths or URLs to anything else this phase produced. Point; never paste the content.

## Doubts

A numbered list, sharing one numbering with the artifact file's `## Doubt log` so `(provisional — see doubt 1)` resolves. Each entry carries four things, and only these four, so an entry can be copied into the log unchanged:

1. **the choice made** — what you did in the absence of an answer;
2. **why it is uncertain** — the evidence you have and the evidence you lack;
3. **what would settle it** — the file to read, the person to ask, the command to run;
4. **load-bearing or carried** — per the rule in the skill's `## Checkpoints`.

Write `None` when there are none. The heading always appears: an absent doubt section reads as an unasked question.

A doubt you could have settled yourself does not belong here. Settle it, then write the brief.

## Next

The next phase and what it will do, ending in one of two things:

- a **stop**: "answer the load-bearing doubts above before I continue";
- a **continue**: "proceeding to Build".

A brief carrying a load-bearing doubt ends in a stop. Everything else continues.

## Example

```markdown
## What happened
Design ended: seams agreed for criteria 1–3; no open design question.

## Where it is
.vscode/docs/brpp-15849-selecting-period-before-first.md

## Doubts
1. **Choice made:** treated "first available period" as the earliest month with data, not the account's open date.
   **Why uncertain:** the schema has both; the ticket says only "available".
   **What would settle it:** ask the product owner, or read the ADR on period semantics.
   **Load-bearing**

## Next
Answer the load-bearing doubts above before I continue.
```
