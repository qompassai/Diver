-- /qompassai/Diver/lsp/deno.lua
-- Deno Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://docs.deno.com/runtime/reference/lsp_integration/
vim.lsp.config['deno_ls'] = {
  cmd = {
    'deno',
    'lsp',
  },
  filetypes = {
    'javascript',
    'json',
    'jsonc',
    'jsx',
    'markdown',
    'typescriptreact',
    'javascriptreact',
    'tsx',
    'typescript',
  },
  init_options = {
    deno = {
      enable = true,
      unstable = true,
      lint = true,
      certificateStores = {},
      tlsCertificate = '',
      unsafelyIgnoreCertificateErrors = false,
      internalDebug = false,
      codeLens = {
        implementations = true,
        references = true,
        referencesAllFunctions = true,
        test = true,
      },
      suggest = {
        names = true,
        paths = true,
        autoImports = true,
        completeFunctionCalls = true,
        imports = {
          autoDiscover = true,
          hosts = {
            ['https://deno.land'] = true,
            ['https://cdn.nest.land'] = true,
            ['https://crux.land'] = true,
          },
        },
      },
    },
  },
  root_markers = {
    'deno.json',
    'deno.jsonc',
    'tsconfig.json',
    '.git',
  },
}