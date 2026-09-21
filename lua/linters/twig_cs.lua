-- Native Twig-CS-Fixer lint adapter; Neovim 0.13+, no nvim-lint dependency.
-- SPDX-License-Identifier: Apache-2.0
-- Upstream GitlabReporter is JSON; there is no built-in --report=json.
local api = vim.api
local fs = vim.fs
local uv = vim.uv
local DIAGNOSTICS_MAX = 4096
local OUTPUT_BYTES_MAX = 1024 * 1024
local MESSAGE_BYTES_MAX = 8192
local severity = {
    blocker = vim.diagnostic.severity.ERROR,
    critical = vim.diagnostic.severity.ERROR,
    major = vim.diagnostic.severity.ERROR,
    minor = vim.diagnostic.severity.WARN,
    info = vim.diagnostic.severity.INFO,
}

---@param output string
---@return table[]
local function records(output)
    assert(#output <= OUTPUT_BYTES_MAX, 'Twig report exceeds output limit')
    assert(output:match('^%s*%['), 'expected Twig GitLab JSON array; check stderr/configuration')
    local ok, decoded = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
    assert(ok and type(decoded) == 'table' and vim.islist(decoded), 'invalid Twig JSON report')
    assert(#decoded <= DIAGNOSTICS_MAX, 'Twig report exceeds diagnostic limit')
    return decoded
end

---@param value unknown
---@return integer
local function line_number(value)
    assert(type(value) == 'number' and value >= 1 and value <= 2147483647, 'invalid Twig line')
    assert(value % 1 == 0, 'Twig line is not an integer')
    return math.floor(value) - 1
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    local diagnostics = {} ---@type vim.Diagnostic.Set[]
    local target = uv.fs_realpath(context.filename) or fs.normalize(context.filename)
    for _, record in ipairs(records(output)) do
        assert(type(record) == 'table', 'invalid Twig violation')
        local location = record.location
        assert(type(location) == 'table', 'missing Twig location')
        assert(type(location.path) == 'string' and location.path ~= '', 'invalid Twig path')
        assert(type(location.lines) == 'table', 'missing Twig line range')
        assert(type(record.description) == 'string' and record.description ~= '', 'missing message')
        assert(type(record.severity) == 'string' and severity[record.severity], 'invalid severity')
        assert(type(record.check_name) == 'string', 'invalid rule name')
        local path = location.path
        if path:sub(1, 1) ~= '/' then
            path = fs.joinpath(context.cwd, path)
        end
        path = uv.fs_realpath(path) or fs.normalize(path)
        if path == target then
            local line = line_number(location.lines.begin)
            diagnostics[#diagnostics + 1] = {
                bufnr = context.bufnr,
                lnum = line,
                col = 0,
                end_lnum = line,
                end_col = 0,
                message = record.description:sub(1, MESSAGE_BYTES_MAX),
                severity = severity[record.severity],
                source = 'twig-cs-fixer',
                code = record.check_name ~= '' and record.check_name or nil,
            }
        end
    end
    assert(api.nvim_buf_is_valid(context.bufnr), 'Twig buffer was removed')
    return diagnostics
end

---@type Linter
return {
    cmd = { './vendor/bin/twig-cs-fixer', 'twig-cs-fixer' },
    args = { 'lint', '--report=gitlab', '--no-cache', '--no-interaction', '--no-ansi', '--' },
    append_fname = true,
    automatic = true,
    stdin = false,
    stream = 'stdout',
    ignore_exitcode = false,
    exit_codes = { 0, 1 },
    root_markers = { '.twig-cs-fixer.php', 'composer.json', '.git' },
    parser = parse,
    parser_mode = 'context',
    timeout = 30000,
}