-- qompassai/Diver/lua/utils/shell.lua
-- Qompass AI Diver CICD Shell Config
---@module 'utils.shell'
local M = {}
function M.sh_filetype_detection()
    vim.filetype.add({
        extension = {
            bash = 'bash',
            fish = 'fish',
            nu = 'nu',
            sh = 'bash',
            zsh = 'zsh',
        },
        pattern = {
            ['.*.bash'] = 'bash',
            ['.*.fish'] = 'fish',
            ['.*.nu'] = 'nu',
            ['.*.sh'] = 'bash',
            ['.*.zsh'] = 'zsh',
            ['.bash*'] = 'bash',
            ['.zsh*'] = 'zsh',
        },
        filename = {
            ['.bashrc'] = 'bash',
            ['.zshrc'] = 'zsh',
            ['config.fish'] = 'fish',
        },
    })
end

return M
