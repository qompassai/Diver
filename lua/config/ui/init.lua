#!/usr/bin/env luajit
-- /home/phaedrus/.config/nvim/lua/config/ui/init.lua
-- Qompass AI Diver UI Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Native UI setup. Markdown decorations and PNG previews use the local
-- config.markdown.render and config.ui.image modules, not image.nvim.

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
    'render',
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

    local ok, require_error = pcall(require, 'config.ui.' .. module_name)
    if not ok then
        error(('failed to load config.ui.%s: %s'):format(module_name, tostring(require_error)))
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

function M.setup()
    for index = 1, #startup_modules do
        load_startup_module(startup_modules[index])
    end

    setup_image_preview()
    setup_markdown_rendering()
end

return M
