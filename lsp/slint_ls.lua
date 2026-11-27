-- /qompassai/Diver/lsp/slint_ls.lua
-- Qompass AI Slint (formerly SixyFPS) LSP Spec
vim.cmd([[ autocmd BufRead,BufNewFile *.slint set filetype=slint ]])
---@type vim.lsp.Config
return {
    capabilities = require('config.core.lsp').capabilities,
    cmd = { ---@type string[]
        'slint-lsp',
    },
    filetypes = { ---@type string[]
        'slint',
    },
    on_attach = function(client, bufnr)
        -- slint-lsp 1.14.1 advertises codeActionProvider as a bare
        -- `true` (probed 2026-11-26): it publishes no codeActionKinds,
        -- so the kinds are read from the live client at runtime and
        -- never hardcoded. Its headline action is Show Preview, which
        -- also rides the executeCommandProvider below.
        if client.server_capabilities.codeActionProvider then
            vim.api.nvim_buf_create_user_command(bufnr, 'LspSlintCodeAction', function()
                local provider = client.server_capabilities.codeActionProvider
                local kinds = type(provider) == 'table' and provider.codeActionKinds or nil
                vim.lsp.buf.code_action({
                    context = {
                        diagnostics = {},
                        only = kinds,
                    },
                })
            end, {
                desc = 'Run Slint code actions',
            })
        end
        -- executeCommandProvider (probed 1.14.1) advertises exactly
        -- slint/populate and slint/showPreview. showPreview takes
        -- [file uri, component name] (upstream
        -- create_show_preview_command); the component defaults to
        -- the word under the cursor (a component definition name).
        vim.api.nvim_buf_create_user_command(bufnr, 'LspSlintShowPreview', function(opts)
            local component = opts.args ~= '' and opts.args or vim.fn.expand('<cword>')
            client:exec_cmd({
                arguments = {
                    vim.uri_from_bufnr(bufnr),
                    component,
                },
                command = 'slint/showPreview',
                title = 'Show Preview',
            }, {
                bufnr = bufnr,
            }, function(err)
                if err then
                    vim.notify('Show Preview failed: ' .. err.message, vim.log.levels.ERROR)
                end
            end)
        end, {
            desc = 'Show Slint live preview for a component',
            nargs = '?',
        })
    end,
    root_dir = function(bufnr, on_dir)
        local root = vim.fs.root(bufnr, { 'Cargo.toml', '.git' })
        if root == nil then
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            if bufname ~= '' then
                root = vim.fs.dirname(bufname)
            end
        end
        if root ~= nil then
            on_dir(root)
        end
    end,
    root_markers = { ---@type string[]
        'Cargo.toml',
        '.git',
    },
    -- slint-lsp 1.14.1 documents no workspace settings (upstream:
    -- "no arguments are required"); import/library paths are
    -- per-project compiler inputs (CLI -I/-L), not global settings,
    -- so this stays empty rather than inventing keys.
    settings = {},
}
