---
name: diver-scip-indexer
description: "Register a new SCIP code-intelligence indexer in Matt's diver Neovim config — verifying the install method against primary sources (with the known gotchas: the sourcegraph-to-scip-code org move, npm-not-pip for scip-python, prebuilt binaries vs package managers), writing the ScipIndexer module in lua/dev/scip/indexers/, registering it in config and the README inventory, and proving it with ScipHealth plus a real index.scip on a fixture project. Reach for it when a language needs precise go-to-definition in diver, or when a provisional indexer (latex, lua, nix) gets a real upstream binary."
license: Apache-2.0
compatibility: Diver live tree (~/.config/nvim) or repo checkout; the indexer binary installable by a verified method; headless nvim for :ScipHealth / :ScipIndex; luac, luacheck, stylua (all on primo).
metadata:
  domain: code-intelligence
  area: lua/dev/scip
  registry: lua/dev/scip/config.lua
allowed-tools: Read Edit Bash
---

# Diver SCIP Indexer

## ELI5

SCIP gives diver whole-project intelligence: precise go-to-definition and
find-references from a prebuilt `index.scip`, even in files the LSP never
opened. Each language gets a tiny **indexer module** saying which binary to
run, with what args, for which filetypes, in which project roots. A config
registers them all in a sorted order, and `:ScipHealth` reports who's
healthy. Adding an indexer means verifying the real install method,
writing one module, registering it, and indexing a fixture project.

## Procedure

1. Read the repo's `AGENTS.md`, the relevant `SKILLS.md` section, and the
   tiger-style-lua skill. Study `lua/dev/scip/indexers/go.lua` (canonical
   simple example) and `php.lua` (dynamic command resolution).
2. **Verify the install method against primary sources** — this is the
   non-obvious recurring step. Known gotchas from the 2026-09-29
   verification of all 15 indexers: the sourcegraph → **scip-code** org
   move; Python installs via **npm** (`@sourcegraph/scip-python`), not pip;
   per-language choice of prebuilt binary vs package manager; project-local
   `vendor/bin/scip-php` preferred for PHP. Never invent an install
   command; record the source URL.
3. Write `lua/dev/scip/indexers/<lang>.lua` returning a `ScipIndexer`:
   `command` (string or function), `args` (table or function), `filetypes`
   (set), `markers` (root-marker list).
4. Register in `lua/dev/scip/config.lua`: add to `default_indexers()` and
   keep `indexer_order` sorted.
5. Add a row to the README inventory table (Binary / Filetypes / Status /
   Install / Upstream columns) plus an install note.
6. Add aliases to `LANGUAGE_ALIASES` in `lua/dev/scip/lang.lua` if the
   filetype isn't already covered.
7. Run the gates. Fix until all green.

## Gates

- `:ScipHealth` reports the indexer ok.
- `require('dev.scip.registry').get('<lang>')` shape-validates
  (`registry.register` validates command/args/filetypes/markers).
- `:ScipIndex` on a fixture project produces `index.scip` and `scip lint`
  passes (`lint_after_index`).
- `tests/lua/scip_wiring.lua` assertions updated and passing.
- `luac -p`, luacheck 0/0, stylua clean on new files.

## SCIP-gated rename pre-flight

After indexing, cross-file renames get safer: run
`dev.refactor.scip.preflight(bufnr)` (see `lua/dev/refactor/scip.lua`,
`core.lua`) before `vim.lsp.buf.rename`. It returns
`{language, indexer, index_fresh, lsp_files, warning}` — if `warning` is
non-nil (the SCIP index is fresh but the LSP saw fewer files), re-index via
`:ScipIndex` or broaden scope first. SCIP is advisory; the LSP stays
authoritative.

## Stop rules

- No indexer exists for a language (today: lua, nix have none upstream) —
  say so and stop; never fake one.
- Do not mark an indexer healthy until `:ScipHealth` says so on the real
  machine, not just in the file.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** optional. Install verification plus one module
  plus fixture indexing usually fits one session; delegate when the
  indexer needs coaxing.
