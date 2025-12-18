-- /qompassai/Diver/lsp/pyright.lua
-- Qompass AI Python LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@param command { args: string }
local function set_python_path(command) ---@return nil
    local path = command.args
    local clients = vim.lsp.get_clients({
        bufnr = vim.api.nvim_get_current_buf(),
        name = 'pyright',
    })
    for _, client in ipairs(clients) do
        if client.settings then
            client.settings.python = vim.tbl_deep_extend('force', client.settings.python --[[@as table]], {
                pythonPath = path,
            })
        else
            client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
                python = {
                    pythonPath = path,
                },
            })
        end
        client:notify('workspace/didChangeConfiguration', {
            settings = nil,
        })
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
    ---Pyright Buffer AutoCmds
    ---@param client vim.lsp.Client
    ---@param bufnr integer
    ---@return nil
    on_attach = function(client, bufnr)
        if client.name ~= 'pyright' then
            return
        end
        vim.api.nvim_buf_create_user_command(bufnr, 'LspPyrightOrganizeImports', function(opts)
            local args = opts.fargs or opts.args or {}
            local silent = args[1] == 'silent'
            local params = {
                command = 'pyright.organizeimports',
                arguments = { vim.uri_from_bufnr(bufnr) },
            }
            vim.lsp.buf_request(bufnr, 'workspace/executeCommand', params, function(err)
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
