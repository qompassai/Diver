-- /qompassai/Diver/lsp/clangd_ls.lua
-- Qompass AI Diver Clangd LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- clangd extension request method names are outside Neovim's generated
-- vim.lsp.protocol.Method union. The only required annotation suppression is
-- inline and uses LuaLS's supported `undefined-field` code.

local SWITCH_SOURCE_HEADER = 'textDocument/switchSourceHeader'
local SYMBOL_INFO = 'textDocument/symbolInfo'
local INLAY_HINTS = 'clangd/inlayHints'

---@param client vim.lsp.Client
---@param method string
---@return boolean
local function supports_method(client, method)
  if type(client.supports_method) ~= 'function' then
    return false
  end

  ---@diagnostic disable-next-line: undefined-field
  return client:supports_method(method)
end

---@param client vim.lsp.Client
---@param method string
---@param params any
---@param handler fun(err: lsp.ResponseError|nil, result: any, context: lsp.HandlerContext|nil, config: table|nil)
---@param bufnr integer
local function clangd_request(client, method, params, handler, bufnr)
  ---@diagnostic disable-next-line: undefined-field
  client:request(method, params, handler, bufnr)
end

---@param bufnr integer
---@param client vim.lsp.Client
local function switch_source_header(bufnr, client)
  if not supports_method(client, SWITCH_SOURCE_HEADER) then
    vim.notify(
      ('method %s is not supported by clangd for the current buffer'):format(SWITCH_SOURCE_HEADER),
      vim.log.levels.WARN
    )
    return
  end

  clangd_request(client, SWITCH_SOURCE_HEADER, vim.lsp.util.make_text_document_params(bufnr), function(err, result)
    if err then
      vim.notify(tostring(err), vim.log.levels.ERROR)
      return
    end

    if type(result) ~= 'string' or result == '' then
      vim.notify('corresponding source/header file cannot be determined', vim.log.levels.INFO)
      return
    end

    vim.cmd.edit(vim.uri_to_fname(result))
  end, bufnr)
end

---@param bufnr integer
---@param client vim.lsp.Client
local function symbol_info(bufnr, client)
  if not supports_method(client, SYMBOL_INFO) then
    vim.notify('clangd does not support textDocument/symbolInfo', vim.log.levels.WARN)
    return
  end

  local win = vim.api.nvim_get_current_win()
  local params = vim.lsp.util.make_position_params(win, client.offset_encoding)

  clangd_request(client, SYMBOL_INFO, params, function(err, result)
    if err or type(result) ~= 'table' or #result == 0 or type(result[1]) ~= 'table' then
      return
    end

    local details = result[1]
    local name = string.format('name: %s', details.name or '')
    local container = string.format('container: %s', details.containerName or '')

    vim.lsp.util.open_floating_preview({ name, container }, '', {
      border = 'rounded',
      focus = false,
      focusable = false,
      height = 2,
      title = 'Symbol Info',
      title_pos = 'center',
      width = math.max(#name, #container),
    })
  end, bufnr)
end

---@param bufnr integer
---@param client vim.lsp.Client
local function request_inlay_hints(bufnr, client)
  if not supports_method(client, INLAY_HINTS) then
    vim.notify('clangd does not support clangd/inlayHints', vim.log.levels.WARN)
    return
  end

  clangd_request(client, INLAY_HINTS, {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  }, function(err, result)
    if err then
      vim.notify(tostring(err), vim.log.levels.ERROR)
      return
    end

    if result == nil then
      vim.notify('clangd returned no inlay hints', vim.log.levels.INFO)
    end
  end, bufnr)
end

---@type vim.lsp.Config
return {
  cmd = {
    'clangd',
    '--clang-tidy',
    '--experimental-modules-support',
  },

  filetypes = {
    'c',
    'cpp',
    'cuda',
    'objc',
    'objcpp',
    'proto',
    'ptx',
  },

  root_markers = {
    '.clangd',
    '.clang-tidy',
    '.clang-format',
    'compile_commands.json',
    'compile_flags.txt',
    'configure.ac',
    '.git',
    'west.yml',
    'zephyr/module.yml',
  },

  capabilities = {
    textDocument = {
      completion = {
        editsNearCursor = true,
      },
      references = {
        container = true,
      },
    },
    offsetEncoding = {
      'utf-8',
      'utf-16',
    },
  },

  init_options = {
    fallbackFlags = {
      '-std=c++17',
    },
  },

  settings = {},

  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'LspClangdSwitchSourceHeader', function()
      switch_source_header(bufnr, client)
    end, {
      desc = 'Switch between source and header',
    })

    vim.api.nvim_buf_create_user_command(bufnr, 'LspClangdShowSymbolInfo', function()
      symbol_info(bufnr, client)
    end, {
      desc = 'Show clangd symbol information',
    })

    vim.api.nvim_buf_create_user_command(bufnr, 'LspClangdInlayHints', function()
      request_inlay_hints(bufnr, client)
    end, {
      desc = 'Request clangd inlay hints',
    })
  end,
}
