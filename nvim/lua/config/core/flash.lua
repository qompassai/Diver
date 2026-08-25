-- /qompassai/Diver/lua/config/core/flash.lua
-- Qompass AI Diver Core Flash Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}

---@param extra table|nil
function M.flash_opts(extra) ---@return table[]
    local o = {
        modes = {
            search = {
                enabled = true,
                highlight = {
                    backdrop = true,
                },
                jump = {
                    history = true,
                    register = true,
                    nohlsearch = true,
                },
            },
            char = { ---@type table[]
                enabled = true,
                config = function(opts)
                    opts.autohide = vim.fn.mode(true):find('no') and vim.v.operator == 'y'
                end,
                chars = { ---@type string[]
                    'f',
                    'F',
                    't',
                    'T',
                    ';',
                    ',',
                },
                keys = { ---@type string[]
                    'f',
                    'F',
                    't',
                    'T',
                    ';',
                    ',',
                },
            },
            treesitter = {
                labels = 'abcdefghijklmnopqrstuvwxyz',
                jump = {
                    pos = 'start',
                },
                search = {
                    incremental = true,
                },
            },
        },
        prompt = { ---@type table[]
            enabled = true,
            prefix = {
                {
                    '⚡',
                    'FlashPromptIcon',
                },
            },
        },
    }
    if extra then
        o = vim.tbl_deep_extend('force', o, extra)
    end
    return o
end

function M.flash_cfg(extra)
    require('flash').setup(M.flash_opts(extra))
end

return M