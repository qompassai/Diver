---
name: salesforce-trailblazer
description: >
  Work through Salesforce Trailblazer (trailhead.salesforce.com) modules
  asynchronously with an AI agent, on top of Diver's Trailhead job queue
  (lua/dev/sf/trailhead.lua). Enqueue a module as a job (kinds: trailmix,
  quest, study, shell, note), break it into steps, attach shell steps that
  run `sf` CLI commands against a scratch org for hands-on challenges, and
  let the agent checkpoint progress, persist state across restarts, and
  report back. Use when the user asks to "work through a trailhead module",
  "start a trailmix", "do this trailhead badge with me", "grind trailhead
  quests", "check my trailhead progress", "resume my trailhead job", or
  mentions SfTrailhead commands, trailhead vouchers, or certification prep.
license: Apache-2.0
compatibility: >
  Neovim with Matt's Diver config providing the dev.sf.trailhead module
  and its :SfTrailhead* user commands. Hands-on steps need the `sf` CLI
  (verified on primo: /usr/bin/sf, pacman package sf 2.150.6-1) and an
  authenticated Salesforce org (scratch, playground, or dev). Browser-based
  module completion is NOT automated — Trailhead exposes no public
  completion API; that step is manual or delegated to a browser task.
metadata:
  app: trailhead
  diver_module: lua/dev/sf/trailhead.lua
  job_kinds: trailmix, quest, study, shell, note
  step_kinds: shell, note
  bounds: 128 jobs max, 4 active, 256 steps per job, 15-min step timeout
  cli: sf (Salesforce CLI, /usr/bin/sf)
  org_plugins: org 5.11.12, apex 3.9.38, deploy-retrieve 3.24.54
  no_completion_api: "true"
allowed-tools: Read Edit Bash
---

# Salesforce Trailblazer — async agent jobs

Work Trailhead modules with an agent running ahead of you. The workflow is
built on Diver's `dev.sf.trailhead` module
(`/home/phaedrus/.GH/Qompass/Diver/lua/dev/sf/trailhead.lua`): a bounded,
disk-persisted job queue. You enqueue a module, attach steps, start the job,
and the agent works the hands-on parts via the `sf` CLI while you read or
do something else. Sessions survive Neovim restarts.

## Hard boundary: what this skill does NOT do

Trailhead exposes **no public completion API**. There is no endpoint an
agent can call to mark a module unit complete, check a badge, or read
quiz answers. This skill never claims otherwise. The honest split:

- **Agent-verifiable:** org-side state. Did the metadata deploy?
  (`sf project deploy start --source-dir ...`). Do the Apex tests pass?
  (`sf apex run test --tests ... --synchronous`). Does the SOQL return
  the expected rows? (`sf data query`). These are shell steps in the job.
- **Human/browser-side:** clicking through Trailhead units, submitting
  quiz answers, and pressing "check challenge" on hands-on challenges.
  That is done by the user, or by a browser task / MCP tool the user
  explicitly approves — which then reports back through
  `:SfTrailheadDone {id} {step} [result]` / `:SfTrailheadFail {id} {step}
  {error}`. The module is designed for exactly this handoff.
- **Authorized browser agent (proven 2026-10-04):** with the user's
  explicit authorization, a browser task CAN complete modules as the
  user: sign in via the user's own takeover for SSO (never ask for or
  handle their IdP password), work modules in trail order, skip badges
  already earned (verify each on the page), spin up a Trailhead
  Playground for hands-on challenges, and report progress every ~5
  modules. Scope the authorization to the named trail only. This is
  still not an API — it is a logged-in browser doing what the user
  asked it to do, and it needs the user's sign-in.

Anything promising automatic badge detection or Trailhead API reads is
fiction. Scope every plan to the split above.

## The workflow

### 1. Enqueue the module

```vim
:SfTrailheadEnqueue {trailmix|quest|study|shell|note} {title}
```

Pick the kind that matches the work: `trailmix` for a whole trailmix,
`quest` for a Trailhead Quest, `study` for reading-heavy modules,
`shell` when the job is mostly CLI work, `note` for research captures.
The command prints the job id — everything else references it.

### 2. Break the module into steps

```vim
:SfTrailheadAddStep {id} {shell|note} {name} [argv...|text...]
```

- `note` steps carry text: the unit's key concepts, quiz-relevant facts,
  links. They complete immediately and become the study log.
