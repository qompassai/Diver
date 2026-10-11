---
name: sf-code-analyzer
description: >
  Scan and fix Salesforce code with Salesforce Code Analyzer (v5) and the
  lightning-flow-scanner through the `sf` CLI: run scans over Apex, flows,
  and metadata from the terminal or from Matt's Neovim (which wires the
  analyzer as a linter), read the results, triage violations by severity,
  and drive the fix-verify loop until the scan is clean or the remainder is
  consciously accepted. Use when the user asks to "run code analyzer",
  "scan this apex", "check this flow", "fix the analyzer violations", or
  mentions PMD, ESLint-for-LWC, RetireJS, DFA, or flow-scanner findings.
  Companion to apex-dev, which owns the edit/test/deploy loop this feeds.
license: Apache-2.0
compatibility: >
  Requires the `sf` CLI with the code-analyzer plugin (verified on primo:
  @salesforce/plugin-code-analyzer 5.16.0, `sf code-analyzer run --help`
  responds) and the lightning-flow-scanner plugin (6.19.3, per apex-dev).
  Neovim side: lua/linters/_salesforce-code-analyzer.lua in Matt's Diver
  config. Run inside an SFDX project (sfdx-project.json).
metadata:
  app: salesforce-code-analyzer
  plugin_version: 5.16.0
allowed-tools: Read Edit Bash
---

# Salesforce Code Analyzer

Code Analyzer is an umbrella: one `sf` command runs several engines —
PMD (Apex and more, including DFA graph-engine rules), ESLint (LWC /
JavaScript), RetireJS (known-vulnerable JS libraries), and the
lightning-flow-scanner rules for flows — and merges their findings into a
single report. Treat its output as a worklist, not a verdict: severity and
rule context decide what must be fixed.

## Run a scan

```bash
# Whole project (from the SFDX project root)
sf code-analyzer run -w force-app -f report.html

# Targeted: one class, one flow directory, machine-readable output
sf code-analyzer run -t "force-app/main/default/classes/AccountService.cls" -f results.sarif
sf code-analyzer run -t "force-app/main/default/flows" -f results.csv

# Only certain engines or rule categories
sf code-analyzer run -w force-app --rule-selector "pmd:Recommended" 
```

- `-w` = workspace paths (files/dirs to scan), `-t` = specific targets.
- Formats: `html` for Matt to read, `sarif`/`csv`/`json` for agents to
  process. Produce both when the scan is a deliverable.
- Exit status is non-zero when violations at/above the severity threshold
  are found — a non-zero exit with a written report is a *successful scan
  with findings*, not a failed command. Read the report either way.

## In Neovim

Matt's Diver config wires the analyzer as a linter
(`lua/linters/_salesforce-code-analyzer.lua`, see the `apex-dev` skill), so
findings appear as diagnostics while editing Apex. Use the editor loop for
fix-as-you-type work; use the CLI for full-project scans, CI-style gates,
and reports. If the two disagree, trust the CLI run — then check plugin
versions on both sides before assuming a rule changed.

## Triage

1. **Severity first.** Sev1/Sev2 (security, correctness — SOQL injection,
   CRUD/FLS violations, hardcoded credentials, unsafe sharing) are
   must-fix. Style and documentation rules are fix-if-cheap or accept
   with a note.
2. **DFA findings deserve a second look.** The PMD graph engine traces
   data flow across methods, so its findings (e.g. injection paths) are
   fewer but more real. Never bulk-dismiss DFA output.
3. **Flow findings** (from lightning-flow-scanner): unused variables,
   hardcoded IDs, DML in loops, missing fault paths. Flows fail
   challenges and audits on these; treat flow Sev2 like Apex Sev2.
4. **False positives:** suppress narrowly (single rule, single location,
   with the analyzer's annotation/config mechanism) and say why in the
   commit or status note. Never disable an engine to make a scan pass.

## The fix-verify loop

1. Scan → report file.
2. Fix one rule class at a time (all `AvoidSoqlInLoops`, then all CRUD
   checks), committing nothing between classes unless asked.
3. Re-run the same scan command; diff violation counts per rule.
4. Run the Apex tests (`sf apex run test`, see `sf-org-workflows`) after
   any behavior-adjacent fix — analyzer-driven refactors (bulkification,
   sharing changes) can change semantics.
5. Stop when: zero Sev1/Sev2, and every remaining finding is either fixed
   or explicitly accepted with a reason in the report.

## Edge cases

- **"code-analyzer is not a sf command":** the plugin is missing or the
  shell resolved a different `sf`. Check `sf plugins` for
  `code-analyzer 5.x`; install only the official plugin
  (`sf plugins install @salesforce/plugin-code-analyzer`) and re-verify
  with `sf code-analyzer run --help`.
- **Scan is slow on first run:** engine warm-up (PMD/JVM) is normal; DFA
  rules are the expensive part. Narrow `-t` while iterating, full `-w`
  for the final gate.
- **Legacy codebases:** a first scan on old code can return hundreds of
  findings. Report the count by severity honestly; propose a ratchet
  (fix Sev1/2 now, baseline the rest) instead of silently mass-editing.
- **Never scan or "fix" map-dev.** Production code changes go through
  TDS's own process, not this loop.
