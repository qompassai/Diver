-- Tests for research.docs.make_header -- the function 19 lang-config
-- BufNewFile templates call (was missing; every call site raised at runtime).
-- Run from the repo root:  lua tests/lua/research_docs_make_header.lua
-- Harness follows tests/lua/mcp_server/*_spec.lua (plain-lua `check`
-- counting, minimal vim stub since `vim` is nil outside Neovim).
-- Exactly 50% validation / 50% adversarial: 6 + 6.
local here = debug.getinfo(1, 'S').source:sub(2)
if here:sub(1, 1) ~= '/' then
    local pwd = io.popen('pwd')
    local cwd = pwd:read('*l')
    pwd:close()
    here = cwd .. '/' .. here
end
local dir = here:match('^(.*)/[^/]*$')
local root = dir:match('^(.*)/tests/lua$')
assert(root ~= nil, 'cannot locate repo root from ' .. dir)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

-- Minimal vim stub: docs.lua binds vim.* fields at require time; only
-- fn.fnamemodify is ever *called* by the code under test (fallback path).
_G.vim = {
    api = {},
    fn = {
        fnamemodify = function(path, mods)
            assert(mods == ':~:.', 'stub only implements :~:.')
            local home = os.getenv('HOME') or ''
            if home ~= '' and path:sub(1, #home) == home then
                path = '~' .. path:sub(#home + 1)
            end
            return path
        end,
        expand = function()
            return ''
        end,
    },
    cmd = function() end,
    bo = {},
    b = {},
    v = {},
    notify = function() end,
    inspect = tostring,
    json = {
        decode = function()
            return nil
        end,
    },
    split = function(s, sep)
        local parts = {}
        for part in s:gmatch('[^' .. sep .. ']+') do
            parts[#parts + 1] = part
        end
        return parts
    end,
    treesitter = {},
    log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
    keymap = {
        set = function() end,
    },
}

local docs = require('research.docs')
assert(type(docs.make_header) == 'function', 'research.docs.make_header must exist')

local passed = 0
local total = 0
local function check(value, message)
    total = total + 1
    assert(value, message)
    passed = passed + 1
end

local function fails(fn, message)
    total = total + 1
    local ok = pcall(fn)
    assert(not ok, message)
    passed = passed + 1
end

local DASHES = string.rep('-', 40)
local COPYRIGHT = 'Copyright (C) 2026 Qompass AI, All rights reserved'

-- ================= VALIDATION (6) =================

-- 1. '#' line-prefix header: exact four lines.
do
    local hdr = docs.make_header('/home/u/qompassai/Diver/new.sh', '#')
    check(#hdr == 4, 'expected 4 header lines, got ' .. #hdr)
    check(hdr[1] == '# /qompassai/Diver/new.sh', 'line1 mismatch: ' .. hdr[1])
    check(hdr[2] == '# Qompass AI - [ ]', 'line2 mismatch: ' .. hdr[2])
    check(hdr[3] == '# ' .. COPYRIGHT, 'line3 mismatch: ' .. hdr[3])
    check(hdr[4] == '# ' .. DASHES, 'line4 mismatch: ' .. hdr[4])
end

-- 2. '--' prefix (lua.lua call site).
do
    local hdr = docs.make_header('/home/u/qompassai/Diver/new.lua', '--')
    check(hdr[1] == '-- /qompassai/Diver/new.lua', 'lua line1: ' .. hdr[1])
    check(hdr[4] == '-- ' .. DASHES, 'lua rule: ' .. hdr[4])
end

-- 3. '//' prefix (c/cpp/go/rust/zig call sites).
do
    local hdr = docs.make_header('/home/u/qompassai/Diver/new.go', '//')
    check(hdr[1] == '// /qompassai/Diver/new.go', 'go line1: ' .. hdr[1])
    check(hdr[3] == '// ' .. COPYRIGHT, 'go copyright: ' .. hdr[3])
end

-- 4. '<!--' block comment: every line wrapped with closer.
do
    local hdr = docs.make_header('/home/u/qompassai/Diver/new.html', '<!--')
    check(hdr[1] == '<!-- /qompassai/Diver/new.html -->', 'html line1: ' .. hdr[1])
    check(hdr[2] == '<!-- Qompass AI - [ ] -->', 'html line2: ' .. hdr[2])
    check(hdr[4] == '<!-- ' .. DASHES .. ' -->', 'html rule: ' .. hdr[4])
end

-- 5. '/*' block comment (css.lua call site).
do
    local hdr = docs.make_header('/home/u/qompassai/Diver/new.css', '/*')
    check(hdr[1] == '/* /qompassai/Diver/new.css */', 'css line1: ' .. hdr[1])
    check(hdr[4] == '/* ' .. DASHES .. ' */', 'css rule: ' .. hdr[4])
end

-- 6. Relative path keeps the leading slash, matching repo headers.
do
    local hdr = docs.make_header('/home/u/qompassai/Diver/deep/dir/f.py', '#')
    check(hdr[1] == '# /qompassai/Diver/deep/dir/f.py', 'leading slash kept: ' .. hdr[1])
end

-- ================= ADVERSARIAL (6) =================

-- 7. Empty filepath is a programmer error: raises.
fails(function()
    docs.make_header('', '#')
end, 'empty filepath must raise')

-- 8. Empty comment prefix raises.
fails(function()
    docs.make_header('/home/u/qompassai/Diver/x.sh', '')
end, 'empty comment must raise')

-- 9. Non-string filepath raises.
fails(function()
    docs.make_header(123, '#')
end, 'numeric filepath must raise')

-- 10. Nil comment raises.
fails(function()
    docs.make_header('/home/u/qompassai/Diver/x.sh', nil)
end, 'nil comment must raise')

-- 11. Path outside /qompassai/ falls back to fnamemodify (:~:.), not an error.
do
    local home = os.getenv('HOME') or ''
    local hdr = docs.make_header(home .. '/proj/f.py', '#')
    check(hdr[1] == '# ~/proj/f.py', 'fallback relpath: ' .. hdr[1])
    check(#hdr == 4, 'fallback still yields 4 lines')
end

-- 12. Each call returns a fresh list: mutating one result is invisible to the next.
do
    local first = docs.make_header('/home/u/qompassai/Diver/a.sh', '#')
    first[1] = 'MUTATED'
    local second = docs.make_header('/home/u/qompassai/Diver/a.sh', '#')
    check(second[1] == '# /qompassai/Diver/a.sh', 'fresh list per call: ' .. second[1])
end

print(('make_header: %d/%d checks passed (12 cases: 6 validation + 6 adversarial)'):format(passed, total))
assert(passed == total and total == 22, 'check count drifted from 22')
