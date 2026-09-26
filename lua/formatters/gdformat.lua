-- #################################################################
-- ~/.config/nvim/lua/formatters/gdformat.lua
-- Native gdformat Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/Scony/godot-gdscript-toolkit
---@source https://github.com/nvimtools/none-ls.nvim/blob/main/doc/BUILTINS.md
---
--- gdformat tidies GDScript, the scripting language of the Godot game
--- engine. The lone `-` means "read the script from stdin and print
--- the pretty version to stdout", so the buffer never has to touch
--- the disk.

---@type FormatterSpec
return {
    cmd = 'gdformat',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { 'project.godot', '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'gd',
}
