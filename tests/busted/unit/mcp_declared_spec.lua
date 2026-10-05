-- tests/busted/unit/mcp_declared_spec.lua
-- Busted unit specs for ai.mcp.declared (Tiger Style).
-- 6 validation + 6 adversarial = 12 tests. Deterministic, no network.

_G.vim.deepcopy = function(orig)
    if type(orig) ~= 'table' then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[_G.vim.deepcopy(k)] = _G.vim.deepcopy(v)
    end
    return copy
end

local declared = require('ai.mcp.declared')

local function with_declarations(decls, fn)
    local saved = package.loaded['ai.mcp.declared_servers']
    package.loaded['ai.mcp.declared_servers'] = decls
    local ok, err = pcall(fn)
    package.loaded['ai.mcp.declared_servers'] = saved
    assert(ok, err)
end

local function good_entry(name, overrides)
    local e = { name = name, command = '/usr/bin/uvx', args = { 'mcp-server-git' }, enabled = true }
    if overrides then
        for k, v in pairs(overrides) do
            e[k] = v
        end
    end
    return e
end

describe('ai.mcp.declared', function()
    describe('validation', function()
        it('loads valid declarations', function()
            with_declarations({ good_entry('a'), good_entry('b') }, function()
                local active, problems = declared.load()
                assert.are.equal(2, #active)
                assert.are.equal(0, #problems)
                assert.is_true(active[1].declared)
            end)
        end)

        it('excludes disabled entries', function()
            with_declarations({ good_entry('a'), good_entry('b', { enabled = false }) }, function()
                local active, problems = declared.load()
                assert.are.equal(1, #active)
                assert.are.equal('a', active[1].name)
                assert.are.equal(0, #problems)
            end)
        end)

        it('accepts secret refs in declarations', function()
            with_declarations({
                good_entry('s', {
                    secrets = { TOK = { provider = 'pass', path = 'some/entry' } },
                }),
            }, function()
                local active, problems = declared.load()
                assert.are.equal(1, #active)
                assert.are.equal(0, #problems)
                assert.are.equal('pass', active[1].secrets.TOK.provider)
            end)
        end)

        it('validates without requiring executables', function()
            with_declarations({ good_entry('x', { command = '/nonexistent/binary' }) }, function()
                local active, problems = declared.load()
                assert.are.equal(1, #active)
                assert.are.equal(0, #problems)
            end)
        end)

        it('returns empty problems on clean load', function()
            with_declarations({ good_entry('a') }, function()
                local _, problems = declared.load()
                assert.are.same({}, problems)
            end)
        end)

        it('marks entries declared without persisting', function()
            with_declarations({ good_entry('a') }, function()
                local active = declared.load()
                assert.is_true(active[1].declared)
                -- declared flag is in-memory; the source table is untouched
            end)
        end)
    end)

    describe('adversarial', function()
        it('reports invalid entries and keeps the rest', function()
            with_declarations({
                good_entry('good'),
                { name = 'bad!', command = '/bin/x', args = {}, enabled = true },
                good_entry('good2'),
            }, function()
                local active, problems = declared.load()
                assert.are.equal(2, #active)
                assert.are.equal(1, #problems)
                assert.are.equal(2, problems[1].index)
            end)
        end)

        it('reports duplicate names', function()
            with_declarations({ good_entry('dup'), good_entry('dup') }, function()
                local active, problems = declared.load()
                assert.are.equal(1, #active)
                assert.are.equal(1, #problems)
                assert.is_truthy(problems[1].err:find('duplicate'))
            end)
        end)

        it('reports bad secret refs', function()
            with_declarations({
                good_entry('s', { secrets = { TOK = { provider = 'bogus', path = 'x' } } }),
            }, function()
                local active, problems = declared.load()
                assert.are.equal(0, #active)
                assert.are.equal(1, #problems)
            end)
        end)

        it('handles non-table module return', function()
            with_declarations('notatable', function()
                local active, problems = declared.load()
                assert.are.equal(0, #active)
                assert.are.equal(1, #problems)
                assert.are.equal(0, problems[1].index)
            end)
        end)

        it('handles missing module gracefully', function()
            local saved = package.loaded['ai.mcp.declared_servers']
            package.loaded['ai.mcp.declared_servers'] = nil
            -- force require to fail by hiding the module
            local orig_searchers = package.searchers
            package.searchers = {
                function()
                    return nil
                end,
            }
            local active, problems = declared.load()
            package.searchers = orig_searchers
            package.loaded['ai.mcp.declared_servers'] = saved
            assert.are.equal(0, #active)
            assert.are.equal(1, #problems)
        end)

        it('does not mutate the source declarations', function()
            local src = { good_entry('a') }
            with_declarations(src, function()
                declared.load()
                assert.is_nil(src[1].declared)
            end)
        end)
    end)
end)
