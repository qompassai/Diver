-- /qompassai/Diver/lsp/tinymist.lua
-- Qompass AI Tinymist LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@param command_name string
---@param client vim.lsp.Client
---@param bufnr integer
---@return fun(), string, string
local function create_tinymist_command(command_name, client, bufnr)
    local export_type = command_name:match('tinymist%.export(%w+)') ---@type string?
    local info_type = command_name:match('tinymist%.(%w+)') ---@type string?
    local raw_name = export_type or info_type or command_name ---@type string
    local cmd_display = raw_name:gsub('^get', 'Get'):gsub('^pin', 'Pin') ---@type string
    local function cmd_func() ---@return nil
        vim.lsp.buf_request(bufnr, command_name, {}, function(err, result, ctx, _)
            local prefix = ('[Tinymist:%s:%s] '):format(client.name or 'tinymist', ctx and ctx.method or command_name)
            if err then
                vim.echo(prefix .. (err.message or tostring(err)), vim.log.levels.ERROR)
                return
            end
            vim.echo(prefix .. 'finished', vim.log.levels.INFO)
            if result ~= nil then
                local bufinfo = ctx and ctx.bufnr and (' (buf ' .. ctx.bufnr .. ')') or ''
                print(prefix .. 'result' .. bufinfo .. ':')
                print(vim.inspect(result))
            end
        end)
    end
    local cmd_name = cmd_display ---@type string
    local cmd_desc = ('Tinymist: %s'):format(cmd_display) ---@type string
    return cmd_func, cmd_name, cmd_desc
end
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'tinymist',
    },
    filetypes = { ---@type string[]
        'typst',
    },
    root_markers = { ---@type string[]
        '.git',
    },
    ---@param client vim.lsp.Client
    on_attach = function(client, bufnr) ---@param bufnr integer
        for _, command in ipairs({
            'tinymist.exportSvg',
            'tinymist.exportPng',
            'tinymist.exportPdf',
            -- 'tinymist.exportHtml',
            'tinymist.exportMarkdown',
            'tinymist.exportText',
            'tinymist.exportQuery',
            'tinymist.exportAnsiHighlight',
            'tinymist.getServerInfo',
            'tinymist.getDocumentTrace',
            'tinymist.getWorkspaceLabels',
            'tinymist.getDocumentMetrics',
            'tinymist.pinMain',
        } --[[@as string[] ]]) do
            local cmd_func, cmd_name, cmd_desc = create_tinymist_command(command, client, bufnr)
            vim.api.nvim_buf_create_user_command(bufnr, 'Lsp' .. cmd_name, cmd_func, {
                nargs = 0,
                desc = cmd_desc,
            })
        end
    end,
}
