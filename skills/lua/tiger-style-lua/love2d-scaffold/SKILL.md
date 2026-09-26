---
name: love2d-scaffold
description: Start a new LÖVE game interactively — a plain-language
  questionnaire (game name, genre, desktop/phone targets) plus a runnable
  Lua prompt script that generates conf.lua, main.lua, and README.md. Use
  when deciding what to make, scaffolding a new LÖVE project, or onboarding
  someone to LÖVE game development.
---

> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.

# LÖVE scaffold: what to make, step by step

Making a game starts with four plain-language decisions. Ask them in
order — in chat, or run the prompter script below which asks them for
you.

## The four questions

1. **What is it called?** — the game name. Becomes the window title,
   the save-folder name (`t.identity`), and the project folder.
2. **What kind of game?** — pick a starting shape:
   - *Empty*: just the game loop. For learning or unusual ideas.
   - *Side view*: a character that runs and jumps (platformer basics).
   - *Top down*: a character that moves around (twin-stick/shooter basics).
3. **Where will people play it?**
   - *Desktop* (Windows, Mac, Linux): keyboard, mouse, gamepad.
   - *Phone* (Android, iOS): touch screen. No hover, big touch targets,
     safe area matters (see `love2d-platforms`).
   - *Both*: the skeleton wires keyboard AND touch to the same actions
     (the semantic-action pattern from `love2d-input`).
4. **How will it ship?** — which desktop systems to package for, and for
   phones, landscape or portrait (orientation is set in the Android
   manifest / iOS Xcode project, not conf.lua).

If the player answers "I don't know" to any question, choose the default:
side view is the most instructive template, "both" platforms keeps
options open, landscape suits most action games.

## The prompter script

`scripts/new-game.lua` is a small interactive program. Run it with any
Lua (5.1+):

```text
lua scripts/new-game.lua
```

It asks the four questions in plain language, then creates a project
folder containing:

- **`conf.lua`** — window, version target (11.5), vsync, high-DPI, and
  commented-out module toggles.
- **`main.lua`** — a working skeleton for the chosen template:
  `love.load` / `love.update` / `love.draw`, Escape quits, keyboard and
  touch both wired to the same movement actions.
- **`README.md`** — how to run it (`love <folder>`), the controls, and
  packaging pointers tailored to the chosen targets (`.love` first,
  then per-platform notes referencing `love2d-distribute`).

It refuses to silently overwrite an existing project — it asks first.

## After scaffolding

1. `cd <folder> && love .` — play the skeleton.
2. Read the generated `main.lua` top to bottom; it is short on purpose.
3. Grow it with the other skills: `love2d-graphics` for drawing,
   `love2d-audio` for sound, `love2d-input` for richer controls,
   `love2d-physics` if you need real physics.
4. When it is a game, `love2d-distribute` ships it per platform.

## Design notes for the questionnaire

- One question at a time; every question has a sensible default.
- Never ask about things the player cannot know yet (shaders, timestep
  models) — those are skill content, not setup questions.
- Platform choice changes generated code (touch wiring) and the README
  (packaging section), never the genre templates.
- The script is plain Lua with no dependencies, so it runs on the same
  machines the game targets.
