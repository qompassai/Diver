-- /qompassai/Diver/lsp/clangd.lua
-- Qompass AI Diver Clangd LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local function switch_source_header(bufnr, client)
  local method = 'textDocument/switchSourceHeader' ---@type string
  if not client or not client.supports_method or not client:supports_method(method) then
    return vim.echo(
      ('method %s is not supported by any servers active on the current buffer'):format(method),
      vim.log.levels.WARN
    )
  end
  client:request( ---@cast client { request: fun(method: string, params: any, handler: fun(err: lsp.ResponseError|nil, result: any), token?: integer|nil) }
    method,
    vim.lsp.util.make_text_document_params(bufnr),
    function(err, result)
      if err then
        vim.echo(tostring(err), vim.log.levels.ERROR)
        return
      end
      if not result then
        vim.echo('corresponding file cannot be determined', vim.log.levels.INFO)
        return
      end
      vim.cmd.edit(vim.uri_to_fname(result))
    end,
    bufnr
  )
end
local function symbol_info(bufnr, client)
  local method = 'textDocument/symbolInfo' ---@type string
  if not Client or not client.supports_method or not client:supports_method(method) then
    return vim.echo('Clangd client not found or symbolInfo not supported', vim.log.levels.ERROR)
  end
  local win = vim.api.nvim_get_current_win()
  local params = vim.lsp.util.make_position_params(win, client.offset_encoding) ---@type table[]
  client:request( ---@cast client { request: fun(method: string, params: any, handler: fun(err: lsp.ResponseError|nil, result: any), token?: integer|nil) }
    method,
    params,
    function(err, res)
      if err or not res or #res == 0 then
        return
      end
      local details = res[1] ---@type table
      local container = string.format('container: %s', details.containerName or '')
      local name = string.format('name: %s', details.name or '')
      vim.lsp.util.open_floating_preview({ name, container }, '', {
        height = 2,
        width = math.max(#name, #container),
        focusable = false,
        focus = false,
        title = 'Symbol Info',
        border = 'rounded',
        title_pos = 'center',
      })
    end,
    bufnr
  )
end
local function request_inlay_hints(bufnr, client)
  local method = 'clangd/inlayHints' ---@type string
  if not Client or not Client:supports_method() or not client:supports_method(method) then
    return vim.echo('clangd does not support inlay hints', vim.log.levels.WARN)
  end
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  }
  Client:request(method, params, function(err, hints)
    if err or not hints then
      return
    end
  end, bufnr)
end
return ---@type vim.lsp.Config
{
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
  init_options = {
    fallbackFlags = {
      '-std=c++17',
    },
  },
  root_markers = {
    '.clangd',
    '.clang-tidy',
    '.clang-format',
    'compile_commands.json',
    'compile_flags.txt',
    'configure.ac',
    '.git',
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
    on_init = function(client, init_result)
      if init_result and init_result.offsetEncoding then
        client.offset_encoding = init_result.offsetEncoding
      end
    end,
    ---@param client vim.lsp.Client
    on_attach = function(client, bufnr) ---@param bufnr integer
      vim.api.nvim_buf_create_user_command(bufnr, 'LspClangdSwitchSourceHeader', function()
        switch_source_header(bufnr, client)
      end, {
        desc = 'Switch between source/header',
      })
      vim.api.nvim_buf_create_user_command(bufnr, 'LspClangdShowSymbolInfo', function()
        symbol_info(bufnr, client)
      end, { desc = 'Show symbol info' })
      if client.name == 'clangd' then
        vim.api.nvim_buf_create_user_command(bufnr, 'LspClangdInlayHints', function()
          request_inlay_hints(bufnr, client)
        end, {
          desc = 'Request clangd inlay hints',
        })
      end
    end,
  },
}