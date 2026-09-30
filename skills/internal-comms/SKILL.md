---
name: internal-comms
description: Internal communications for Qompass AI in Matt's plain, evidence-based voice. Covers 3P updates (Progress/Plans/Problems), project status reports, incident reports, program briefs, leadership updates, and FAQs. Reach for this whenever Matt asks for a weekly 3P, a status report on a repo or program, an incident writeup for his security-sensitive infrastructure, a concise leadership-style brief, or a set of answered FAQs — or whenever raw notes, git history, Gmail threads, or calendar events need shaping into a disciplined, attributed comms format. Gathers evidence from Gmail, Google Calendar, repo state, and memory before drafting; every claim is attributed to a source and no numbers are invented.
license: Apache-2.0
compatibility: Works standalone from user-supplied notes. For evidence gathering it pairs with the gmail and google-calendar skills plus local repo state (git log) and memory files (~/MEMORY.md, ~/memory/, goal workspaces); those are soft dependencies — when unavailable, say so and draft from what the user provides instead of inventing sources.
metadata:
  domain: communications
  org: Qompass AI
  formats: 3p-updates, status-report, incident-report, program-brief, faq-answers, general-comms
allowed-tools: Read Edit Bash
---

# Internal Communications — Qompass AI

Write internal communications for Qompass AI: Matt's company. He is a solo founder
directing an agent fleet, a former intel officer, and an evidence-driven writer. His
voice is plain, opinionated, and precise — ELI5 to open, then full depth, never hype.

## Standing rules (apply to every format)

1. **Attribute every claim.** Each fact traces to a source: a Gmail thread, a calendar
   event, a commit SHA, a gate run, a memory file. Name the source in or beside the claim.
2. **Never invent numbers.** Metrics come only from observed runs (test counts, SHAs,
   timestamps). If a number isn't verified, leave it out or mark it explicitly as
   unverified.
3. **Report exactly what ran, passed, failed, or was skipped.** No rounding up, no
   "mostly green."
4. **Distinguish confirmed from suspected.** Hypotheses are labeled as hypotheses —
   especially in incident reports.
5. **If a source is unavailable, say so.** Ask Matt for the missing piece rather than
   filling the gap with plausible text.

## Workflow

1. **Identify the type** from the request: 3P update, project status report, incident
   report, program brief, FAQ set, or general comms.
2. **Load the format file** from `examples/`:
   - `examples/3p-updates.md` — Progress/Plans/Problems weekly update
   - `examples/status-report.md` — project or repo status report
   - `examples/incident-report.md` — incident report (security-sensitive infra)
   - `examples/program-brief.md` — periodic digest across programs
   - `examples/faq-answers.md` — frequently asked questions with answers
   - `examples/general-comms.md` — anything else; clarify audience and tone first
3. **Clarify scope** before drafting: which program/repo, which time period, who the
   audience is. Ask when ambiguous.
4. **Gather evidence** from Matt's actual sources (see below), then **draft in the
   format's strict structure**, then **review** for concision and attribution.

## Matt's sources (use these, not generic corporate ones)

- **Gmail** (gmail skill): threads with decisions, reports, external correspondence.
  Cite thread subject + date.
- **Google Calendar** (google-calendar skill): events, milestones, deadlines. Cite event
  title + date.
- **Repo state**: `git log` across his repos (diver, rose.nvim, phlow, others in play).
  Cite short SHAs.
- **Memory and goals**: `~/MEMORY.md`, `~/memory/` daily notes, goal workspaces and
  tracked items. Cite the file.
- **Matt himself**: when sources are thin, ask — he is the primary source of record.

## Keywords

3P update, progress plans problems, status report, incident report, postmortem, program
brief, leadership update, Qompass AI update, FAQ, weekly update

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. The envelope for this skill carries its bundled resources:

<skill_resources>
<file>examples/3p-updates.md</file>
<file>examples/status-report.md</file>
<file>examples/incident-report.md</file>
<file>examples/program-brief.md</file>
<file>examples/faq-answers.md</file>
<file>examples/general-comms.md</file>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** partial — delegate evidence gathering. The
  Gmail / calendar / git / memory sweep runs well in a subagent that
  returns cited facts. Drafting stays in-session: voice and judgment stay
  with Matt.
