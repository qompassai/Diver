-- /qompassai/Diver/lsp/basedpy_ls.lua
-- Qompass AI Based Pyright (BasedPy) LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local function set_python_path(command) ---@param command { args: string }
  local path = command.args
  local clients = vim.lsp.get_clients({ ---@type vim.lsp.Client[]
    bufnr = vim.api.nvim_get_current_buf(),
    name = 'basedpyright',
  })
  for _, client in ipairs(clients) do
    if client.settings then
      ---@diagnostic disable-next-line: param-type-mismatch
      client.settings.python = vim.tbl_deep_extend('force', client.settings.python or {}, {
        pythonPath = path,
      })
    else
      client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
        python = {
          pythonPath = path,
        },
      })
    end
    client:notify('workspace/didChangeConfiguration',
      {
        settings = nil,
      })
  end
end
return ---@type vim.lsp.Config
{
  cmd = {
    'basedpyright-langserver',
    '--stdio'
  },
  filetypes = {
    'python',
  },
  root_markers = {
    '.git',
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
    'pyrightconfig.json',
    '.pyrightconfig.json',
    'pyrightconfig.jsonc',
    '.pyrightconfig.jsonc',
  },
  settings = {
    basedpyright = {
      python = {
        pythonPath = "/usr/bin/python3.13",
      },
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = 'openFilesOnly',
        typeCheckingMode = 'strict',
        reportMissingTypeStubs = 'warning',
      },
    },
  },
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'LspPyrightOrganizeImports', function()
      local params = {
        command = 'basedpyright.organizeimports',
        arguments = {
          vim.uri_from_bufnr(bufnr),
        },
      }
      client:request('workspace/executeCommand', params, nil, bufnr)
    end, {
      desc = 'Organize Imports',
    })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspPyrightSetPythonPath', set_python_path, {
      desc = 'Reconfigure basedpyright python path',
      nargs = 1,
      complete = 'file',
    })
  end,
}