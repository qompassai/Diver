-- Purpose: action-menu entries for the BiDi track, following the
-- dev.apps.android action convention ({id, label, group, keywords, run}).
-- Each action shells out to the matching :Bidi* command so there is one
-- code path from menu to browser.

local M = {}

---@class BidiAction
---@field id string
---@field label string
---@field group string
---@field keywords string
---@field run fun()

---Session-lifecycle actions: open, navigate, eval.
---@return BidiAction[]
local function session_actions()
    return {
        {
            id = 'bidi_open_chrome',
            label = 'BiDi: open Chrome session',
            group = 'Browser',
            keywords = 'bidi chrome browser open automation webdriver',
            run = function()
                vim.cmd('BidiOpen chrome')
            end,
        },
        {
            id = 'bidi_open_firefox',
            label = 'BiDi: open Firefox session',
            group = 'Browser',
            keywords = 'bidi firefox browser open automation webdriver gecko',
            run = function()
                vim.cmd('BidiOpen firefox')
            end,
        },
        {
            id = 'bidi_navigate',
            label = 'BiDi: navigate tab',
            group = 'Browser',
            keywords = 'bidi navigate url goto browser',
            run = function()
                local url = vim.fn.input('BiDi URL: ', 'https://')
                if url ~= '' then
                    vim.cmd('BidiNavigate ' .. url)
                end
            end,
        },
        {
            id = 'bidi_eval',
            label = 'BiDi: evaluate JavaScript (confirms)',
            group = 'Browser',
            keywords = 'bidi eval javascript js script browser',
            run = function()
                local js = vim.fn.input('BiDi JS: ', 'document.title')
                if js ~= '' then
                    vim.cmd('BidiEval ' .. js)
                end
            end,
        },
    }
end

---Observation actions: screenshot, console, network, close.
---@return BidiAction[]
local function observe_actions()
    return {
        {
            id = 'bidi_screenshot',
            label = 'BiDi: screenshot to buffer',
            group = 'Browser',
            keywords = 'bidi screenshot png capture browser',
            run = function()
                vim.cmd('BidiScreenshot')
            end,
        },
        {
            id = 'bidi_console',
            label = 'BiDi: stream console to quickfix',
            group = 'Browser',
            keywords = 'bidi console log quickfix browser',
            run = function()
                vim.cmd('BidiConsole')
            end,
        },
        {
            id = 'bidi_network',
            label = 'BiDi: observe network to quickfix',
            group = 'Browser',
            keywords = 'bidi network traffic requests quickfix browser',
            run = function()
                vim.cmd('BidiNetwork')
            end,
        },
        {
            id = 'bidi_close',
            label = 'BiDi: close session',
            group = 'Browser',
            keywords = 'bidi close quit teardown browser',
            run = function()
                vim.cmd('BidiClose')
            end,
        },
    }
end

---All BiDi actions. Pure data + thin run closures.
---@return BidiAction[]
function M.get_actions()
    local actions = session_actions()
    for _, action in ipairs(observe_actions()) do
        actions[#actions + 1] = action
    end
    return actions
end

---Run one action by id. Returns (nil, err) on unknown id.
---@param id string
---@return boolean? ok
---@return string? err
function M.run_action_by_id(id)
    for _, action in ipairs(M.get_actions()) do
        if action.id == id then
            action.run()
            return true, nil
        end
    end
    return nil, 'unknown BiDi action: ' .. tostring(id)
end

---Show the action menu via vim.ui.select.
function M.show_menu()
    local actions = M.get_actions()
    local labels = {}
    for i = 1, #actions do
        labels[i] = actions[i].label
    end
    vim.ui.select(labels, { prompt = 'BiDi actions' }, function(choice)
        if choice == nil then
            return
        end
        for i = 1, #actions do
            if actions[i].label == choice then
                actions[i].run()
                return
            end
        end
    end)
end

return M
