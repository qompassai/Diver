-- #################################################################
-- /qompassai/.GH/Qompass/Diver/lsp/cc_ls.lua
-- Qompass AI Ccls LSP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
-- ccls: https://github.com/MaskRay/ccls
-- Neovim LSP: https://neovim.io/doc/user/lsp.html
local api = vim.api
local lsp = vim.lsp
local levels = vim.log.levels
---@type any
local METHOD_SWITCH_SOURCE_HEADER = 'textDocument/switchSourceHeader'

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(message, level or levels.INFO, {
    title = 'ccls',
  })
end
---@param client vim.lsp.Client
---@param bufnr integer
local function switch_source_header(client, bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    notify('Cannot switch source/header: the buffer is no longer valid', levels.WARN)
    return
  end

  local params = lsp.util.make_text_document_params(bufnr)
  local sent = client:request(METHOD_SWITCH_SOURCE_HEADER, params, function(err, result)
    if err then
      notify(('Source/header switch failed: %s'):format(err.message or tostring(err)), levels.ERROR)
      return
    end

    if type(result) ~= 'string' or result == '' then
      notify('Corresponding source or header file could not be determined', levels.WARN)
      return
    end

    local ok, filename = pcall(vim.uri_to_fname, result)
    if not ok or type(filename) ~= 'string' or filename == '' then
      notify('ccls returned an invalid source/header URI', levels.ERROR)
      return
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(bufnr) then
        return
      end

      api.nvim_cmd({
        cmd = 'edit',
        args = {
          filename,
        },
      }, {})
    end)
  end, bufnr)

  if not sent then
    notify('Unable to send the source/header request to ccls', levels.ERROR)
  end
end

---@type vim.lsp.Config
return {
  cmd = {
    'ccls',
  },
  filetypes = {
    'c',
    'cpp',
    'cuda',
    'objc',
    'objcpp',
  },
  flags = {
    allow_incremental_sync = true,
    debounce_text_changes = 150,
  },
  init_options = {
    compilationDatabaseDirectory = 'build',
    cache = {
      directory = '.ccls-cache',
      format = 'binary',
      hierarchicalPath = false,
      retainInMemory = 2,
    },
    clang = {
      excludeArgs = {},
      extraArgs = {},
    },
    codeLens = {
      localVariables = true,
    },
    completion = {
      caseSensitivity = 2,
      detailedLabel = true,
      dropOldRequests = true,
      duplicateOptional = true,
      filterAndSort = true,
      include = {
        blacklist = {},
        maxPathSize = 30,
        suffixWhitelist = {
          '.h',
          '.hh',
          '.hpp',
          '.hxx',
          '.inc',
        },
        whitelist = {},
      },
      maxNum = 100,
      placeholder = true,
    },
    diagnostics = {
      blacklist = {},
      onChange = 1000,
      onOpen = 0,
      onSave = 0,
      spellChecking = true,
      whitelist = {},
    },
    highlight = {
      blacklist = {},
      largeFileSize = 2097152,
      lsRanges = true,
      whitelist = {},
    },
    index = {
      blacklist = {},
      comments = 2,
      initialBlacklist = {},
      initialWhitelist = {},
      maxInitializerLines = 5,
      onChange = true,
      parametersInDeclarations = true,
      threads = 0,
      trackDependency = 2,
      whitelist = {},
    },
    request = {
      timeout = 5000,
    },
    workspaceSymbol = {
      caseSensitivity = 1,
      maxNum = 1000,
      sort = true,
    },
    xref = {
      maxNum = 2000,
    },
  },
  offset_encoding = 'utf-32',
  on_attach = function(client, bufnr)
    require('config.core.lsp').on_attach(client, bufnr)
    api.nvim_buf_create_user_command(bufnr, 'LspCclsSwitchSourceHeader', function()
      switch_source_header(client, bufnr)
    end, {
      desc = 'Ccls: switch between source and header',
      force = true,
    })
  end,
  root_markers = {
    {
      'compile_commands.json',
      '.ccls',
    },
    '.git',
  },
  workspace_required = true,
}
