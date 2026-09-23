-- Native :checkhealth acp.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local M = {}
function M.check()
    local health, config = vim.health, require('acp.config')
    health.start('Diver agent protocols')
    if vim.fn.has('nvim-0.13') == 1 then
        health.ok('Neovim 0.13+')
    else
        health.error('Neovim 0.13+ required')
    end
    if vim.fn.executable(config.options.curl) == 1 then
        health.ok('curl available')
    else
        health.error('Install curl (Arch: pacman -S curl)')
    end
    for _, name in ipairs(config.names()) do
        local agent = config.options.agents[name]
        health.info(name .. ': ' .. agent.protocol .. ' — ' .. agent.url)
        if agent.token_env and not vim.env[agent.token_env] then
            health.warn(name .. ': missing credential environment variable ' .. agent.token_env)
        end
    end
    if #config.names() == 0 then
        health.warn('No trusted agent endpoints configured')
    end
    health.info('A2A JSONRPC 1.0 / explicit 0.3; Communication ACP is a legacy adapter')
    health.info('Context CLI is optional; project documents are selected explicitly')
end
return M
