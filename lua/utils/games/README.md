-- #################################################################
-- /qompassai/Diver/lua/utils/games/README.md
-- Qompass AI Games Native Tooling
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
# `utils.games` -- native game-engine tooling

Native, plugin-free Neovim tooling for Aseprite, Godot, Redot, Unity,
and Unreal, following the same shape as `utils.dev.android` and
`utils.dev.sf`: each engine is driven straight through its own CLI
via `vim.system`/`vim.fn.jobstart`, with no third-party plugin
dependency.

## Layout

```
lua/utils/games/
  init.lua              -- wires every engine's setup() + a combined `:Games` menu
  shared/
    util.lua             -- executable/root discovery, action-id helpers
    output.lua            -- per-engine build/output window + progress spinner factory
    ui.lua                -- grouped vim.ui.select action menu
    godot_engine.lua       -- shared native-tooling factory for Godot-compatible engines
  aseprite/{config,util,actions,commands,init}.lua
  godot/init.lua           -- thin wrapper around shared/godot_engine.lua
  redot/init.lua           -- thin wrapper around shared/godot_engine.lua
  unity/{config,util,actions,commands,init}.lua
  unreal/{config,util,actions,commands,init}.lua
```

Every engine module exposes the same shape: `config`, `util`,
`actions` (with `get_actions()`, `run_action_by_id(id)`,
`show_menu()`), and `commands` (`setup_commands()`,
`setup_keymaps()`, `setup()`). Godot and Redot share one
implementation (`shared/godot_engine.lua`) parameterized per engine,
since Redot is a Godot 4-compatible fork and keeps `project.godot` /
`.tscn` / `.gd` file compatibility -- but each still gets its own
cached state, output window, and keymap group.

## Wiring it into `utils/init.lua`

Add one line next to the other `safe_require`d subsystems:

```lua
M.games = safe_require('utils.games')
if M.games and M.games.setup then
  M.games.setup()
end
```

## Commands

Each engine registers `:<Engine>` (opens its action menu),
`:<Engine>Action <id>` (run by id, tab-completes), and one
`:<Engine><PascalCaseId>` command per action. `:Games` opens a
combined menu across every loaded engine.

| Engine   | Menu command | Example per-action command |
|----------|---------------|-----------------------------|
| Aseprite | `:Aseprite`   | `:AsepriteExportSpriteSheet` |
| Godot    | `:Godot`      | `:GodotRunProject`           |
| Redot    | `:Redot`      | `:RedotExportRelease`        |
| Unity    | `:Unity`      | `:UnityBuildProject`         |
| Unreal   | `:Unreal`     | `:UnrealPackageProject`      |

## Keymaps

All keymaps live under the free `<leader>g` ("games") group, one
sub-letter per engine, then an action letter -- e.g. `<leader>gge`
opens the Godot editor, `<leader>gab` batch-exports an Aseprite
sprite sheet:

| Prefix        | Engine   |
|---------------|----------|
| `<leader>ga*` | Aseprite |
| `<leader>gg*` | Godot    |
| `<leader>gr*` | Redot    |
| `<leader>gu*` | Unity    |
| `<leader>ge*` | Unreal   |

## Binary / environment discovery

Every engine checks an explicit env var override first, then falls
back to `$PATH`:

| Engine   | Override env vars                                              | Fallback binaries                        |
|----------|-----------------------------------------------------------------|-------------------------------------------|
| Aseprite | `NVIM_ASEPRITE_BIN`, `ASEPRITE_BIN`                              | `aseprite`, `Aseprite`                     |
| Godot    | `NVIM_GODOT_BIN`, `GODOT_BIN`, `GODOT4_BIN`                      | `godot4`, `godot`, `Godot`, `Godot_v4`     |
| Redot    | `NVIM_REDOT_BIN`, `REDOT_BIN`, `REDOT4_BIN`                      | `redot4`, `redot`, `Redot`, `Redot_v4`     |
| Unity    | `NVIM_UNITY_EDITOR_BIN`, `UNITY_EDITOR_BIN`, `UNITY_BIN`         | Unity Hub install matching `ProjectVersion.txt`, else `unity-editor`/`Unity`/`unity` |
| Unreal   | `NVIM_UNREAL_ENGINE_ROOT`, `UNREAL_ENGINE_ROOT`, `UE_ENGINE_ROOT`, `UE_ROOT` (project: `NVIM_UNREAL_PROJECT`) | scans `~/UnrealEngine*`, `/opt/UnrealEngine`, `/opt/unreal-engine` |

The Unreal env var names intentionally match the ones already used by
`lua/dap/unreal.lua`, so a single `NVIM_UNREAL_ENGINE_ROOT` covers
both build/package tooling here and native (`lldb-dap`/GDB DAP)
source debugging there -- this module does not duplicate the debug
adapter. Godot already has LSP (`lsp/gdscript_ls.lua`,
`lsp/gdshader_ls.lua`) and linting (`linters/gdlint.lua`,
`linters/gdscript-linter.lua`) elsewhere in this config; `utils.games`
only adds the missing editor/run/export layer. Redot can reuse the
same GDScript LSP/linters since its scripting language is unchanged.

## Project root detection

| Engine   | Root marker(s)                              |
|----------|-----------------------------------------------|
| Aseprite | n/a -- operates on the current/prompted sprite file (`.aseprite`/`.ase`) |
| Godot    | `project.godot`                                |
| Redot    | `project.godot`                                |
| Unity    | `ProjectSettings/ProjectVersion.txt`           |
| Unreal   | `*.uproject` (searched upward)                 |

## TODO / extension points

- [ ] Aseprite: palette/theme sync command, tileset export preset.
- [ ] Godot/Redot: `--dry-run` scene diff before export; DAP wiring
      alongside the existing GDScript LSP.
- [ ] Unity: multi-target batch build (`-buildTarget` matrix), Package
      Manager `resolve`/`lock` actions.
- [ ] Unreal: cook-only action, `Setup.sh`/`GenerateProjectFiles`
      bootstrap for a freshly cloned engine checkout, editor plugin
      packaging (`RunUAT.sh BuildPlugin`).
- [ ] Shared: a `:GamesDoctor` command reporting every engine's
      resolved binary/root in one table (today, each engine's
      `describe_project`/`describe_environment` action covers this
      per-engine).
