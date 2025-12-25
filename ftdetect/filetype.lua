-- /qompassai/Diver/ftdetect/filetype.lua
-- Qompass AI Filetype Detect Filetype Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
if vim.g.do_filetype_lua == 1 then
    vim.filetype.add({
        extension = {
            schelp = 'scdoc',
        },
    })
end
