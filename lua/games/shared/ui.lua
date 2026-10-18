-- /qompassai/Diver/lua/games/shared/ui.lua
-- Qompass AI Games Shared UI
---@module 'games.shared.ui'
local M = {}

function M.select_root_menu(actions, run_action, opts)
    opts = opts or {}
    local group_order = opts.group_order or {}
    local order_index = {}
    for i, name in ipairs(group_order) do
        order_index[name] = i
    end

    local sorted = vim.deepcopy(actions)
    table.sort(sorted, function(a, b)
        local ga = order_index[a.group] or math.huge
        local gb = order_index[b.group] or math.huge
        if ga ~= gb then
            return ga < gb
        end
        return a.label < b.label
    end)

    vim.ui.select(sorted, {
        prompt = opts.prompt or 'Select action:',
        format_item = function(action)
            if action.group then
                return string.format('[%s] %s', action.group, action.label)
            end
            return action.label
        end,
    }, function(choice)
        if choice then
            run_action(choice)
        end
    end)
end

return M
