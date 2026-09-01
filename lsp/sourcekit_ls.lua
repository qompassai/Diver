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

local LANGUAGE_IDS = {
  objc = 'objective-c',
  objcpp = 'objective-cpp',
}

return ---@type vim.lsp.Config
{
  capabilities = {
    textDocument = {
      diagnostic = {
        dynamicRegistration = true,
        relatedDocumentSupport = true,
      },
    },

    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
  },

  cmd = {
    'sourcekit-lsp',
  },

  filetypes = {
    'c',
    'cpp',
    'objc',
    'objcpp',
    'swift',
  },

  get_language_id = function(_, filetype)
    return LANGUAGE_IDS[filetype] or filetype
  end,

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
}
