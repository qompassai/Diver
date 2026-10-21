# 2026-10-17 night — Diver fix bundle (Owner's rulings, T9)

Four ruled items landed on main (commits d111c952, 10c07e35, 33af9808):

- **ai/context.lua**: `M.browse` guarded on `fzf_module.fzfpick`, a name
  `config.nav.fzf` never exported (the export is `fzf_pick`) — the fzf
  path was dead and every browse fell through to `vim.ui.select`. Guard
  and call site now use `fzf_pick`; headless probe with a stubbed picker
  proves the seam end to end.
- **linters/alex.lua**: bare `cmd = 'alex'` resolves to the Haskell
  lexer generator on any machine that has it (primo's /usr/bin/alex is
  Alex 3.5.4.2). `npx --no-install alex` does NOT save you — npm exec
  falls back to the PATH binary (verified). The adapter now resolves
  project `node_modules/.bin/alex` first, then the npm-global package's
  `cli.js` under the prefix owning `npm` (executable, env-node shebang),
  bare `alex` only as a last resort.
- **config/core/filetype.lua**: the `.*/pages/.*%.page -> html` pattern
  beat the `page = 'visualforce'` extension rule, so SFDX Visualforce
  pages never got visualforce_ls. Ruled Option 2: the pattern is now a
  function — `visualforce` when an ancestor holds `sfdx-project.json`,
  else `html`.
- **formatters/awkfmt.lua NOT authored**: no upstream `awkfmt` tool is
  verifiable (GitHub repo search 0, pkg.go.dev 0, no registry hits) —
  the catalog entry is an aspirational name from 2026-09-25. Inventing a
  CLI was refused; the runner degrades gracefully. Needs Owner's word on
  which tool (if any) the entry should bind — gawk's own pretty-printer
  (`gawk -o-` / `--pretty-print`) is the only real AWK formatter found.
