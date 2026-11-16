-- /qompassai/Diver/lua/games/wasm4/util.lua
-- Qompass AI WASM-4 Util
--- Binary discovery, project detection, and the Rust link fix for WASM-4.
---@module 'games.wasm4.util'

local config = require('games.wasm4.config')
local shared_util = require('games.shared.util')

local M = {}

local LINK_FLAG = 'link-arg=--allow-undefined'
local LINK_FLAG_LINE = '"-C", "link-arg=--allow-undefined",'
local RUST_TARGET = 'wasm32-unknown-unknown'

---Detect the cart project enclosing `start_dir` by walking upward for
---each kind's template marker, in config.project_kind_order.
---@param start_dir string Directory to start the upward search from.
---@return string? root Project root directory.
---@return string? kind Project kind name from config.project_kinds.
function M.detect_project(start_dir)
    for _, kind_name in ipairs(config.project_kind_order) do
        local kind = config.project_kinds[kind_name]
        local found = vim.fs.find({ kind.marker }, {
            upward = true,
            path = start_dir,
        })[1]
        if found ~= nil then
            return vim.fs.dirname(found), kind_name
        end
    end
    return nil, nil
end

---Apply the proven Rust link fix to a scaffolded cart: current rust-lld
---refuses the WASM-4 console API's undefined env-import symbols (blit,
---textUtf8, ...) at link time, so the generated `.cargo/config.toml`
---needs `--allow-undefined` in its rustflags. The flag line is inserted
---after the template's stack-size line (the shape of the hand-patched
---reference cart), or before the rustflags array's closing bracket
---when no stack-size line is present. Idempotent.
---@param project_dir string Rust cart project directory.
---@return boolean? changed True when the file was patched, false when
---the flag was already present, nil on failure.
---@return string? error Failure description when changed is nil.
function M.ensure_rust_link_fix(project_dir)
    local path = project_dir .. '/.cargo/config.toml'
    local content = shared_util.read_file(path)
    if content == nil then
        return nil, 'cannot read ' .. path
    end
    if content:find(LINK_FLAG, 1, true) ~= nil then
        return false, nil
    end

    local lines = vim.split(content, '\n', { plain = true })
    local anchor_index = nil
    local closing_index = nil
    for index = 1, #lines do
        if lines[index]:find('link-arg=-zstack-size=', 1, true) ~= nil then
            anchor_index = index
        end
        if lines[index] == ']' then
            closing_index = index
        end
    end

    local insert_index
    local indent = '    '
    if anchor_index ~= nil then
        insert_index = anchor_index + 1
        indent = lines[anchor_index]:match('^%s*') or indent
    elseif closing_index ~= nil then
        insert_index = closing_index
    else
        return nil, 'no rustflags anchor found in ' .. path
    end

    local inserted = {
        indent .. '# Current rust-lld refuses undefined symbols; the WASM-4 API',
        indent .. '# functions (blit, textUtf8, ...) are env imports by design.',
        indent .. LINK_FLAG_LINE,
    }
    for offset = #inserted, 1, -1 do
        table.insert(lines, insert_index, inserted[offset])
    end

    local handle, open_error = io.open(path, 'w')
    if handle == nil then
        return nil, 'cannot write ' .. path .. ': ' .. tostring(open_error)
    end
    handle:write(table.concat(lines, '\n'))
    handle:close()
    return true, nil
end

---@return string? Binary path when executable, nil otherwise.
function M.find_binary()
    local override = shared_util.env_first(config.env_names)
    if override ~= nil and override ~= '' then
        local resolved = shared_util.first_executable({ override })
        if resolved ~= nil then
            return resolved
        end
        vim.notify('WASM-4: configured binary is not executable: ' .. override, vim.log.levels.WARN)
    end
    local configured = shared_util.first_executable({ config.current.bin })
    if configured ~= nil then
        return configured
    end
    return shared_util.first_executable(config.binaries)
end

---@param root string Project root directory.
---@param kind_name string? Project kind name from config.project_kinds (nil-safe).
---@return string? cart Absolute path of the kind's built cart.
function M.project_cart_path(root, kind_name)
    local kind = config.project_kinds[kind_name]
    if kind == nil then
        return nil
    end
    return root .. '/' .. kind.cart
end

---@return string? Binary path, notifying on ERROR when missing.
function M.require_binary()
    local bin = M.find_binary()
    if bin == nil then
        vim.notify('WASM-4 executable not found. Set NVIM_WASM4_BIN or add w4 to $PATH.', vim.log.levels.ERROR)
    end
    return bin
end

---@return string? Trimmed `w4 --version` output, nil when unavailable.
function M.version()
    local bin = M.find_binary()
    if bin == nil then
        return nil
    end
    local completed_obj = vim.system({ bin, '--version' }, { text = true })
    ---@cast completed_obj vim.SystemObj
    local completed = completed_obj:wait()
    if completed.code ~= 0 then
        return nil
    end
    return shared_util.trim(completed.stdout or '')
end

---@return boolean True when the Rust wasm32 target is installed.
function M.wasm32_target_installed()
    if vim.fn.executable('rustup') == 0 then
        return false
    end
    local completed_obj = vim.system({ 'rustup', 'target', 'list', '--installed' }, { text = true })
    ---@cast completed_obj vim.SystemObj
    local completed = completed_obj:wait()
    if completed.code ~= 0 then
        return false
    end
    for line in (completed.stdout or ''):gmatch('[^\r\n]+') do
        if shared_util.trim(line) == RUST_TARGET then
            return true
        end
    end
    return false
end

return M
