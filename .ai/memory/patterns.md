# Patterns — diver

## Validation

- Live shallow clone: `~/workspace/repos/diver` (refresh via
  `~/workspace/repos/refresh.sh` or `git -C <dir> pull --ff-only`).
- Primo is source of truth when checkout disagrees.
- Primo GitHub SSH is BROKEN (Matt must fix keypair); use API/HTTPS pushes.
- Skill: `diver-lsp-config` for regenerating `lsp/*_ls.lua` with code actions.
  Verify code-action kinds from upstream before hardcoding — never invent.

## LuaLS workspace root

LuaLS refuses `/home/phaedrus` as workspace root (safety). `cd` into the
project dir first so the server picks up the project root.

## Karpathy principles (adopted 2026-09-28)

1. Think before coding. 2. Simplicity first. 3. Surgical changes.
4. Goal-driven execution. Fused with Tiger Style for all work.

## Agent coordination

- Every brief carries a handover contract. Never inject into a running
  coordinator's file set. Disjoint file ownership.
- Worker context: primo `~/.local/share/pax-worker-preamble.md` +
  `~/.local/share/pax-skills/`.

## Repomap (codebase map for agents)

One-shot generation (no flake wiring in this repo):

```
nix run github:qompassai/nix?dir=repomap -- /path/to/repo --budget 15000 --out .repomap.txt
```

`.repomap.txt` is a derived artifact — gitignore it, never commit it.
For automatic regeneration on `nix develop`, wire the flake input per
github.com/qompassai/nix/tree/main/repomap/README.md.
