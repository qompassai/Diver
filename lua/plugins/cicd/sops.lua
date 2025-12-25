-- qompassai/Diver/lua/plugins/cicd/sops.lua
-- Qompass AI Diver Secret Operatoins (SOPs) Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    'trixnz/sops.nvim',
    lazy = false,
    config = function(_, opts)
        require('config.cicd.sops').sops(opts)
    end,
}
