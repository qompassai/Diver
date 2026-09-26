-- /qompassai/Diver/lua/ai/recon/commands.lua
-- User commands for the recon subsystem.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
-- Requiring this module registers the commands; it starts nothing.
--   :ReconBridge [start|stop|status] [port]  control the WebSocket bridge
--   :ReconSkills                              pick and describe a skill
--   :ReconSkill {name} {target} [args...]     run a skill (gated, logged)
--   :ReconTools                               list CLI tools + availability
--   :ReconAuditLog                            open the invocation audit log
--   :ReconKeygen [classic|hybrid|quantum]     generate a token-signing key
--   :ReconKeys                                list signing keys
--   :ReconToken [mint|show|revoke|list]       manage bridge capability tokens
---@module 'ai.recon.commands'

local M = {}

local function notify(msg, level)
    vim.notify('[recon] ' .. msg, level or vim.log.levels.INFO)
end

---@return string[]
local function complete_skill_names()
    local ok, skills = pcall(require, 'ai.mcp.skills')
    if not ok then
        return {}
    end
    local names = {}
    for _, skill in ipairs(skills.list()) do
        names[#names + 1] = skill.name
    end
    return names
end

local function cmd_bridge(opts)
    local bridge = require('ai.webmcp.bridge')
    local action = opts.fargs[1] or 'status'
    if action == 'start' then
        local port = tonumber(opts.fargs[2]) or 17871
        local status = bridge.start({ port = port })
        if status.running then
            notify(('bridge listening on %s:%d (token required)'):format(status.host, status.port))
            notify('paste a token from :ReconToken mint into the dashboard to connect')
        else
            notify('bridge failed to start: ' .. tostring(status.error), vim.log.levels.ERROR)
        end
    elseif action == 'stop' then
        bridge.stop()
        notify('bridge stopped')
    elseif action == 'status' then
        local status = bridge.status()
        if status.running then
            notify(
                ('bridge up on %s:%d (%d clients, %d authed, token %s)'):format(
                    status.host,
                    status.port,
                    status.clients,
                    status.authed_clients,
                    status.require_token and 'required' or 'off'
                )
            )
        else
            notify('bridge not running')
        end
    else
        notify('usage: ReconBridge [start|stop|status] [port]', vim.log.levels.WARN)
    end
end

local function cmd_keygen(opts)
    local strength = opts.fargs[1] or 'classic'
    if strength ~= 'classic' and strength ~= 'hybrid' and strength ~= 'quantum' then
        notify('usage: ReconKeygen [classic|hybrid|quantum]', vim.log.levels.WARN)
        return
    end
    local pqc = require('ai.security.pqc')
    if not pqc.supports(strength) then
        notify(strength .. ' unavailable (backend=' .. pqc.backend() .. '); needs liboqs', vim.log.levels.ERROR)
        return
    end
    notify('generating ' .. strength .. ' signing key (this takes a moment)...')
    vim.schedule(function()
        local token = require('ai.security.token')
        local key, err = token.generate(strength)
        if key == nil then
            notify('keygen failed: ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        token.set_active('sig-' .. strength)
        notify(('generated %s key (%s), now active for tokens'):format(strength, key.kind))
    end)
end

local function cmd_keys()
    local token = require('ai.security.token')
    local pqc = require('ai.security.pqc')
    local lines = { '# Signing keys (backend: ' .. pqc.backend() .. ')', '' }
    for _, k in ipairs(token.list_keys()) do
        lines[#lines + 1] = ('- %s%s  %s / %s  created %s'):format(
            k.name,
            k.active and '  [active]' or '',
            k.strength or '?',
            k.kind or '?',
            k.created and os.date('%Y-%m-%d', k.created) or '?'
        )
    end
    if #lines == 2 then
        lines[#lines + 1] = '(none yet — run :ReconKeygen)'
    end
    vim.cmd('new')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.filetype = 'markdown'
    vim.bo.readonly = true
    vim.bo.modifiable = false
end

local function cmd_token(opts)
    local token = require('ai.security.token')
    local action = opts.fargs[1] or 'show'
    if action == 'mint' then
        local ttl = tonumber(opts.fargs[2]) or token.DEFAULT_TTL
        if ttl <= 0 or ttl > 2592000 then
            notify('ttl must be 1..2592000 seconds (30 days)', vim.log.levels.WARN)
            return
        end
        local t, err = token.mint('bridge', ttl)
        if t == nil then
            notify('mint failed: ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        vim.fn.setreg('+', t)
        notify('token minted (copied to + register, paste into dashboard)')
    elseif action == 'show' then
        local t, err = token.mint('bridge')
        if t == nil then
            notify('mint failed: ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        vim.fn.setreg('+', t)
        notify('fresh token minted and copied to + register')
    elseif action == 'revoke' then
        local target = opts.fargs[2]
        if target == nil or target == '' then
            notify('usage: ReconToken revoke {token|jti}', vim.log.levels.WARN)
            return
        end
        local ok, err = token.revoke(target)
        if not ok then
            notify('revoke failed: ' .. tostring(err), vim.log.levels.ERROR)
        else
            notify('token revoked')
        end
    elseif action == 'list' then
        cmd_keys()
    else
        notify('usage: ReconToken [mint [ttl]|show|revoke {token|jti}|list]', vim.log.levels.WARN)
    end
end

local function cmd_skills()
    local ok, skills = pcall(require, 'ai.mcp.skills')
    if not ok then
        notify('skills loader unavailable', vim.log.levels.ERROR)
        return
    end
    local list = skills.list()
    if #list == 0 then
        notify('no skills loaded; check :ReconSkills path (skills_dir)', vim.log.levels.WARN)
        return
    end
    local items = {}
    for _, skill in ipairs(list) do
        items[#items + 1] = ('%-32s %-10s %s'):format(skill.name, skill.category, skill.description:sub(1, 60))
    end
    vim.ui.select(items, { prompt = 'Recon skill (shows procedure):' }, function(choice)
        if choice == nil then
            return
        end
        local name = choice:match('^(%S+)')
        local skill = skills.get(name)
        if skill == nil then
            return
        end
        local lines = vim.split(skill.body, '\n', { plain = true })
        vim.cmd('new')
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.bo.filetype = 'markdown'
        vim.bo.readonly = true
        vim.bo.modifiable = false
    end)
end

local function cmd_skill(opts)
    local name = opts.fargs[1]
    local target = opts.fargs[2]
    if name == nil or target == nil then
        notify('usage: ReconSkill {name} {target} [args...]', vim.log.levels.WARN)
        return
    end
    local extra = {}
    for i = 3, #opts.fargs do
        extra[#extra + 1] = opts.fargs[i]
    end
    local ok, skills = pcall(require, 'ai.mcp.skills')
    if not ok then
        notify('skills loader unavailable', vim.log.levels.ERROR)
        return
    end
    notify(('running skill %s against %s ...'):format(name, target))
    skills.execute(name, { target = target, args = extra }, 'command', function(ok2, result)
        if not ok2 then
            notify('skill failed: ' .. tostring(result.error), vim.log.levels.ERROR)
            return
        end
        local lines = { '# ' .. name .. ' -> ' .. target, '' }
        if result.stdout ~= nil then
            for _, line in ipairs(vim.split(result.stdout, '\n', { plain = true })) do
                lines[#lines + 1] = line
            end
        else
            for _, line in ipairs(vim.split(tostring(result.note or 'done'), '\n', { plain = true })) do
                lines[#lines + 1] = line
            end
            if result.procedure ~= nil then
                lines[#lines + 1] = ''
                for _, line in ipairs(vim.split(result.procedure, '\n', { plain = true })) do
                    lines[#lines + 1] = line
                end
            end
        end
        if result.stderr ~= nil and result.stderr ~= '' then
            lines[#lines + 1] = ''
            lines[#lines + 1] = '--- stderr ---'
            for _, line in ipairs(vim.split(result.stderr, '\n', { plain = true })) do
                lines[#lines + 1] = line
            end
        end
        vim.cmd('new')
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.bo.filetype = 'markdown'
        vim.bo.readonly = true
        vim.bo.modifiable = false
        notify('skill finished (code ' .. tostring(result.code) .. ')')
    end)
end

local function cmd_tools()
    local tools = require('ai.recon.tools')
    local lines = { '# Recon CLI tools', '' }
    for _, t in ipairs(tools.list()) do
        lines[#lines + 1] = ('- %-12s [%s] %s %s'):format(
            t.name,
            t.active and 'active' or 'passive',
            t.available and 'installed' or 'MISSING',
            t.desc
        )
    end
    vim.cmd('new')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.filetype = 'markdown'
    vim.bo.readonly = true
    vim.bo.modifiable = false
end

local function cmd_auditlog()
    local auditlog = require('ai.security.auditlog')
    local path = auditlog.path()
    if vim.fn.filereadable(path) ~= 1 then
        notify('audit log is empty (no tool calls recorded yet)')
        return
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

local function cmd_rocks()
    local rocks = require('ai.recon.rocks')
    local lines = { '# Recommended LuaRocks (triaged from awesome-lua)', '' }
    for _, r in ipairs(rocks.report()) do
        lines[#lines + 1] = ('- %-10s [%s] %s'):format(r.rock, r.installed and 'installed' or 'missing', r.why)
        if not r.installed then
            lines[#lines + 1] = '  install: ' .. r.install
        end
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = '## Skipped (Neovim covers natively)'
    for _, s in ipairs(rocks.SKIPPED) do
        lines[#lines + 1] = ('- %-12s covered by %s'):format(s.rock, s.covered_by)
    end
    vim.cmd('new')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.filetype = 'markdown'
    vim.bo.readonly = true
    vim.bo.modifiable = false
end

---Register all :Recon* commands. Idempotent.
function M.register()
    vim.api.nvim_create_user_command('ReconBridge', cmd_bridge, {
        nargs = '*',
        desc = 'Control the WebMCP bridge (start|stop|status)',
    })
    vim.api.nvim_create_user_command('ReconSkills', cmd_skills, {
        nargs = 0,
        desc = 'Browse loaded recon skills',
    })
    vim.api.nvim_create_user_command('ReconSkill', cmd_skill, {
        nargs = '+',
        complete = complete_skill_names,
        desc = 'Run a recon skill against a target',
    })
    vim.api.nvim_create_user_command('ReconTools', cmd_tools, {
        nargs = 0,
        desc = 'List recon CLI tools and availability',
    })
    vim.api.nvim_create_user_command('ReconAuditLog', cmd_auditlog, {
        nargs = 0,
        desc = 'Open the tool-call audit log',
    })
    vim.api.nvim_create_user_command('ReconRocks', cmd_rocks, {
        nargs = 0,
        desc = 'Recommended LuaRocks triaged from awesome-lua',
    })
    vim.api.nvim_create_user_command('ReconKeygen', cmd_keygen, {
        nargs = '?',
        complete = function()
            return { 'classic', 'hybrid', 'quantum' }
        end,
        desc = 'Generate a token-signing key (classic|hybrid|quantum)',
    })
    vim.api.nvim_create_user_command('ReconKeys', cmd_keys, {
        nargs = 0,
        desc = 'List token-signing keys',
    })
    vim.api.nvim_create_user_command('ReconToken', cmd_token, {
        nargs = '*',
        desc = 'Manage bridge capability tokens (mint|show|revoke|list)',
    })
end

return M
