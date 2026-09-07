#!/usr/bin/env lua5.1
-- /home/phaedrus/.config/nvim/lua/config/ui/init.lua
-- Qompass AI Diver UI Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-----------------------------------------------------

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

---@type ui.image.Options
local image_options = {
  allow_http = false,
  cache_entry_count_max = 32,
  debounce_ms = 150,
  enabled = false,
  image_bytes_max = 10 * 1024 * 1024,
  markdown_filetypes = {
    markdown = true,
    ['markdown.mdx'] = true,
  },
  notify_errors = false,
  pending_request_count_max = 1,
  preview_height_fraction = 0.70,
  preview_margin = 2,
  preview_row = 2,
  preview_width_fraction = 0.32,
  preview_zindex = 60,
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
  local image_preview = require('config.ui.image')

  if type(image_preview) ~= 'table' then
    error('config.ui.image must return a module table')
  end

  if type(image_preview.setup) ~= 'function' then
    error('config.ui.image must expose setup(options)')
  end

  image_preview.setup(image_options)
end

function M.setup()
  for index = 1, #startup_modules do
    local module_name = startup_modules[index]

    load_startup_module(module_name)
  end

  setup_image_preview()
end

return M
