# Current Work — diver

Neovim config/distro (qompassai/diver). Matt's main interface.

## Active (2026-10-04)

- **Live-first workflow**: Make config changes in LIVE `~/.config/nvim`
  (back up to `~/.config/nvim.bak` first). Only after Matt validates live,
  mirror into Diver repo, commit, push. His "looks good, move it" is the
  per-change authorization.
- **Uncommitted inventory** (as of 2026-09-30): installer cascade, 3-pass
  audit, 10 agent skills (awaiting Matt's auth/decision).
- **Open** (Matt's call): bounty-pipeline expansion, ssh.lua command
  injection fix, DAP/SQL module forks, rose.nvim spawn flip, diver push.
- **Bevy/RON**: `:BevyLint` routes through pinned nightly
  (`nightly-2026-04-16`); `ron_ls` enabled; Mode A preserved
  (rust-analyzer diagnostics off, bacon-ls primary).

## Standing rules

- Push posture: per-push confirmation, byte-identical, no force,
  remote-verified. All authorizations consumed; ask per push.
- 138 tiger-style formatter adapters; gates: luacheck 0, stylua clean.
- NEVER push without Matt's explicit confirmation naming exact files.
- Destructive git: git-wip-guard protocol (snapshot, confirm, verify).
- Never reconstruct the 7 WIP files lost 2026-09-25 — only Matt's exact
  machine copies.
