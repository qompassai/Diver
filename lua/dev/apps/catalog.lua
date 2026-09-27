-- lua/dev/apps/catalog.lua
-- Qompass AI Diver Dev Apps Catalog
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------------------------------------------
-- Seeded catalog of interactive CLI/TUI applications from Matt's dotfiles
-- (~/.config). Entries are DATA, not modules: adding an application is a few
-- lines here, never a new file. Schema is DevAppSpec below; init.lua
-- validates every entry at setup().
-- ----------------------------------------------------------------------------

---@class DevAppSpec
---@field cmd string[] argv to execute; cmd[1] must be on PATH
---@field desc string one-line description (picker label and :AppsInfo)
---@field kind 'float'|'split'|'tab' where the terminal opens; default 'float'
---@field ctx 'none'|'file'|'root' working-directory context; default 'none'
---@field env table<string, string>? extra environment variables for the child
---@field args string[]? extra argv appended after cmd at launch

---@type table<string, DevAppSpec>
local catalog = {
    btop = {
        cmd = { 'btop' },
        desc = 'Resource monitor (CPU, memory, disks, network)',
        kind = 'float',
    },
    discordo = {
        cmd = { 'discordo' },
        desc = 'Terminal Discord client',
        kind = 'tab',
    },
    ipython = {
        cmd = { 'ipython' },
        desc = 'Interactive Python shell',
        kind = 'split',
        ctx = 'root',
    },
    irssi = {
        cmd = { 'irssi' },
        desc = 'Terminal IRC client',
        kind = 'tab',
    },
    jupyter = {
        cmd = { 'jupyter', 'console' },
        desc = 'Jupyter console in the terminal',
        kind = 'split',
        ctx = 'root',
    },
    khal = {
        cmd = { 'khal', 'interactive' },
        desc = 'Terminal calendar',
        kind = 'float',
    },
    lynx = {
        cmd = { 'lynx' },
        desc = 'Terminal web browser',
        kind = 'tab',
    },
    neomutt = {
        cmd = { 'neomutt' },
        desc = 'Terminal email client',
        kind = 'tab',
    },
}

return catalog
