# docs/salesforce

Teach-docs and references for the Diver async Salesforce agent-task
workstream (`lua/dev/sf/tasks.lua`, built on the durable job queue in
`lua/dev/sf/trailhead.lua`).

## What lives here

- `<module>.md` — per-module teach-docs, **generated** by the agent-task
  dispatcher when a task finishes (see `:SfTasksDoc <job-id>`).
  Never hand-edit; regenerate.
- `FLAGS.md` — every `sf` flag the task catalog uses, verified against
  the current Salesforce CLI Command Reference.
- `auth.md` — what you must do yourself before any live run
  (the CLI cannot log you in on its own).
- `README.md` — this file.

## Honesty rules (read before trusting a teach-doc)

1. A teach-doc records **CLI evidence only**: exact commands, exit
   codes, and output. It never claims Trailhead badge completion --
   the Trailhead website has no public API and cannot be checked.
2. The header of every generated doc states the **run mode**:
   `live` (real `sf` against a real org) or `hermetic dry-run`
   (stubbed `sf`; proves the wiring, not the org).
3. If no org is authorized, the org probe step fails and the doc says
   so. That is the correct outcome, not a bug.
4. Commands in the catalog use only flags verified in `FLAGS.md`.
   Anything unverifiable was left out.
