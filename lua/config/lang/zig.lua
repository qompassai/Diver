-- /qompassai/diver/lua/config/lang/zig.lua
-- qompass ai diver zig config
-- copyright (c) 2025 qompass ai, all rights reserved
------------------------------------
---@module 'config.lang.zig'
local M = {} ---@class ZigConfigModule


function M.zig_autocmds() ---@return nil
  vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = { "*.zig", "*.zon", "*.zine" },
    callback = function()
      require("conform").format({ async = true, lsp_fallback = true })
    end
  })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { "zig", "zon", "zine" },
    callback = function()
      vim.opt_local.shiftwidth = 4
      vim.opt_local.tabstop = 4
      vim.opt_local.softtabstop = 4
      vim.opt_local.expandtab = true
    end,
  })
end

---@param opts? table
function M.zig_conform(opts) ---@return table
  opts = opts or {}
  local formatters = require('conform').conform_setup().formatters_by_ft.zig or {}
  return vim.tbl_deep_extend("force", {}, formatters)
end

function M.zig_cmp()
  return {
    sources = {
      { name = 'nvim_lsp' },
      { name = 'buffer' },
      { name = 'luasnip' },
    },
    mapping = require('cmp').mapping.preset.insert({
      ['<c-b>'] = require('cmp').mapping.scroll_docs(-4),
      ['<c-f>'] = require('cmp').mapping.scroll_docs(4),
      ['<c-space>'] = require('cmp').mapping.complete(),
      ['<c-e>'] = require('cmp').mapping.abort(),
      ['<cr>'] = require('cmp').mapping.confirm({ select = true }),
    }),
    snippet = {
      expand = function(args)
        require('luasnip').lsp_expand(args.body)
      end,
    },
    experimental = { ghost_text = true },
  }
end

function M.zig_diagnostics() ---@param ctx { file: string, bufnr: integer }
  return function(ctx)
    local output = vim.fn.systemlist(vim.fn.shellescape(ctx.file))
    local diagnostics = {}
    for _, line in ipairs(output) do
      local line_num, col_num, code, msg = line:match(':(%d+):(%d+): (%S+): (.*)')
      if line_num and col_num and code and msg then
        local lnum = tonumber(line_num)
        local col = tonumber(col_num)
        if lnum and col then
          table.insert(diagnostics, {
            lnum = lnum - 1,
            col = col - 1,
            message = string.format('[%s] %s', code, msg),
            severity = vim.diagnostic.severity.WARN,
            source = 'zlint',
          })
        end
      end
    end
    local ns = vim.api.nvim_create_namespace("zlint")
    vim.diagnostic.set(ns, ctx.bufnr, diagnostics)
  end
end

function M.zig_lamp() ---@return table
  return {
    g = {
      zig_lamp_zls_auto_install = false,
      zig_lamp_fall_back_sys_zls = true,
      zig_lamp_zls_lsp_opt = vim.tbl_deep_extend("force", {}, M.zig_lsp()),
      zig_lamp_pkg_help_fg = "#cf5c00",
      zig_lamp_zig_fetch_timeout = 5000,
    },
  }
end

function M.zig_lsp() ---@return nil
  return {}
end

function M.zig_vim() ---@return nil
  vim.g.zig_fmt_autosave = 1
  vim.g.zig_fmt_parse_errors = 1
  vim.g.zig_fmt_skip_files = ''
  vim.g.zig_highlight_delimiters = 1
  vim.g.zig_highlight_named_parameters = 1
  vim.g.zig_highlight_builtin_functions = 1
end

function M.zig_treesitter() ---@return table
  return {
    ensure_installed = { 'zig' },
    highlight = {
      enable = true,
      disable = {},
    },
    indent = {
      enable = true,
    },
  }
end

---@param opts? table
function M.zig_cfg(opts) ---@return ZigConfig
  opts = opts or {}
  local lamp_cfg = M.zig_lamp().g
  for key, value in pairs(lamp_cfg) do
    vim.g[key] = value
  end
  vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = { '*.zig', '*.zon' },
    callback = M.zig_diagnostics(),
  })
  return {
    autocmds = M.zig_autocmds(),
    diagnostics = M.zig_diagnostics,
  }
end

return M
