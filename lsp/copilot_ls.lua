-- /qompassai/Diver/lsp/copilot_ls.lua
-- Qompass AI CoPilot LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@alias CopilotCustomMethod '"signIn"'|'"signOut"'

---@class CopilotSignInCommandCtx
---@field userCode string
---@field command lsp.Command
---@field status? string
---@field user? string
---@field verificationUri? string
---@class CopilotSignOutResult
---@field status string
---@param client vim.lsp.Client
---@param method CopilotCustomMethod|string
---@param params table|nil
---@param handler lsp.Handler
---@param bufnr integer|nil
local function copilot_request(client, method, params, handler, bufnr)
    ---@cast method string
    client:request(method, params, handler, bufnr)
end
---@param bufnr integer
local function sign_in(bufnr, client) ---@param client vim.lsp.Client
    copilot_request(
        client,
        'signIn',
        nil, ---@param result CopilotSignInCommandCtx|nil
        function(err, result) ---@param err lsp.ResponseError|nil
            if err then
                vim.echo({
                    {
                        err.message,
                        'ErrorMsg',
                    },
                }, false)
                return
            end
            if not result then
                return
            end
            if result.command ~= nil and result.userCode ~= nil then
                local code = result.userCode
                local command = result.command
                vim.fn.setreg('+', code)
                vim.fn.setreg('*', code)
                local continue = vim.fn.confirm(
                    'Copied your one-time code to clipboard.\n' .. 'Open the browser to complete the sign-in process?',
                    '&Yes\n&No'
                )
                if continue == 1 then
                    ---@param cmd_err lsp.ResponseError|nil
                    ---@param cmd_result { status: string, user?: string }|nil
                    client:exec_cmd(command, { bufnr = bufnr }, function(cmd_err, cmd_result)
                        if cmd_err then
                            vim.echo({
                                {
                                    cmd_err.message,
                                    'ErrorMsg',
                                },
                            }, false)
                            return
                        end
                        if cmd_result ~= nil and cmd_result.status == 'OK' and cmd_result.user ~= nil then
                            vim.echo({
                                {
                                    'Signed in as ' .. cmd_result.user .. '.',
                                    'None',
                                },
                            }, false)
                        end
                    end)
                end
            end
            if result.status == 'PromptUserDeviceFlow' and result.userCode and result.verificationUri then
                vim.echo({
                    {
                        'Enter your one-time code ' .. result.userCode .. ' in ' .. result.verificationUri,
                        'None',
                    },
                }, false)
            elseif result.status == 'AlreadySignedIn' and result.user then
                vim.echo({
                    {
                        'Already signed in as ' .. result.user .. '.',
                        'None',
                    },
                }, false)
            end
        end,
        bufnr
    )
end
---@param client vim.lsp.Client
local function sign_out(client)
    ---@param err lsp.ResponseError|nil
    ---@param result CopilotSignOutResult|nil
    copilot_request(client, 'signOut', nil, function(err, result)
        if err then
            vim.echo({ { err.message, 'ErrorMsg' } }, false)
            return
        end
        if not result then
            return
        end
        if result.status == 'NotSignedIn' then
            vim.echo({
                {
                    'Not signed in.',
                    'None',
                },
            }, false)
        end
    end, nil)
end
---@type vim.lsp.Config
return {
    cmd = {
        'copilot-language-server',
        '--stdio',
    },
    root_markers = {
        '.git',
    },
    init_options = {
        editorInfo = {
            name = 'Neovim',
            version = tostring(vim.version()),
        },
        editorPluginInfo = {
            name = 'Neovim',
            version = tostring(vim.version()),
        },
    },
    settings = {
        telemetry = {
            telemetryLevel = 'none',
        },
    },
    on_attach = function(client, bufnr)
        vim.api.nvim_buf_create_user_command(bufnr, 'LspCopilotSignIn', function()
            sign_in(bufnr, client)
        end, {
            desc = 'Sign in Copilot with GitHub',
        })
        vim.api.nvim_buf_create_user_command(bufnr, 'LspCopilotSignOut', function()
            sign_out(client)
        end, {
            desc = 'Sign out Copilot with GitHub',
        })
    end,
}
