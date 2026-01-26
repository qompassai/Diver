-- /qompassai/Diver/lsp/muon.lua
-- Qompass AI Diver Muon LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return {
    cmd = {
        'muon',
        'analyze',
        'lsp',
    },
    filetypes = {
        'meson',
    },
    root_dir = function(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        local cmd = {
            'muon',
            'analyze',
            'root-for',
            fname,
        }
        vim.system(cmd, { text = true }, function(output)
            if output.code == 0 then
                if output.stdout then
                    on_dir(vim.trim(output.stdout))
                    return
                end
                on_dir(nil)
            else
                vim.schedule(function()
                    vim.notify(
                        string.format(
                            '[muon] cmd failed with code %d: %s\n%s',
                            output.code,
                            table.concat(cmd, ' '),
                            output.stderr or ''
                        ),
                        vim.log.levels.ERROR
                    )
                end)
            end
        end)
    end,
}