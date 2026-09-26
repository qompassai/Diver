# skills/

Agent skills for this repository, in the standard `SKILL.md` format.

## Layering: guide first, specifics underneath

For each language, the Tiger Style guide is the base layer and is always
applied first. Language-specific skills nest underneath their language's
guide:

```text
skills/<lang>/tiger-style-<lang>/
  SKILL.md              # base guide: ALWAYS applied first for <lang> work
  references/           # optional: guide supporting docs
  <specific-skill>/
    SKILL.md            # specific skill: applied after the base guide
    references/         # optional
```

Example:

```text
skills/lua/tiger-style-lua/
  SKILL.md
  love2d-basics/SKILL.md
  love2d-graphics/SKILL.md
  love2d-audio/SKILL.md
  love2d-input/SKILL.md
  love2d-physics/SKILL.md
  love2d-platforms/SKILL.md
  love2d-distribute/SKILL.md
  love2d-scaffold/
    SKILL.md
    scripts/new-game.lua
```

## Composition rule

Every language-specific skill MUST open with a prerequisite line naming
its parent guide, so the guide applies even when the skill is discovered
standalone:

```markdown
> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.
```

## Naming

The directory name must match the frontmatter `name` at every level.
`skills/lua/tiger-style-lua/` holds `name: tiger-style-lua`.

## Language homes

```text
skills/
  c/tiger-style-c/
  cpp/tiger-style-cpp/
  go/tiger-style-go/
  lua/tiger-style-lua/        # populated
  nix/tiger-style-nix/
  python/tiger-style-python/
  scala/tiger-style-scala/
  typescript/tiger-style-typescript/
  zig/tiger-style-zig/
```

Directories without a `SKILL.md` yet are placeholders (`.gitkeep` only).
Skill sources live in the agent workspace at
`~/workspace/skills/tiger-style-<lang>/`.

## Not a skill

The repository playbook `SKILLS.md` at the repo root is referenced by
`AGENTS.md`/`CLAUDE.md` and is not an installable agent skill. Do not
move it under `skills/`.
