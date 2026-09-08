-- qompassai/Diver/lua/config/data/common.lua
-- Qompass AI Diver Data Common Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.detect_sql_root_dir(fname)
    local util = require('lspconfig.util')
    local root = util.root_pattern('.sqlfluff', '.sqlfluffrc', 'setup.cfg', '.env', 'package.json')(fname)
        or util.root_pattern('.git')(fname)
    return root or vim.fn.getcwd()
end
function M.setup_dadbod_connections(connections_file)
    local connections_path = vim.fn.expand(connections_file or '~/.config/nvim/dbx.lua')
    if vim.fn.filereadable(connections_path) == 1 then
        local ok, connections = pcall(dofile, connections_path)
        if ok and connections then
            vim.g.db_ui_save_location = vim.fn.stdpath('data') .. '/db_ui'
            vim.g.db_ui_connections = connections
        end
    end
end
return M
