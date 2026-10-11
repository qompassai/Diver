-- /qompassai/Diver/lua/ai/recon/rocks.lua
-- Recommended LuaRocks, triaged from forhappy/awesome-lua.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: the awesome-lua list is mostly a 2015 time
-- capsule (dead links to luaforge and Google Code). Five
-- entries survived triage as genuinely useful and not already
-- covered by Neovim builtins. They are recommended, not
-- required: nothing in lua/ai/recon hard-depends on them.
-- M.check() reports what is installed; M.install_cmd(name)
-- prints the install command.
---@module 'ai.recon.rocks'

local M = {}

---@class RockRec
---@field covers string what it adds over Neovim builtins
---@field rock string luarocks name
---@field why string one-line justification

M.RECOMMENDED = {
    {
        covers = 'Real failure diagnostics; runs under plain nvim -l',
        rock = 'busted',
        why = 'Standard Lua test framework (describe/it) as the hand-rolled suite grows',
    },
    {
        covers = 'Neovim has no grammar engine; treesitter needs a compiled parser per language',
        rock = 'lpeg',
        why = 'PEG grammars for ad-hoc scan-output parsing (nmap/gobuster logs)',
    },
    {
        covers = 'No XML parser builtin',
        rock = 'luaexpat',
        why = 'SAX XML parser: the direct path to reading nmap -oX inside Neovim',
    },
    {
        covers = 'vim.uv has zero TLS support; today this means shelling out to curl/openssl',
        rock = 'luasec',
        why = 'OpenSSL-backed TLS sockets in-process (cert inspection, STARTTLS, raw TLS probes)',
    },
    {
        covers = 'Import per-module; no bloat',
        rock = 'penlight',
        why = 'pl.stringx / pl.pretty: better string and pretty-printing than vim.inspect for nested scan data',
    },
}

---Deliberately skipped: Neovim already covers these natively.
M.SKIPPED = {
    { covered_by = 'vim.uv + native coroutines', rock = 'copas' },
    { covered_by = 'vim.uv.fs_* / vim.fs', rock = 'luafilesystem' },
    { covered_by = 'vim.iter (map/filter/fold since 0.10)', rock = 'luafun' },
    { covered_by = 'vim.notify + vim.log.levels', rock = 'lualogging' },
    { covered_by = 'vim.uv (TCP/UDP) + vim.system curl for HTTP', rock = 'luasocket' },
}

---True when the rock's main module loads.
---@param rock string
---@return boolean
function M.available(rock)
    assert(type(rock) == 'string', 'rock must be a string')
    local mod = rock == 'penlight' and 'pl.stringx' or rock
    return pcall(require, mod)
end

---Install command for a recommended rock.
---@param rock string
---@return string
function M.install_cmd(rock)
    assert(type(rock) == 'string', 'rock must be a string')
    return 'luarocks install --local ' .. rock
end

---Availability report for :ReconRocks.
---@return table[]
function M.report()
    local out = {}
    for _, rec in ipairs(M.RECOMMENDED) do
        out[#out + 1] = {
            install = M.install_cmd(rec.rock),
            installed = M.available(rec.rock),
            rock = rec.rock,
            why = rec.why,
        }
    end
    return out
end

return M
