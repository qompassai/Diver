-- ~/.config/nvim/lua/dap/d.lua
-- Qompass AI Diver D DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- There is no D-specific debug adapter upstream: serve-d is an
-- LSP server only, and D tooling debugs through native adapters.
-- LDC (ldc2 -g) and DMD (-g) emit DWARF, and LLVM's LLDB carries
-- D support in-tree (the D demangler and D type handling in
-- LLVM core), so the verified path is LLVM's standalone
-- `lldb-dap` -- the same adapter this config already drives for
-- Zig (see lua/dap/zig.lua and ADAPTER_VERDICTS.md) -- with
-- `codelldb` as the fallback. Build with debug info first:
-- `dub build --build=debug` (or ldc2 -g); release binaries
-- without symbols are this module's expected failure case, not
-- something to paper over.

local api = vim.api
local fn = vim.fn
local uv = vim.uv

local M = {}

local FILETYPES = {
    d = true,
}

local FILETYPE_PATTERNS = {
    'd',
}

local FILE_PATTERNS = {
    '*.d',
    '*.di',
}

local CONFIGURED_FLAG = 'd_dap_configured'

local MASON_ROOT = vim.fs.joinpath(fn.stdpath('data'), 'mason')

--- Bound for `dub build` invocations; compilation can be slow,
--- but a hung child must not freeze the editor forever.
local D_COMMAND_TIMEOUT_MS = 600000

---@type string[]
local ROOT_MARKERS = {
    'dub.json',
    'dub.sdl',
    'meson.build',
    '.git',
}

M.adapters = {
    primary = {
        name = 'lldb-dap',
        command = 'lldb-dap',
    },
    fallback = {
        name = 'codelldb',
        command = 'codelldb',
    },
}

---@param name string
---@return string?
local function env_override(name)
    local value = os.getenv(name)

    if type(value) == 'string' and value ~= '' then
        return value
    end

    return nil
end

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(message, level or vim.log.levels.INFO, {
        title = 'dap.d',
    })
end

---@param prompt string
---@param default? string
---@param completion? string
---@return string
local function input(prompt, default, completion)
    return fn.input(prompt, default or '', completion or 'file')
end

--- Resolve an adapter executable: environment override, PATH,
--- then the mason bin directory. Returns nil when the adapter is
--- genuinely unavailable; callers report that, never invent one.
---@param spec { name: string, command: string }
---@return string?
local function resolve_adapter(spec)
    local override = env_override('D_DAP_' .. spec.name:upper():gsub('-', '_'))
    if override and fn.executable(override) == 1 then
        return override
    end
    if fn.executable(spec.command) == 1 then
        return spec.command
    end
    local mason_bin = vim.fs.joinpath(MASON_ROOT, 'bin', spec.command)
    if uv.fs_stat(mason_bin) then
        return mason_bin
    end
    return nil
end

---@param bufnr integer
---@return string
local function project_root(bufnr)
    local name = api.nvim_buf_get_name(bufnr)
    local root = vim.fs.root(bufnr, ROOT_MARKERS)
    if root then
        return root
    end
    return vim.fs.dirname(name)
end

--- Run `dub build --build=debug` at the project root, bounded by
--- D_COMMAND_TIMEOUT_MS. Returns true on a zero exit code.
---@param root string
---@return boolean
local function dub_build_debug(root)
    if fn.executable('dub') ~= 1 then
        notify('dap.d: dub not on PATH; build the debug binary first', vim.log.levels.WARN)
        return false
    end
    local job = fn.jobstart({ 'dub', 'build', '--build=debug' }, {
        cwd = root,
        stdout_buffered = true,
        stderr_buffered = true,
    })
    if job <= 0 then
        notify('dap.d: failed to start dub build', vim.log.levels.ERROR)
        return false
    end
    local result = fn.jobwait({ job }, D_COMMAND_TIMEOUT_MS)[1]
    if result == -1 then
        fn.jobstop(job)
        notify('dap.d: dub build timed out', vim.log.levels.ERROR)
        return false
    end
    if result ~= 0 then
        notify('dap.d: dub build failed (exit ' .. tostring(result) .. ')', vim.log.levels.ERROR)
        return false
    end
    return true
end

--- Register the D adapter and launch configurations with
--- nvim-dap. Expected-missing dependencies (no nvim-dap, no
--- adapter binary) return false with a notification; nothing is
--- registered half-way.
---@return boolean
function M.setup()
    if vim.g[CONFIGURED_FLAG] then
        return true
    end
    local ok, dap = pcall(require, 'dap')
    if not ok then
        notify('dap.d: nvim-dap unavailable', vim.log.levels.WARN)
        return false
    end

    local primary_path = resolve_adapter(M.adapters.primary)
    local fallback_path = resolve_adapter(M.adapters.fallback)
    local adapter_name = nil
    local adapter_path = nil
    if primary_path then
        adapter_name, adapter_path = M.adapters.primary.name, primary_path
    elseif fallback_path then
        adapter_name, adapter_path = M.adapters.fallback.name, fallback_path
    end
    if not adapter_path then
        notify('dap.d: neither lldb-dap nor codelldb is available', vim.log.levels.WARN)
        return false
    end

    dap.adapters['d-native'] = {
        type = 'executable',
        command = adapter_path,
        name = adapter_name,
    }

    dap.configurations.d = {
        {
            type = 'd-native',
            request = 'launch',
            name = 'Launch (dub build, debug)',
            program = function()
                local bufnr = api.nvim_get_current_buf()
                local root = project_root(bufnr)
                if not dub_build_debug(root) then
                    return ''
                end
                local guess = vim.fs.joinpath(root, vim.fs.basename(root))
                return input('Path to executable: ', guess, 'file')
            end,
            cwd = function()
                return project_root(api.nvim_get_current_buf())
            end,
            stopOnEntry = false,
        },
        {
            type = 'd-native',
            request = 'launch',
            name = 'Launch executable',
            program = function()
                return input('Path to executable: ', vim.fs.joinpath(fn.getcwd(), ''), 'file')
            end,
            cwd = '${workspaceFolder}',
            stopOnEntry = false,
        },
    }

    vim.g[CONFIGURED_FLAG] = true
    return true
end

M.filetypes = FILETYPES
M.filetype_patterns = FILETYPE_PATTERNS
M.file_patterns = FILE_PATTERNS

return M
