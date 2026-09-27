#!/usr/bin/env luajit
-- lua/config/ui/init.lua
-- Qompass AI Diver UI Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Native UI setup. Markdown decorations and PNG previews use the local
-- config.markdown.render and config.ui.image modules, not image.nvim.

---Public front door to the interface toolkit, usable from every lua/ subdirectory.
---
---Plain-language version: this module is how the rest of the config reaches
---the interface pieces. `require('config.ui').float` opens popup windows,
---`.icons` and `.nerd` hand you icon tables, `.themes` switches color schemes,
---and so on. Submodules load lazily on first access, so requiring this module
---itself is cheap and has no side effects.
---@module 'config.ui'

local M = {}

---@type string[]
local startup_modules = {
    'colors',
    'decor',
    'float',
    'icons',
    'illuminate',
    'line',
    'nerd',
    'padding',
    'themes',
}

local image_options = {
    enabled = true,
    height = 16,
    margin = 2,
    row = 2,
    width = 42,
    zindex = 60,
}

---@param module_name string
local function load_startup_module(module_name)
    assert(type(module_name) == 'string')
    assert(module_name ~= '')

    local ok, mod_or_error = pcall(require, 'config.ui.' .. module_name)
    if not ok then
        error(('failed to load config.ui.%s: %s'):format(module_name, tostring(mod_or_error)))
    end
    -- Require-time side effects are banned in config.ui: a module that needs
    -- boot work exposes setup(), and the startup sequence calls it here.
    if type(mod_or_error) == 'table' and type(mod_or_error.setup) == 'function' then
        local ok_setup, setup_error = pcall(mod_or_error.setup)
        if not ok_setup then
            error(('failed to set up config.ui.%s: %s'):format(module_name, tostring(setup_error)))
        end
    end
end

local function setup_image_preview()
    local image = require('config.ui.image')
    assert(type(image) == 'table', 'config.ui.image must return a module table')
    assert(type(image.setup) == 'function', 'config.ui.image must expose setup(options)')

    image.setup(image_options)
end

local function setup_markdown_rendering()
    -- Single attach path: config.markdown.render owns its FileType autocmd
    -- and the enable/disable lifecycle. The duplicate MarkdownRendering
    -- augroup that used to live here is gone; setup() is idempotent, so
    -- calling it from both this (currently unused) entry point and the
    -- boot sequence can never double-attach.
    local render = require('config.markdown.render')
    assert(type(render) == 'table', 'config.markdown.render must return a module table')
    assert(type(render.setup) == 'function', 'config.markdown.render must expose setup()')

    render.setup()
end

---Boot entry point, invoked by config/init.lua through call_if_present.
---Follows the <name>_config convention shared by config.lang and config.nav.
---@param _opts? table reserved for future boot options
function M.ui_config(_opts)
    for index = 1, #startup_modules do
        load_startup_module(startup_modules[index])
    end

    setup_image_preview()
    setup_markdown_rendering()
end

---@class ConfigUiFacade
---@field colors table config.ui.colors: highlight groups and colorizer setup
---@field decor table config.ui.decor: treesitter decorations and textobjects
---@field float table config.ui.float: floating terminal windows
---@field icons table config.ui.icons: icon tables and devicons wiring
---@field illuminate table config.ui.illuminate: cursor-word illumination
---@field image table config.ui.image: inline PNG preview rendering
---@field line table config.ui.line: statusline (lualine) setup
---@field nerd table config.ui.nerd: nerd-font glyph data table
---@field padding table config.ui.padding: window padding controls
---@field themes table config.ui.themes: colorscheme management

---@type table<string, boolean>
local facade_names = {
    colors = true,
    decor = true,
    float = true,
    icons = true,
    illuminate = true,
    image = true,
    line = true,
    nerd = true,
    padding = true,
    themes = true,
}

-- Lazy facade: submodules load on first access and are cached, so
-- requiring config.ui stays cheap and side-effect free.
setmetatable(M, {
    __index = function(self, key)
        if facade_names[key] then
            local mod = require('config.ui.' .. key)
            rawset(self, key, mod)
            return mod
        end
        return nil
    end,
})

return M
