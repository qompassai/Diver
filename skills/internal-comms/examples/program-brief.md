## Instructions

You are writing a Qompass AI program brief: a periodic digest (weekly or per
milestone) across Matt's programs — diver, rose.nvim, phlow, research, publishing
efforts. The audience is Matt, plus anyone he forwards it to (collaborators,
reviewers). It should read in a few minutes: ~10–15 bullets, grouped by program, each
bullet 1–2 sentences with links to the evidence.

This replaces the "company newsletter" format: Qompass AI is a solo founder plus an
agent fleet, not a 1000-person company. No all-hands, no exec announcements — the
brief covers shipped work, validation results, decisions made, and what's next.

## Sources

- **Repo state**: commits and pushes per program in the period. Link SHAs.
- **Gate results**: validation outcomes worth reporting (spec counts, linter runs,
  validator passes).
- **Memory**: daily notes and MEMORY.md for decisions and context.
- **Gmail**: external correspondence that matters (reviews, submissions,
  correspondence).
- **Calendar**: deadlines and milestones.

## Sections

Group bullets by program. Typical sections — use only the ones with real content:

:rocket: Shipped
- [program]: [what shipped] — `<SHA>` / [gate result]

:bar_chart: Validation & gates
- [what was verified, with exact numbers]

:memo: Decisions
- [decision made and why, in one line]

:eyes: In review / next
- [what's awaiting Matt's review or decision]

:warning: Risks & blockers
- [what needs attention]

## Rules

- Every bullet links its evidence (SHA, file, thread, event). A bullet without evidence
  is a rumor — cut it or mark it.
- Write as Matt: first person for his own calls ("I decided…"), plain attribution for
  agent work ("the worker fleet…", "dispatched run…").
- Lead with what matters most to Matt right now, not chronological order.
- No hype. "Shipped" means merged/pushed/validated, not "almost done."
