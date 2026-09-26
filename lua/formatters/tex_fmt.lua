-- #################################################################
-- ~/.config/nvim/lua/formatters/tex_fmt.lua
-- Native tex-fmt Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/wgunderwood/tex-fmt/releases/tag/v0.5.7
---
--- Tiger Style for LaTeX formatting profile (tiger style formatting rules:
--- 4-space indentation, 100-column review target, deterministic output).
--- Upstream defaults are 2-space indent and 80-column wrap; both are
--- overridden explicitly. `--noconfig` keeps the result independent of
--- stray tex-fmt.toml files: the flags below ARE the pinned profile.
--- tex-fmt handles .tex, .bib, .cls and .sty; the runner selects it for
--- the tex, latex and plaintex filetypes.

local TEX_FMT_WIDTH = 100
local TEX_FMT_INDENT = 4

---@class TexFmtConfig
---@field width integer Line length for wrapping (tiger-style: 100).
---@field indent integer Indent width in spaces (tiger-style: 4).
---@field no_config boolean Ignore tex-fmt.toml files for deterministic output.

---@type TexFmtConfig
local CONFIG = {
    width = TEX_FMT_WIDTH,
    indent = TEX_FMT_INDENT,
    no_config = true,
}

assert(CONFIG.width > 0 and CONFIG.width <= 1000, 'tex_fmt: width must be within 1..1000 columns')
assert(CONFIG.indent > 0 and CONFIG.indent <= 16, 'tex_fmt: indent must be within 1..16 spaces')

local TEX_FILETYPES = { tex = true, latex = true, plaintex = true }

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if not TEX_FILETYPES[context.filetype] then
        error('tex_fmt requires a TeX filetype (tex, latex, plaintex)')
    end

    local args = {
        '--stdin',
        '--tabsize',
        tostring(CONFIG.indent),
        '--wraplen',
        tostring(CONFIG.width),
    }

    if CONFIG.no_config then
        args[#args + 1] = '--noconfig'
    end

    return args
end

---@type FormatterSpec
return {
    cmd = 'tex-fmt',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = nil,
    decode = nil,
    pre_transform = nil,
}
