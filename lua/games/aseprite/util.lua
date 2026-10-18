-- /qompassai/Diver/lua/games/aseprite/util.lua
-- Qompass AI Aseprite Util
---@module 'games.aseprite.util'
local config = require('games.aseprite.config')
local shared_util = require('games.shared.util')
local M = {}
function M.current_sprite_or_prompt()
    local current = vim.api.nvim_buf_get_name(0)
    if M.is_sprite_file(current) then
        return current
    end

    local input = shared_util.trim(vim.fn.input('Aseprite sprite file: ', '', 'file'))
    if input == '' then
        return nil
    end
    return vim.fn.expand(input)
end
function M.find_binary()
    local override = shared_util.env_first(config.env_names)
    if override then
        local resolved = shared_util.first_executable({ override })
        if resolved then
            return resolved
        end
        vim.notify('Aseprite: configured binary is not executable: ' .. override, vim.log.levels.WARN)
    end
    return shared_util.first_executable(config.binaries)
end
function M.is_sprite_file(path)
    if not path or path == '' then
        return false
    end
    for _, ext in ipairs(config.sprite_extensions) do
        if path:sub(-#ext) == ext then
            return true
        end
    end
    return false
end
function M.require_binary()
    local bin = M.find_binary()
    if not bin then
        vim.notify(
            'Aseprite executable not found. Set NVIM_ASEPRITE_BIN or add aseprite to $PATH.',
            vim.log.levels.ERROR
        )
    end
    return bin
end
function M.user_palette_dir()
    if shared_util.is_windows() then
        return config.user_palette_dir_by_os.windows
    elseif shared_util.is_mac() then
        return config.user_palette_dir_by_os.mac
    end
    return config.user_palette_dir_by_os.linux
end

return M
