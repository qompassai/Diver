# Changelog — `test`-branch fix program

Fixes applied on the `test` branch against the findings of the second Diver
audit (2026-09-25, `~/workspace/diver-audit-v2/DIVER-AUDIT.md`: 7 CRITICAL
bugs C1–C7 proven at runtime, 12 HIGH findings). Every entry below was
verified present in the working tree before being documented; claims that
could not be verified are listed under "Not verified / open" instead.

Conventions: `file:line` is the working-tree location of the change;
"source" is the documented, valid authority grounding it (Neovim `:h`
topics, upstream docs — never invented). Effects marked "measured during
the fix program" come from the program's own runs, not re-verified here.

## Formatter program (2026-09-25): 105 new native formatter adapters

Second program on this branch, at Matt's request: add native formatter
configs for every formatter the config did not already cover, wire
`init.lua`/`catalog.lua` so the whole config stays functional, bring the
ELI5 docs up to date, and audit the full `lua/formatters/` tree
(138 files). Worked half-validating / half-adversarial until the gates
below were green.

### New adapters (105)

105 new `lua/formatters/<name>.lua` adapters, one per tool: aiken_fmt,
air, autopep8, bean_format, bibtex_tidy, biome, black, blackd, brittany,
buf_format, buildifier, cabal_fmt, cl_format, cljfmt, cmake_format,
cookstyle, csharpier, cue_fmt, deno_fmt, dfmt, dhall_format, djlint,
docstrfmt, dprint, efmt, elm_format, erb_formatter, erlfmt, fantomas,
findent, fnlfmt, forge_fmt, fourmolu, fprettify, gdformat, gofmt,
grain_format, hclfmt, hledger_fmt, htmlbeautify, janet_format, jq,
julia_formatter, just_fmt, kcl_fmt, ktlint, kulala_fmt, latexindent,
mago_format, mbake, mdformat, mh_style, mix_format, muon_fmt, nginxfmt,
nickel_format, nomad_fmt, nufmt, ocamlformat, opa_fmt, ormolu, packer_fmt,
panache, perltidy, phpcbf, powershell_formatter, prettier, prettierd,
puppet_lint_fix, purs_tidy, qmlformat, raco_fmt, refmt, robotidy, rubocop,
rubyfmt, ruff_format, rumdl_fmt, rustfmt, schemat, shellharden, snakefmt,
sqlfluff, sqruff, standardrb, styler, stylua, superhtml, swift_format,
swiftformat, taplo, templ_fmt, terraform_fmt, tofu_fmt, tombi,
twig_cs_fixer, typstfmt, typstyle, verible_verilog_format, vsg, xmlformat,
xmllint, yamlfmt, yapf, zprint.

Every adapter carries an ELI5 `---` header (what the tool does, what each
flag means, in plain language) and a `---@source` upstream URL; all tool
flags are explicit (no silent reliance on upstream defaults); all
subprocess input goes through argv form (`vim.system`), never shell
interpolation.
- **Source:** per-adapter `---@source` URLs (upstream project pages);
  `:h vim.system()` for the argv-form contract.

### Wiring (`init.lua`)

- `module_sources` + `formatters_by_ft` entries for the new adapters.
- `zigfmt` → `zig_fmt`: the old entry referenced `formatters.zigfmt`,
  which has no module file; the adapter on disk is `zig_fmt.lua`.
- `crystal_format` / `nimpretty` wired for the `crystal` / `nim`
  filetypes.
- 8 stale inline `M.register` specs removed (alejandra, gofumpt,
  goimports, htmlbeautify, blackd, and 3 more); only `css-beautify` and
  `sql-formatter` remain inline — no module files exist for them.
- Strict-LuaLS fix: the `formatters_by_ft` fallback-chain loops now bind
  the chain to a `---@type string[]` local, clearing the one
  `param-type-mismatch` under the `lsp/lua_ls.lua` strict profile
  (`checkTableShape=true`, `weakNilCheck=false`, `weakUnionCheck=false`).
- Normalized to the repo's own `.stylua.toml` (4-space indent).

### Tool catalog (`catalog.lua`, +738 lines)

