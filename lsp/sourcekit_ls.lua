-- #################################################################
-- /qompassai/lsp/sourcekit_ls.lua
-- Qompass AI Sourcekit Ls
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
return ---@type vim.lsp.Config
{
  cmd = {
    'sourcekit-lsp',
  },
  filetypes = {
    'swift',
    'objc',
    'objcpp',
    'c',
    'cpp',
  },
  root_markers = {
    'buildServer.json',
    {
      '*.xcodeproj',
      '*.xcworkspace',
    },
    {
      'compile_commands.json',
      'Package.swift',
    },
    '.git',
  },
  get_language_id = function(_, filetype)
    local language_ids = {
      objc = 'objective-c',
      objcpp = 'objective-cpp',
    }
    return language_ids[filetype] or filetype
  end,
  capabilities = vim.tbl_deep_extend('force', require('config.core.lsp').capabilities, {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
    textDocument = {
      diagnostic = {
        dynamicRegistration = true,
        relatedDocumentSupport = true,
      },
    },
  }),
  on_attach = require('config.core.lsp').on_attach,
}
