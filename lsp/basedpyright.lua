-- /qompassai/Diver/lsp/basedpyright.lua
-- Qompass AI Basedpyright LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config["basedpyright"] = {
  cmd = { "basedpyright", "--stdio" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "pyrightconfig.json",
    ".pyrightconfig.json",
    "pyrightconfig.json5",
    ".pyrightconfig.json5",
    ".git",
  },
  initializationOptions = {
    telemetry = { enabled = false },
  },
  single_file_support = true,
  settings = {
    basedpyright = {
      venvPath = vim.fn.expand("~/.pyenv/versions"),
      analysis = {
        typeCheckingMode = "strict",
        diagnosticMode = "workspace",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
  commands = {
    PyrightOrganizeImports = {
      description = "Organize Imports",
    },
    PyrightSetPythonPath = {
      description = "Reconfigure basedpyright with the provided python path",
      nargs = 1,
      complete = "file",
    },
  },
}
