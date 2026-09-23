-- Native scratch buffers and selectors. Remote text cannot create mappings or commands.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local api, util = vim.api, require('acp.util')
local M = {}
local INSPECTORS_MAX, DISPLAY_BYTES_MAX, DISPLAY_LINES_MAX = 8, 1024 * 1024, 16384
local inspectors = {}

local function buffer(name, filetype)
    local value = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(value, name)
    vim.bo[value].buftype = 'nofile'
    vim.bo[value].bufhidden = 'hide'
    vim.bo[value].swapfile = false
    vim.bo[value].modeline = false
    vim.bo[value].filetype = filetype
    return value
end

local function replace(buf, text)
    if not api.nvim_buf_is_valid(buf) then
        return
    end
    vim.bo[buf].modifiable = true
    api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(util.display(text), '\n', { plain = true }))
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
end

function M.render(state)
    if not state.buffer or not api.nvim_buf_is_valid(state.buffer) then
        return
    end
    local lines = {
        '# ' .. state.agent_name .. ' (' .. state.agent.protocol .. ')',
        '',
        'State: ' .. state.remote.state .. (state.busy and ' | observing' or ''),
        'Task/run: ' .. (state.remote.id or 'not assigned'),
        '',
    }
    if state.error then
        lines[#lines + 1] = 'Error: ' .. state.error .. '\n'
    end
    for _, part in ipairs(state.prompt_parts) do
        lines[#lines + 1] = '## Sent\n\n' .. part.text .. '\n'
    end
    for _, message in ipairs(state.remote.messages) do
        lines[#lines + 1] = '## '
            .. message.role
            .. '\n\n'
            .. require('acp.model').text(message.parts)
            .. '\n'
    end
    for _, id in ipairs(state.remote.artifact_order) do
        local artifact = state.remote.artifacts[id]
        lines[#lines + 1] = '## Artifact: '
            .. tostring(artifact.name or id)
            .. '\n\n'
            .. require('acp.model').text(artifact.parts)
            .. '\n'
    end
    if state.remote.await_request then
        lines[#lines + 1] = '## Awaiting input\n\n' .. (util.json(state.remote.await_request) or '')
    end
    local text = table.concat(lines, '\n')
    if #text > DISPLAY_BYTES_MAX then
        text = text:sub(1, DISPLAY_BYTES_MAX) .. '\n[Display byte limit]'
    end
    local count, cut = 0, nil
    for position in text:gmatch('()\n') do
        count = count + 1
        if count == DISPLAY_LINES_MAX then
            cut = position
            break
        end
    end
    if cut then
        text = text:sub(1, cut) .. '[Display line limit]'
    end
    replace(state.buffer, text)
end

function M.open(state)
    if not state.buffer or not api.nvim_buf_is_valid(state.buffer) then
        state.buffer = buffer('acp://' .. state.key, 'markdown')
        vim.b[state.buffer].acp_session = state.key
    end
    vim.cmd('botright vsplit')
    api.nvim_win_set_buf(0, state.buffer)
    M.render(state)
    require('mappings.acpmap').buffer(state.buffer)
end

function M.inspect(title, value)
    local text = type(value) == 'string' and value or util.json(value)
    if not text then
        util.notify('Could not encode inspection data')
        return
    end
    local _, line_count = text:gsub('\n', '')
    if #text > DISPLAY_BYTES_MAX or line_count > DISPLAY_LINES_MAX then
        util.notify('Inspection exceeds 1 MiB or 16384 lines; select less content')
        return nil
    end
    inspectors = vim.tbl_filter(api.nvim_buf_is_valid, inspectors)
    if #inspectors >= INSPECTORS_MAX then
        util.notify('Close an inspection buffer before opening another (limit 8)')
        return nil
    end
    local id, err = util.id()
    if not id then
        util.notify(err)
        return
    end
    local buf = buffer('acp-inspect://' .. id, 'text')
    inspectors[#inspectors + 1] = buf
    vim.bo[buf].bufhidden = 'wipe'
    replace(buf, title .. '\n\n' .. text)
    vim.cmd('botright split')
    api.nvim_win_set_buf(0, buf)
    vim.keymap.set(
        'n',
        'q',
        '<cmd>close<CR>',
        { buffer = buf, silent = true, desc = 'Close inspector' }
    )
    return buf
end

function M.close(state)
    if state.buffer and api.nvim_buf_is_valid(state.buffer) then
        api.nvim_buf_delete(state.buffer, { force = true })
    end
    state.buffer = nil
end
return M