- New installer recipes: cargo (`efmt`, `hledger_fmt`, `nickel_format`,
  `panache`, `rumdl_fmt`, `schemat`, `sqruff`, `taplo`, `tex_fmt`,
  `tombi`, `typstfmt`, `typstyle`), Go tools (`buildifier`, `cue_fmt`,
  `hclfmt`, `jsonnetfmt`, `templ_fmt`, `yamlfmt`), npm, plus new
  `pip` / `gem` / `composer` / `dotnet` installer helpers.
- New catalog search paths: `dotnet-tools`, `gems/bin`,
  `node_modules/.bin`, `python/bin`.
- All 131 catalog entries carry a source URL (release API or project
  page).
- `zigfmt` catalog key renamed to `zig_fmt`; bespoke entries added for
  `crystal_format` (Crystal ships `crystal tool format`) and `nimpretty`
  (ships with choosenim).
- Fixed an over-120-column `instructions` string (`janet_format`).

### Old-adapter audit (12 files)

ELI5 headers added to 11 adapters (bibtex-tidy, clang_format, gersemi,
gofumpt, goimports, jsonnetfmt, ktfmt, phpcsfixer, pint, scalafmt,
shfmt); all flags verified explicit; argv-form confirmed everywhere.
pint's profile is documented as project-config-driven — no `--preset`
forced, since that could override project configs (precedence not
verifiable here; left as documented behavior, not changed).

### Source-URL audit

- 133/138 files had a valid `---@source`; fixed 7: `d2.lua`
  (malformed annotation), `fourmolu.lua` (0-star fork → canonical
  `fourmolu/fourmolu`), `rubyfmt.lua` (fork → `fables-tales/rubyfmt`),
  `cmake_format.lua` (null-ls fork snapshot → `cheshirekow/cmake_format`),
  `uncrustify.lua` (removed stray Neovim-docs URL),
  `puppet_lint_fix.lua` (plain-http pinned docs → `puppetlabs/puppet-lint`),
  `bean_format.lua` (null-ls fork → `beancount/beancount`; verified the
  tool ships with Beancount itself).
- Framework files (`init.lua`, `catalog.lua`, `process.lua`, `tools.lua`)
  carry `---@source https://github.com/qompassai/diver`.
- 17-URL spot check: 0 dead links. Several adapters intentionally cite
  upstream issues/PRs that document the exact stdin behavior the adapter
  relies on (e.g. `forge_fmt` → foundry PR 1336, `mix_format` →
  elixir-lang issue 7411).

### Gates (measured 2026-09-25, `lua/formatters/`, 138 files)

- luacheck 1.2.0 (repo `.luacheckrc`): 0 warnings / 0 errors.
- stylua 2.5.2 `--check` (repo `.stylua.toml`): clean.
- lua-language-server 3.19.1 `--check`: 0 problems under the repo
  `.luarc.json`; 0 problems under the strict `lsp/lua_ls.lua` profile.
- Headless require sweep: 138/138 modules load, 0 failures.
- Headless startup smoke: exit 0 ×3, ~291 ms to `NVIM STARTED`
  (audit baseline was 1682–5194 ms).
- Adversarial: 105/105 new adapters clean — 0 critical, 0 high, 0 low.
  320+ hostile args-builder calls (quotes, `$()`, backticks, newlines,
  unicode, 4000-char paths) all returned clean argv lists; a fake-PATH
  binary confirmed payloads arrive as single argv elements and never
  execute; missing binaries fail in ~0 ms with `Formatter unavailable`;
  13 tempfile-mode adapters leak nothing on success or failure.

### Open / not done (pre-existing, needs Matt's decision)

- 4 `module_sources` names have no module file (`awkfmt`,
  `nixpkgs_fmt`, `ptop`, `scarb_fmt`) — pre-existing; the runner
  degrades gracefully (`M.validate()` clean).
- `dioxus` catalog entry has no filetype wiring — pre-existing gap.
- pint `--preset` vs project-config precedence not verified here
  (pint not installed).

## Linter program (2026-09-25): 21 new adapters, 92 orphans registered

Third program on this branch, at Matt's request: the counterpart to the
formatter program — complete the linter coverage in `lua/linters/`,
verify the previously-dead `:Lint*` commands and the C6 modules, audit
every adapter (source URL, explicit settings, tiger style), and wire
everything so the whole config stays functional. Worked
half-writing / half-adversarial until the gates were green.

### New adapters (21)

One file per tool in `lua/linters/`, each with an ELI5 `---` header,
`---@source` upstream URL, explicit flags, argv-only execution, and
bounded parsers:

