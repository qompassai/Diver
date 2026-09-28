-- tests/busted/unit/sandbox_spec.lua
-- Busted unit specs for ai.harness.sandbox (Tiger Style).
-- 6 validation + 6 adversarial. Deterministic, no network.

local sandbox = require('ai.harness.sandbox')

describe('sandbox', function()
    it('resolves all four profiles', function()
        for _, name in ipairs({ 'none', 'readonly', 'restricted', 'standard' }) do
            local profile, err = sandbox.resolve(name)
            assert(profile ~= nil, err)
            assert(profile.name == name)
            assert(type(profile.limits) == 'table')
            assert(profile.tmp_separate == true)
        end
    end)

    it('check_spawn accepts a valid argv spec', function()
        local profile = assert(sandbox.resolve('restricted'))
        local ok, err = sandbox.check_spawn(profile, { argv = { 'ls', '-la' }, cwd = '/tmp' })
        assert(ok == true, err)
    end)

    it('check_spawn accepts a bare argv with no cwd or env', function()
        local profile = assert(sandbox.resolve('none'))
        assert(sandbox.check_spawn(profile, { argv = { 'true' } }))
    end)

    it('describe summarizes a profile in one line', function()
        local profile = assert(sandbox.resolve('readonly'))
        local text = sandbox.describe(profile)
        assert(text:find('sandbox:readonly', 1, true) ~= nil)
        assert(text:find('workspace=read-only', 1, true) ~= nil)
        assert(text:find('network=none', 1, true) ~= nil)
        assert(text:find('wall_ms=120000', 1, true) ~= nil)
    end)

    it('profiles carry the documented workspace modes', function()
        local modes = {
            none = 'none',
            readonly = 'read-only',
            restricted = 'read-write',
            standard = 'read-write',
        }
        for name, want in pairs(modes) do
            local profile = assert(sandbox.resolve(name))
            assert(profile.workspace_mode == want)
        end
    end)

    it('profiles carry the documented network modes', function()
        local nets = {
            none = 'none',
            readonly = 'none',
            restricted = 'loopback',
            standard = 'allowlist',
        }
        for name, want in pairs(nets) do
            local profile = assert(sandbox.resolve(name))
            assert(profile.network == want)
        end
    end)
end)

describe('sandbox adversarial', function()
    it('rejects an unknown profile name', function()
        local profile, err = sandbox.resolve('yolo')
        assert(profile == nil)
        assert(err:find('unknown sandbox profile', 1, true) ~= nil)
    end)

    it('rejects an empty argv', function()
        local profile = assert(sandbox.resolve('none'))
        local ok, err = sandbox.check_spawn(profile, { argv = {} })
        assert(ok == nil)
        assert(err:find('non-empty array', 1, true) ~= nil)
    end)

    it('rejects a non-string argv element', function()
        local profile = assert(sandbox.resolve('none'))
        local ok, err = sandbox.check_spawn(profile, { argv = { 'ls', 5 } })
        assert(ok == nil)
        assert(err:find('argv[2]', 1, true) ~= nil)
    end)

    it('rejects an argv element past the size bound', function()
        local profile = assert(sandbox.resolve('none'))
        local ok, err = sandbox.check_spawn(profile, { argv = { string.rep('x', 4097) } })
        assert(ok == nil)
        assert(err:find('exceeds size bound', 1, true) ~= nil)
    end)

    it('rejects a non-string cwd', function()
        local profile = assert(sandbox.resolve('none'))
        local ok, err = sandbox.check_spawn(profile, { argv = { 'ls' }, cwd = 42 })
        assert(ok == nil)
        assert(err:find('spec.cwd must be a string', 1, true) ~= nil)
    end)

    it('rejects a shell string instead of an argv array', function()
        local profile = assert(sandbox.resolve('none'))
        local ok, err = sandbox.check_spawn(profile, { argv = 'ls -la' })
        assert(ok == nil)
        assert(err:find('non-empty array', 1, true) ~= nil)
    end)
end)
