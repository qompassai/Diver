-- One owner for diagnostics and filetype-aware native lint/format runners.
-- SPDX-License-Identifier: Apache-2.0
local core = require('mappings._core')
local M = {}
local OWNER = 'lintmap'

local function runners(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local lint = package.loaded.linters
  local format = package.loaded.formatters
  if type(lint) ~= 'table' or type(lint.linters_by_ft) ~= 'table' or lint.linters_by_ft[filetype] == nil then
    lint = nil
  end
  if
    type(format) ~= 'table'
    or type(format.formatters_by_ft) ~= 'table'
    or format.formatters_by_ft[filetype] == nil
  then
    format = nil
  end
  return lint, format
end

local function format_buffer(bufnr)
  local _, formatter = runners(bufnr)
  if formatter and type(formatter.format) == 'function' then
    formatter.format({ bufnr = bufnr, async = true })
    return
  end
  local items = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method('textDocument/formatting', bufnr) then
      items[#items + 1] = {
        label = client.name .. ' [' .. client.id .. ']',
        run = function()
          vim.lsp.buf.format({
            bufnr = bufnr,
            id = client.id,
            async = false,
            timeout_ms = 3000,
          })
        end,
      }
    end
  end
  if #items == 1 then
    items[1].run()
  else
    core.select(bufnr, items, 'Choose one formatter')
  end
end

local function attach(bufnr)
  local maps = {}
  if core.source(bufnr) then
    local lint, format = runners(bufnr)
    if format or core.supports(bufnr, 'textDocument/formatting') then
      maps[#maps + 1] = {
        lhs = '<LocalLeader>cf',
        desc = 'Format buffer',
        rhs = function()
          format_buffer(bufnr)
        end,
      }
    end
    if lint and type(lint.run) == 'function' then
      maps[#maps + 1] = {
        lhs = '<LocalLeader>cl',
        desc = 'Lint current filetype',
        rhs = function()
          lint.run(bufnr, { notify = true })
        end,
      }
    end
    if lint and type(lint.reset) == 'function' then
      maps[#maps + 1] = {
        lhs = '<LocalLeader>cr',
        desc = 'Reset runner lint diagnostics',
        rhs = function()
          lint.reset(bufnr)
        end,
      }
    end
    if lint or format then
      maps[#maps + 1] = {
        lhs = '<LocalLeader>ci',
        desc = 'Buffer lint/format tools',
        rhs = function()
          if lint and type(lint.info) == 'function' then
            lint.info(bufnr, false)
          end
          if format and type(format.info) == 'function' then
            format.info(bufnr, false)
          end
        end,
      }
      maps[#maps + 1] = {
        lhs = '<LocalLeader>cx',
        desc = 'Cancel lint and format jobs',
        rhs = function()
          if lint and type(lint.stop) == 'function' then
            lint.stop(bufnr)
          end
          if format and type(format.stop) == 'function' then
            format.stop(bufnr)
          end
        end,
      }
    end
  end
  core.install(OWNER, bufnr, maps)
end

function M.setup()
  core.watch(OWNER, attach)
  core.install(OWNER, 0, {
    {
      lhs = '<Leader>xd',
      desc = 'Line diagnostics',
      rhs = function()
        vim.diagnostic.open_float({ scope = 'line' })
      end,
    },
    {
      lhs = '<Leader>xl',
      desc = 'Buffer diagnostic location list',
      rhs = function()
        vim.diagnostic.setloclist({ open = true })
      end,
    },
    {
      lhs = '<Leader>xq',
      desc = 'All collected diagnostics in quickfix',
      rhs = function()
        vim.diagnostic.setqflist({ open = true })
      end,
    },
    {
      lhs = '<Leader>xt',
      desc = 'Toggle diagnostics for current buffer',
      rhs = function()
        local filter = { bufnr = vim.api.nvim_get_current_buf() }
        vim.diagnostic.enable(not vim.diagnostic.is_enabled(filter), filter)
      end,
    },
    {
      lhs = '<Leader>xv',
      desc = 'Toggle diagnostic virtual lines globally',
      rhs = function()
        local enabled = vim.diagnostic.config().virtual_lines
        vim.diagnostic.config({ virtual_lines = not enabled })
      end,
    },
  })
end

function M.teardown()
  core.teardown(OWNER)
end
M.setup_lintmap = M.setup
return M
