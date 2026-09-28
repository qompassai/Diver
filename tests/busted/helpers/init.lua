-- tests/busted/helpers/init.lua
-- Busted helper: minimal _G.vim stub for headless runs (Tiger Style).
-- Loaded once before any spec via the .busted `helper` key. Installs the
-- stub through _G so modules that reference the `vim` global see it.
-- Deliberately does NOT load Test.More: Busted and lua-TestMore stay
-- separate frameworks with separate assertion lifecycles.

-- Content-sensitive stub hash so artifact dedup tests stay meaningful.
-- Portable arithmetic only: no bitwise operators (LuaJIT compat).
local function stub_sha256(s)
    local hash = 2166136261
    for i = 1, #s do
        local byte = s:byte(i)
        local xored = 0
        local place = 1
        local a, b = hash, byte
        for _ = 1, 32 do
            if a == 0 and b == 0 then
                break
            end
            if (a % 2) ~= (b % 2) then
                xored = xored + place
            end
            a = (a - (a % 2)) / 2
            b = (b - (b % 2)) / 2
            place = place * 2
        end
        hash = (xored * 16777619) % 4294967296
    end
    return string.format('stubsha:%08x:%d', hash, #s)
end

_G.vim = {
    uv = {
        hrtime = function()
            return math.floor(os.clock() * 1000000000)
        end,
    },
    fn = {
        sha256 = stub_sha256,
        getcwd = function()
            return '/tmp/diver-busted'
        end,
        stdpath = function(what)
            return '/tmp/diver-busted/' .. tostring(what)
        end,
        executable = function()
            return 0
        end,
    },
    api = {},
    lsp = {},
    tbl_count = function(t)
        local n = 0
        for _ in pairs(t) do
            n = n + 1
        end
        return n
    end,
    notify = function() end,
    schedule = function(fn)
        fn()
    end,
}

return {}
