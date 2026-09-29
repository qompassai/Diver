# agents/

Versioned configuration for the external agent CLIs Matt drives from this
environment. These are the *safe* subsets — config and standing instructions
only. Nothing secret, nothing generated, nothing bulky.

## Layout

- `opencode/` — `~/.config/opencode`: `opencode.json`, `tui.json`,
  `package.json`, and the `agents/*.md` worker briefs.
- `codex/` — `~/.codex`: `config.toml` (interactive defaults),
  `worker.config.toml` (Pax-dispatched worker profile), `AGENTS.md`
  (standing instructions).
- `claude-code/` — `~/.claude`: `settings.json` (interactive permissions),
  `worker-settings.json` and `orchestrator-settings.json` (Pax dispatch
  profiles), `CLAUDE.md` (project instructions).

## Deliberately excluded

- **Secrets.** `opencode.json` ships with its `apiKey` replaced by the
  `${OPENCODE_API_KEY}` placeholder — set it in the environment (or secret
  store) on the target machine. Never commit a real key here.
- **Auth/state.** `~/.codex/auth.json`, `~/.claude/.credentials.json`,
  `~/.claude.json`, all `*.sqlite*` files, `sessions/`, `cache/`, `logs/`,
  `backups/`, `shell_snapshots/`, `history.jsonl` — machine-local state,
  regenerated on first run.
- **Dependencies.** `node_modules/`, `package-lock.json`, `bun.lock` —
  reinstall on the target machine (`npm install` / `bun install` in
  `~/.config/opencode`).
- **Ephemera.** `*.bak-*` files.

## Restoring on a fresh machine

```sh
mkdir -p ~/.config/opencode ~/.codex ~/.claude
cp agents/opencode/* ~/.config/opencode/
cp agents/codex/* ~/.codex/
cp agents/claude-code/* ~/.claude/
export OPENCODE_API_KEY="..."   # or wire it into your secret store
(cd ~/.config/opencode && npm install)
```

Then re-authenticate each CLI once (`codex`, `claude` login flows); the
permission profiles above take effect immediately.