- `cspell` — https://github.com/streetsidesoftware/cspell
- `deno` — https://docs.deno.com/runtime/reference/cli/lint/
- `eslint` — https://eslint.org/docs/latest/use/command-line-interface
- `fish` — https://github.com/fish-shell/fish-shell
- `flake8` — https://flake8.pycqa.org/
- `json_tool` — https://docs.python.org/3/library/json.html
- `markdownlint-cli2` — https://github.com/DavidAnson/markdownlint-cli2
- `mypy` — https://mypy.readthedocs.io/
- `php` — https://www.php.net/manual/en/features.commandline.php
- `pycodestyle` — https://pycodestyle.pycqa.org/
- `pylint` — https://pylint.readthedocs.io/
- `quick-lint-js` — https://quick-lint-js.com/
- `ruby` — https://www.ruby-lang.org/
- `ruff` — https://github.com/astral-sh/ruff
- `selene` — https://github.com/Kampfkarren/selene
- `sqruff` — https://github.com/quarylabs/sqruff
- `tombi` — https://github.com/tombi-toml/tombi
- `vale` — https://vale.sh/
- `write_good` — https://github.com/btford/write-good
- `zizmor` — https://github.com/woodruffw/zizmor
- `zsh` — https://www.zsh.org/

### Wiring (`lua/linters/init.lua`)

- `M.module_sources`: 85 → 177 entries, re-sorted (key = filename with
  `-` → `_`).
- `M.linters_by_ft`: 25 existing filetype tables extended + 34 new
  filetype keys; every name verified resolving to a `module_sources`
  key, no duplicates per filetype.
- `M.validate()` is now orphan-aware: it scans `lua/linters/` and
  reports any on-disk adapter missing from `module_sources`, unless
  listed in the new `M.unregistered_adapters` table.
- `secretlint` added to `M.manual_linters` (opt-in; a node-based
  secrets scanner should not auto-run).
- Removed obsolete self-`register()` calls from `phpcs`,
  `phpinsights`, `phpmd` (they caused require loops once the modules
  were registered; `module_sources` covers them now).
- `validate()` now accepts `function` cmd (the `Linter` type's
  `LintCmd` alias and the runner both support it).

### C4 / C6 re-verification (headless-proven)

- C4: all 6 `:Lint*` commands (`Lint`, `LintDisable`, `LintEnable`,
  `LintInfo`, `LintReset`, `LintValidate`) exist after setup, which is
  genuinely invoked from the root `init.lua` — PASS.
- C6: `hledger` and `lightning-flow-scanner` require cleanly but their
  hard dependencies (`utils.hledger`,
  `linters._salesforce-code-analyzer`) do not exist in the repo, so
  they can only ever return `{unavailable=...}` sentinels. They are
  **quarantined** in `M.unregistered_adapters` with documented
  reasons, not registered as if they worked — needs Matt's call:
  implement the helpers, or delete the files. (`latex` also
  quarantined: it is a disabled SCIP indexer, not a linter.)

### Audit findings fixed

- 113 orphan adapters found (on disk, require-clean, unreachable
  through the runner); 92 registered, 3 quarantined with reasons,
  the rest were the 18 already-registered new ones.
- 32 LuaLS strict warnings in the new adapters → 0 (narrowing
  `---@cast` after range checks, `---@return vim.Diagnostic.Set?`
  annotations, 2 nil-narrowing restructures in `fish.lua`/`vale.lua`).
