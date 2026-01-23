-- /qompassai/Diver/lua/config/core/lint.lua
-- Qompass AI Diver Core Linter Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
vim.api.nvim_create_autocmd({
    'BufWritePost',
    'InsertLeave',
}, {
    group = vim.api.nvim_create_augroup('Lint', {
        clear = true,
    }),
    callback = function(args)
        M.lint(args.buf)
    end,
})
vim.cmd([[
    iabbr cosnt const
    iabbr imprt import
    iabbr imoprt import
    iabbr udpate update
    iabbr imrpvoe improve
    iabbr imrpvoe improve
    iabbr ipmrove  improve
    iabbr imrpve improve
    iabbr imprve improve
    iabbr Imrpvoe Improve
    iabbr Imrpvoe Improve
    iabbr Ipmrove Improve
    iabbr Imrpve Improve
    iabbr Imprve Improve
    iabbr funcition function
    iabbr funciton function
    iabbr fucntion function
    iabbr functoin function
    iabbr funtion function
    iabbr fucntoin function
    iabbr aciton action
    iabbr acton action
    iabbr actoin action
    iabbr actin action
    iabbr ation action
    iabbr actoins actions
    iabbr acitns actions
    iabbr resposne response
    iabbr respnse response
    iabbr reponse response
    iabbr respone response
    iabbr resonse response
    iabbr resopnse response
    iabbr resposnes responses
    iabbr respnses responses
    iabbr reponses responses
    iabbr transation transaction
    iabbr transaciton transaction
    iabbr transacton transaction
    iabbr transction transaction
    iabbr trasaction transaction
    iabbr trasnsaction transaction
    iabbr transactoin transaction
    iabbr transactoins transactions
    iabbr transations transactions
    iabbr transacitons transactions
    iabbr transactons transactions
    iabbr transctions transactions
    iabbr repot report
    iabbr reort report
    iabbr rport report
    iabbr reprt report
    iabbr reoprt report
    iabbr repots reports
    iabbr reorts reports
    iabbr rports reports
    iabbr repotAction reportAction
    iabbr reportAciton reportAction
    iabbr reportActoin reportAction
    iabbr reprotAction reportAction
    iabbr reoprtAction reportAction
    iabbr reprtAction reportAction
    iabbr Onxy Onyx
    iabbr Onix Onyx
    iabbr Onyix Onyx
    iabbr Onxyx Onyx
    iabbr onxy onyx
    iabbr onix onyx
    iabbr onyix onyx
    iabbr onxyx onyx
    iabbr transationID transactionID
    iabbr transacitonID transactionID
    iabbr transactonID transactionID
    iabbr transctionID transactionID
    iabbr trasactionID transactionID
    iabbr trasnsactionID transactionID
    iabbr transactoinID transactionID
    iabbr repotActionID reportActionID
    iabbr reportAcitonID reportActionID
    iabbr reportActoinID reportActionID
    iabbr reprotActionID reportActionID
    iabbr reoprtActionID reportActionID
    iabbr reprtActionID reportActionID
    iabbr repotID reportID
    iabbr reortID reportID
    iabbr rportID reportID
    iabbr reprtID reportID
    iabbr reoprtID reportID
]])
local running_procs_by_buf = {} ---@type table<integer, table<string, integer>>
local namespaces = setmetatable({}, {
    __index = function(tbl, key)
        ---@cast key string
        local ns = vim.api.nvim_create_namespace(key)
        rawset(tbl, key, ns)
        return ns
    end,
})
---@return integer
function M.get_namespace(name) ---@param name string
    return namespaces[name]
end

---@return string[]
function M.get_running(bufnr) ---@param bufnr? integer
    local linters = {}
    if bufnr then
        bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
        local running_procs = running_procs_by_buf[bufnr] or {}
        for linter_name, _ in pairs(running_procs) do
            table.insert(linters, linter_name)
        end
    else
        for _, running_procs in pairs(running_procs_by_buf) do
            for linter_name, _ in pairs(running_procs) do
                table.insert(linters, linter_name)
            end
        end
    end
    return linters
end

local linters_root = require('linters') ---@type table
local linters_by_ft = linters_root.linters_by_ft or {}
local linter_specs = {} ---@type table<string, vim.lint.Config|false>
local function get_linter_spec(name)
    if linter_specs[name] ~= nil then
        return linter_specs[name] or nil
    end
    local ok, spec = pcall(require, 'linters.' .. name)
    if not ok then
        vim.notify('lint: failed to load linter \'' .. name .. '\': ' .. spec, vim.log.levels.ERROR)
        linter_specs[name] = false
        return nil
    end
    linter_specs[name] = spec
    return spec
end
local function run_linter(name, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local spec = get_linter_spec(name)
    if not spec or not spec.cmd then
        return
    end
    local ns = M.get_namespace(name)
    local args = {}
    if type(spec.args) == 'function' then
        args = spec.args(bufnr)
    elseif type(spec.args) == 'table' then
        args = vim.list_extend({}, spec.args)
    end
    local cmdline = { spec.cmd }
    vim.list_extend(cmdline, args or {})
    local stdin = spec.stdin == true
    local append_fname = spec.append_fname ~= false
    if append_fname then
        table.insert(cmdline, vim.api.nvim_buf_get_name(bufnr))
    end
    local text
    if stdin then
        text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
    end
    local output = { stdout = {}, stderr = {} }
    running_procs_by_buf[bufnr] = running_procs_by_buf[bufnr] or {}
    local job_id = vim.fn.jobstart(cmdline, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                vim.list_extend(output.stdout, data)
            end
        end,
        on_stderr = function(_, data)
            if data then
                vim.list_extend(output.stderr, data)
            end
        end,
        on_exit = function()
            running_procs_by_buf[bufnr][name] = nil
            local stream = spec.stream or 'stdout'
            local lines
            if stream == 'stdout' then
                lines = output.stdout
            elseif stream == 'stderr' then
                lines = output.stderr
            else
                lines = vim.list_extend(output.stdout, output.stderr)
            end
            local joined = table.concat(lines, '\n')
            local diags = {}
            if type(spec.parser) == 'function' then
                diags = spec.parser(joined, bufnr) or {}
            end
            vim.diagnostic.set(ns, bufnr, diags, {})
        end,
    })
    running_procs_by_buf[bufnr][name] = job_id
    if stdin and text then
        vim.fn.chansend(job_id, text)
        vim.fn.chanclose(job_id, 'stdin')
    end
end
function M.lint(opts)
    if opts == nil or type(opts) ~= 'table' then
        opts = { bufnr = opts }
    end
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local name = opts.name
    if name then
        run_linter(name, bufnr)
        return
    end
    local ft = vim.bo[bufnr].filetype
    local names = linters_by_ft[ft]
    if not names then
        return
    end
    for _, n in ipairs(names) do
        run_linter(n, bufnr)
    end
end
return M