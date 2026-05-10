-- /qompassai/Diver/lsp/pyrefly_ls.lua
-- Qompass AI Pyrefly LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------
local function safe_inlay_hints(bufnr)
    local hints = vim.lsp.inlay_hint
    if not hints then
        return
    end
    hints.enable(false, {
        bufnr = bufnr,
    })
    vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            hints.enable(true, {
                bufnr = bufnr,
            })
        end
    end, 150)
end

return ---@type vim.lsp.Config
{
    cmd = {
        'pyrefly',
        'lsp',
    },
    filetypes = {
        'python',
    },
    on_attach = function(client, bufnr)
        require('config.core.lsp').on_attach(client, bufnr)
        client.server_capabilities.semanticTokensProvider = nil
        local augroup = vim.api.nvim_create_augroup('pyrefly_hint_refresh_' .. bufnr, { clear = true })
        vim.api.nvim_create_autocmd('BufWritePre', {
            group = augroup,
            buffer = bufnr,
            callback = function()
                vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
            end,
        })
        vim.api.nvim_create_autocmd('BufWritePost', {
            group = augroup,
            buffer = bufnr,
            callback = function()
                safe_inlay_hints(bufnr)
            end,
        })
    end,
    pythonPath = '/usr/bin/python3',
    root_markers = {
        '.git',
        'mypy.ini',
        'pyproject.toml',
        'pyrefly.toml',
        'requirements.txt',
        'setup.cfg',
        'setup.py',
    },
    settings = {
        pyrefly = {
            displayTypeErrors = 'force-on',
            disableLanguageServices = false,
            extraPaths = {},
            analysis = {
                diagnosticMode = 'workspace',
                importFormat = 'absolute',
                inlayHints = {
                    callArgumentNames = 'off',
                    functionReturnTypes = true,
                    pytestParameters = true,
                    variableTypes = true,
                },
                showHoverGoToLinks = true,
            },
            disabledLanguageServices = {
                codeAction = false,
                completion = false,
                definition = false,
                declaration = false,
                documentHighlight = false,
                documentSymbol = false,
                hover = false,
                implementation = false,
                inlayHint = false,
                references = false,
                rename = false,
                semanticTokens = false,
                signatureHelp = false,
                typeDefinition = false,
            },
        },
    },
    on_exit = function(code, _, _)
        vim.notify('Closing Pyrefly LSP exited with code: ' .. code, vim.log.levels.INFO)
    end,
}
