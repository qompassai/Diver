-- /qompassai/diver/lua/config/lang/zig.lua
-- qompass ai diver zig config
-- copyright (c) 2025 qompass ai, all rights reserved
------------------------------------
local M = {}

function M.zig_autocmds()
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

function M.zig_conform()
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

function M.zig_diagnostics()
  return function(ctx)
    local output = vim.fn.systemlist(
      vim.fn.shellescape(ctx.file))
    local diagnostics = {}
    for _, line in ipairs(output) do
      local line_num, col_num, code, msg = line:match(':(%d+):(%d+): (%S+): (.*)')
      if line_num then
        table.insert(diagnostics, {
          lnum = tonumber(line_num) - 1,
          col = tonumber(col_num) - 1,
          message = string.format('[%s] %s', code, msg),
          severity = vim.diagnostic.severity.WARN,
          source = 'zlint'
        })
      end
    end
    local ns = vim.api.nvim_create_namespace("zlint")
    vim.diagnostic.set(ns, ctx.bufnr, diagnostics)
  end
end

function M.zig_lamp()
  local lsp_settings = M.zig_lsp().settings or {}
  return {
    g = {
      zig_lamp_zls_auto_install = true,
      zig_lamp_fall_back_sys_zls = true,
      zig_lamp_zls_lsp_opt = vim.tbl_deep_extend("force", {}, lsp_settings),
      zig_lamp_pkg_help_fg = "#cf5c00",
      zig_lamp_zig_fetch_timeout = 5000,
    },
  }
end

---@return table
function M.zig_lsp()
  local function find_executable(names)
    return vim.iter(names):map(function(name)
      return vim.fs.find(name, {
        path = table.concat({
          vim.fn.expand("~") .. '/.local/bin',
          vim.fn.stdpath('data') .. '/mason/bin',
          vim.env.PATH or ''
        }, ':')
      })[1]
    end):next()
  end
  local zls_path = find_executable({ 'zls' }) or 'zls'
  local zig_path = find_executable({ 'zig' }) or 'zig'
  local zlint_path = find_executable({ 'zlint' }) or 'zlint'
  return {
    cmd = { zls_path },
    settings = {
      zls = {
        enable_ast_check_diagnostics = true,
        enable_build_on_save = true,
        zig_exe_path = zig_path,
        enable_inlay_hints = true,
        inlay_hints = {
          parameter_names = true,
          variable_names = true,
          builtin = true,
          type_names = true
        }
      }
    },
    zlint_path = zlint_path
  }
end

---@return nil
function M.zig_vim()
  vim.g.zig_fmt_autosave = 1
  vim.g.zig_fmt_parse_errors = 1
  vim.g.zig_fmt_skip_files = ''
  vim.g.zig_highlight_delimiters = 1
  vim.g.zig_highlight_named_parameters = 1
  vim.g.zig_highlight_builtin_functions = 1
end

---@return table
function M.zig_treesitter()
  return {
    ensure_installed = {},
    highlight = {
      enable = true,
      disable = {},
    },
    indent = {
      enable = true,
    },
  }
end

---@return ZigConfig
function M.zig_cfg()
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
