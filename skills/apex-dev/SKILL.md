---
name: apex-dev
description: >
  Salesforce Apex development in Matt's Neovim using his Diver config's
  real toolchain: the Apex language server (java + apex-jorje-lsp.jar via
  lsp/apex_ls.lua, with embedded SOQL completion), the Salesforce Code
  Analyzer linter and lightning-flow-scanner via the `sf` CLI plugins, the
  Apex DAP replay/interactive debug adapters (lua/dap/apex.lua), anonymous
  Apex execution and test runs through `sf apex`, SOQL/SOSL via the SOQL
  language server and `sf data query`, and deploy/retrieve through
  `sf project`. Use when the user asks to "write apex", "debug this apex
  class", "run my apex tests", "deploy to the org", "check this trigger",
  "run this soql", mentions .cls/.trigger/.apex files, or invokes
  SfApex*/SfDeploy*/SfAnalyze* commands.
license: Apache-2.0
compatibility: >
  Neovim with Matt's Diver config (lsp/apex_ls.lua, lsp/soql_ls.lua,
  lua/dap/apex.lua, lua/linters/_salesforce-code-analyzer.lua,
  lua/dev/sf/*). Salesforce project root marked by sfdx-project.json.
  Requires the `sf` CLI (/usr/bin/sf, pacman package sf 2.150.6-1,
  verified on primo) and java (/usr/bin/java). The Apex LSP jar,
  apexfmt, the SOQL language server, and the DAP JS adapters are NOT
  installed on primo — the skill marks each as a setup step, not as
  available tooling.
metadata:
  app: salesforce-apex
  lsp_config: lsp/apex_ls.lua
  lsp_launcher: apex.jorje.lsp.ApexLanguageServerLauncher
  lsp_jar_path: stdpath('data')/apex-ls/apex-jorje-lsp.jar
  lsp_jar_source: https://github.com/forcedotcom/salesforcedx-vscode/raw/main/packages/salesforcedx-vscode-apex/jars/apex-jorje-lsp.jar
  soql_lsp: lsp/soql_ls.lua (soql-language-server --stdio, npm @salesforce/soql-language-server)
  formatter: apexfmt (BufWritePost hook in apex_ls.lua, runs only if executable)
  linter: Salesforce Code Analyzer v5 via sf (code-analyzer plugin 5.13.0)
  flow_linter: lightning-flow-scanner (plugin 6.19.3)
  dap_module: lua/dap/apex.lua (node + apexReplayDebug.js / apexDebug.js from salesforcedx-vscode)
  cli: sf (/usr/bin/sf)
  sf_plugins: apex 3.9.38, org 5.11.12, deploy-retrieve 3.24.54, data 4.0.110
  filetypes: apex (.cls, .trigger), apex script (.apex), soql, sosl
allowed-tools: Read Edit Bash
---

# Apex development

The full Apex loop in Matt's Neovim: edit with the Apex language server,
format, lint with Salesforce's analyzers, run anonymous Apex, run tests,
deploy, and debug with the Apex DAP adapters. Every tool below is either
verified present on primo or explicitly marked as a setup step.

## Toolchain status (verified on primo, 2026-09-29)

| Tool | Status | Notes |
|---|---|---|
| `sf` CLI | installed (`/usr/bin/sf`, pacman `sf 2.150.6-1`) | plugins: apex 3.9.38, org 5.11.12, deploy-retrieve 3.24.54, data 4.0.110, code-analyzer 5.13.0, lightning-flow-scanner 6.19.3 |
| `java` | installed (`/usr/bin/java`) | launches the Apex LSP jar |
| `node` | installed (`/usr/bin/node`) | runs the DAP JS adapters once installed |
| Apex LSP jar | **not installed** | download from the salesforcedx-vscode repo (see metadata `lsp_jar_source`) to `stdpath('data')/apex-ls/apex-jorje-lsp.jar`; the config notifies on missing jar instead of failing silently |
| `apexfmt` | **not installed** | formatting hook is a no-op until it is on PATH |
| `soql-language-server` | **not installed** | npm `@salesforce/soql-language-server` |
| DAP adapters (`apexDebug.js`, `apexReplayDebug.js`) | **not installed** | set `NVIM_APEX_INTERACTIVE_ADAPTER` / `NVIM_APEX_REPLAY_ADAPTER` or `NVIM_SALESFORCE_DAP_ROOT` to a salesforcedx-vscode checkout |

Do not claim the LSP, formatting, or debugging works before the missing
pieces are installed — the configs degrade gracefully (notify, no-op) by
design.

## The loop

### 1. Edit — Apex LSP

`lsp/apex_ls.lua` starts `java -cp <jar>
apex.jorje.lsp.ApexLanguageServerLauncher` for the `apex` filetype
(`.cls`, `.trigger` per `lua/config/core/filetype.lua`; single-file
support off). Root markers: `sfdx-project.json`, `.git`. Notable
`init_options`: embedded SOQL completion on, synchronized init jobs on.
`on_attach` sets `omnifunc` and **disables** the LSP's
`documentFormattingProvider` — formatting is external (see below), never
fought over. JVM flags (`-Ddebug.internal.errors`,
`-Dlwc.typegeneration.disabled`, `-Xmx2048M`) are explicit in the config;
tune via `settings.apex.jvm` or `apex_jvm_max_heap`.

### 2. Format — apexfmt

Formatting is a `BufWritePost` hook in `apex_ls.lua`, not an LSP
capability: on save of `*.cls`/`*.trigger`/`*.apex` it runs `apexfmt
<file>` as a background job and reloads the buffer on success. It only
fires when `apexfmt` is executable — today it silently skips. Install
apexfmt to activate; until then, format manually.

### 3. Lint — Salesforce Code Analyzer + Flow Scanner

`lua/linters/_salesforce-code-analyzer.lua` is a factory (`M.new({ name
= ..., selector = ... })`) that runs the analyzer through `sf`
(code-analyzer plugin v5, installed). Rule selectors combine
engine/ruleset/severity/rule name or tag — see `:SfAnalyzeRules`,
`:SfAnalyzeSeverity`, `:SfAnalyzeConfig`. Entry points: `:SfAnalyzeFile`
(current buffer), `:SfAnalyzeProject` (whole project),
`:SfAnalyzeDiagnostics` / `:SfAnalyzeDiagnosticsClear`. Flows get the
dedicated `lightning-flow-scanner` linter (plugin 6.19.3, selector
`flow:Recommended`).

### 4. Run — anonymous Apex and tests

```bash
sf apex run --file path/to/script.apex --target-org <alias>   # .apex scripts only
sf apex run test --tests ClassName --synchronous --result-format human
sf apex run test --tests ClassName.methodName --synchronous --result-format human
sf apex run test --test-level RunLocalTests --synchronous --result-format human
sf apex get test --result-format human                          # fetch async results
```

In-nvim: `:SfApexRunCurrent` / `:SfApexRunFile` (`.apex` scripts),
`:SfApexTestClass` / `:SfApexTestCurrent` / `:SfTestRunAll` /
`:SfTestRunNearest`. Anonymous Apex must use the `.apex` extension —
the module refuses anything else.

### 5. Deploy / retrieve

```bash
sf project deploy start --source-dir <path> --target-org <alias>
sf project deploy start --manifest package.xml --target-org <alias>   # validate with --dry-run
sf project retrieve start --source-dir <path>
```

In-nvim: `:SfDeployCurrent` / `:SfDeployFile` / `:SfDeployManifest` /
`:SfDeployProject` / `:SfDeployValidate`, `:SfRetrieveCurrent` /
`:SfRetrieveFile` / `:SfRetrieveManifest`. Deploy the file under the
cursor while editing; validate (`--dry-run`) before touching shared
orgs.

### 6. Debug — Apex DAP adapters

`lua/dap/apex.lua` registers two node-based adapters from the
salesforcedx-vscode bundle:

- `apex` (interactive, `apexDebug.js`) — live debugging against the org.
- `apex-replay` (`apexReplayDebug.js`) — replay debugging from a debug
  log: `:SfApexLogGet` / `:SfApexLogTail` to fetch logs, then
  `:SfApexReplayDebug` to step through the recorded execution.

Adapter discovery order: `NVIM_APEX_REPLAY_ADAPTER` /
`NVIM_APEX_INTERACTIVE_ADAPTER` env vars, then
`NVIM_SALESFORCE_DAP_ROOT` pointing at a salesforcedx-vscode checkout,
then conventional bundle paths. None are installed on primo today —
the module warns with the exact env vars to set.

### 7. SOQL / data

`lsp/soql_ls.lua` wires `soql-language-server --stdio` (npm
`@salesforce/soql-language-server`, not installed) for `.soql`/`.sosl`
files: completion, diagnostics, go-to-definition, hover, rename. The
always-available path is the CLI: `sf data query --query "SELECT ..."
--json` (`:SfSoql`, `:SfSoqlBuffer`, `:SfSoqlFile`, `:SfSoqlExplain`),
plus `sf data export tree` for test-data seeding.

## Related configs (same repo, not this skill)

- `lsp/lwc_ls.lua` and `lsp/visualforce_ls.lua` exist but are thin
  configs with no verified local toolchain — not covered here.
- `lsp/agentscript_ls.lua` is Agentforce scripting, a different domain.
- The `:Sf*` command surface (~110 commands: org, auth, data, flow,
  packaging, schema, user) lives in the config's sf modules; this
  skill covers the Apex-centric subset above.

## Activation

<skill_resources>
manifest:
  files: []
  note: SKILL.md only. The LSP, DAP, linter, and sf-module configs live
    in Diver (lsp/, lua/dap/apex.lua, lua/linters/, lua/dev/sf/) and are
    referenced by path; the `sf` CLI and java do the real work. Nothing
    is bundled in the skill.
</skill_resources>

- **Per-session dedup:** never re-inject this skill into a session whose
  context already contains it. If the skill text is present, act on it —
  do not paste it again or summarize it back.
- **Subagent delegation verdict: partial.** Delegate long non-interactive
  runs — full test suites (`RunLocalTests`), whole-project Code Analyzer
  passes, bulk deploys — and have the subagent return the result summary.
  Keep interactive debugging (live DAP sessions, replay stepping) and
  org-auth decisions in-session: they need Matt's judgment and his
  authenticated org context.

## Rejected scope

- LWC / Visualforce / AgentScript LSP configs — present in the repo but
  thin and unverified; excluded rather than half-documented.
- `sfdx` (legacy CLI) — the config and this skill standardize on `sf`.
- Anything requiring the missing jar/adapters/formatter is marked as a
  setup step, never presented as working.
