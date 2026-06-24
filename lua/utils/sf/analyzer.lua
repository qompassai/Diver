-- lua/utils/sf/analyzer.lua
local cmdutil = require('utils.sf.cmdutil')
local util = require('utils.sf.util')

local M = {}

local ns = vim.api.nvim_create_namespace('sf_code_analyzer')

local function severity_from(value)
    local s = tostring(value or ''):lower()

    if s == 'critical' or s == 'high' then
        return vim.diagnostic.severity.ERROR
    elseif s == 'moderate' then
        return vim.diagnostic.severity.WARN
    elseif s == 'low' then
        return vim.diagnostic.severity.INFO
    end

    return vim.diagnostic.severity.HINT
end

local function normalize_path(path)
    if not path or path == '' then
        return nil
    end
    return vim.fs.normalize(path)
end
local function current_buf_path(bufnr)
    return normalize_path(vim.api.nvim_buf_get_name(bufnr))
end

local function read_file(path)
    local fd = io.open(path, 'r')
    if not fd then
        return nil
    end
    local content = fd:read('*a')
    fd:close()
    return content
end

local function violation_to_diagnostic(v)
    local start_line = math.max((tonumber(v.startLine) or 1) - 1, 0)
    local start_col = math.max((tonumber(v.startColumn) or 1) - 1, 0)
    local end_line = math.max((tonumber(v.endLine) or tonumber(v.startLine) or 1) - 1, start_line)
    local end_col = math.max((tonumber(v.endColumn) or tonumber(v.startColumn) or 1) - 1, start_col)

    local rule = v.rule or v.ruleName or v.engine or 'code-analyzer'
    local message = v.message or v.primaryMessage or 'Salesforce Code Analyzer violation'

    if v.help then
        message = message .. ' [' .. tostring(v.help) .. ']'
    end

    return {
        lnum = start_line,
        col = start_col,
        end_lnum = end_line,
        end_col = end_col,
        severity = severity_from(v.severity),
        source = 'sf-code-analyzer',
        code = rule,
        message = message,
    }
end

local function collect_file_diagnostics(decoded, file)
    local diagnostics = {}
    local violations = decoded.violations or {}

    for _, v in ipairs(violations) do
        local vpath = normalize_path(v.file or v.fileName or v.filePath or v.path)
        if not vpath or vpath == file then
            table.insert(diagnostics, violation_to_diagnostic(v))
        end
    end

    return diagnostics
end

local function run_json_command(target, extra_args)
    local tmpfile = vim.fn.tempname() .. '.json'
    local cmd = {
        'sf',
        'code-analyzer',
        'run',
        '--target',
        target,
        '--output-file',
        tmpfile,
    }

    if extra_args and type(extra_args) == 'table' then
        for _, arg in ipairs(extra_args) do
            table.insert(cmd, arg)
        end
    end

    local result = vim.system(cmd, { text = true }):wait()

    if result.code ~= 0 then
        local stderr = result.stderr or ''
        if stderr == '' then
            stderr = result.stdout or 'Code Analyzer failed'
        end
        vim.notify(stderr, vim.log.levels.ERROR)
        return nil
    end

    local content = read_file(tmpfile)
    if not content then
        vim.notify('Unable to read analyzer output: ' .. tmpfile, vim.log.levels.ERROR)
        return nil
    end

    local ok, decoded = pcall(vim.json.decode, content)
    if not ok or type(decoded) ~= 'table' then
        vim.notify('Failed to parse Code Analyzer JSON output', vim.log.levels.ERROR)
        return nil
    end

    return decoded, tmpfile
end

function M.clear_diagnostics(bufnr)
    vim.diagnostic.reset(ns, bufnr or 0)
end

function M.config()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf code-analyzer config', 20)
end

function M.config_generate(opts)
    if not util.ensure_sf() then
        return
    end
    local output = cmdutil.get_arg(opts)
    local cmd = 'sf code-analyzer config generate'
    if output then
        cmd = cmd .. ' --output-file ' .. util.shellescape(output)
    end
    util.open_term_cmd(cmd, 20)
end

function M.rules()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf code-analyzer rules', 20)
end

function M.run_file(opts)
    if not util.ensure_sf() then
        return
    end

    local target = cmdutil.get_arg(opts) or current_buf_path(vim.api.nvim_get_current_buf())
    if not target or target == '' then
        return
    end

    util.open_term_cmd('sf code-analyzer run --target ' .. util.shellescape(target) .. ' --view table', 20)
end

function M.run_file_diagnostics(opts)
    if not util.ensure_sf() then
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local target = cmdutil.get_arg(opts)
    local file = target and normalize_path(target) or current_buf_path(bufnr)

    if not file or file == '' then
        vim.notify('No file target for analyzer diagnostics', vim.log.levels.WARN)
        return
    end

    local decoded = run_json_command(file)
    if not decoded then
        return
    end

    local diagnostics = collect_file_diagnostics(decoded, file)

    vim.diagnostic.set(ns, bufnr, diagnostics, {
        underline = true,
        virtual_text = true,
        signs = true,
        severity_sort = true,
    })

    vim.notify(string.format('Code Analyzer: %d diagnostic(s) loaded', #diagnostics), vim.log.levels.INFO)
end

function M.run_project_json(opts)
    if not util.ensure_sf() or not util.ensure_project() then
        return
    end
    local target = cmdutil.get_arg(opts) or 'force-app'
    util.open_term_cmd('sf code-analyzer run --target ' .. util.shellescape(target) .. ' --view json', 20)
end

function M.run_project_json_to_file(opts)
    if not util.ensure_sf() or not util.ensure_project() then
        return
    end

    local target = cmdutil.get_arg(opts) or 'force-app'
    local output = vim.fn.input('Output JSON file> ', 'sfca_results.json')

    if output == '' then
        return
    end

    util.open_term_cmd(
        'sf code-analyzer run --target '
            .. util.shellescape(target)
            .. ' --output-file '
            .. util.shellescape(output)
            .. ' --view table',
        20
    )
end

function M.run_severity(opts)
    if not util.ensure_sf() or not util.ensure_project() then
        return
    end
    local severity = cmdutil.get_arg(opts) or vim.fn.input('Severity [Critical|High|Moderate|Low|Info]> ')

    if severity == '' then
        return
    end

    util.open_term_cmd(
        'sf code-analyzer run --target force-app --severity-threshold ' .. util.shellescape(severity) .. ' --view table',
        20
    )
end

return M
