-- /qompassai/Diver/lua/plugins/data/sqlite.lua
-- Qompass AI Diver SQLite Plugin Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

return {
    'kkharji/sqlite.lua',
    config = function()
        vim.g.sqlite_clib_path = '/usr/lib/libsqlite3.so'
    end,
}
