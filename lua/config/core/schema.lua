-- schema.lua
-- Qompass AI Diver Schema Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@module 'config.core.schema'
local M = {
  json = {},
  yaml = {}
}
---@param index table<string, integer>
---@param tbl   vim.Schema[]
---@param key   string
---@return vim.Schema|nil, integer|nil
local function get_index(index, tbl, key)
  local i = index[key]
  if not i then
    return nil
  end
  return tbl[i], i
end
function M.load()
  return require('schemastore.catalog')
end

function M.json.load()
  return M.load().json
end

function M.json.get(name)
  local catalog = M.json.load()
  return get_index(catalog.index, catalog.schemas, name), nil
end

function M.json.schemas(opts)
  local catalog = M.json.load()
  if not opts then
    return catalog.schemas
  end
  opts = vim.tbl_extend('force',
    {
      select = {},
      replace = {},
      ignore = {},
      extra = {},
    }, opts)
  if type(opts.extra) == 'table' and not vim.tbl_isempty(opts.extra) then
    catalog = vim.deepcopy(catalog)
    for _, extra_schema in ipairs(opts.extra) do
      local _, idx = get_index(catalog.index, catalog.schemas, extra_schema.name)
      if idx == nil then
        idx = #catalog.schemas + 1
      end
      catalog.schemas[idx] = extra_schema
      catalog.index[extra_schema.name] = idx
    end
  end
  local schemas = vim.deepcopy(catalog.schemas)
  if type(opts.replace) == 'table' and not vim.tbl_isempty(opts.replace) then
    for name, schema in pairs(opts.replace) do
      local orig_schema, index = get_index(catalog.index, schemas, name)
      if orig_schema == nil or index == nil then
        error('schemastore.json.schemas(): replace: schema not found: ' .. name)
      end
      if type(schema) == 'string' then
        orig_schema.url = schema
      else
        assert(
          schema.name == orig_schema.name,
          string.format(
            'schemastore.json.schemas(): replace: replaced schema has different name: %s != %s',
            schema.name,
            orig_schema.name
          )
        )
        schemas[index] = schema ---@type table[]
      end
    end
  end
  local has_select = type(opts.select) == 'table' and not vim.tbl_isempty(opts.select)
  local has_ignore = type(opts.ignore) == 'table' and not vim.tbl_isempty(opts.ignore)

  assert(
    not (has_select and has_ignore),
    'schemastore.json.schemas(): the \'select\' and \'ignore\' settings are mutually exclusive'
  )

  if has_select then
    schemas = vim.tbl_map(function(name)
      local schema = get_index(catalog.index, schemas, name)
      assert(schema ~= nil, 'schemastore.json.schemas(): select: schema not found: ' .. name)
      return schema
    end, opts.select)
  elseif has_ignore then
    local ignore = {}
    for _, name in ipairs(opts.ignore) do
      local _, index = get_index(catalog.index, schemas, name)
      assert(index ~= nil, 'schemastore.json.schemas(): ignore: schema not found: ' .. name)
      table.insert(ignore, index)
    end
    table.sort(ignore, function(a, b)
      return a > b
    end)
    for _, index in ipairs(ignore) do
      table.remove(schemas, index)
    end
  end

  return schemas
end

---@param opts table
---@return { [string]: string[] }
function M.yaml.schemas(opts)
  local origin = M.json.schemas(opts) ---@type vim.Schema[]
  local schemas = {} ---@type { [string]: string[] }
  vim.tbl_map(function(schema) ---@param schema vim.Schema
    schemas[schema.url] = schema.fileMatch
  end, origin)
  return schemas
end

local function years_from(from, to)
  local cur_year = tonumber(os.date('%Y'))
  to = to and to or cur_year
  return from == to and tostring(from) or ('%d-%d'):format(from, to)
end
local function http_get(url)
  local res = vim.fn.systemlist({
    'curl',
    '--location',
    '--silent',
    '--fail',
    url,
  })
  assert(vim.v.shell_error == 0, ('GET %s failed'):format(url))
  return res
end
local function endpoint_url(...)
  return table.concat({ M.config.base_url, ... }, '/')
end
local function catalog_url(kind)
  return endpoint_url(kind, 'catalog.json')
end
local function gen_index(tbl)
  local index = {}
  for i, entry in ipairs(tbl) do
    index[entry.name] = i
  end
  return index
end
local function get_catalog(kind)
  local catalog = vim.fn.json_decode(http_get(catalog_url(kind)))
  local index = gen_index(catalog.schemas)
  catalog.index = index
  return catalog
end
local function gen_module(decls)
  local res = M.config.copyright_notice
  res = res .. '-- stylua: ignore start\n\n'
  res = res .. 'local M = {}\n\n'
  for ident, val in pairs(decls) do
    res = res .. 'M.' .. ident .. ' = ' .. val .. '\n\n'
  end
  res = res .. 'return M\n\n'
  res = res .. '-- stylua: ignore end'
  return res
end
M.config = {
  base_url = 'https://www.schemastore.org/api',
  out = '/dev/stdout',
  copyright_notice = ([[
-- !! AUTO-GENERATED - DO NOT EDIT !!
--
--  This file is an automatically generated version of the SchemaStore
--  catalog, converted from JSON to Lua.
--
--  SchemaStore.nvim is copyright %s Maddison Hellstrom and contributors
--
--  The SchemaStore project can be found at:
--
--      https://schemastore.org
--
--  The original SchemaStore catalog carries the following copyright:
--
--  Copyright %s Qompass AI 2025
--
--  Both projects are released under the following terms:
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

]]):format(years_from(2026), years_from(2025)),
}
function M.setup(config)
  local c = vim.tbl_deep_extend('force', M.config, config)
  if not c.out or c.out == '-' or c.out == '' then
    c.out = '/dev/stdout'
  end
  M.config = c
  return M
end

function M.run()
  local catalog_module = gen_module({
    json = vim.inspect(get_catalog('json')),
  })
  local ok = vim.fn.writefile(vim.split(catalog_module, '\n', { plain = true }), M.config.out)
  assert(ok == 0, 'Write failed: ' .. vim.v.errmsg)
end

return M