- `deadnix.lua`: removed `goto`/`::continue::` (stylua hard parse
  error vs the repo's `syntax="All"`), tabs → 4 spaces.
- `clj-kondo.lua`: parser threw on empty output (the normal clean
  case) → returns `{}` like the other parsers.
- `tombi.lua`: `LOCATION_PATTERN` required a space after the filename
  colon but live output is `at bad.toml:2:1` — could never match;
  fixed and verified against observed output.
- `code_analyzer` quarantined: it is a factory (`M.new(options)`),
  not a `Linter`; nothing instantiates it.
- 20/20 `---@source` URLs spot-checked against upstream: all
  canonical, 0 dead, 0 forks.

### Adversarial results

- 52 parsers × 11 hostile inputs (empty, noise, malformed JSON/XML,
  NUL bytes, 200 KB single line, 1 MiB blob, unicode): 0 unhandled
  errors; 7 adapters that deliberately `error()` are converted by the
  runner's `pcall` into ERROR notifications — graceful, no crash.
- Shell-injection probe (hostile filename with quotes, `$()`,
  backticks, newline): arrived as exactly one argv element; no marker
  files created — filenames never enter a shell string.
- Missing binaries fail cleanly (`status='unavailable'`); 1 MiB+
  files rejected before spawning; 2 MiB / 40 000-line output parsed
  in 472 ms.

### Gates (self-measured 2026-09-25, `lua/linters/`, 183 files)

- luacheck 1.2.0 (repo `.luacheckrc`): **0 warnings / 0 errors**
- stylua 2.5.2 `--check` (repo `.stylua.toml`): **clean**
- lua-language-server 3.19.1 `--check` (strict profile mirroring
  `lsp/lua_ls.lua`): **0 diagnostics**
- Headless require sweep: **183/183**; `setup()` ok;
  `M.validate()` **0 problems**; 6/6 `:Lint*` commands present
- Headless startup smoke: exit 0

### ELI5 docs

- Every new adapter carries an ELI5 `---` header.
- `lua/linters/README.md`: new "New Linter Adapters (21)" section
  (table: tool → plain-language "what it checks" → filetypes).

### Open / not done (needs Matt's decision)

- `hledger` / `lightning-flow-scanner`: implement the missing helper
  modules, or delete the adapter files.
- Cold-start `init.lua` trips on `render-markdown.nvim` bootstrap
  (`env.lua:20: attempt to index field 'spec'`) during `vim.pack`
  install — pre-existing, exit still 0, linters unaffected.

## Critical fixes (C1–C7)

### C1 — `require('types')` no longer neuters `vim.api.nvim_create_autocmd`
- **What:** `init.lua` — the runtime `require('types')` (line 198 in the base
  revision) is removed. The `lua/types/*.lua` LuaCATS stub files still exist
  for the type checker but are never executed at startup.
- **Why:** `lua/types/nvim.lua:99` defines `vim.api.nvim_create_autocmd` as
  an empty function. Requiring the file at runtime silently replaced the real
  API for the whole session: every later autocmd registration returned nil
  and registered nothing, with no error. The companion stub at line 47 also
  clobbered the real `_G.gh` pack-spec helper.
- **Source:** `:h nvim_create_autocmd()` (the API contract that was being
  shadowed); lua-language-server indexes workspace files without a runtime
  `require` (workspace/library settings in the lua-language-server docs), so
  nothing needed the require at runtime.

### C2 — Python ftplugin no longer wipes Python autocmds
- **What:** `after/ftplugin/python.lua:8,11` — the file now uses a private
  augroup name `DiverPythonFt` and a `local M` table.
- **Why:** The old code ran `nvim_create_augroup('Python', { clear = true })`
  on *every* Python `FileType` event, reusing the same group name that
  `lua/config/lang/python.lua` uses at startup for its 4 autocmds
  (bandit/vulture lint-on-save, ruff format-on-write, the `FileType` callback
  creating `:PythonLint`/`:PyTestFile`/`:PyTestFunc`, LspAttach). Group count
  went 4→0, so those commands never materialized. It was the only one of the
  8 ftplugins to reuse a startup group name with `clear=true`; the global
  `M` also tripped luacheck W111.
- **Source:** `:h nvim_create_augroup()` (`clear=true` semantics); luacheck
  W111 (setting a non-standard global).

### C3 — Shell injection closed at `:terminal` sinks (and related argv fixes)
- **What:**
  - `lua/config/lang/python.lua:59,63` — `PyTestFile` / `PyTestFunc` wrap
    the filename (and `<cword>`) in `fn.shellescape()`; pytest `path::test`
    syntax preserved.
  - `lua/config/lang/scala.lua:223` — `ScalaRun` wraps the filename in
    `fn.shellescape()`.
  - `lua/utils/docs/mail.lua:347,375` — pandoc and `file --mime-type` calls
    converted to argv-form `vim.system({...})`, which bypasses the shell.
  - `lua/config/lang/go.lua:18-43` — gvm invocations now go through a real
    memoized `run_cached_gvm(argv)` using argv-form `vim.system` (the old
    code interpolated strings and called the nested function "cached" while
    re-spawning bash+gvm on every call); the nested `_G`-leaking function
    is gone.
- **Why:** `:terminal` with a string command goes through the shell, and
  unquoted filename concatenation was proven exploitable at runtime (a
  filename containing `$(touch …)` created the marker file). Latent only
  because of C2; fixing C2 without this would have made it live. The mail
  and go sites are the same bug class (user-controlled paths interpolated
  into shell commands).
- **Source:** `:h terminal` (string commands are executed by the shell);
  `:h shellescape()`; `:h vim.system()` (list form bypasses the shell).
- **Effect:** injection sinks eliminated; gvm lookups memoized (one
  subprocess per distinct argv instead of per call).

### C4 — Dead command families wired up
- **What:** `init.lua:211-219` — after the plain `require()`s, a guarded loop
  calls `setup()` on `formatters`, `linters`, and `config.data` when the
  module exposes one.
- **Why:** These modules create their user commands only inside `setup()`;
  `require()` alone left `:Format`/`:FormatLsp`/… (`lua/formatters/init.lua`),
  `:Lint`/`:LintDisable`/… (`lua/linters/init.lua:1212`), and
  `:SqliteAttach`/`:SqliteDetach`/… (`lua/config/data/init.lua:639`) dead
  (`exists(':Format') == 0`). The init.lua comment records the verification.
- **Source:** `:h nvim_create_user_command()` (commands exist only where
  created); the modules' own `setup()` contracts.

### C6 — Linter adapters fail closed instead of crashing on missing modules
- **What:**
  - `lua/linters/hledger.lua:4` and
    `lua/linters/lightning-flow-scanner.lua:18` — `require` of the absent
    `utils.hledger` / `linters._salesforce-code-analyzer` modules is now
    `pcall`-guarded and returns an `unavailable: …` reason instead of an
    unconditional load failure.
  - `lua/plugin/cloud/init.lua` deleted — it was dead code shadowed by
    `lua/plugin/cloud.lua` (`?.lua` beats `?/init.lua`) and required a
    nonexistent `plugins.cloud.*` namespace.
- **Why:** These were the only genuine repo bugs in the 528-module require
  sweep (520 OK); the adapters crashed at load time.
- **Source:** Lua 5.1 reference manual §5.1 (`pcall`); Neovim's
  `runtimepath` lookup order (`?.lua` before `?/init.lua`).

### C7 — `image.nvim` removed from the plugin spec
- **What:** `lua/plugin/ui/md.lua:19-27` — the `3rd/image.nvim` spec is
  removed (with an explanatory NOTE), and `3rd/diagram.nvim` goes with it
  since it requires the `image` module. Image rendering stays native via
  `lua/config/ui/image.lua` (`vim.ui.img`).
- **Why:** The rockspec build failed (missing luarocks hererocks lua), the
  failure was swallowed, and lazy.nvim retried the install every startup —
  ~11KB of `[image.nvim] checkout|build` task spam per launch. Measured
  cost: `require('config.lazy')` was 1207 ms of 1682 ms startup (72%; a
  second profile measured 2905 ms of 5194 ms).
- **Source:** lazy.nvim docs (the `build` step and missing-plugin retry
  behavior); the audit's `--startuptime` profiles.
- **Effect:** startup ~410 ms vs the 1682–5194 ms baseline (measured during
  the fix program).

## New: `lua/security/` toolkit
- **What:** new modules `lua/security/init.lua`, `rce.lua`, `mitm.lua`,
  `zombie.lua`, `supplychain.lua`; `init.lua:200` runs
  `require('security').setup()` (idempotent), registering the
  `:SecurityAudit` command and the `diver_security` augroup after
  plugin-manager setup and before user keymaps/commands.
- **Why:** Matt's standing requirement for the config: tooling that
  identifies and stops remote code execution, man-in-the-middle attacks,
  zombie processes, and supply-chain poisoning.
- **Source:** the audit's B3 shell-interpolation / subprocess findings as
  the concrete threat classes; `:h nvim_create_augroup()` for the
  lifecycle group.
- Each module carries a plain-language ("ELI5") LuaCATS doc header (see
  Docs below).

## Startup performance
- **What:** `init.lua:39-44` — the startup `fn.system('id -u')` call now
  prefers `vim.uv.os_get_passwd()`, keeping the old form only as a fallback.
- **Why:** fork+exec at startup is ~880× slower than the libuv call.
- **Source:** `:h vim.uv` (libuv bindings, `os_get_passwd`).
- **Effect:** ~11.2 ms/call → ~0.013 ms/call (isolated microbenchmark from
  the audit).

## Plugin lockfile desync resolved
- **What:** `nvim-pack-lock.json` regenerated to vim.pack's expected format
  (stale `version` metadata dropped); pinned revs (e.g. `coq.nvim`,
  `mini.ai`) now match what vim.pack records.
- **Why:** the tracked lockfile pinned revs that disagreed with the
  installed checkouts, producing checkhealth ERRORs.
- **Source:** `:h vim.pack` (lockfile semantics).

## Correctness cleanups
- **Duplicate assignments fixed** — `lua/utils/docs/license.lua:27`
  (`auto = true`, was `false` then `true`), `:170` (`rst = '//'`, was
  `'..'` then `'//'`); `lua/config/ui/colors.lua:149`
  (`@punctuation.bracket`, single definition) and `:300` (`Pmenu`, single
  definition). Later-wins was accidental; the surviving value is now the
  only one.
- **Stale annotation fixed** — `lua/acp/rpc.lua:15`:
  `---@field proc vim.SystemObj?` (was `uv.uv_process_t?`, but `M.start`
  assigns the result of `vim.system()`).
- **DAP require-time side effect removed** — `lua/dap/init.lua`: no bare
  top-level `M.setup()` anymore (the old line-2000 call ran on every
  `require('dap')` at `init.lua:202` and leaked a DEBUG notify to stderr
  each startup). Setup is now lazy via `ensure_setup()` (`:946`), which
  installs command wrappers that call the idempotent `M.setup()` on first
  use.
- **Bash ftplugin buffer-local** — `after/ftplugin/bash.lua:9-11`:
  `BufWritePre` now registers with `buffer = 0`, killing the N-duplicate
  format-on-write pileup (one autocmd per buffer opened).
- **`red.lua` recursion → explicit stack** — `lua/utils/red/red.lua:13-40`:
  `iter_files` walks with an explicit stack plus a `seen` set guarding
  symlink cycles, replacing recursion over attacker-controlled directory
  depth (which also silently dropped all-but-first match per subdirectory).
- **Source:** `:h nvim_create_autocmd()` (`buffer` key); Tiger Style
  (bounded work, no recursion); `:h vim.system()` for the `SystemObj` type.

## Formatter config schism resolved
- **What:** `lsp/stylua_ls.lua:41-44` now uses 4 spaces /
  `AutoPreferSingle`, matching `.stylua.toml:6-9`. The working tree was
  reformatted to that single convention (561 files changed, mostly the
  2-space files under `lua/`).
- **Why:** CLI `.stylua.toml` (4 spaces) vs in-editor `lsp/stylua_ls.lua`
  (tabs, `ForceSingle`) disagreed, and 549/923 files failed
  `stylua --check` — neither profile matched the bulk of the repo.
- **Source:** stylua's documented config keys (`indent_type`,
  `indent_width`, `quote_style`); repo convention (4-space indent per
  AGENTS.md).
