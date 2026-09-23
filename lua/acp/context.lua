-- /qompassai/Diver/lua/acp/context.lua
-- Qompass AI Agent Context Protocol Tooling (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/prmichaelsen/agent-context-protocol
--
-- Unrelated to the Agent CLIENT Protocol implemented elsewhere in this
-- directory (registry.lua, rpc.lua, protocol.lua, session.lua, ui.lua,
-- permissions.lua, store.lua). This file is a documentation *convention*:
-- a structured `agent/` directory of markdown knowledge files per project,
-- with no RPC and no running process. Named `context.lua`, not `acp.lua`,
-- specifically so the two protocols sharing an acronym never collide in a
-- `require(...)` path.

local fs = vim.fs
local uv = vim.uv

local M = {}

local FILE_COUNT_MAX = 2000

---@type table<string, string>
local TEMPLATES = {
  ['SPEC.md'] = '# Specification\n\n## Problem\n\n## Approach\n\n## Non-Goals\n',
  ['PLAN.md'] = '# Plan\n\n## Steps\n\n1. \n\n## Open Questions\n',
  ['DECISIONS.md'] = '# Decisions\n\nRecord one entry per accepted decision, oldest first.\n\n'
    .. '## YYYY-MM-DD: <title>\n\n- Context:\n- Decision:\n- Consequences:\n',
}

---@param root? string
---@return string
local function context_dir(root)
  return fs.joinpath(root or vim.fn.getcwd(), 'agent')
end

---@param root? string
---@return integer created_count
function M.scaffold(root)
  local dir = context_dir(root)
  vim.fn.mkdir(dir, 'p', '700')

  local created = 0
  for filename, contents in pairs(TEMPLATES) do
    local path = fs.joinpath(dir, filename)
    if uv.fs_stat(path) == nil then
      local fd = uv.fs_open(path, 'wx', 384)
      if fd then
        uv.fs_write(fd, contents, 0)
        uv.fs_close(fd)
        created = created + 1
      end
    end
  end
  return created
end

---@param root? string
---@return string[] paths Relative to the context directory.
function M.list(root)
  local dir = context_dir(root)
  local paths = {}
  local handle = uv.fs_scandir(dir)
  if not handle then
    return paths
  end
  while true do
    local name, kind = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if kind == 'file' and #paths < FILE_COUNT_MAX then
      paths[#paths + 1] = name
    end
  end
  table.sort(paths)
  return paths
end

---@param root? string
---@param how? 'edit'|'split'|'vsplit'|'tabedit'
function M.browse(root, how)
  local dir = context_dir(root)
  local paths = M.list(root)
  if #paths == 0 then
    vim.notify('No agent/ context files found; run :AcpContextScaffold first', vim.log.levels.WARN)
    return
  end

  local picker_ok, fzf_module = pcall(require, 'config.nav.fzf')
  local function open(name)
    local path = fs.joinpath(dir, name)
    if how and how ~= 'edit' then
      vim.cmd(how)
    end
    vim.cmd.edit(path)
  end

  if picker_ok and type(fzf_module) == 'table' and type(fzf_module.fzfpick) == 'function' then
    local items = {}
    for _, name in ipairs(paths) do
      items[#items + 1] = { label = name, value = name }
    end
    fzf_module.fzfpick(items, function(value)
      if value then
        open(value)
      end
    end, { prompt = 'Agent context files' })
    return
  end

  vim.ui.select(paths, { prompt = 'Agent context files' }, function(choice)
    if choice then
      open(choice)
    end
  end)
end

return M
