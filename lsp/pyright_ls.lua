-- /qompassai/Diver/lsp/pyright.lua
-- Qompass AI Python LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@param command { args: string }
local function set_python_path(command) ---@return nil|string
    local path = command.args
    local Clients = vim.lsp.get_clients({ ---@type vim.lsp.Client[]
        bufnr = vim.api.nvim_get_current_buf(),
        name = 'pyright',
    })
    for _, Client in ipairs(Clients) do
        local settings = Client.settings or Client.config.settings or {} ---@type table<string, boolean|string|number|unknown[]|vim.NIL>
        ---@type { pythonPath: string }
        local python = { pythonPath = path }
        settings.python = python
        if Client.settings ~= nil then
            Client.settings = settings
        else
            Client.config.settings = settings
        end
        Client:notify('workspace/didChangeConfiguration', { settings = nil })
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
        vim.api.nvim_buf_create_user_command(
            bufnr,
            'LspPyrightOrganizeImports',
            function(opts) ---@param opts { fargs?: string[], args?: string|string[] }
                local args = opts.fargs or opts.args or {}
                local silent = args[1] == 'silent' ---@cast args string[]
                local params = { ---@type lsp.ExecuteCommandParams
                    command = 'pyright.organizeimports',
                    arguments = { vim.uri_from_bufnr(bufnr) },
                }
                vim.lsp.buf_request(
                    bufnr,
                    'workspace/executeCommand',
                    params,
                    function(err) ---@param err lsp.ResponseError|nil
                        if err and not silent then
                            vim.echo(
                                ('[%s] Organize imports failed: %s'):format(client.name, err.message),
                                vim.log.levels.ERROR
                            )
                        end
                    end
                )
            end,
            {
                desc = 'Organize Imports',
                nargs = '?',
            }
        )
        vim.api.nvim_buf_create_user_command(bufnr, 'LspPyrightSetPythonPath', set_python_path, {
            desc = ('Reconfigure %s with the provided python path'):format(client.name),
            nargs = 1,
            complete = 'file',
        })
    end,
}