- **Mislabeled tree-sitter queries deleted** — `queries/lua/` now contains
  only `.scm` files (`refactor_comment.scm`, `refactor_debug_path.scm`,
  …); the byte-identical `.lua` twins are gone. They broke luacheck (E011)
  and stylua alike.
- **Source:** nvim-treesitter query files use the `.scm` extension.

## Keymaps
- **`<Leader>h…` conflict resolved and documented** —
  `lua/mappings/ddxmap.lua:190-194`: the old `<leader>hl/hs/hy` config
  self-check maps are removed (they could never install: `cicdmap` owns
  bare `<M-h>` as the terminal toggle, a strict prefix, and
  `mappings/_core.lua:142` `conflict()` rejects prefix collisions). The
  config-health verbs now live on lintmap: `<Leader>xc` (`:ConfigTigerCheck`),
  `<Leader>xo` (`:ConfigTigerCheckLog`), `<Leader>xw`
  (`:DiagnosticsWorkspace`) — see `lua/mappings/lintmap.lua:162-174`.
- **Note:** `conflict()` itself is unchanged (see "Not verified / open").

## Docs
- **ELI5 LuaCATS headers** — `lua/security/{init,rce,mitm,zombie,supplychain}.lua`
  each open with a plain-language header explaining what the module does
  ("seatbelts and smoke detectors"), part of Matt's requirement for
  LDoc-renderable docs that explain the config like he's five.

