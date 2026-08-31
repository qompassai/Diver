-- #################################################################
-- /qompassai/Diver/lsp/deno_ls.lua
-- Qompass AI Diver Deno LSP Config
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
---@source https://docs.deno.com/runtime/reference/lsp_integration/
---@source https://docs.deno.com/runtime/reference/vscode/
---@source https://docs.deno.com/runtime/reference/deno_json/
---@source https://docs.deno.com/runtime/reference/cli/unstable_flags/

local api = vim.api
local fs = vim.fs
local lsp = vim.lsp

local core_lsp =
  require('config.core.lsp')

local capabilities =
  vim.tbl_deep_extend(
    'force',
    {},
    core_lsp.capabilities,
    {
      experimental = {
        --
        -- Deno's experimental testing protocol requires both the client and
        -- server to advertise `testingApi`.
        --
        testingApi = true,
      },
    }
  )

---@type string[]
local unstable_features = {
  'broadcast-channel',
  'bundle',
  'cron',
  'detect-cjs',
  'kv',
  'lazy-dynamic-imports',
  'net',
  'no-legacy-abort',
  'node-globals',
  'npm-lazy-caching',
  'sloppy-imports',
  'tsgo',
  'unsafe-proto',
  'webgpu',
  'worker-options',
}

---@param filename string
---@return string?
local function find_deno_root(filename)
  if filename == '' then
    return nil
  end

  return fs.root(
    filename,
    {
      'deno.json',
      'deno.jsonc',
    }
  )
end

---@param _ lsp.InitializeParams?
---@param config vim.lsp.Config
---@return boolean?
local function before_init(_, config)
  local bufnr =
    api.nvim_get_current_buf()

  local filename =
    api.nvim_buf_get_name(bufnr)

  if filename == '' then
    return false
  end

  local root =
    find_deno_root(filename)

  --
  -- Tiger boundary:
  --
  -- Never enable Deno merely because a source buffer happens to use a
  -- JavaScript / TypeScript filetype. A deno.json or deno.jsonc must own the
  -- workspace.
  --
  if root == nil then
    return false
  end

  config.root_dir =
    root

  config.workspace_folders = {
    {
      name =
        fs.basename(root),

      uri =
        vim.uri_from_fname(root),
    },
  }

  return true
end

---@param client vim.lsp.Client
---@param bufnr integer
local function cache_dependencies(
  client,
  bufnr
)
  client:request(
    'workspace/executeCommand',
    {
      command =
        'deno.cache',

      arguments = {
        {
          referrer =
            vim.uri_from_bufnr(
              bufnr
            ),

          uris = {},
        },
      },
    },
    nil,
    bufnr
  )
end

---@param client vim.lsp.Client
local function reload_configuration(client)
  client:notify(
    'workspace/didChangeConfiguration',
    {
      settings =
        client.config.settings,
    }
  )
end

---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach(client, bufnr)
  core_lsp.on_attach(
    client,
    bufnr
  )

  api.nvim_buf_create_user_command(
    bufnr,
    'DenoCache',
    function()
      cache_dependencies(
        client,
        bufnr
      )
    end,
    {
      desc =
        'Cache Deno dependencies',
    }
  )

  api.nvim_buf_create_user_command(
    bufnr,
    'DenoReload',
    function()
      reload_configuration(
        client
      )
    end,
    {
      desc =
        'Reload Deno workspace configuration',
    }
  )

  api.nvim_buf_create_user_command(
    bufnr,
    'DenoRestart',
    function()
      local client_id =
        client.id

      client:stop(true)

      vim.schedule(
        function()
          lsp.enable(
            'deno_ls',
            true
          )

          vim.notify(
            ('Restarted Deno LSP client %d'):format(
              client_id
            ),
            vim.log.levels.INFO
          )
        end
      )
    end,
    {
      desc =
        'Restart Deno language server',
    }
  )
end

