-- /qompassai/Diver/lsp/checkmake.lua
-- Qompass AI Makefile Lint Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['checkmake_ls'] = {
    cmd = {
        'checkmake',
    },
    filetypes = {
        'make',
        'makefile',
    },
    codeActionProvider = false,
    colorProvider = false,
    semanticTokensProvider = nil,
    settings = {
        checkmake = {},
    },
    on_attach = function(client, bufnr)
        local _ = client ---@diagnostic disable-line: unused-local
        local function run_checkmake()
            bufnr = bufnr or vim.api.nvim_get_current_buf()
            local filename = vim.api.nvim_buf_get_name(bufnr)
            if filename == '' then
                vim.notify('checkmake: buffer has no name', vim.log.levels.WARN)
                return
            end
            vim.fn.jobstart({
                'checkmake',
                filename,
            }, {
                stdout_buffered = true,
                stderr_buffered = true,
                on_stdout = function(_, data)
                    if not data then
                        return
                    end
                    local qf = {}
                    for _, line in ipairs(data) do
                        if line ~= '' then
                            local f, l, c, msg = line:match('^(.-):(%d+):(%d+):%s*(.*)')
                            if f and l and c and msg then
                                table.insert(qf, {
                                    filename = f,
                                    lnum = tonumber(l),
                                    col = tonumber(c),
                                    text = msg,
                                    type = 'W',
                                })
                            end
                        end
                    end
                    if #qf > 0 then
                        vim.fn.setqflist(qf, 'r')
                        vim.cmd('copen')
                    else
                        vim.notify('checkmake: no issues', vim.log.levels.INFO)
                    end
                end,
                on_stderr = function(_, err)
                    if err and err[1] and err[1] ~= '' then
                        vim.notify('checkmake: ' .. table.concat(err, '\n'), vim.log.levels.ERROR)
                    end
                end,
            })
        end
        vim.keymap.set('n', '<leader>ml', run_checkmake, {
            buffer = bufnr,
            desc = 'Lint Makefile with checkmake',
        })
    end,
}