## Follow-up fixes (found by adversarial re-testing after the audit)
- **`_G.gh` was nil at startup** — `lua/plugin/init.lua` now requires
  `plugin.cloud` before `plugin.nav`. The `vim.pack` migration dropped the
  `plugin.cloud` require, so the `_G.gh` pack-spec helper never got defined.
  Verified: `_G.gh` is a function and builds a GitHub pack spec.
- **`run_linter` split** — `lua/linters/init.lua` went from ~294 lines to 72
  via `prepare_linter_run` (spec resolution, command build) and
  `on_linter_result` (diagnostic publishing). Success, unavailable-linter,
  and cancellation paths smoke-tested.
- **Unavailable linters fail silently, not loudly** — `hledger` and
  `lightning-flow-scanner` return typed unavailable sentinels instead of
  raising; `get_linter_spec` recognizes the sentinel and skips the adapter
  without an ERROR notification. (Root cause: `require` coerces a nil first
  return to `true`, so the "reason" string was being lost.)
- **MITM: failed downloads no longer leave stale files** —
  `lua/security/mitm.lua`: a failed `curl` now deletes the destination file
  instead of leaving the previous (possibly attacker-planted) copy in place;
  curl exit codes are checked; URL scheme matching is case-insensitive; plain
  HTTP is refused.
