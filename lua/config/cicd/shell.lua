-- qompassai/Diver/lua/config/cicd/shell.lua
-- Qompass AI Diver CICD Shell Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.detect_sh_root_dir(fname)
    local root = util.root_pattern('.git')(fname)
    local stat = vim.uv.fs_stat(fname)
    if not stat or stat.type ~= 'file' then
        return root
    end
    local file = io.open(fname, 'r')
    if file then
        local first_line = file:read()
        file:close()
        if type(first_line) == 'string' and first_line:match('^#!') then
            local shells = {
                'sh',
                'zsh',
                'fish',
                'nu',
            }
            for _, shell in ipairs(shells) do
                if first_line:match('^#!.*/' .. shell) then
                    return root or vim.fn.getcwd()
                end
            end
        end
    end
    return root
end

function M.sh_filetype_detection()
    vim.filetype.add({
        extension = {
            sh = 'bash',
            bash = 'bash',
            zsh = 'zsh',
            fish = 'fish',
            nu = 'nu',
        },
        pattern = {
            ['.*.sh'] = 'bash',
            ['.*.bash'] = 'bash',
            ['.bash*'] = 'bash',
            ['.*.zsh'] = 'zsh',
            ['.zsh*'] = 'zsh',
            ['.*.fish'] = 'fish',
            ['.*.nu'] = 'nu',
        },
        filename = {
            ['.bashrc'] = 'bash',
            ['.zshrc'] = 'zsh',
            ['config.fish'] = 'fish',
        },
    })
end

return M
