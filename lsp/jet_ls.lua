#!/usr/bin/env lua

-- jet_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@brief
---
--- https://github.com/aviatesk/JETLS.jl
---
--- For JETLS installation: Use the Julia Apps helper:
--- ```sh
--- julia -e 'using Pkg; Pkg.Apps.add(; url="https://github.com/aviatesk/JETLS.jl", rev="release")'
--- ```
--- To update it, run the same command again

local cmd = {
    'jetls',
    'serve',
}

---@type vim.lsp.Config
return {
    cmd = cmd,
    filetypes = {
        'julia',
    },
    root_markers = {
        'Project.toml',
    },
}