- `shell` steps carry an argv list (no shell interpolation — argv form
  only, matching Diver's subprocess discipline) that runs locally via
  `vim.system`, e.g. `sf org create scratch --definition-file
  config/project-scratch-def.json`, `sf project deploy start
  --source-dir force-app`, `sf apex run test --tests MyClassTest
  --synchronous --result-format human`.

A good module plan mirrors the Trailhead unit list: one step per unit,
study units as notes, hands-on units as shell steps against the org.

### 2b. Trail-scale: one job for a whole trail (proven 2026-10-04)

For a full trail (e.g. "Become an Agentblazer Champion 2026", 29 modules):
enqueue ONE `trailmix` job, then add one step per module **in trail order**
as an *external* step (name only — no argv, no note). External steps wait
for `:SfTrailheadDone {id} {step} [result]` / `:SfTrailheadFail {id}
{step} {error}`, which is the honest shape of Trailhead work: the browser
side (user or authorized browser agent) reports back, the queue advances.

Get the module list from the trail page's embedded JSON-LD: fetch the HTML
and extract `"@type":"Course"` entries (each has `name`, `url`, and
`learningResourceType`). Trailhead page text alone omits module titles —
the JSON-LD is the reliable source.

Pair each module step with a **teaching file**: fetch the module's unit
pages, study the content, and write a mechanism-level Markdown file
(plain-language opening → full depth, decision rules, exam gotchas,
hands-on guidance; never brand it "ELI5") to a per-trail directory such as
`~/workspace/salesforce-mcp/trailblazer/<trail-slug>/<module-slug>.md`.
The teaching files are the durable value for certification prep; the queue
tracks workflow progress, the files carry the knowledge.

**Reconcile before repeating (no API exists):** Trailhead has no public
completion API, so check the user's public Trailblazer profile
(`https://www.salesforce.com/trailblazer/<id>`) via the browser — the
badge grid lists every earned module. Cross-check the trail's module names
against the badge list, then mark already-earned steps complete with a
result like "badge already earned <date> (verified on Trailblazer
profile)". Never redo earned badges.

### 3. Start and monitor

```vim
:SfTrailheadStart {id}     " start (or restart) the job
:SfTrailheadStatus {id}    " one-job status
:SfTrailheadJobs           " list all jobs
:SfTrailheadLog {id}       " bounded log (last 50 lines persisted)
```

Steps run in order; a shell step's exit code decides pass/fail. The queue
is bounded (4 active jobs, 256 steps/job, 15-minute step timeout) so a
stuck org command can't hang the session forever. Job state is written
to disk, so `:SfTrailheadResume {id}` picks up after a restart.
(Durability fixes 2026-10-04: `step_done` now persists after advancing,
and the load path preserves terminal step states — completed work
survives restarts. Verified: 8/29 steps intact across a fresh nvim.)

### 4. Verify hands-on challenges

For each hands-on step, verify **in the org**, not in the browser:

1. Deploy the unit's metadata: `sf project deploy start --source-dir
   <path> --target-org <alias>`.
2. Run the relevant tests: `sf apex run test --tests <ClassName>
   --synchronous --result-format human` — zero failures required.
3. For data/setup challenges: `sf data query --query "SELECT ..."` and
   confirm the rows exist.
4. Mark the step done with the evidence as the result string, or failed
   with the error output. The log keeps the receipts.

### 5. Pause / resume / cancel

```vim
:SfTrailheadResume {id}     " resume a paused/interrupted job
:SfTrailheadCancel {id}     " cancel one job
:SfTrailheadCancelAll       " cancel everything active
```

Async means the user walks away: always leave the job resumable, never
assume the session stays open.

## Certification vouchers

`:SfTrailheadQuests` prints the researched voucher sources from the
module, each labeled VERIFIED (confirmed against an official Salesforce
source) or SPECULATIVE (third-party/unconfirmed). Verified entries in
the module: Trailhead Quests (monthly themed challenges, voucher is a
prize not guaranteed), Trailhead Coach (Workforce Partner / Talent
Alliance cohorts only), Trailhead Military (active duty, reserve, guard,
veterans, military spouses), AI Associate / AI Specialist free first
attempts (time-bound promotion — re-verify before planning around it).
Speculative: Certification Days (50%-off historically, program status
unconfirmed), community meetup raffles, third-party voucher trackers.
Quote the label when passing these to the user.

## Activation

<skill_resources>
manifest:
  files: []
  note: SKILL.md only. The job queue lives in Diver's
    lua/dev/sf/trailhead.lua and is driven through the :SfTrailhead*
    user commands; the Salesforce CLI does the org-side work. Nothing is
    bundled in the skill.
</skill_resources>

- **Per-session dedup:** never re-inject this skill into a session whose
  context already contains it. If the skill text is present, act on it —
  do not paste it again or summarize it back.
- **Subagent delegation verdict: recommended.** Trailhead jobs are the
  textbook async workload: long, non-interactive hands-on runs (deploys,
  test suites) with persisted state and a bounded log. Delegate the job
  to a subagent, hand it the job id and the step plan, and have it
  report via :SfTrailheadStatus / :SfTrailheadLog checkpoints. Keep
  browser-side completion with the user or an explicitly approved
  browser task — never let a subagent freelance browser actions.

## Rejected scope

- Automatic badge/unit completion detection — impossible, no Trailhead
  API (see hard boundary).
- Quiz-answer lookup or answer automation — not a real workflow in the
  config; excluded deliberately.
- Trailhead GO / mobile offline modules — no CLI backing, out of scope.
