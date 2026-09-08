-- /qompassai/Diver/lua/utils/red/shark.lua
-- Qompass AI Diver Red WireShark Util
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {} ---@version JIT
local api = vim.api
local bo = vim.bo
local escape = vim.fn.shellescape
local insert = table.insert
local notify = vim.notify
local WARN = vim.log.levels.WARN
local wo = vim.wo
local function run_cmd_in_term(cmd, title)
    vim.cmd('botright split')
    local buf = api.nvim_create_buf(false, true)
    api.nvim_win_set_buf(0, buf)
    bo[buf].buftype = 'terminal'
    bo[buf].bufhidden = 'hide'
    bo[buf].swapfile = false
    if title then
        vim.cmd('file ' .. title)
    end
    vim.cmd('terminal ' .. cmd)
    wo[0].number = false
    wo[0].relativenumber = false
end
local function run_cmd_capture_output(cmd)
    local handle = io.popen(cmd .. ' 2>/dev/null')
    if not handle then
        return nil, 'failed to spawn: ' .. cmd
    end
    local out = handle:read('*a') or ''
    handle:close()
    local lines = {}
    for l in out:gmatch('[^]+') do
        insert(lines, l)
    end
    return lines, nil
end
local function show_in_scratch(title, lines, ft)
    if not lines then
        lines = {}
    end
    local buf = vim.api.nvim_create_buf(false, true)
    bo[buf].bufhidden = 'wipe'
    bo[buf].buftype = 'nofile'
    bo[buf].swapfile = false
    if ft then
        bo[buf].filetype = ft
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.cmd('botright split')
    api.nvim_win_set_buf(0, buf)
    wo[0].number = false
    wo[0].relativenumber = false
    vim.cmd('file ' .. title)
end
function M.list_interfaces()
    local lines, err = run_cmd_capture_output('tshark -D')
    if err then
        notify('[tshark] ' .. err, vim.log.levels.ERROR)
        return
    end
    if #lines == 0 then
        notify('[tshark] no interfaces reported (need sudo or dumpcap perms?)', WARN)
        return
    end
    show_in_scratch('TsharkInterfaces', lines, 'tshark')
end

function M.live_capture(opts)
    opts = opts or {}
    local ifname = opts.ifname or 'any'
    local capture_filter = opts.capture_filter or ''
    local display_filter = opts.display_filter or ''
    local count = opts.count
    local hex = opts.hex or false
    local parts = { 'sudo', 'tshark', '-i', escape(ifname) }
    if count and tonumber(count) then
        insert(parts, '-c ' .. tonumber(count))
    end
    if capture_filter ~= '' then
        insert(parts, '-f ' .. escape(capture_filter))
    end
    if display_filter ~= '' then
        insert(parts, '-Y ' .. escape(display_filter))
    end
    if hex then
        insert(parts, '-x')
    end
    local cmd = table.concat(parts, ' ')
    run_cmd_in_term(cmd, 'TsharkCapture')
end

function M.read_pcap(path, display_filter)
    if not path or path == '' then
        notify('[tshark] provide a pcap path', WARN)
        return
    end
    local parts = { 'tshark', '-r', escape(path) }
    if display_filter and display_filter ~= '' then
        insert(parts, '-Y ' .. escape(display_filter))
    end
    local cmd = table.concat(parts, ' ')
    run_cmd_in_term(cmd, 'TsharkPcap')
end

function M.live_http(ifname)
    M.live_capture({
        ifname = ifname or 'any',
        display_filter = 'http',
    })
end

function M.live_dns(ifname)
    M.live_capture({
        ifname = ifname or 'any',
        display_filter = 'dns',
    })
end

function M.live_tls(ifname)
    M.live_capture({
        ifname = ifname or 'any',
        display_filter = 'tls',
    })
end

function M.live_host(ifname, host)
    if not host or host == '' then
        notify('[tshark] host required, e.g. :TsharkHost any example.com', WARN)
        return
    end
    M.live_capture({
        ifname = ifname or 'any',
        capture_filter = 'host ' .. host,
    })
end

return M