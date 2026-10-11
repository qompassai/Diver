---
name: sf-org-workflows
description: >
  Run Salesforce hands-on work from the terminal with the `sf` CLI against
  Matt's orgs — inventory and target the right org, deploy/retrieve metadata
  in an SFDX project, run Apex tests, query with SOQL, and move data — the
  loop used to complete Trailhead hands-on challenges in a Trailhead
  Playground up to (never past) the graded Check Challenge click. Use when
  the user asks to "do the hands-on part", "deploy this to the playground",
  "run the module challenge in the org", "query the org", or is working a
  Trailhead module with an org-based unit. Companion to apex-dev (the
  in-editor Apex loop) and salesforce-trailblazer (the module queue).
license: Apache-2.0
compatibility: >
  Requires the `sf` CLI on primo (@salesforce/cli 2.152.14, pacman `sf`).
  Orgs already authenticated there: trailheadPlayground (default org),
  agentforce-de, gov-superbadge. map-dev (TDS production) is SEALED:
  read-only recon at most, never deploy/write/check-challenge against it.
metadata:
  app: salesforce-cli
  default_org: trailheadPlayground
  sealed_orgs: map-dev
allowed-tools: Read Edit Bash
---

# sf org workflows

The terminal half of Matt's Salesforce work: everything a Trailhead hands-on
unit asks an org to *do*, done with `sf` instead of clicks — then parked one
step before the graded action, which is always Matt's click.

## The boundary (never cross)

- **Playgrounds and dev orgs only.** All deploys, data changes, and test
  runs happen in `trailheadPlayground` or another throwaway org.
- **map-dev is sealed.** It is a production org. No deploys, no writes, no
  challenge checks against it. Read-only `sf org list` / describe-level
  recon at most, and only when Matt asks.
- **Graded actions are Matt's.** Never click Check Challenge / Verify in
  Trailhead, never submit quiz answers, never complete superbadge units.
  Your deliverable is: org work done and verified org-side, plus a handoff
  note naming the exact remaining click.
- **No account actions.** No signups, attestations, profile or privacy
  changes, no new playground creation unless Matt has approved that
  specific step (org provisioning decisions are his — see the status file).

## Step 0 — Inventory before touching anything

```bash
sf org list                 # aliases, usernames, connection status
sf config get target-org    # what a bare command would hit
```

Confirm the target org alias *in the command* (`-o trailheadPlayground`)
rather than relying on the default whenever more than one org is connected.
If the org you need is not Connected, stop: re-auth is a browser login,
which is Matt's step. Report the exact blocker; do not attempt credential
workarounds, and never ask for credentials.

## The hands-on loop (per module unit)

1. **Read the unit's requirements literally.** Note every object, field,
   value, name, and picklist value it demands — challenge checkers match
   strings exactly, including API names and capitalization.
2. **Build in a project.** Work inside an SFDX project
   (`sfdx-project.json` at the root; scaffold with
   `sf project generate -n <name>` only if none exists).
3. **Author metadata as files**, not Setup clicks: custom objects/fields as
   `*.object-meta.xml` / `*.field-meta.xml`, Apex as `.cls` + `-meta.xml`,
   flows as `.flow-meta.xml`. Files are reviewable, diffable, redeployable.
4. **Deploy to the playground:**
   `sf project deploy start -o trailheadPlayground -d force-app`
   (narrow `-d` to the changed paths for iteration speed).
5. **Verify org-side** — never trust a successful deploy alone:
   - Data/schema: `sf data query -o trailheadPlayground -q "SELECT ..."`
     (SOQL reference below).
   - Logic: `sf apex run test -o trailheadPlayground -n <TestClass> -r human`
     or anonymous Apex for a quick probe:
     `sf apex run -o trailheadPlayground -f scripts/apex/probe.apex`.
6. **Record and park.** Update the module status file
   (`~/workspace/salesforce-mcp/trailblazer/MODULE-STATUS.md`): what was
   deployed, the verification evidence, and the exact remaining click for
   Matt ("Trailhead → <module> → <unit> → Check Challenge").

## SOQL from the terminal

```bash
sf data query -o trailheadPlayground \
  -q "SELECT Id, Name FROM Account WHERE Industry = 'Technology' LIMIT 10"
sf data query -o trailheadPlayground -t -q "SELECT Id FROM Contact"  # Tooling API
sf data query -o trailheadPlayground -q "..." -r csv > out.csv       # bulk-friendly output
```

- Quote the whole query; escape for the shell once, not per-clause.
- For schema discovery use `sf org list metadata` / `sf sobject describe`
  equivalents via `sf data query -t` on EntityDefinition when unsure of an
  API name — a wrong API name is the #1 cause of "the challenge checker
  can't find it" failures.
- SOQL *inside* Apex (embedded queries, completion) is apex-dev's topic;
  this skill covers SOQL as an org-verification tool.

## Data moves (when a unit needs records)

```bash
sf data import tree -o trailheadPlayground -f data/accounts.json
sf data export tree -o trailheadPlayground -q "SELECT Id, Name FROM Account" -d data/out
sf data delete bulk -o trailheadPlayground -f data/delete.csv -s Account  # destructive: playground only, confirm first
```

Bulk CSV import/export (`sf data import bulk` / `sf data export bulk`) for
anything over a few hundred rows.

## Retrieve (org → files)

```bash
sf project retrieve start -o trailheadPlayground -m ApexClass:MyClass
sf project retrieve start -o trailheadPlayground -d force-app   # by source dir manifest
```

Retrieve before editing org-first artifacts (flows built in a prior UI
session) so the deploy in step 4 diffs against truth.

## Edge cases

- **Deploy passes, checker fails:** re-read the unit text for the exact
  label/API name/default value; checkers test the *requirement string*,
  not the spirit. Re-query org-side and compare character by character.
- **Test run red in playground:** read the failure before changing code —
  playgrounds accumulate other modules' data; a validation rule or
  required field from an earlier module is a common false cause.
- **Session expired mid-module:** stop and park. Re-auth is Matt's
  browser step; note it in the status file.
- **Module wants a special org** (Agentforce playground, DE org features):
  that is a provisioning decision for Matt, recorded as a blocker — the
  Prompt Builder / agent-auth modules are parked on exactly this.
- **Superbadge orgs** (`gov-superbadge`): Matt earns superbadges himself
  per Salesforce policy. Never run challenge work there.
