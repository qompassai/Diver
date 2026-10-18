-- /qompassai/diver/tests/security/mask.lua
-- Qompass AI Diver secret-masking tests
-- Run from the config root:
--   nvim --headless -u NONE -i NONE -l tests/security/mask.lua
--
-- Covers security.mask: extmark overlays on secret values, toggle,
-- and the guarantee that buffer text is never modified. The honest
-- security model (screen-only) is asserted, not just documented.
local api, fn = vim.api, vim.fn
local bundle = fn.getcwd()
vim.opt.runtimepath:prepend(bundle)

local failures = 0
local count = 0
local function check(value, label)
    count = count + 1
    if value then
        print('PASS: ' .. label)
    else
        print('FAIL: ' .. label)
        failures = failures + 1
    end
end

vim.notify = function(_, _) end

local ok, mask = pcall(require, 'security.mask')
check(ok and mask ~= nil, 'require(security.mask) loads')
if not ok then
    print(('mask: %d checks, %d failures'):format(count, failures))
    os.exit(1)
end

mask.setup()

local NS = api.nvim_get_namespaces()['diver_secret_mask']
check(NS ~= nil, 'mask namespace created on setup')

-- .env buffer: values get overlays, keys stay readable.
local buf = api.nvim_create_buf(false, true)
api.nvim_buf_set_name(buf, '/tmp/test-mask/.env')
api.nvim_buf_set_lines(buf, 0, -1, false, {
    'API_KEY=supersecret123',
    'DATABASE_URL=postgres://user:pass@host/db',
    '# just a comment',
    'PLAIN=hello',
})
api.nvim_set_current_buf(buf)
local before = api.nvim_buf_get_lines(buf, 0, -1, false)

mask.toggle(buf)
check(mask.is_masked(buf), 'buffer marked masked after toggle')

local marks = api.nvim_buf_get_extmarks(buf, NS, 0, -1, { details = true })
check(#marks >= 2, ('secret values overlaid (%d extmarks)'):format(#marks))

-- The overlay covers the VALUE, and buffer text is byte-identical.
local after = api.nvim_buf_get_lines(buf, 0, -1, false)
local same = #before == #after
for i = 1, #before do
    same = same and before[i] == after[i]
end
check(same, 'buffer text unchanged by masking (screen-only)')
check(after[1] == 'API_KEY=supersecret123', 'secret still in buffer (honest model: mask hides, not redacts)')

-- Toggle off clears overlays.
mask.toggle(buf)
check(not mask.is_masked(buf), 'buffer unmarked after second toggle')
local cleared = api.nvim_buf_get_extmarks(buf, NS, 0, -1, {})
check(#cleared == 0, 'extmarks cleared on untoggle')

-- Adversarial: unsupported extension is a safe no-op.
local buf2 = api.nvim_create_buf(false, true)
api.nvim_buf_set_name(buf2, '/tmp/test-mask/notes.txt')
api.nvim_buf_set_lines(buf2, 0, -1, false, { 'API_KEY=supersecret123' })
mask.toggle(buf2)
local marks2 = api.nvim_buf_get_extmarks(buf2, NS, 0, -1, {})
check(#marks2 == 0, 'no masks applied to unsupported extension')
mask.toggle(buf2) -- untoggle the no-op
api.nvim_buf_delete(buf2, { force = true })

-- Adversarial: JSON secret keys masked, non-secret keys untouched.
local buf3 = api.nvim_create_buf(false, true)
api.nvim_buf_set_name(buf3, '/tmp/test-mask/config.json')
api.nvim_buf_set_lines(buf3, 0, -1, false, {
    '{ "api_key": "shhh", "name": "visible" }',
})
mask.toggle(buf3)
local marks3 = api.nvim_buf_get_extmarks(buf3, NS, 0, -1, { details = true })
check(#marks3 >= 1, 'JSON secret value overlaid')
-- The overlay must not cover the "name" value: check extmark columns.
local covers_name = false
for _, m in ipairs(marks3) do
    local row, col, det = m[2], m[3], m[4]
    if row == 0 and det and det.end_col then
        local line = '{ "api_key": "shhh", "name": "visible" }'
        local covered = line:sub(col + 1, det.end_col)
        if covered:find('visible') then
            covers_name = true
        end
    end
end
check(not covers_name, 'non-secret JSON value not covered')
api.nvim_buf_delete(buf3, { force = true })

-- Adversarial: toggle on invalid buffer asserts.
local assert_ok = pcall(mask.toggle, 99999)
check(not assert_ok, 'toggle on invalid buffer raises')

-- :MaskToggle command exists.
local cmds = api.nvim_get_commands({})
check(cmds['MaskToggle'] ~= nil, ':MaskToggle registered')

api.nvim_buf_delete(buf, { force = true })
print(('mask: %d checks, %d failures'):format(count, failures))
os.exit(failures == 0 and 0 or 1)
