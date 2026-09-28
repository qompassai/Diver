# Verified `sf` flags

Every flag wired into the agent-task catalog (`lua/dev/sf/tasks.lua`)
was checked against the Salesforce CLI Command Reference on
2026-09-28 (reference version 2.152.14):

- Command index:
  <https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference.html>
- Cross-checked against the official Spring '26 CLI PDF:
  <https://resources.docs.salesforce.com/260/latest/en-us/sfdc/pdf/sfdx_cli_reference.pdf>

The local `sf` on primo is `@salesforce/cli/2.139.6` (verified before
this workstream). Flags below are reference-stable across these
versions.

## Flags used by the task catalog

| Command | Flag | Meaning | Notes |
|---|---|---|---|
| `sf org list` | `--json` | JSON output | Non-mutating auth inventory probe |
| `sf config get` | `target-org` | Config variable read | Shows the default target org |
| `sf config get` | `--json` | JSON output | |
| `sf project deploy start` | `--source-dir` | Metadata path(s) to deploy | Scoped to one file per step; full-project deploys deliberately not wired |
| `sf project deploy start` | `--json` | JSON output | |
| `sf project deploy start` | `--target-org` | Org to deploy to | Optional; default config used when omitted |
| `sf apex run` | `--file` | Anonymous Apex script file | |
| `sf apex run` | `--json` | JSON output | |
| `sf apex run` | `--target-org` | Org to run against | Optional |
| `sf data query` | `--query` | SOQL string | argv form; no shell interpolation |
| `sf data query` | `--json` | JSON output | Overrides `--result-format`; do not combine |
| `sf data query` | `--target-org` | Org to query | Optional |

## Verified but deliberately NOT wired into autonomous tasks

| Command | Flags | Why excluded |
|---|---|---|
| `sf org login web` | `--alias`, `--set-default` | Interactive browser login; documented in `auth.md` for Matt to run himself |
| `sf org open` | `--target-org`, `--path` | Opens a browser; not autonomous |
| `sf project deploy start` | `--ignore-errors`, `--ignore-conflicts`, `--ignore-warnings` | Override/silence flags; unsafe in an agent |
| `sf apex run test` | `--class-names`, `--tests`, `--test-level`, `--wait`, `--synchronous`, `--result-format`, `--code-coverage`, `--json` | Verified in the reference; not yet needed by any catalog module. Wire only when a module has real test classes. Note: the reference requires "View All Data" permission for this command. |

## Gaps

- Trailhead badge/challenge completion has no public API; teach-docs
  record CLI evidence only.
- `sf` command help text (`sf <topic> --help`) is the fastest local
  re-verification if the CLI is ever upgraded.
