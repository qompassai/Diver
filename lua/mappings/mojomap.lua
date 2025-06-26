-- ~/.config/nvim/lua/mappings/mojomap.lua
-- ---------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
local M = {}
function M.setup_mojomap()
    vim.api.nvim_create_autocmd("FileType", {
        pattern = {"mojo"},
        callback = function(args)
            if vim.bo[args.buf].filetype ~= "mojo" then return end
            vim.opt_local.tabstop = 4
            vim.opt_local.shiftwidth = 4
            vim.opt_local.expandtab = true
            vim.keymap.set("n", "<leader>mr", ":MojoRun<CR>",
                           {buffer = args.buf, desc = "Run Mojo file"})
            vim.keymap.set("n", "<leader>dmf", ":MojoDebug<CR>",
                           {buffer = args.buf, desc = "Debug Mojo file"})
        end
    })
end
return M
