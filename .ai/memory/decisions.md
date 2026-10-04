# Architectural Decisions — diver

## Live-first workflow (2026-09-29)

**Decision**: Change the LIVE `~/.config/nvim` tree first; mirror to repo
only after Matt validates.

**Context**: Matt uses Neovim as his main interface. Breaking his live
config breaks his workflow.

**Consequence**: Backup before changes. "Looks good, move it" authorizes
that change's commit+push. Always show `git diff --cached --stat` first.

## Per-push confirmation (standing)

**Decision**: Every push to diver requires Matt's explicit confirmation.

**Context**: Diver is Matt's daily driver. Bad pushes break his editor.

**Consequence**: No standing push auth (unlike phlow/lumen/light-show).
Byte-identical verification, never force-push.

## Skill layering (2026-09-29)

**Decision**: `skills/<lang>/tiger-style-<lang>/SKILL.md` is the base guide,
applied first; specific skills nest underneath with prerequisite pointers.

**Consequence**: Directory names match skill frontmatter names. Root
SKILLS.md is the playbook, not a skill.

## Self-contained linter configs (2026-09-30)

**Decision**: Wire full cspell dictionary config into the cspell linter
itself — zero user-side setup friction.

## Diagnostic attribution (2026-09-30)

**Decision**: Virtual-text diagnostics name the producing tool via one
global setting, not per-linter config.
