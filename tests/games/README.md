# tests/games/

Game dev tooling: Love2D, Blender, Aseprite, characters.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `games/aseprite_ai_art.lua` — Headless test for games/aseprite AI-art import + prompt builder.
- `games/blender_e2e.lua` — E2E honesty gate for games/blender: procedural scene generation,
- `games/blender_render_export.lua` — Headless test for games/blender render/export/sprite arg building,
- `games/blender_versions.lua` — Headless test for games/blender version discovery and guards.
- `games/character_engines.lua` — Headless test for the per-engine character modules (TRACK D-ENGINES).
- `games/character_kit.lua` — Headless test for games/shared character kit.
- `games/love2d_adapters.lua` — Headless test for the six LÖVE2D engine adapters
- `games/love2d_core.lua` — Headless test for games.love2d core: versions, package, release, adapters.
- `games/love2d_libs_dev.lua` — Headless test for games.love2d libs + dev loop + config shape.

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
games/aseprite_ai_art.lua
  └──▶ lua/games/aseprite/import, lua/games/aseprite/prompts
games/blender_e2e.lua
  └──▶ lua/games/blender/batch, lua/games/blender/export, lua/games/blender/render, lua/games/blender/sprites (+1 more)
games/blender_render_export.lua
  └──▶ lua/games/blender/export, lua/games/blender/render, lua/games/blender/sprites
games/blender_versions.lua
  └──▶ lua/games/blender/versions
games/character_engines.lua
  └──▶ lua/data, lua/games/aseprite/character, lua/games/blender/character, lua/games/godot/character (+5 more)
games/character_kit.lua
  └──▶ lua/games/shared/character
games/love2d_adapters.lua
  └──▶ lua/games/blender/config, lua/games/love2d/adapters, lua/games/love2d/adapters/aseprite, lua/games/love2d/adapters/blender (+5 more)
games/love2d_core.lua
  └──▶ lua/games/love2d/adapters, lua/games/love2d/config, lua/games/love2d/package, lua/games/love2d/release (+1 more)
games/love2d_libs_dev.lua
  └──▶ lua/games/love2d/adapters, lua/games/love2d/config, lua/games/love2d/dev, lua/games/love2d/libs (+1 more)
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

(no commands or keymaps asserted in these tests)

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/games/aseprite_ai_art.lua
nvim --headless -u NONE -i NONE -l tests/games/blender_e2e.lua
nvim --headless -u NONE -i NONE -l tests/games/blender_render_export.lua
nvim --headless -u NONE -i NONE -l tests/games/blender_versions.lua
nvim --headless -u NONE -i NONE -l tests/games/character_engines.lua
nvim --headless -u NONE -i NONE -l tests/games/character_kit.lua
nvim --headless -u NONE -i NONE -l tests/games/love2d_adapters.lua
nvim --headless -u NONE -i NONE -l tests/games/love2d_core.lua
nvim --headless -u NONE -i NONE -l tests/games/love2d_libs_dev.lua
```

</details>
