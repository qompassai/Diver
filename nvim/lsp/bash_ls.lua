-- /qompassai/Diver/lsp/bash_ls.lua
-- Qompass AI Bash LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'bash-language-server',
    'start',
  },
  filetypes = {
    'bash',
    'sh',
  },
  root_markers = {
    '.git',
  },
  settings = {
    bashIde = {
      backgroundAnalysisMaxFiles = 500,
      globPattern = vim.env.GLOB_PATTERN or '*@(.sh|.inc|.bash|.command)',
      logLevel = 'warning',
      maxNumberOfProblems = 200,
      shellcheck = {
        enable = true,
        executablePath = 'shellcheck',
        severity = {
          error = 'error',
          info = 'info',
          style = 'info',
          warning = 'warning',
        },
      },
      completion = {
        enabled = true,
        includeDirs = {
          '$XDG_CONFIG_HOME/bash-completion',
          '$XDG_CONFIG_HOME/bash-completion.d',
        },
      },
      diagnostics = {
        enabled = true,
      },
      shfmt = {
        binaryNextLine = true,
        caseIndent = true,
        funcNextLine = true,
        ignoreEditorconfig = false,
        indent = 2,
        keepPadding = false,
        languageDialect = 'auto',
        path = 'shfmt',
        simplifyCode = true,
        spaceRedirects = true,
      },
      explainshellEndpoint = vim.env.EXPLAINSHELL_ENDPOINT or nil,
    },
  },
}
