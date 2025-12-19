-- /qompassai/Diver/lsp/pyright.lua
-- Qompass AI Python LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@param command { args: string }
local function set_python_path(command) ---@return nil
  local path = command.args
  local clients = vim.lsp.get_clients({ ---@type vim.lsp.Client[]
    bufnr = vim.api.nvim_get_current_buf(),
    name = 'pyright',
  })
  for _, client in ipairs(clients) do
    local settings = client.settings or client.config.settings or
        {} ---@type table<string, boolean|string|number|unknown[]|vim.NIL>
    ---@type { pythonPath: string }
    local python = { pythonPath = path }
    settings.python = python
    if client.settings ~= nil then
      client.settings = settings
    else
      client.config.settings = settings
    end
    client:notify('workspace/didChangeConfiguration', { settings = nil })
  end
end
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'pyright',
    '--stdio',
    '--pythonplatform',
    'linux',
  },
  filetypes = { ---@type string[]
    'python',
  },
  root_markers = { ---@type string[]
    '.git',
    'Pipfile',
    'pyproject.toml',
    'pyrightconfig.json',
    'requirements.txt',
    'setup.cfg',
    'setup.py',
  },
  settings = { ---@type table
    python = {
      analysis = {
        autoImportCompletions = true,
        autoSearchPaths = true,
        diagnosticMode = 'openFilesOnly',
        extraPaths = {
          './src',
          './lib',
        },
        stubPath = 'typings',
        typeCheckingMode = 'strict',
        useLibraryCodeForTypes = true,
      },
    },
  },
  ---Pyright AutoCmds
  ---@param bufnr integer
  on_attach = function(client, bufnr) ---@param client vim.lsp.Client
    if client.name ~= 'pyright' then
      return ---@return nil
    end
    vim.api.nvim_buf_create_user_command(bufnr, 'LspPyrightOrganizeImports',
      function(opts) ---@param opts { fargs?: string[], args?: string|string[] }
        local args = opts.fargs or opts.args or {}
        local silent = args[1] == 'silent' ---@cast args string[]
        local params = { ---@type lsp.ExecuteCommandParams
          command = 'pyright.organizeimports',
          arguments = { vim.uri_from_bufnr(bufnr) },
        }
        vim.lsp.buf_request(bufnr, 'workspace/executeCommand', params,
          function(err) ---@param err lsp.ResponseError|nil
            if err and not silent then
              vim.notify(
                ('[%s] Organize imports failed: %s'):format(client.name, err.message),
                vim.log.levels.ERROR
              )
            end
          end)
      end, {
        desc = 'Organize Imports',
        nargs = '?',
      })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspPyrightSetPythonPath', set_python_path, {
      desc = ('Reconfigure %s with the provided python path'):format(client.name),
      nargs = 1,
      complete = 'file',
    })
  end,
}