-- Purpose: the :Bidi* user commands. Thin wrappers over the bidi
-- session API. :BidiEval never runs without explicit per-invocation
-- confirmation, mirroring ai/mcp/tools.lua: the ai.security policy module
-- gets first say, otherwise vim.ui.select names the exact expression.
-- The only bypass is an exact match in config.eval_allowlist.

local config = require('dev.browser.bidi.config')

local M = {}

---@return table bidi session API (lazy so setup order never matters)
local function bidi()
    return require('dev.browser.bidi')
end

---Build the confirmation prompt for a JS expression. Pure.
---@param expression string
---@return string prompt
function M._eval_prompt(expression)
    local preview = expression
    if #preview > config.eval_preview_chars_max then
        preview = preview:sub(1, config.eval_preview_chars_max) .. '... (truncated)'
    end
    return 'Run JavaScript in the automated browser? ' .. preview
end

---True when the expression is exactly allowlisted in config.
---@param expression string
---@return boolean
function M._allowlisted(expression)
    for i = 1, #config.eval_allowlist do
        if config.eval_allowlist[i] == expression then
            return true
        end
    end
    return false
end

---Per-invocation confirmation for :BidiEval. Consults ai.security when
---present (same pattern as ai/mcp/tools.lua); otherwise asks explicitly.
---@param expression string
---@param on_decision fun(allowed: boolean, reason: string)
function M._confirm_eval(expression, on_decision)
    assert(type(on_decision) == 'function', 'on_decision must be a function')
    if M._allowlisted(expression) then
        on_decision(true, 'eval allowlist')
        return
    end
    local ok, security = pcall(require, 'ai.security')
    if ok and type(security) == 'table' and type(security.confirm_tool_call) == 'function' then
        local sok, serr = pcall(security.confirm_tool_call, 'bidi', 'script.evaluate', {
            expression = expression,
        }, on_decision)
        if sok then
            return
        end
        on_decision(false, 'security module error: ' .. tostring(serr))
        return
    end
    local ui_ok, ui_err = pcall(vim.ui.select, { 'Run JavaScript', 'Cancel' }, {
        prompt = M._eval_prompt(expression),
    }, function(choice)
        if choice == 'Run JavaScript' then
            on_decision(true, 'confirmed in prompt')
        else
            on_decision(false, 'cancelled')
        end
    end)
    if not ui_ok then
        on_decision(false, 'confirmation UI unavailable: ' .. tostring(ui_err))
    end
end

---@param name string
---@param rhs fun(opts: table)
---@param opts table
local function command(name, rhs, opts)
    vim.api.nvim_create_user_command(name, rhs, opts)
end



local function reg_open_navigate()
    command('BidiOpen', function(opts)
        local kind = opts.args ~= '' and opts.args or 'chrome'
        bidi().open(kind, function(err, info)
            if err ~= nil then
                vim.notify('bidi: open failed: ' .. err, vim.log.levels.ERROR)
                return
            end
            vim.notify(
                ('bidi: %s session %s, tab %s'):format(kind, info.session_id, info.context_id),
                vim.log.levels.INFO
            )
        end)
    end, {
        nargs = '?',
        complete = function()
            return { 'chrome', 'firefox' }
        end,
        desc = 'BiDi: verify+spawn driver, open session and tab',
    })

    command('BidiNavigate', function(opts)
        if opts.args == '' then
            vim.notify('bidi: :BidiNavigate needs a URL', vim.log.levels.WARN)
            return
        end
        bidi().navigate(opts.args, function(err)
            if err ~= nil then
                vim.notify('bidi: navigate failed: ' .. err, vim.log.levels.ERROR)
            else
                vim.notify('bidi: navigated to ' .. opts.args, vim.log.levels.INFO)
            end
        end)
    end, { nargs = 1, desc = 'BiDi: navigate the tab (wait complete)' })
end

---:BidiEval with its per-invocation confirmation.
local function reg_eval()
    command('BidiEval', function(opts)
        if opts.args == '' then
            vim.notify('bidi: :BidiEval needs a JS expression', vim.log.levels.WARN)
            return
        end
        local expression = opts.args
        M._confirm_eval(expression, function(allowed, reason)
            if not allowed then
                vim.notify('bidi: eval denied: ' .. reason, vim.log.levels.WARN)
                return
            end
            bidi().evaluate(expression, function(err, value)
                if err ~= nil then
                    vim.notify('bidi: eval failed: ' .. err, vim.log.levels.ERROR)
                    return
                end
                vim.notify('bidi: => ' .. vim.inspect(value), vim.log.levels.INFO)
            end)
        end)
    end, { nargs = 1, desc = 'BiDi: evaluate JS (asks for confirmation)' })
end

---:BidiScreenshot and :BidiConsole.
local function reg_screenshot_console()
    command('BidiScreenshot', function()
        bidi().screenshot(function(err, bufnr)
            if err ~= nil then
                vim.notify('bidi: screenshot failed: ' .. err, vim.log.levels.ERROR)
                return
            end
            vim.api.nvim_set_current_buf(bufnr)
            vim.notify('bidi: screenshot in buffer ' .. bufnr, vim.log.levels.INFO)
        end)
    end, { nargs = 0, desc = 'BiDi: capture screenshot to a scratch buffer' })

    command('BidiConsole', function()
        bidi().console(function(err)
            if err ~= nil then
                vim.notify('bidi: console stream failed: ' .. err, vim.log.levels.ERROR)
                return
            end
            vim.cmd('copen')
        end)
    end, { nargs = 0, desc = 'BiDi: stream console entries to quickfix' })
end

---:BidiNetwork and :BidiClose.
local function reg_network_close()
    command('BidiNetwork', function()
        bidi().network_log(function(err)
            if err ~= nil then
                vim.notify('bidi: network observe failed: ' .. err, vim.log.levels.ERROR)
                return
            end
            vim.cmd('copen')
        end)
    end, { nargs = 0, desc = 'BiDi: observe network events to quickfix' })

    command('BidiClose', function()
        bidi().close(function()
            vim.notify('bidi: session closed', vim.log.levels.INFO)
        end)
    end, { nargs = 0, desc = 'BiDi: close session and reap driver' })
end

---:BidiOpen and :BidiNavigate.
---Register all :Bidi* commands. Idempotent via nvim_create_user_command
---replace semantics on re-setup.
function M.register()
    reg_open_navigate()
    reg_eval()
    reg_screenshot_console()
    reg_network_close()
end

return M
