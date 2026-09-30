## Instructions

You are writing a 3P update for Qompass AI: Progress, Plans, Problems. The audience is
Matt himself (his record of the week), and occasionally an advisor or collaborator with
some context but not day-to-day detail. It must read in 30–60 seconds.

Qompass AI is a solo-founder company: Matt plus an agent fleet. "Progress" therefore
covers what Matt shipped and what his agents completed under his direction — name the
repo and cite the commit SHA or gate result. Scale the granularity to the week, not the
commit: a 3P is a summary, not a changelog.

The three sections:

1. **Progress**: what shipped or completed in the period. Milestones, merged work,
   validated results. Every item attributable — commit SHA, gate numbers, or a named
   source.
2. **Plans**: top priorities for the next period. What is actually next, not a wishlist.
3. **Problems**: what is slowing things down — blockers, broken tooling, open questions,
   risks. Name them plainly; this is the most valuable section.

## Sources

Gather from Matt's sources before drafting:

- **Repo state**: `git log --since="1 week ago" --oneline` across active repos (diver,
  rose.nvim, phlow, others in play). Shipped = committed/pushed with a verified SHA.
- **Memory**: `~/memory/` daily notes for the week; `~/MEMORY.md` for standing context.
- **Goals/tracking**: goal activity entries and tracked items closed or updated in the
  period.
- **Gmail**: threads with decisions or external developments in the period.
- **Calendar**: milestones hit or meetings that changed direction.

Time windows: Progress and Problems cover the past week (up to today); Plans cover the
coming week.

If a source is unavailable, say which one and draft from the rest — never invent
activity to fill a quiet week. A quiet week is reported as a quiet week.

## Workflow

1. **Clarify scope**: which program (or whole company) and which week. Default:
   Qompass AI, past 7 days.
2. **Gather evidence** from the sources above.
3. **Draft** in the strict format below.
4. **Review**: 30–60 second read; every claim attributed; no invented numbers; Problems
   section honest.

## Formatting

The format is fixed. Use exactly this structure:

[pick an emoji that fits the week's vibe] Qompass AI — <program or "Company"> (week of <Mon>–<Sun>, <dates>)
Progress: [1–3 sentences. What shipped. Cite SHAs or gate results.]
Plans: [1–3 sentences. Top priorities for next week.]
Problems: [1–3 sentences. Blockers and risks, stated plainly.]

Each section is 1–3 sentences, matter-of-fact, data-driven. Metrics only where
verified — "215/215 busted specs passing" is fine when the run happened; "significant
progress" is not a metric.
