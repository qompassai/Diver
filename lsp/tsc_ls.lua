-- #################################################################
-- /qompassai/lsp/tsc_ls.lua
-- Qompass AI Tsc Ls
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
    'tsc',
    '--lsp',
    '--stdio',
  },
  filetypes = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
  },
  root_markers = {
    '.git',
    'bun.lock',
    'bun.lockb',
    'package-lock.json',
    'pnpm-lock.yaml',
    'yarn.lock',
  },
  settings = {
    ['js/ts'] = {
      customConfigFileName = '',
      format = {
        enabled = true,
      },
      inlayHints = {
        parameterNames = {
          enabled = 'none',
        },
      },
      organizeImports = {
        accentCollation = true,
        caseFirst = 'default',
        locale = 'en',
        numericCollation = false,
        sort = 'auto',
        typeOrder = 'auto',
        unicodeCollation = 'ordinal',
      },
      preferences = {
        autoImportEntrypointDirectorySearch = false,
        importModuleSpecifier = 'shortest',
        importModuleSpecifierEnding = 'auto',
        jsxAttributeCompletionStyle = 'auto',
        quoteStyle = 'auto',
      },
      reportStyleChecksAsWarnings = true,
      suggest = {
        autoClosingTags = {
          enabled = true,
        },
        autoImports = true,
        includeCompletionsForImportStatements = true,
        jsdoc = {
          enabled = true,
          generateReturns = true,
        },
      },
      validate = {
        enabled = true,
      },
      workspaceSymbols = {
        excludeLibrarySymbols = true,
        scope = 'allOpenProjects',
      },
    },
  },
}
