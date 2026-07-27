-- #################################################################
-- /qompassai/lua/utils/bsp/python.lua
-- Qompass AI Python BSP Extension
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
local M = {}

local function core()
  return require('qompassai.lua.utils.bsp')
end

local function notify(msg, level)
  core().notify(msg, level)
end

local function is_python_target(target)
  return target
    and (
      target.dataKind == 'python'
      or (target.languageIds and vim.tbl_contains(target.languageIds, 'python'))
    )
end

function M.is_python_target(target)
  return is_python_target(target)
end

function M.targets(cb)
  local bsp = core()

  if not bsp.is_initialized() then
    notify('BSP not initialized', vim.log.levels.WARN)
    return
  end

  bsp.targets(function(targets)
    local py = vim.tbl_filter(is_python_target, targets or {})

    if cb then
      cb(py)
      return
    end

    if #py == 0 then
      notify('no python targets found', vim.log.levels.WARN)
      return
    end

    local names = {}
    for _, target in ipairs(py) do
      local meta = target.data or {}
      local label = target.displayName or (target.id and target.id.uri) or '<unknown>'
      if meta.version then
        label = ('%s [py %s]'):format(label, meta.version)
      end
      table.insert(names, label)
    end

    notify('python targets: ' .. table.concat(names, ', '))
  end)
end

function M.info(cb)
  M.targets(function(targets)
    local out = {}

    for _, target in ipairs(targets or {}) do
      local data = target.data or {}
      table.insert(out, {
        id = target.id,
        name = target.displayName or (target.id and target.id.uri) or '<unknown>',
        baseDirectory = target.baseDirectory,
        tags = target.tags,
        languageIds = target.languageIds,
        version = data.version,
        interpreter = data.interpreter,
      })
    end

    if cb then
      cb(out)
      return
    end

    if #out == 0 then
      notify('no python target metadata found', vim.log.levels.WARN)
      return
    end

    local lines = {}
    for _, item in ipairs(out) do
      table.insert(
        lines,
        ('%s | version=%s | interpreter=%s'):format(
          item.name,
          item.version or '?',
          item.interpreter or '?'
        )
      )
    end

    notify(table.concat(lines, '
'))
  end)
end

function M.options(cb)
  local bsp = core()

  if not bsp.is_initialized() then
    notify('BSP not initialized', vim.log.levels.WARN)
    return
  end

  M.targets(function(targets)
    if not targets or #targets == 0 then
      notify('no python targets found', vim.log.levels.WARN)
      return
    end

    local ids = vim.tbl_map(function(t)
      return t.id
    end, targets)

    bsp.request('buildTarget/pythonOptions', {
      targets = ids,
    }, function(err, result)
      if err then
        notify('pythonOptions failed: ' .. (err.message or 'unknown error'), vim.log.levels.ERROR)
        return
      end

      local items = result and result.items or {}

      if cb then
        cb(items)
        return
      end

      if #items == 0 then
        notify('no python options returned', vim.log.levels.WARN)
        return
      end

      local lines = {}
      for _, item in ipairs(items) do
        local uri = item.target and item.target.uri or '<unknown>'
        local opts = table.concat(item.interpreterOptions or {}, ' ')
        table.insert(lines, ('%s -> %s'):format(uri, opts ~= '' and opts or '<none>'))
      end

      notify(table.concat(lines, '
'))
    end)
  end)
end

function M.setup_commands(opts)
  opts = opts or {}
  local prefix = opts.prefix or 'BspPython'

  vim.api.nvim_create_user_command(prefix .. 'Targets', function()
    M.targets()
  end, {})

  vim.api.nvim_create_user_command(prefix .. 'Info', function()
    M.info()
  end, {})

  vim.api.nvim_create_user_command(prefix .. 'Options', function()
    M.options()
  end, {})
end

return M