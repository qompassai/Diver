-- /qompassai/lua/linters/psscryptanalyzer.lua
-- Qompass AI Psscryptanalyzer
---@module 'linters.psscryptanalyzer'
local diagnostic = vim.diagnostic
local fn = vim.fn
---@class PSScriptAnalyzerRecord
---@field EndColumn? integer
---@field EndLine? integer
---@field Message? string
---@field RuleName? string
---@field Severity? string
---@field StartColumn? integer
---@field StartLine? integer

local analyzer_command = [=[
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Import-Module PSScriptAnalyzer -MinimumVersion 1.18.0 -ErrorAction Stop -WarningAction SilentlyContinue

$source = [Console]::In.ReadToEnd()
$records = @(
    Invoke-ScriptAnalyzer -ScriptDefinition $source -ErrorAction Stop |
        ForEach-Object {
            [pscustomobject]@{
                RuleName   = [string]$_.RuleName
                Severity   = [string]$_.Severity
                Message    = [string]$_.Message
                StartLine  = [int]$_.Extent.StartLineNumber
                StartColumn = [int]$_.Extent.StartColumnNumber
                EndLine    = [int]$_.Extent.EndLineNumber
                EndColumn  = [int]$_.Extent.EndColumnNumber
            }
        }
)

[Console]::Out.Write((ConvertTo-Json -InputObject $records -Depth 4 -Compress))
]=]

---@param value unknown
---@param fallback integer
---@return integer
local function integer(value, fallback)
    if value == nil then
        return fallback
    end
    local parsed = fn.str2nr(tostring(value), 10)
    return parsed > 0 and parsed or fallback
end

---@param value unknown
---@return integer
local function severity(value)
    local name = tostring(value or ''):lower()
    if name == 'error' or name == 'parseerror' then
        return diagnostic.severity.ERROR
    end
    if name == 'information' or name == 'info' then
        return diagnostic.severity.INFO
    end
    return diagnostic.severity.WARN
end

---@param output string
---@param _context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
    if vim.trim(output) == '' then
        return {}
    end
    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or type(decoded) ~= 'table' then
        error(('invalid PSScriptAnalyzer JSON: %s'):format(vim.trim(output)), 0)
    end

    ---@cast decoded PSScriptAnalyzerRecord[]
    local diagnostics = {}
    for _, record in ipairs(decoded) do
        if type(record) == 'table' then
            local start_line = math.max(integer(record.StartLine, 1) - 1, 0)
            local start_column = math.max(integer(record.StartColumn, 1) - 1, 0)
            local end_line = math.max(integer(record.EndLine, start_line + 1) - 1, start_line)
            local minimum_end_column = end_line == start_line and start_column + 1 or 0
            local end_column = math.max(integer(record.EndColumn, minimum_end_column + 1) - 1, minimum_end_column)
            local rule = tostring(record.RuleName or 'PSScriptAnalyzer')
            local message = tostring(record.Message or 'Unknown PSScriptAnalyzer diagnostic')

            diagnostics[#diagnostics + 1] = {
                lnum = start_line,
                end_lnum = end_line,
                col = start_column,
                end_col = end_column,
                message = ('[%s] %s'):format(rule, message),
                severity = severity(record.Severity),
                source = 'PSScriptAnalyzer',
                code = rule,
            }
        end
    end

    return diagnostics
end

return ---@type Linter
{
    append_fname = false,
    args = {
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        analyzer_command,
    },
    cmd = 'pwsh',
    cwd = function(context)
        return vim.fs.dirname(context.filename) or context.cwd
    end,
    exit_codes = {
        [0] = true,
    },
    parser = parse,
    stdin = true,
    stream = 'stdout',
    timeout = 30000,
}
