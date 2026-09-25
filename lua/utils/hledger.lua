-- qompassai/lua/utils/hledger.lua
-- Qompass AI Diver hledger journal policy
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- ELI5: `hledger check` is a spell-checker for your money journal. It reads
-- the journal and reports the first problem it finds: a line it cannot
-- parse, a transaction whose postings do not add up, or a balance assertion
-- that fails. This module holds the explicit policy the native linter
-- adapter (`lua/linters/hledger.lua`) needs: which binary to run, which
-- arguments to pass it, and how to turn hledger's error report into editor
-- diagnostics. hledger reports only one error at a time, so the parser is
-- written for that shape: `hledger: Error: FILE:LINE[-ENDLINE][:COL]:`
-- followed by a short excerpt and an explanation.
--
---@source https://hledger.org/hledger.html#check
---@source https://github.com/hledgerorg/hledger/blob/HEAD/hledger/test/errors/README.md

local diagnostic = vim.diagnostic

local SOURCE = 'hledger'
local MAX_DIAGNOSTICS = 8
local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 1 * 1024 * 1024

---@class HledgerJournalConfig
---@field env_executable string Binary name, resolved through PATH by the linter runner.
---@field automatic_lint boolean Whether the linter may run on buffer events.
---@field timeout_ms integer Subprocess timeout in milliseconds.

---@class HledgerJournal
---@field config HledgerJournalConfig Explicit policy consumed by the linter adapter.
---@field arguments string[] argv appended after the executable.
---@field cwd LintCwd Working directory resolver for the linter process.
---@field parse LintContextParser hledger error output parser.

