-- /qompassai/Diver/lua/utils/nb.lua
-- Qompass AI Diver Notebook Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
local api = vim.api
local fn = vim.fn
local function default_cmd_for_ft(ft)
    if ft == 'python' then
        return 'python -i'
    elseif ft == 'lua' then
        return 'lua -i'
    elseif ft == 'r' or ft == 'rmarkdown' or ft == 'quarto' then
        return 'R --quiet'
    elseif ft == 'javascript' or ft == 'typescript' then
        return 'node'
    elseif ft == 'sh' or ft == 'bash' or ft == 'zsh' then
        return 'bash'
    elseif ft == 'julia' then
        return 'julia'
    elseif ft == 'ruby' then
        return 'irb'
    elseif ft == 'php' then
        return 'php -a'
    else
        return 'python -i'
    end
end
local function ensure_kernel(default_cmd)
    for _, buf in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == 'terminal' then
            return buf
        end
    end
    vim.cmd('botright split')
    local term_buf = api.nvim_create_buf(false, true)
    api.nvim_win_set_buf(0, term_buf)
    vim.cmd('terminal ' .. default_cmd)
    return term_buf
end
local function prep_code_for_ft(ft, lines)
    if ft == 'r' or ft == 'rmarkdown' or ft == 'quarto' then
        local out = {}
        for _, l in ipairs(lines) do
            if not l:match('^```') then
                table.insert(out, l)
            end
        end
        return out
    end
    return lines
end
local function current_cell_range()
    local bufnr = api.nvim_get_current_buf()
    local cur = api.nvim_win_get_cursor(0)
    local lnum = cur[1]
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local start_lnum = 1
    local end_lnum = #lines
    for i = lnum, 1, -1 do
        if lines[i]:match('^## %%%%') then
            start_lnum = i + 1
            break
        end
    end
    for i = lnum + 1, #lines do
        if lines[i]:match('^## %%%%') then
            end_lnum = i - 1
            break
        end
    end
    if end_lnum < start_lnum then
        return nil, nil
    end
    return start_lnum, end_lnum
end
local function send_range_to_term(term_buf, bufnr, start_lnum, end_lnum)
    local ft = vim.bo[bufnr].filetype
    local lines = api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false)
    if #lines == 0 then
        return
    end
    lines = prep_code_for_ft(ft, lines)
    if #lines == 0 then
        return
    end
    lines[#lines + 1] = ''
    local job_id = fn.term_getjob(term_buf)
    if not job_id or job_id == 0 then
        vim.notify('[notebook] terminal job not found', vim.log.levels.ERROR)
        return
    end
    for _, line in ipairs(lines) do
        fn.chansend(job_id, line .. '\n')
    end
end

function M.run_cell()
    local bufnr = api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype
    local start_lnum, end_lnum = current_cell_range()
    if not start_lnum or not end_lnum then
        vim.notify('[notebook] no cell found around cursor', vim.log.levels.WARN)
        return
    end
    local term_buf = ensure_kernel(default_cmd_for_ft(ft))
    send_range_to_term(term_buf, bufnr, start_lnum, end_lnum)
end

function M.run_selection()
    local bufnr = api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype
    local start_pos = fn.getpos([['<]])
    local end_pos = fn.getpos([['>]])
    local start_lnum = start_pos[2]
    local end_lnum = end_pos[2]
    if start_lnum > end_lnum then
        start_lnum, end_lnum = end_lnum, start_lnum
    end
    local term_buf = ensure_kernel(default_cmd_for_ft(ft))
    send_range_to_term(term_buf, bufnr, start_lnum, end_lnum)
end

function M.restart_kernel()
    for _, buf in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == 'terminal' then
            vim.cmd('bwipeout ' .. buf)
        end
    end
    vim.notify('[notebook] kernel terminal will restart on next run', vim.log.levels.INFO)
end

return M