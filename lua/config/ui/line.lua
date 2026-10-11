-- /qompassai/Diver/lua/config/ui/line.lua
-- Qompass AI Diver Statusline Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}

local api = vim.api
local diagnostic = vim.diagnostic
local lsp = vim.lsp

local branch_cache = {
    cwd = nil,
    branch = '',
    at = 0,
}
local BRANCH_TTL_MS = 5000

---@return string
local function git_branch()
    local cwd = vim.fn.getcwd()
    local now = vim.uv.hrtime() / 1e6
    if branch_cache.cwd == cwd and (now - branch_cache.at) < BRANCH_TTL_MS then
        return branch_cache.branch
    end
    local out = vim.fn.systemlist('git branch --show-current 2>/dev/null')
    local branch = (out[1] or ''):gsub('%s+', '')
    branch_cache = {
        cwd = cwd,
        branch = branch,
        at = now,
    }
    return branch
end

---@param bufnr integer
---@return string
local function diag_counts(bufnr)
    local counts = {
        0,
        0,
        0,
        0,
    } -- error, warn, info, hint
    for _, d in ipairs(diagnostic.get(bufnr)) do
        local s = d.severity
        if s >= 1 and s <= 4 then
            counts[s] = counts[s] + 1
        end
    end
    local parts = {}
    local icons = {
        'E:',
        'W:',
        'I:',
        'H:',
    }
    for i = 1, 4 do
        if counts[i] > 0 then
            parts[#parts + 1] = icons[i] .. counts[i]
        end
    end
    return table.concat(parts, ' ')
end

---@param bufnr integer
---@return string
local function lsp_names(bufnr)
    local clients = lsp.get_clients({ bufnr = bufnr })
    if #clients == 0 then
        return ''
    end
    local names = {}
    for _, client in ipairs(clients) do
        names[#names + 1] = client.name
    end
    table.sort(names)
    return table.concat(names, ',')
end

-- Mode metadata: text label and highlight group per vim mode code.
-- V-BLOCK is byte 22 (CTRL-V); Lua decimal escape '\22'.
---@type table<string, { [1]: string, [2]: string }>
local MODE_INFO = {
    n = {
        'NORMAL',
        'DiverModeN',
    },
    i = {
        'INSERT',
        'DiverModeI',
    },
    v = {
        'VISUAL',
        'DiverModeV',
    },
    V = { 'V-LINE', 'DiverModeV' },
    ['\22'] = { 'V-BLOCK', 'DiverModeV' },
    c = { 'COMMAND', 'DiverModeC' },
    R = { 'REPLACE', 'DiverModeR' },
    t = { 'TERMINAL', 'DiverModeT' },
    s = { 'SELECT', 'DiverModeV' },
}

local function define_hls()
    local hls = {
        DiverModeN = {
            fg = '#0a0e14',
            bg = '#7df9ff',
            bold = true,
        },
        DiverModeI = {
            fg = '#0a0e14',
            bg = '#98c379',
            bold = true,
        },
        DiverModeV = {
            fg = '#0a0e14',
            bg = '#c678dd',
            bold = true,
        },
        DiverModeC = { fg = '#0a0e14', bg = '#e5c07b', bold = true },
        DiverModeR = { fg = '#0a0e14', bg = '#e06c75', bold = true },
        DiverModeT = { fg = '#0a0e14', bg = '#56b6c2', bold = true },
        DiverSLMain = { fg = '#c8d3e0', bg = '#141b26' },
        DiverSLDiag = { fg = '#e06c75', bg = '#141b26', bold = true },
        DiverSLDim = { fg = '#5b6b82', bg = '#141b26' },
    }
    local names = {}
    for name in pairs(hls) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        api.nvim_set_hl(0, name, hls[name])
    end
end

function _G.diver_sl_branch()
    local b = git_branch()
    return b ~= '' and (' ' .. b) or ''
end

function _G.diver_sl_diags()
    local win = vim.g.statusline_winid or 0
    local bufnr = win ~= 0 and api.nvim_win_get_buf(win) or api.nvim_get_current_buf()
    return diag_counts(bufnr)
end

function _G.diver_sl_lsp()
    local win = vim.g.statusline_winid or 0
    local bufnr = win ~= 0 and api.nvim_win_get_buf(win) or api.nvim_get_current_buf()
    local clients = lsp.get_clients({ bufnr = bufnr })
    if #clients == 0 then
        return 'LSP: none'
    end
    return ('LSP: %d active'):format(#clients)
end

function _G.diver_sl_lsp_names()
    local bufnr = api.nvim_get_current_buf()
    local names = lsp_names(bufnr)
    return names ~= '' and (' ' .. names) or ''
end

function _G.diver_sl_encoding()
    local enc = vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding
    if vim.bo.bomb then
        enc = enc .. ' [BOM]'
    end
    -- Hide plain utf-8 without BOM (the common case)
    if enc == 'utf-8' then
        return ''
    end
    return enc
end

function _G.diver_sl_ft()
    local ft = vim.bo.filetype
    return ft ~= '' and ('[' .. ft .. ']') or ''
end

---Tabline: tab pages with current tab highlighted.
---@return string
function _G.diver_tabline()
    local s = ''
    local n_tabs = vim.fn.tabpagenr('$')
    for i = 1, n_tabs do
        local is_cur = i == vim.fn.tabpagenr()
        s = s .. '%' .. i .. 'T'
        s = s .. (is_cur and '%#TabLineSel#' or '%#TabLine#')
        s = s .. ' ' .. i .. ' '
        -- buffer name in tab
        local buflist = vim.fn.tabpagebuflist(i)
        local winnr = vim.fn.tabpagewinnr(i)
        local bufnr = buflist[winnr]
        local name = vim.fn.bufname(bufnr)
        if name == '' then
            name = '[No Name]'
        else
            name = vim.fn.fnamemodify(name, ':p:~')
        end
        s = s .. name .. ' '
    end
    s = s .. '%#TabLineFill#%T'
    return s
end

---Format an integer with thousands separators: 1234567 -> "1,234,567".
---@param n integer
---@return string
local function commas(n)
    return tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end

---Word and character counts for the current buffer, dimmed.
---@return string e.g. "1,234 words · 5,678 chars"
local function word_char_counts()
    local wc = vim.fn.wordcount()
    return commas(wc.words or 0) .. ' words · ' .. commas(wc.chars or 0) .. ' chars'
end

---Winbar: per-window top bar with filename, LSP status, and treesitter.
---@return string
function _G.diver_winbar()
    local bufnr = vim.api.nvim_get_current_buf()
    local fname = vim.fn.expand('%:t')
    if fname == '' then
        fname = '[No Name]'
    end
    local names = (function()
        local clients = vim.lsp.get_clients({ bufnr = bufnr })
        if #clients == 0 then
            return ''
        end
        local n = {}
        for _, c in ipairs(clients) do
            n[#n + 1] = c.name
        end
        table.sort(n)
        return table.concat(n, ',')
    end)()
    local ts = ''
    local ok, lang = pcall(vim.treesitter.language.get_lang, vim.bo[bufnr].filetype)
    if ok and lang then
        ts = '󰐅 ' .. lang
    end
    local parts = { fname }
    if names ~= '' then
        parts[#parts + 1] = 'LSP: ' .. names
    end
    local spinner = _G.diver_sl_spinner()
    if spinner ~= '' then
        parts[#parts + 1] = spinner
    end
    if ts ~= '' then
        parts[#parts + 1] = ts
    end
    -- Add tool statuses (formatters, linters, DAP, SCIP)
    local tools = _G.diver_sl_tools()
    if tools ~= '' then
        parts[#parts + 1] = tools
    end
    return table.concat(parts, ' │ ')
end

local progress_state = {
    active = false,
    kind = '',
    title = '',
    frame = 1,
}
local spinner_frames = {
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
}

local progress_autocmd_set = false
local function setup_progress_autocmd()
    if progress_autocmd_set then
        return
    end
    progress_autocmd_set = true
    api.nvim_create_autocmd('LspProgress', {
        desc = 'Track LSP progress for statusline spinner',
        callback = function(args)
            local data = args.data
            if type(data) ~= 'table' or type(data.params) ~= 'table' then
                return
            end
            local value = data.params.value
            if type(value) ~= 'table' then
                return
            end
            if value.kind == 'begin' then
                progress_state.active = true
                progress_state.title = value.title or ''
            elseif value.kind == 'end' then
                progress_state.active = false
                progress_state.title = ''
            end
            vim.cmd('redrawstatus')
        end,
    })
    local timer = vim.uv.new_timer()
    timer:start(
        0,
        120,
        vim.schedule_wrap(function()
            if progress_state.active then
                progress_state.frame = (progress_state.frame % #spinner_frames) + 1
                vim.cmd('redrawstatus')
            end
        end)
    )
end

function _G.diver_sl_spinner()
    if not progress_state.active then
        return ''
    end
    local frame = spinner_frames[progress_state.frame]
    local title = progress_state.title
    if title ~= '' then
        return frame .. ' ' .. title
    end
    return frame
end

---Get active formatter names for buffer.
---@param bufnr integer
---@return string
local function formatter_names(bufnr)
    local ok, formatters = pcall(require, 'formatters')
    if not ok then
        return ''
    end
    local ok2, info = pcall(formatters.info, bufnr, false)
    if not ok2 or type(info) ~= 'table' then
        return ''
    end
    -- info is a string or table; extract names
    if type(info) == 'string' then
        return info
    end
    return ''
end

---Get active linter names for buffer.
---@param bufnr integer
---@return string
local function linter_names(bufnr)
    local ok, linters = pcall(require, 'linters')
    if not ok then
        return ''
    end
    local ok2, info = pcall(linters.info, bufnr, false)
    if not ok2 or type(info) ~= 'table' then
        return ''
    end
    if type(info) == 'string' then
        return info
    end
    return ''
end

---Check DAP session status.
---@return string
local function dap_status()
    local ok, dap = pcall(require, 'dap')
    if not ok then
        return ''
    end
    local ok2, session = pcall(function()
        return dap.session()
    end)
    if ok2 and session then
        return '● DAP'
    end
    return ''
end

---Check SCIP index status for current project.
---@return string
local function scip_status()
    local cwd = vim.fn.getcwd()
    -- Check for SCIP index files
    local candidates = {
        cwd .. '/.scip/index.scip',
        cwd .. '/index.scip',
    }
    for _, path in ipairs(candidates) do
        if vim.fn.filereadable(path) == 1 then
            return 'SCIP ✓'
        end
    end
    return ''
end

function _G.diver_sl_tools()
    local bufnr = api.nvim_get_current_buf()
    local parts = {}
    local fmt = formatter_names(bufnr)
    if fmt ~= '' then
        parts[#parts + 1] = 'fmt:' .. fmt
    end
    local lint = linter_names(bufnr)
    if lint ~= '' then
        parts[#parts + 1] = 'lint:' .. lint
    end
    local dap = dap_status()
    if dap ~= '' then
        parts[#parts + 1] = dap
    end
    local scip = scip_status()
    if scip ~= '' then
        parts[#parts + 1] = scip
    end
    return table.concat(parts, ' ')
end

---Build the full statusline. Invoked via %! so the return value is
---evaluated as a statusline format: %#Group# switches and % items work
---here, unlike inside %{...} whose result is taken as literal text.
---@return string
function _G.diver_statusline()
    local mode_code = api.nvim_get_mode().mode
    local info = MODE_INFO[mode_code] or { mode_code:upper(), 'DiverModeN' }
    local mode_hl = info[2]

    local parts = {}
    parts[#parts + 1] = '%#' .. mode_hl .. '# ' .. info[1] .. ' '
    parts[#parts + 1] = '%#DiverSLMain#'
    local branch = _G.diver_sl_branch()
    if branch ~= '' then
        parts[#parts + 1] = ' ' .. branch
    end
    parts[#parts + 1] = ' %f%m%r'
    parts[#parts + 1] = ' %#DiverSLDim#' .. word_char_counts() .. '%#DiverSLMain#'
    local diags = _G.diver_sl_diags()
    if diags ~= '' then
        parts[#parts + 1] = ' %#DiverSLDiag#' .. diags .. '%#DiverSLMain#'
    end
    parts[#parts + 1] = '%='
    parts[#parts + 1] = '%#DiverSLMain#' .. _G.diver_sl_lsp() .. ' '
    local enc = _G.diver_sl_encoding()
    if enc ~= '' then
        parts[#parts + 1] = enc .. ' '
    end
    parts[#parts + 1] = _G.diver_sl_ft() .. ' %l:%c %p%% '
    parts[#parts + 1] = '%#' .. mode_hl .. '# ' .. os.date('%Y-%m-%d %H:%M:%S') .. ' '
    return table.concat(parts, '')
end

local clock_timer_set = false
local function setup_clock_timer()
    if clock_timer_set then
        return
    end
    clock_timer_set = true
    local timer = vim.uv.new_timer()
    timer:start(
        1000,
        1000,
        vim.schedule_wrap(function()
            vim.cmd('redrawstatus')
        end)
    )
end

---Configure the native statusline, tabline, and winbar.
function M.setup()
    define_hls()
    -- Re-apply after any colorscheme change: :colorscheme clears all custom
    -- highlight groups, which would leave the mode bands uncolored.
    local group = api.nvim_create_augroup('DiverLine', {
        clear = true,
    })
    api.nvim_create_autocmd('ColorScheme', {
        group = group,
        callback = define_hls,
        desc = 'Re-apply Diver statusline highlight groups',
    })
    setup_progress_autocmd()
    setup_clock_timer()
    vim.o.laststatus = 2
    vim.o.showtabline = 1 -- show tabline only when >1 tab
    vim.o.tabline = '%!v:lua.diver_tabline()'
    vim.o.winbar = '%!v:lua.diver_winbar()'
    -- %! evaluates the builder's return as a statusline format string.
    vim.o.statusline = '%!v:lua.diver_statusline()'
end

return M
