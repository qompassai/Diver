-- /qompassai/Diver/lsp/robotcode.lua
-- Qompass AI RobotCode LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'robotcode',
        'language-server',
    },
    filetypes = { ---@type string[]
        'robot',
        'resource',
    },
    root_markers = { ---@type string[]
        '.git',
        'Pipfile',
        'pyproject.toml',
        'robot.toml',
    },
    get_language_id = function(_, _)
        return 'robotframework'
    end,
}