return ---@type vim.lsp.Config
{
  before_init =
    before_init,

  capabilities =
    capabilities,

  cmd = {
    'deno',
    'lsp',
  },

  filetypes = {
    'javascript',
    'javascriptreact',
    'jsx',
    'tsx',
    'typescript',
    'typescriptreact',
  },

  init_options = {
    --
    -- Initialization options are kept intentionally aligned with workspace
    -- settings so Deno starts with the same policy before its first
    -- workspace/configuration request.
    --
    cache = nil,

    certificateStores = {
      'mozilla',
      'system',
    },

    config = nil,

    enable = true,

    enablePaths = {},

    importMap = nil,

    internalDebug = true,

    lint = true,

    tlsCertificate = nil,

    unstable =
      unstable_features,

    unsafelyIgnoreCertificateErrors = {},
  },

  on_attach =
    on_attach,

  root_markers = {
    'deno.json',
    'deno.jsonc',
  },

  settings = {
    deno = {
      cache = nil,

      certificateStores = {
        'mozilla',
        'system',
      },

      codeLens = {
        implementations = true,

        references = true,

        referencesAllFunctions = true,

        test = true,

        testArgs = {
          '--allow-all',

          --
          -- Enable all current granular unstable runtime features for tests.
          --
          '--unstable-broadcast-channel',
          '--unstable-bundle',
          '--unstable-cron',
          '--unstable-detect-cjs',
          '--unstable-kv',
          '--unstable-lazy-dynamic-imports',
          '--unstable-net',
          '--unstable-no-legacy-abort',
          '--unstable-node-globals',
          '--unstable-npm-lazy-caching',
          '--unstable-sloppy-imports',
          '--unstable-tsgo',
          '--unstable-unsafe-proto',
          '--unstable-webgpu',
          '--unstable-worker-options',
        },
      },

      config = nil,

      documentPreloadLimit = 10000,

      enable = true,

      enablePaths = {},

      importMap = nil,

      inlayHints = {
        enumMemberValues = {
          enabled = true,
        },

        functionLikeReturnTypes = {
          enabled = true,
        },

        parameterNames = {
          enabled = 'all',

          suppressWhenArgumentMatchesName =
            false,
        },

        parameterTypes = {
          enabled = true,
        },

        propertyDeclarationTypes = {
          enabled = true,
        },

        variableTypes = {
          enabled = true,

          suppressWhenTypeMatchesName =
            false,
        },
      },

      internalDebug = true,

      --
      -- nil means "do not start an inspector automatically".
      --
      -- Set to a concrete port only when actively debugging the Deno language
      -- server itself.
      --
      internalInspect = nil,

      lint = true,

      maxTsServerMemory = 8192,

      organizeImports = {
        enabled = true,
      },

      suggest = {
        autoImports = true,

        completeFunctionCalls =
          true,

        imports = {
          autoDiscover = true,

          hosts = {
            ['https://cdn.jsdelivr.net'] =
              true,

            ['https://deno.land'] =
              true,

            ['https://esm.sh'] =
              true,

            ['https://gist.githubusercontent.com'] =
              true,

            ['https://jsr.io'] =
              true,

            ['https://raw.esm.sh'] =
              true,

            ['https://raw.githubusercontent.com'] =
              true,
          },
        },

        names = true,

        paths = true,
      },

      symbols = {
        document = {
          enabled = true,
        },

        workspace = {
          enabled = true,
        },
      },

      testing = {
        args = {
          '--allow-all',

          '--unstable-broadcast-channel',
          '--unstable-bundle',
          '--unstable-cron',
          '--unstable-detect-cjs',
          '--unstable-kv',
          '--unstable-lazy-dynamic-imports',
          '--unstable-net',
          '--unstable-no-legacy-abort',
          '--unstable-node-globals',
          '--unstable-npm-lazy-caching',
          '--unstable-sloppy-imports',
          '--unstable-tsgo',
          '--unstable-unsafe-proto',
          '--unstable-webgpu',
          '--unstable-worker-options',
        },

        enable = true,
      },

      tlsCertificate = nil,

      --
      -- Current Deno versions accept an array of granular unstable feature
      -- names instead of relying on the deprecated blanket --unstable flag.
      --
      unstable =
        unstable_features,

      --
      -- Intentionally empty:
      --
      -- enabling every feature should not require globally disabling TLS
      -- verification.
      --
      unsafelyIgnoreCertificateErrors = {},
    },

    javascript = {
      inlayHints = {
        enumMemberValues = {
          enabled = true,
        },

        functionLikeReturnTypes = {
          enabled = true,
        },

        parameterNames = {
          enabled = 'all',

          suppressWhenArgumentMatchesName =
            false,
        },

        parameterTypes = {
          enabled = true,
        },

        propertyDeclarationTypes = {
          enabled = true,
        },

        variableTypes = {
          enabled = true,

          suppressWhenTypeMatchesName =
            false,
        },
      },

      preferences = {
        autoImportFileExcludePatterns = {},

        importModuleSpecifier =
          'shortest',

        jsxAttributeCompletionStyle =
          'auto',

        preferTypeOnlyAutoImports =
          true,

        quoteStyle =
          'single',

        useAliasesForRenames =
          true,
      },

      suggest = {
        autoImports = true,

        classMemberSnippets = {
          enabled = true,
        },

        completeFunctionCalls =
          true,

        enabled = true,

        includeAutomaticOptionalChainCompletions =
          true,

        includeCompletionsForImportStatements =
          true,

        names = true,

        objectLiteralMethodSnippets = {
          enabled = true,
        },

        paths = true,
      },

      updateImportsOnFileMove = {
        enabled = 'always',
      },
    },

    typescript = {
      inlayHints = {
        enumMemberValues = {
          enabled = true,
        },

        functionLikeReturnTypes = {
          enabled = true,
        },

        parameterNames = {
          enabled = 'all',

          suppressWhenArgumentMatchesName =
            false,
        },

        parameterTypes = {
          enabled = true,
        },

        propertyDeclarationTypes = {
          enabled = true,
        },

        variableTypes = {
          enabled = true,

          suppressWhenTypeMatchesName =
            false,
        },
      },

      preferences = {
        autoImportFileExcludePatterns = {},

        importModuleSpecifier =
          'shortest',

        jsxAttributeCompletionStyle =
          'auto',

        preferTypeOnlyAutoImports =
          true,

        quoteStyle =
          'single',

        useAliasesForRenames =
          true,
      },

      suggest = {
        autoImports = true,

        classMemberSnippets = {
          enabled = true,
        },

        completeFunctionCalls =
          true,

        enabled = true,

        includeAutomaticOptionalChainCompletions =
          true,

        includeCompletionsForImportStatements =
          true,

        names = true,

        objectLiteralMethodSnippets = {
          enabled = true,
        },

        paths = true,
      },

      updateImportsOnFileMove = {
        enabled = 'always',
      },
    },
  },
}