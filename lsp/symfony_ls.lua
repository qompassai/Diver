-- #################################################################
-- /qompassai/lsp/symfony_ls.lua
-- Qompass AI Symfony Ls
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/symfony/language-tools
---@type vim.lsp.Config
return {
  cmd = { 'symfony-lsp' },
  filetypes = {
    'php',
    'twig',
    'yaml',
    'json',
    'xml',
    'javascript',
    'typescript',
    'env',
  },
  root_markers = {
    'composer.json',
    '.git',
  },
  workspace_required = true,
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
  },
  init_options = {
    phpCommand = {
      'php',
    },
    containerProjectRoot = '',
    consolePath = 'bin/console',
    environment = 'dev',
    debug = true,
    runtimeIndexing = true,
    projectRoots = {},
    trace = 'off',
  },
  settings = {
    symfonyLsp = {
      phpCommand = { 'php' },
      containerProjectRoot = '',
      consolePath = 'bin/console',
      environment = 'dev',
      debug = true,
      runtimeIndexing = true,
      projectRoots = {},
      translationDiagnostics = false,
    },
  },
  commands = {
    ['editor.action.showReferences'] = function(command, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      local arguments = command.arguments or {}
      local uri = arguments[1]
      local position = arguments[2]
      local references = arguments[3]
      if type(uri) ~= 'string' or type(position) ~= 'table' or type(references) ~= 'table' then
        vim.notify('Symfony Language Tools returned an invalid reference command.', vim.log.levels.ERROR)
        return
      end

      local items = vim.lsp.util.locations_to_items(references, client.offset_encoding)
      vim.fn.setqflist({}, ' ', {
        title = command.title,
        items = items,
        context = {
          command = command,
          bufnr = ctx.bufnr,
        },
      })
      vim.lsp.util.show_document({
        uri = uri,
        range = {
          start = position,
          ['end'] = position,
        },
      }, client.offset_encoding)
      vim.cmd('botright copen')
    end,
  },
}
