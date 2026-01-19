-- /qompassai/Diver/fixer/alejandra.lua
-- Qompass AI Alejandra Nix Fixer Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = 'alejandra',
    stdin = true,
    append_fname = false,
    args = {},
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
        if output == '' then
            return {}
        end
        return {
            {
                lnum = 0,
                end_lnum = 0,
                col = 0,
                end_col = 0,
                severity = vim.diagnostic.severity.ERROR,
                source = 'alejandra',
                message = output,
            },
        }
    end,
}
