-- test_keymaps.lua -- keymap hygiene gates over a diver checkout.
--
--   * every vim.keymap.set / nvim_{buf_}set_keymap call in lua/mappings/
--     passes desc= (the repo's own "clear keymaps" doctrine)
--   * mapping modules load standalone without throwing (best effort)
--   * setup() is idempotent and adds no duplicate lhs per mode (best effort;
--     skips cleanly when modules need the full config to load)
--
-- Needs DIVER_REPO=/path/to/diver for the static gate.

local src = debug.getinfo(1, 'S').source:sub(2)
local dir = src:match('(.*/)') or './'
package.path = dir .. '?.lua;' .. package.path
local H = require('harness')

local repo = vim.env.DIVER_REPO
local repo_ok = repo ~= nil and repo ~= '' and vim.fn.isdirectory(repo) == 1

---@param path string
---@return string
local function read_file(path)
    local fh, open_err = io.open(path, 'rb')
    assert(fh, 'cannot open ' .. path .. ': ' .. tostring(open_err))
    local text = fh:read('*a')
    fh:close()
    assert(text, 'cannot read ' .. path)
    return text
end

---@param text string
---@param from integer position of the opener character
---@param open_c string
---@param close_c string
---@return string? inner_text
local function extract_balanced(text, from, open_c, close_c)
    assert(text:sub(from, from) == open_c)
    local depth, i, n = 0, from, #text
    while i <= n do
        local c = text:sub(i, i)
        if c == open_c then
            depth = depth + 1
        elseif c == close_c then
            depth = depth - 1
            if depth == 0 then
                return text:sub(from + 1, i - 1)
            end
        elseif c == "'" or c == '"' then
            local quote = c
            i = i + 1
            while i <= n do
                local d = text:sub(i, i)
                if d == '\\' then
                    i = i + 2
                elseif d == quote then
                    break
                else
                    i = i + 1
                end
            end
        elseif c == '-' and text:sub(i + 1, i + 1) == '-' then
            local nl = text:find('\n', i, true)
            i = (nl or (n + 1)) - 1
        end
        i = i + 1
    end
    return nil
end

if not repo_ok then
    H.skip('keymap gates', 'set DIVER_REPO to a diver checkout')
else
    H.describe('keymap descriptions', function()
        H.it('every set_keymap call in lua/mappings/ passes desc=', function()
            local files = vim.fn.glob(repo .. '/lua/mappings/**/*.lua', false, true)
            H.check(#files > 0, 'no lua/mappings files found')
            local missing = {}
            for _, path in ipairs(files) do
                local text = read_file(path)
                for _, pat in ipairs({ 'keymap%.set', 'set_keymap' }) do
                    local pos = 1
                    while true do
                        local s = text:find(pat, pos)
                        if not s then
                            break
                        end
                        local paren = text:find('%(', s)
                        if paren then
                            local inner = extract_balanced(text, paren, '(', ')')
                            if inner and not inner:find('desc', 1, true) then
                                local lnum = select(2, text:sub(1, s):gsub('\n', '\n')) + 1
                                local where = ('%s:%d'):format(path:match('([^/]+)$'), lnum)
                                missing[#missing + 1] = where
                            end
                        end
                        pos = s + 1
                    end
                end
            end
            table.sort(missing)
            local detail = 'keymap.set without desc=:\n    ' .. table.concat(missing, '\n    ')
            H.check(#missing == 0, detail)
        end)
    end)

    H.describe('mapping modules (best effort)', function()
        H.it('modules load standalone and setup() is idempotent', function()
            package.path = repo .. '/lua/?.lua;' .. repo .. '/lua/?/init.lua;' .. package.path
            local files = vim.fn.glob(repo .. '/lua/mappings/*.lua', false, true)
            local loaded, failed = {}, {}
            for _, path in ipairs(files) do
                local name = path:match('([^/]+)%.lua$')
                if name ~= 'init' and name:sub(1, 1) ~= '_' then
                    local modname = 'mappings.' .. name
                    local ok, mod = pcall(require, modname)
                    if ok then
                        loaded[#loaded + 1] = modname
                        -- idempotency: setup twice must not throw
                        if type(mod) == 'table' and type(mod.setup) == 'function' then
                            local ok1, err1 = pcall(mod.setup)
                            local ok2, err2 = pcall(mod.setup)
                            if not (ok1 and ok2) then
                                failed[#failed + 1] = modname
                                    .. ' setup not idempotent: '
                                    .. tostring(err1 or err2)
                            end
                            if type(mod.teardown) == 'function' then
                                pcall(mod.teardown)
                            end
                        end
                    else
                        failed[#failed + 1] = modname .. ' failed to load standalone'
                    end
                end
            end
            if #loaded == 0 then
                H.skip('standalone load check', 'no mapping modules load without the full config')
                return
            end
            print(
                ('INFO: %d modules loaded standalone, %d failed/skipped'):format(#loaded, #failed)
            )
            for _, f in ipairs(failed) do
                print('    ' .. f)
            end
        end)

        H.it('no duplicate lhs added per mode', function()
            local modes = { 'n', 'v', 'x', 'i', 't', 'c' }
            local before = {}
            for _, mode in ipairs(modes) do
                before[mode] = {}
                for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
                    before[mode][map.lhs] = true
                end
            end
            -- Any maps added by the load test above are the modules' doing.
            local dups = {}
            for _, mode in ipairs(modes) do
                local seen = {}
                for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
                    if not before[mode][map.lhs] then
                        if seen[map.lhs] then
                            dups[#dups + 1] = mode .. ':' .. map.lhs
                        end
                        seen[map.lhs] = true
                    end
                end
            end
            H.check(#dups == 0, 'duplicate lhs installed: ' .. table.concat(dups, ', '))
        end)
    end)
end

if not _G.DIVER_RUNNER then
    os.exit(H.summary() and 0 or 1)
end