- **LuaLS strict is at zero actionable** — all targeted categories
  (`param-type-mismatch`, `undefined-field`, `cast-local-type`,
  `need-check-nil`) are 0 across 925 files. Along the way:
  - `lua/utils/games/shared/async_util.lua`: new `pawait_task()` typed
    wrapper (`---@generic R`, `Task<R>` → `boolean, R?`). Calling
    `vim.async.pawait()` directly on a `Task<SystemCompleted>` leaves the
    overload's `R...` pack unbound in LuaLS 3.19.1 (see the `@overload`
    annotations in the 0.13 runtime's `lua/vim/async/_core.lua`); the
    single-generic wrapper binds it. `unity/actions.lua` and
    `unreal/actions.lua` use it now.
  - Six `await-in-sync` sites documented as intentional dual-mode
    (`dap.lua` x2, `dap/session.lua` x2, `dap/ui.lua`, `utils/media/rpc.lua`):
    each yields only inside a coroutine context, so `---@async` would falsely
    taint sync callers.
  - `lua/linters/fsharplint.lua`: the `position()` guard now leads with an
    explicit `row == nil` check so the checker can narrow `number?` → `number`
    (`integer()` alone can't narrow; runtime behavior unchanged).
  - `lua/linters/npm_groovy_lint.lua`: `setup`/`transform_buffer` are
    forward-declared in the table literal with their final types — they're
    defined via `function M.x` 600+ lines later, which the checker's
    missing-fields pass can't see.
  - `lua/plugin/ui/icons.lua`: two unused `opts` args renamed to `_opts`.
- **Source:** `:h vim.async.pawait()` / runtime `lua/vim/async/_core.lua`
  overload annotations; LuaLS EmmyLua annotations (`---@generic`,
  `---@cast`); `:h coroutine.yield()` for the dual-mode pattern.

## Not verified / open (needs Matt's decision)
- **C5 — `<M-h>` vs `<Leader>h` family:** `conflict()` is unchanged, so the
  `<Leader>h…` maps still cannot install while `cicdmap` owns `<M-h>`.
  Matt must either accept `<M-h>` as terminal-only or move the terminal
  toggle. The audit's K1 proposed replacements were partially adopted as
  `<Leader>xc/xo/xw` above.
- **`dbx.lua` plaintext credentials:** `dbx.lua:13,20,52,56` still contain
  `user:password@…` connection strings. Left untouched — needs Matt's call
  on how to handle them.
- **`run_linter` split:** claimed by the fix program, but the tree shows
  `M.run_linter` (`lua/linters/init.lua:713-1001`, ~289 lines) at
  essentially the same size as the base revision (285 lines), with the same
  23 module-level helpers as before; the diff in that region is a pure
  2-space→4-space reindent. No structural split is verifiable, so no
  entry is claimed for it above.
- **Startup ~410 ms** is the fix program's measured figure; not re-run in
  this verification pass.
