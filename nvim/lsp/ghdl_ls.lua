-- /qompassai/Diver/lsp/ghdl_ls.lua
-- Qompass AI GHDL VHDL LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- https://github.com/ghdl/ghdl/tree/master/pyGHDL/lsp
-- pip install --user pyTooling pyVHDLModel pyVHDLParser
-- git clone https://github.com/ghdl/ghdl.git
-- cd ghdl && pip install .
vim.lsp.config['ghdl_ls'] = {
    cmd = {
        'ghdl-ls',
    },
    filetypes = {
        'vhdl',
        'vhd',
    },
    root_markers = {
        'hdl-prj.json',
        '.git',
    },
}
