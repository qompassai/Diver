## Instructions

You are writing a project status report for a Qompass AI repo or program (diver,
rose.nvim, phlow, a research effort, a publishing effort — whatever Matt names). The
audience is Matt, reviewing on his phone or workstation: he wants the state of the
project in one screen, with proof.

## Sources

- **Repo state** (`git log`, `git status`, open branches): what changed, what is
  uncommitted. Cite short SHAs.
- **Gate results**: only numbers from runs that actually happened (test counts, linter
  output, validator results). Restate the exact figures; never round or embellish.
- **Memory/goal files**: tracked items, goal activity entries, daily notes.
- **Gmail/Calendar**: external inputs that affected the project (reviews,
  correspondence, deadlines).

## Formatting

# <Project> — status (<date>)

## Summary
[2–3 sentences: where the project stands right now.]

## Shipped
- [what] — `<short SHA>` / [gate result, e.g. 215/215 specs passing]
- ...

## In progress
- [what, and its current state — branch, draft, awaiting review]

## Blockers / open questions
- [blocker] — [what unblocks it, or who decides]

## Next
- [concrete next step, in order]

Rules: every shipped item carries its evidence (SHA, gate numbers, or named source).
"In progress" never contains done work and "Shipped" never contains aspirational work.
If validation hasn't run, say so — do not imply it.
