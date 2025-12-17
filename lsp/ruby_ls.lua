-- /qompassai/Diver/lsp/ruby-lsp.lua
-- Qompass AI Ruby LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@param client vim.lsp.Client
---@param bufnr integer
local function add_ruby_deps_command(client, bufnr)
  vim.api.nvim_buf_create_user_command(bufnr, 'ShowRubyDeps',
    function(opts) ---@param opts { args: string }
      local params = vim.lsp.util.make_text_document_params()
      local showAll = opts.args == 'all'
      vim.lsp.buf_request(bufnr, "rubyLsp/workspace/dependencies", params, function(err, result)
        if err then
          print("Error showing deps: " .. err.message)
          return
        end
        local qf_list = {}
        for _, item in ipairs(result or {}) do
          if showAll or item.dependency then
            table.insert(qf_list, {
              text = string.format("%s (%s) - %s", item.name, item.version, item.dependency),
              filename = item.path,
            })
          end
        end
        vim.fn.setqflist(qf_list)
        vim.cmd("copen")
      end)
    end,
    {
      nargs = '?',
      complete = function()
        return {
          'all'
        }
      end,
    }
  )
end
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'ruby-lsp',
  },
  filetypes = { ---@type string[]
    'ruby',
    'eruby'
  },
  root_markers = { ---@type string[]
    'Gemfile',
    '.git'
  },
  init_options = { ---@type table
    enabledFeatures = {
      codeActions = true,
      codeLens = true,
      completion = true,
      definition = true,
      diagnostics = true,
      documentHighlights = true,
      documentLink = true,
      documentSymbols = true,
      foldingRanges = true,
      formatting = true,
      hover = true,
      inlayHint = true,
      onTypeFormatting = true,
      selectionRanges = true,
      semanticHighlighting = true,
      signatureHelp = true,
      typeHierarchy = true,
      workspaceSymbol = true,
    },
    featuresConfiguration = { ---@type boolean[]
      inlayHint = {
        implicitHashValue = true,
        implicitRescue = true,
      },
      indexing = {
        excludedPatterns = { ---@type string[]
          'log/**',
          'tmp/**',
          'vendor/**',
          'node_modules/**',
          'public/**',
        },
        includedPatterns = { ---@type string[]
          'app/**',
          'config/**',
          'lib/**',
          'test/**',
          'spec/**',
        },
        excludedGems = { ---@type string[]
          'bootsnap',
          'sass-rails',
        },
        excludedMagicComments = { ---@type string[]
          'frozen_string_literal:true',
          'compiled:true'
        },
        formatter = 'standard', ---@type string
        linters = { ---@type string[]
          'standard'
        },
        experimentalFeaturesEnabled = true, ---@type boolean
      },
      addonSettings = {
        ['Ruby LSP Rails'] = {
          enablePendingMigrationsPrompt = true, ---@type boolean
        },
      },
    },
  },
  ---@param client vim.lsp.Client
  ---@param bufnr integer
  on_attach = function(client, bufnr)
    add_ruby_deps_command(client, bufnr)
  end,
}