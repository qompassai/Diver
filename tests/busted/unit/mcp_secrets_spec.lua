-- tests/busted/unit/mcp_secrets_spec.lua
-- Busted unit specs for ai.mcp.secrets (Tiger Style).
-- 8 validation + 8 adversarial = 16 tests. Deterministic, no network.
-- Extends the helper vim stub with system/env/deepcopy for resolve tests.

-- Extend the stub _G.vim installed by tests.busted.helpers.
_G.vim.system = function(argv, opts)
    return {
        wait = function()
            if argv[1] == '/bin/echo' then
                return { code = 0, stdout = (argv[2] or '') .. '\n' }
            end
            if argv[1] == 'pass' then
                if argv[3] == 'good/entry' then
                    return { code = 0, stdout = '  s3cr3t-value  \n' }
                end
                return { code = 1, stdout = '' }
            end
            return { code = 127, stdout = '' }
        end,
    }
end
_G.vim.env = setmetatable({ MCP_SPEC_TEST_VAR = 'env-secret-123' }, {
    __index = function(_, k)
        return os.getenv(k)
    end,
})
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

local secrets = require('ai.mcp.secrets')

describe('ai.mcp.secrets', function()
    describe('validate_refs', function()
        it('accepts nil (no secrets)', function()
            assert.is_true(secrets.validate_refs(nil))
        end)

        it('accepts all three providers', function()
            local ok, err = secrets.validate_refs({
                A = { provider = 'env', path = 'SOME_VAR' },
                B = { provider = 'pass', path = 'some/entry' },
                C = { provider = 'command', argv = { '/bin/echo', 'hi' } },
            })
            assert.is_true(ok, err)
        end)

        it('rejects unknown provider', function()
            local ok, err = secrets.validate_refs({ A = { provider = 'vault', path = 'x' } })
            assert.is_false(ok)
            assert.is_truthy(err:find('provider'))
        end)

        it('rejects dash-leading path (flag injection)', function()
            local ok, err = secrets.validate_refs({ A = { provider = 'pass', path = '--help' } })
            assert.is_false(ok)
            assert.is_truthy(err:find('dash'))
        end)

        it('rejects relative command path', function()
            local ok, err = secrets.validate_refs({ A = { provider = 'command', argv = { 'bin/echo' } } })
            assert.is_false(ok)
            assert.is_truthy(err:find('absolute'))
        end)

        it('rejects empty argv', function()
            local ok, err = secrets.validate_refs({ A = { provider = 'command', argv = {} } })
            assert.is_false(ok)
        end)

        it('rejects non-table secrets', function()
            local ok = secrets.validate_refs('notatable')
            assert.is_false(ok)
        end)

        it('rejects bad variable names', function()
            local ok = secrets.validate_refs({ ['bad-name'] = { provider = 'env', path = 'X' } })
            assert.is_false(ok)
        end)
    end)

    describe('resolve', function()
        it('resolves env provider', function()
            local r, err = secrets.resolve({
                name = 't',
                secrets = { TOK = { provider = 'env', path = 'MCP_SPEC_TEST_VAR' } },
            })
            assert.is_nil(err)
            assert.are.equal('env-secret-123', r.TOK)
        end)

        it('resolves pass provider and trims whitespace', function()
            local r, err = secrets.resolve({
                name = 't',
                secrets = { TOK = { provider = 'pass', path = 'good/entry' } },
            })
            assert.is_nil(err)
            assert.are.equal('s3cr3t-value', r.TOK)
        end)

        it('resolves command provider', function()
            local r, err = secrets.resolve({
                name = 't',
                secrets = { TOK = { provider = 'command', argv = { '/bin/echo', 'cmd-secret' } } },
            })
            assert.is_nil(err)
            assert.are.equal('cmd-secret', r.TOK)
        end)

        it('returns empty table when no secrets', function()
            local r, err = secrets.resolve({ name = 't' })
            assert.is_nil(err)
            assert.are.same({}, r)
        end)

        it('fails cleanly on missing env var', function()
            local r, err = secrets.resolve({
                name = 't',
                secrets = { TOK = { provider = 'env', path = 'MCP_SPEC_DEFINITELY_MISSING_XYZ' } },
            })
            assert.is_nil(r)
            assert.is_truthy(err:find('MCP_SPEC_DEFINITELY_MISSING_XYZ'))
        end)

        it('fails cleanly on pass error without leaking', function()
            local r, err = secrets.resolve({
                name = 't',
                secrets = { TOK = { provider = 'pass', path = 'bad/entry' } },
            })
            assert.is_nil(r)
            assert.is_truthy(err:find('cannot resolve secret TOK'))
            assert.is_falsy(err:find('s3cr3t'))
        end)

        it('rejects invalid refs before resolving', function()
            local r, err = secrets.resolve({
                name = 't',
                secrets = { TOK = { provider = 'bogus', path = 'x' } },
            })
            assert.is_nil(r)
            assert.is_truthy(err:find('invalid secret refs'))
        end)

        it('never includes secret values in errors', function()
            local r, err = secrets.resolve({
                name = 't',
                secrets = { TOK = { provider = 'env', path = 'MCP_SPEC_TEST_VAR' } },
            })
            assert.is_nil(err)
            -- resolve succeeded; now force an error path and check
            local _, err2 = secrets.resolve({
                name = 't2',
                secrets = { TOK = { provider = 'pass', path = 'bad/entry' } },
            })
            assert.is_falsy(err2:find('env%-secret%-123'))
            assert.is_falsy(err2:find('s3cr3t%-value'))
        end)
    end)
end)
