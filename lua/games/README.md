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
| Shared   | `:GamesDoctor` | -- (runs `:checkhealth utils.games`, see below) |

`:GamesDoctor` reports every engine's resolved binary/root in one
table -- unlike each engine's own `describe_project`/`describe_environment`
action, which only covers that one engine, this probes all five
concurrently (see [Neovim 0.13 features leveraged](#neovim-013-features-leveraged)
below) and renders through `:checkhealth`, so the same report also
shows up automatically in `:checkhealth` sweeps.

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

- [x] Aseprite: palette/theme sync command, tileset export preset.
      (`export_palette`, `sync_palette_to_user_config`,
      `export_sheet_type_preset` in `aseprite/actions.lua`.)
- [x] Godot/Redot: `--dry-run` scene diff before export; DAP wiring
      alongside the existing GDScript LSP.
      (`export_dry_run` in `shared/godot_engine.lua`. DAP wiring is an
      honest partial: Godot/Redot have no general-purpose DAP server
      the way Unreal has `lldb-dap`/GDB in `lua/dap/unreal.lua` --
      there is nothing to wire a DAP client to. `remote_debug_launch`
      instead wires up Godot's actual remote-debug protocol,
      `--remote-debug tcp://host:port`, the closest real capability to
      attaching a debugger that this engine offers.)
- [x] Unity: multi-target batch build (`-buildTarget` matrix), Package
      Manager `resolve`/`lock` actions.
      (`build_target_matrix`, `packages_list`, `packages_add` in
      `unity/actions.lua`.)
- [x] Unreal: cook-only action, `Setup.sh`/`GenerateProjectFiles`
      bootstrap for a freshly cloned engine checkout, editor plugin
      packaging (`RunUAT.sh BuildPlugin`).
      (`cook_only`, `bootstrap_engine_checkout`, `package_plugin` in
      `unreal/actions.lua`.)
- [x] Shared: a `:GamesDoctor` command reporting every engine's
      resolved binary/root in one table (today, each engine's
      `describe_project`/`describe_environment` action covers this
      per-engine).
      (`health.lua` + `:GamesDoctor` in `init.lua`, backed by
      `:checkhealth utils.games`.)

## Neovim 0.13 features leveraged

Each feature below was evaluated on its own merits against this
plugin's actual needs -- adopted where it was a genuine fit, and
honestly skipped (with the reason recorded) where it wasn't. Batteries
included is not the same as use everything:

| Feature | Used here? | Where / why |
|---|---|---|
| `vim.async` (structured concurrency, `:h lua-async`) | Yes | `health.lua`'s `collect_rows()` runs all five engine probes as concurrent sibling tasks (`shared/async_util.lua`'s `run_concurrent`); `shared/godot_engine.lua`'s `remote_debug_launch` and export tooling, `unity/actions.lua`'s `build_target_matrix` (sequential by necessity -- see its own comment on why not concurrent), and `unreal/actions.lua`'s `bootstrap_engine_checkout` (strictly ordered Setup.sh then GenerateProjectFiles.sh) all use it to express ordered/concurrent external-process orchestration without a callback staircase. |
| `vim.health` | Yes | `health.lua` implements `M.check()` for `:checkhealth utils.games`, surfaced as `:GamesDoctor`. |
| `vim.json` | Yes | `shared/godot_engine.lua`'s export-state manifest (`read_export_manifest`/`write_export_manifest`); `unity/actions.lua`'s `packages_list`/`packages_add` read and edit `Packages/manifest.json` and `Packages/packages-lock.json`. |
| `vim.ui.select` | Yes | `aseprite/actions.lua`'s `export_sheet_type_preset` picks a sheet-type via `vim.ui.select`; `shared/ui.lua`'s grouped action menu (used by every `:<Engine>` command) is itself built on `vim.ui.select`. |
| `CmdAtom` (subscribe to any user action) | No -- wrong semantic fit | `CmdAtom` is for repeatable/dot-repeatable editor actions, not a background job finishing. Reporting build/export completion instead uses a plain `User` autocmd (`shared/events.lua`'s `fire_task_result`, firing `GamesTaskCompleted`/`GamesTaskFailed`) -- the correctly-scoped primitive for an async job completing, available as an optional hook for anyone wiring statuslines/notifications to this plugin's job results. |
| Multicursor, Packspec/`pkg.json`, cmdwin-as-normal-buffer, Remote-ssh | No -- out of scope | None of these relate to driving external game-engine CLIs; this plugin has no multi-cursor editing surface, is not itself a package consumed via Packspec, and does not open a command-line window or manage remote sessions. |
| `vim.ui.img` | No -- no use case | This plugin never needs to render an image inline in Neovim (Aseprite's sheet/export previews are left to Aseprite itself); revisit if a preview-exported-sprite-sheet action is ever requested. |
| Interactive `:!` / `:[range]terminal` improvements | No -- not relied upon | Not confirmed as shipped in the exact form described at the time this was written; every external command in this plugin already goes through `vim.system`/`vim.fn.jobstart`, which does not depend on this feature either way. |
| `dir.lua` / `DirReadPost` (directory browser, replaces netrw) | Considered, not implemented | Investigated for filtering build-artifact directories (e.g. hiding `Library/`, `Saved/`, `.import/`) out of a project's directory listing. The high-level feature is real, but the exact buffer-manipulation contract for filtering/sorting entries from `DirReadPost` could not be confirmed against official documentation at the time this was written. Left as a documented extension point -- see `:h dir-render` -- rather than shipping code against an unconfirmed API. |

## Tiger Style

Every file in this scaffold follows the assertion-heavy, small-function,
fixed-bounds, fail-loudly discipline documented in
[TigerBeetle's TIGER_STYLE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md).
Concretely, in this codebase that means: `assert()`s on structural
preconditions that should never be false in correct usage (missing
`vim.async` on old Neovim, a fixed bound exceeded); named, explicit
constants instead of inline magic numbers for every bound that could
otherwise be unbounded (`MAX_BUILD_TARGETS`, `MAX_CONCURRENT_TASKS`,
`EXPORT_SCAN_MAX_DEPTH`, `EXPORT_SCAN_MAX_ENTRIES`, generous-but-finite
timeouts like `ENGINE_BOOTSTRAP_TIMEOUT_MS`); short, single-purpose
functions; and heavy why-not-what comments at every non-obvious
decision (see e.g. `unity/actions.lua`'s comment on why
`build_target_matrix` builds sequentially, never concurrently).

## Learning Lua from a networking/Linux background

If you know your way around switching, routing, DHCP, ACLs, and
Linux systems administration but are newer to Lua: see
[`docs/LUA-FOR-NETWORK-LINUX-FOLKS.md`](docs/LUA-FOR-NETWORK-LINUX-FOLKS.md)
for a primer that maps Lua's core concepts (tables, `nil` vs `false`,
`pcall`/`assert`, coroutines, `vim.async`, closures-as-factories) onto
things you already know cold, with pointers to real functions in this
scaffold for every concept.