---@param value any
---@param fallback integer
---@return integer
local function integer(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then
        return fallback
    end
    return math.floor(parsed)
end

---@param value any
---@return integer
local function zero_based(value)
    return math.max(integer(value, 1) - 1, 0)
end

---@param value string
---@return string
local function compact(value)
    return vim.trim(value:gsub('%s+', ' '))
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
    assert(type(limit) == 'number', 'truncate requires a numeric limit')
    assert(limit > 0, 'truncate requires a positive limit')

    if #value <= limit then
        return value
    end

    if limit <= 3 then
        return value:sub(1, limit)
    end

    return value:sub(1, limit - 3) .. '...'
end

---@param value string
---@return string
local function strip_ansi(value)
    return value:gsub('\27%[[%d;?]*[ -/]*[@-~]', '')
end

---@class HledgerErrorLocation
---@field file string
---@field start_line integer 1-based start line.
---@field end_line integer? 1-based end line; defaults to start_line.
---@field start_column integer? 1-based start column; defaults to 1.
---@field end_column integer? 1-based end column.

---@param line string
---@return HledgerErrorLocation?
local function parse_header(line)
    if #line > MAX_LINE_BYTES then
        return nil
    end

    local file, start_line, end_line, start_column, end_column =
        line:match('^hledger:%s*Error:%s*(.-):(%d+)%-?(%d*):?(%d*)%-?(%d*):?%s*$')

    if file == nil or start_line == nil then
        return nil
    end

    ---@type HledgerErrorLocation
    local location = {
        file = file,
        start_line = integer(start_line, 1),
        end_line = end_line ~= '' and integer(end_line, 0) or nil,
        start_column = start_column ~= '' and integer(start_column, 0) or nil,
        end_column = end_column ~= '' and integer(end_column, 0) or nil,
    }

    return location
end

---@class HledgerErrorBlock
---@field location HledgerErrorLocation
---@field lines string[] Excerpt and explanation lines following the header.

---@param text string
---@return HledgerErrorBlock[]
local function split_blocks(text)
    ---@type HledgerErrorBlock[]
    local blocks = {}
    ---@type HledgerErrorBlock?
    local current = nil

    for raw_line in text:gmatch('[^\r\n]+') do
        if #blocks >= MAX_DIAGNOSTICS then
            break
        end

        local location = parse_header(raw_line)
        if location ~= nil then
            current = { location = location, lines = { raw_line } }
            blocks[#blocks + 1] = current
        elseif current ~= nil and #raw_line <= MAX_LINE_BYTES then
            current.lines[#current.lines + 1] = raw_line
        end
    end

    return blocks
end

---@param file string
---@param context LintContext
---@return boolean
local function is_buffer_file(file, context)
    -- With `-f -` hledger names the input `-`; accept stdin placeholders.
    if file == '' or file == '-' or file == 'stdin' or file == '<stdin>' then
        return true
    end

    local buffer_name = context.filename
    if type(buffer_name) ~= 'string' or buffer_name == '' then
        return false
    end

    local candidate = vim.fs.normalize(file) or file
    local expected = vim.fs.normalize(buffer_name) or buffer_name
    return candidate == expected
end

---@param block HledgerErrorBlock
---@param context LintContext
---@return vim.Diagnostic?
local function block_diagnostic(block, context)
    if not is_buffer_file(block.location.file, context) then
        return nil
    end

    local location = block.location
    local lnum = zero_based(location.start_line)
    local end_lnum = location.end_line ~= nil and zero_based(location.end_line) or lnum
    if end_lnum < lnum then
        end_lnum = lnum
    end

    local col = zero_based(location.start_column)
    local end_col = col
    if location.end_column ~= nil and (location.end_line == nil or location.end_line == location.start_line) then
        end_col = math.max(zero_based(location.end_column), col)
    end

    local message = compact(table.concat(block.lines, '\n'))
    if message == '' then
        message = 'hledger reported an error'
    end

    return {
        bufnr = context.bufnr,
        code = 'check',
        col = col,
        end_col = end_col,
        end_lnum = end_lnum,
        lnum = lnum,
        message = truncate(message, MAX_MESSAGE_BYTES),
        severity = diagnostic.severity.ERROR,
        source = SOURCE,
    }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(context)
    return {
        {
            bufnr = context.bufnr,
            code = 'output-limit',
            col = 0,
            end_col = 0,
            end_lnum = 0,
            lnum = 0,
            message = ('hledger output exceeded the %d-byte parser limit'):format(MAX_OUTPUT_BYTES),
            severity = diagnostic.severity.WARN,
            source = SOURCE,
        },
    }
end

---@param text string
---@param context LintContext
---@return vim.Diagnostic[]
local function unrecognized_output(text, context)
    -- `hledger check` is silent when the journal is valid, so any output we
    -- cannot parse is still worth surfacing instead of dropping.
    return {
        {
            bufnr = context.bufnr,
            code = 'unrecognized-output',
            col = 0,
            end_col = 0,
            end_lnum = 0,
            lnum = 0,
            message = truncate(compact(text), MAX_MESSAGE_BYTES),
            severity = diagnostic.severity.ERROR,
            source = SOURCE,
        },
    }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
    assert(type(output) == 'string', 'hledger parser requires output string')
    assert(type(context) == 'table', 'hledger parser requires LintContext')
    assert(type(context.bufnr) == 'number', 'hledger parser requires context.bufnr')

    if vim.trim(output) == '' then
        return {}
    end

    if #output > MAX_OUTPUT_BYTES then
        return oversized_output(context)
    end

    local text = strip_ansi(output)
    local blocks = split_blocks(text)

    ---@type vim.Diagnostic[]
    local diagnostics = {}
    for _, block in ipairs(blocks) do
        local item = block_diagnostic(block, context)
        if item ~= nil then
            diagnostics[#diagnostics + 1] = item
        end
    end

    if #blocks == 0 then
        return unrecognized_output(text, context)
    end

    return diagnostics
end

---@param context LintContext
---@return string
local function cwd_for(context)
    assert(type(context) == 'table', 'hledger cwd requires LintContext')
    assert(type(context.root) == 'string', 'hledger cwd requires context.root')
    assert(context.root ~= '', 'hledger cwd requires a non-empty context.root')

    return context.root
end

-- `-f -` reads the journal from standard input (the adapter sets stdin);
-- the general option precedes the command, matching the documented form.
---@type HledgerJournal
local journal = {
    config = {
        -- Binary name resolved through PATH; the runner reports a clean
        -- "Linter executable not found" when hledger is not installed.
        env_executable = 'hledger',
        -- `check` is fast and pure, so buffer-event runs give instant
        -- feedback while editing, like flycheck-hledger.
        automatic_lint = true,
        timeout_ms = 30000,
    },
    arguments = { '-f', '-', 'check' },
    cwd = cwd_for,
    parse = parse,
}

return journal
