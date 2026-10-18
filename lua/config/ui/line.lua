-- /qompassai/Diver/lua/config/ui/line.lua
-- Qompass AI Diver Statusline Config
---@module 'config.ui.line'
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

local changes_cache = {
    cwd = nil,
    text = '',
    at = 0,
}

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

---@return string e.g. "+12 ~3 -4"; empty when the tree is clean
local function git_changes()
    local cwd = vim.fn.getcwd()
    local now = vim.uv.hrtime() / 1e6
    if changes_cache.cwd == cwd and (now - changes_cache.at) < BRANCH_TTL_MS then
        return changes_cache.text
    end
    local added = 0
    local changed = 0
    local removed = 0
    for _, line in ipairs(vim.fn.systemlist('git diff --numstat HEAD 2>/dev/null')) do
        local add_count, del_count = line:match('^(%d+)%s+(%d+)%s+')
        if add_count ~= nil and del_count ~= nil then
            local added_lines = tonumber(add_count)
            local removed_lines = tonumber(del_count)
            if added_lines ~= nil and removed_lines ~= nil then
                local both = math.min(added_lines, removed_lines)
                changed = changed + both
                added = added + (added_lines - both)
                removed = removed + (removed_lines - both)
            end
        end
    end
    local parts = {}
    if added > 0 then
        parts[#parts + 1] = '+' .. added
    end
    if changed > 0 then
        parts[#parts + 1] = '~' .. changed
    end
    if removed > 0 then
        parts[#parts + 1] = '-' .. removed
    end
    local text = table.concat(parts, ' ')
    changes_cache = {
        cwd = cwd,
        text = text,
        at = now,
    }
    return text
end

-- Per-severity diagnostic segments: icon and highlight group.
-- Icons match the sign text in lua/config/core/lsp.lua; segment
-- colors are the built-in Diagnostic* defaults, composed onto the
-- panel background by define_hls (the DiverSLDiag* groups), so the
-- statusline always agrees with the sign column and virtual text.
-- Segments are in severity order (the semantic order).
local DIAG_SEGMENTS = {
    { severity = diagnostic.severity.ERROR, icon = '󰅚 ', hl = 'DiverSLDiagError' },
    { severity = diagnostic.severity.WARN, icon = '󰀪 ', hl = 'DiverSLDiagWarn' },
    { severity = diagnostic.severity.INFO, icon = '󰋽 ', hl = 'DiverSLDiagInfo' },
    { severity = diagnostic.severity.HINT, icon = '󰌶 ', hl = 'DiverSLDiagHint' },
}

---@param bufnr integer
---@return string statusline-format text: one highlighted icon and count per severity, zeros included
local function diag_counts(bufnr)
    local counts = diagnostic.count(bufnr)
    local parts = {}
    for _, segment in ipairs(DIAG_SEGMENTS) do
        local n = counts[segment.severity] or 0
        parts[#parts + 1] = '%#' .. segment.hl .. '#' .. segment.icon .. n
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
        'normal',
        'DiverModeN',
    },
    i = {
        'insert',
        'DiverModeI',
    },
    v = {
        'visual',
        'DiverModeV',
    },
    V = { 'v-line', 'DiverModeV' },
    ['\22'] = { 'v-block', 'DiverModeV' },
    c = { 'command', 'DiverModeC' },
    R = { 'replace', 'DiverModeR' },
    t = { 'terminal', 'DiverModeT' },
    s = { 'select', 'DiverModeV' },
}

local function define_hls()
    local hls = {
        DiverModeN = {
            fg = '#0a0e14',
            bg = '#58c3ff',
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
        DiverArrowCMain = { fg = '#e5c07b', bg = '#141b26' },
        DiverArrowCPanel = { fg = '#e5c07b', bg = '#1e2836' },
        DiverArrowIMain = { fg = '#98c379', bg = '#141b26' },
        DiverArrowIPanel = { fg = '#98c379', bg = '#1e2836' },
        DiverArrowNMain = { fg = '#58c3ff', bg = '#141b26' },
        DiverArrowNPanel = { fg = '#58c3ff', bg = '#1e2836' },
        DiverArrowRMain = { fg = '#e06c75', bg = '#141b26' },
        DiverArrowRPanel = { fg = '#e06c75', bg = '#1e2836' },
        DiverArrowTMain = { fg = '#56b6c2', bg = '#141b26' },
        DiverArrowTPanel = { fg = '#56b6c2', bg = '#1e2836' },
        DiverArrowVMain = { fg = '#c678dd', bg = '#141b26' },
        DiverArrowVPanel = { fg = '#c678dd', bg = '#1e2836' },
        DiverSLArrowMain = { fg = '#141b26', bg = '#1e2836' },
        DiverSLArrowPanel = { fg = '#1e2836', bg = '#141b26' },
        DiverSLDimPanel = { fg = '#5b6b82', bg = '#1e2836' },
        DiverSLPanel = { fg = '#c8d3e0', bg = '#1e2836' },
    }
    -- Diagnostic segment colors come from the active colorscheme's
    -- Diagnostic* groups, composed onto the panel background (a bare
    -- Diagnostic* group has no bg, which would punch a hole in the
    -- panel). Re-derived on every call, so colorscheme changes and
    -- the ColorScheme autocmd keep them correct.
    local function diag_segment(name)
        local hl = api.nvim_get_hl(0, { name = name })
        local fg = '#c8d3e0'
        if hl.fg ~= nil then
            fg = string.format('#%06x', hl.fg)
        end
        return { fg = fg, bg = '#1e2836', bold = true }
    end
    hls.DiverSLDiagError = diag_segment('DiagnosticError')
    hls.DiverSLDiagHint = diag_segment('DiagnosticHint')
    hls.DiverSLDiagInfo = diag_segment('DiagnosticInfo')
    hls.DiverSLDiagWarn = diag_segment('DiagnosticWarn')
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

function _G.diver_sl_changes()
    return git_changes()
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
    return ft
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
    return (tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
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
    local fname = vim.fn.expand('%:p:~')
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
    if timer == nil then
        return
    end
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
    local info = MODE_INFO[mode_code] or { mode_code, 'DiverModeN' }
    local mode_hl = info[2]
    local arrow_suffix = mode_hl:sub(-1)

    local parts = {}
    -- Mode block with a pointed boundary into the panel section.
    parts[#parts + 1] = '%#' .. mode_hl .. '# ' .. info[1] .. ' '
    parts[#parts + 1] = '%#DiverArrow' .. arrow_suffix .. 'Panel#' .. ''
    -- Panel section: branch, changes, diagnostics.
    local panel = {}
    local branch = _G.diver_sl_branch()
    if branch ~= '' then
        panel[#panel + 1] = branch
    end
    local changes = _G.diver_sl_changes()
    if changes ~= '' then
        panel[#panel + 1] = changes
    end
    panel[#panel + 1] = _G.diver_sl_diags()
    parts[#parts + 1] = '%#DiverSLPanel# ' .. table.concat(panel, ' ') .. ' '
    parts[#parts + 1] = '%#DiverSLArrowPanel#' .. ''
    -- Filename on main; word/char counts on a panel chip with a
    -- boundary arrow in and out.
    parts[#parts + 1] = '%#DiverSLMain# %f%m%r '
    parts[#parts + 1] = '%#DiverSLArrowMain#' .. ''
    parts[#parts + 1] = '%#DiverSLDimPanel# ' .. word_char_counts() .. ' '
    parts[#parts + 1] = '%#DiverSLArrowPanel#' .. ''
    parts[#parts + 1] = '%#DiverSLMain#'
    parts[#parts + 1] = '%='
    -- Right side: LSP and encoding on main, filetype on the panel,
    -- position and clock on main, line:col on the mode block.
    parts[#parts + 1] = '%#DiverSLMain#' .. _G.diver_sl_lsp() .. ' '
    local enc = _G.diver_sl_encoding()
    if enc ~= '' then
        parts[#parts + 1] = enc .. ' '
    end
    local ft = _G.diver_sl_ft()
    if ft ~= '' then
        parts[#parts + 1] = '%#DiverSLArrowPanel#' .. ''
        parts[#parts + 1] = '%#DiverSLPanel# ' .. ft .. ' '
        parts[#parts + 1] = '%#DiverSLArrowMain#' .. ''
        parts[#parts + 1] = '%#DiverSLMain#'
    end
    parts[#parts + 1] = ' %P ' .. os.date('%Y-%m-%d %H:%M:%S') .. ' '
    parts[#parts + 1] = '%#DiverArrow' .. arrow_suffix .. 'Main#' .. ''
    parts[#parts + 1] = '%#' .. mode_hl .. '# %l:%c '
    return table.concat(parts, '')
end

local clock_timer_set = false
local function setup_clock_timer()
    if clock_timer_set then
        return
    end
    clock_timer_set = true
    local timer = vim.uv.new_timer()
    if timer == nil then
        return
    end
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
    api.nvim_create_autocmd('DiagnosticChanged', {
        group = group,
        callback = function()
            vim.cmd('redrawstatus')
        end,
        desc = 'Redraw statusline when diagnostics change',
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
