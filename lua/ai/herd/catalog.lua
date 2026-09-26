-- /qompassai/Diver/lua/ai/herd/catalog.lua
-- Qompass AI herd Agent CLI Catalog (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Curated catalog of interactive coding-agent CLIs the herd spawner may
-- launch. Pure data plus `vim.fn.executable` probes: no subprocesses are
-- spawned here and no shell strings are built.
--
-- No-invented-names policy: an entry exists only when its binary name is
-- certain, verified against the vendor's own docs, repo, or install
-- instructions. A plausible brand name, a model name, or an npm package
-- that installs a differently-named binary is not enough. Names that
-- could not be verified are omitted and reported in the delivery report,
-- never guessed into the table.
--
-- launch_argv returns the bare interactive argv ({ cli }) with no
-- initial-prompt flags: the task text is pasted into the launched pane
-- by the spawner, so CLI-specific prompt flags are not invented here.

local M = {}

local NAME_LENGTH_MAX = 64

---@class HerdCliEntry
---@field name string Catalog key; always the executable binary name.
---@field label string Human-readable name for menus and prompts.
---@field cli string Executable binary name as found on PATH.
---@field launch_argv fun(): string[] Bare interactive argv, freshly built.

---Build one catalog entry. The argv method closes over the entry table
---so `entry.launch_argv()` and `entry:launch_argv()` both work, and each
---call returns a fresh table the caller may mutate freely.
---@param name string
---@param label string
---@param cli string
---@return HerdCliEntry
local function make_entry(name, label, cli)
    assert(type(name) == 'string', 'name must be a string')
    assert(#name >= 1 and #name <= NAME_LENGTH_MAX, 'name length out of bounds')
    assert(type(label) == 'string' and #label >= 1, 'label must be non-empty')
    assert(type(cli) == 'string' and #cli >= 1, 'cli must be non-empty')
    local entry = { name = name, label = label, cli = cli }
    entry.launch_argv = function()
        return { entry.cli }
    end
    return entry
end

---Fixed catalog in deterministic (alphabetical) order. Binary names:
---claude (Anthropic Claude Code docs), codex (OpenAI Codex CLI docs),
---cursor-agent (Cursor docs), opencode (opencode docs), copilot (GitHub
---Copilot CLI: docs.github.com shows `copilot --version` and a bare
---`copilot` to start a session), grok (xai-org/grok-build README: the
---official install ships the Rust artifact renamed as `grok`).
---@type HerdCliEntry[]
M.CATALOG = {
    make_entry('claude', 'Claude Code', 'claude'),
    make_entry('codex', 'OpenAI Codex CLI', 'codex'),
    make_entry('copilot', 'GitHub Copilot CLI', 'copilot'),
    make_entry('cursor-agent', 'Cursor Agent', 'cursor-agent'),
    make_entry('grok', 'Grok Build', 'grok'),
    make_entry('opencode', 'opencode', 'opencode'),
}

---Return the entry whose name matches exactly (case-sensitive), or nil
---when no entry has that name.
---@param name string
---@return HerdCliEntry?
function M.get(name)
    assert(type(name) == 'string', 'name must be a string')
    assert(#name >= 1, 'name must be non-empty')
    for _, entry in ipairs(M.CATALOG) do
        if entry.name == name then
            return entry
        end
    end
    return nil
end

---List the catalog entries whose binary is executable on PATH, in
---CATALOG order. Performs executable probes only; no subprocesses, no
---other I/O.
---@return { name: string, label: string, cli: string }[]
function M.detect_all()
    local found = {}
    for _, entry in ipairs(M.CATALOG) do
        if vim.fn.executable(entry.cli) == 1 then
            found[#found + 1] = {
                name = entry.name,
                label = entry.label,
                cli = entry.cli,
            }
        end
    end
    return found
end

return M
