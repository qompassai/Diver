-- #################################################################
-- ~/.config/nvim/lua/formatters/nixfmt.lua
-- Native nixfmt Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/NixOS/nixfmt/releases/tag/v1.5.0
---
--- Tiger Style for Nix formatting profile (docs/TIGER_STYLE_NIX.md §23):
--- one pinned formatter (nixfmt 1.5.0), two-space indentation, and a
--- 100-column review target. Deterministic output wins over manual
--- wrapping, so strict mode is on: the result depends on the Nix
--- expression, not on how the input happened to be laid out.
--- nixfmt reads no config files; these flags ARE the pinned profile.

local NIXFMT_INDENT = 2
local NIXFMT_WIDTH = 100

---@class NixfmtConfig
---@field width integer Maximum line width in characters (tiger-style: 100).
---@field strict boolean Stricter mode, less influenced by input layout.

---@type NixfmtConfig
local CONFIG = {
    width = NIXFMT_WIDTH,
    strict = true,
}

assert(CONFIG.width > 0 and CONFIG.width <= 1000, 'nixfmt: width must be within 1..1000 columns')

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filetype ~= 'nix' then
        error('nixfmt requires the nix filetype')
    end

    local args = {
        '--width',
        tostring(CONFIG.width),
        '--indent',
        tostring(NIXFMT_INDENT),
    }

    if CONFIG.strict then
        args[#args + 1] = '--strict'
    end

    if context.filename ~= '' then
        args[#args + 1] = '--filename'
        args[#args + 1] = context.filename
    end

    -- `-` selects stdin; a bare invocation is deprecated upstream.
    args[#args + 1] = '-'

    return args
end

---@type FormatterSpec
return {
    allow_empty = false,
    args = build_args,
    automatic = true,
    cmd = 'nixfmt',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = nil,
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'flake.nix', 'default.nix', 'shell.nix', '.git' },
}
