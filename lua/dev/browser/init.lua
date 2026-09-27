-- Purpose: lazy entry point for dev.browser. require() is side-effect
-- free; setup() is idempotent, wires the BiDi session API and the :Bidi*
-- commands, then pcall-guards a hook for the future dev.browser.cdp
-- module (owned by the sibling CDP track -- this file never creates
-- anything under cdp/).

local M = {}

---Idempotent setup. Safe to call more than once.
function M.setup()
    if M._setup_done then
        return
    end
    M._setup_done = true
    require('dev.browser.bidi').setup()
    require('dev.browser.bidi.commands').register()
    -- Sibling-track hook: the CDP builder owns lua/dev/browser/cdp/.
    -- Guarded so this setup works before that track lands.
    local ok, cdp = pcall(require, 'dev.browser.cdp')
    if ok and type(cdp) == 'table' and type(cdp.setup) == 'function' then
        local sok, serr = pcall(cdp.setup)
        if not sok then
            vim.notify('dev.browser: cdp.setup failed: ' .. tostring(serr), vim.log.levels.WARN)
        end
    end
end

return M
