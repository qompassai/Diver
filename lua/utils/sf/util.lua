local M = {}

function M.executable(bin)
    return vim.fn.executable(bin) == 1
end

function M.shellescape(value)
    return vim.fn.shellescape(value)
end

function M.current_file()
    return vim.api.nvim_buf_get_name(0)
end

function M.current_dir()
    return vim.fn.expand('%:p:h')
end

function M.current_basename()
    return vim.fn.expand('%:t:r')
end

function M.current_line()
    return vim.api.nvim_win_get_cursor(0)[1]
end

function M.filetype()
    return vim.bo.filetype
end

function M.notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = 'Salesforce' })
end

function M.open_term_cmd(cmd, height)
    height = height or 14
    vim.cmd('botright ' .. height .. 'split | terminal ' .. cmd)
end

function M.ensure_sf()
    if not M.executable('sf') then
        M.notify('sf CLI not found in PATH', vim.log.levels.ERROR)
        return false
    end
    return true
end

function M.has_file()
    local file = M.current_file()
    if file == '' then
        M.notify('No current file', vim.log.levels.WARN)
        return false
    end
    return true
end

return M
