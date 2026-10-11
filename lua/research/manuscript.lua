-- /qompassai/Diver/lua/research/manuscript.lua
-- Qompass AI Diver Manuscript Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@param metadata? table
---@return string[]
function M.author_template(metadata)
    metadata = metadata or {}
    return {
        '---',
        'title: "' .. (metadata.title or '') .. '"',
        'short-title: "' .. (metadata.short_title or '') .. '"',
        'author:',
        '  - name: ""',
        'bibliography: references.bib',
        'csl: ""',
        '---',
        '',
        '# Abstract',
        '',
        '# Introduction',
        '',
        '# Methods',
        '',
        '# Results',
        '',
        '# Discussion',
        '',
        '# Conclusions',
        '',
        '# References',
        '',
    }
end

---@param bufnr? integer
---@return string[]
function M.headings(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype
    local out = {}
    for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        local heading
        if ft == 'markdown' then
            heading = line:match('^%s*#+%s+(.+)$')
        elseif ft == 'tex' or ft == 'plaintex' or ft == 'latex' then
            heading = line:match('\\section%*?{(.-)}')
                or line:match('\\subsection%*?{(.-)}')
                or line:match('\\subsubsection%*?{(.-)}')
        end
        if heading then
            out[#out + 1] = vim.trim(heading)
        end
    end
    return out
end

---@param text string
---@return table
function M.metadata(text)
    local fields = {
        article_type = 'Article Type:%s*([^\r\n]+)',
        full_title = 'Full Title:%s*([^\r\n]+)',
        keywords = 'Keywords:%s*([^\r\n]+)',
        manuscript_number = 'Manuscript Number:%s*([^\r\n]+)',
        short_title = 'Short Title:%s*([^\r\n]+)',
        word_count = 'Word Count:%s*(%d+)',
    }
    local out = {}
    for key, pattern in pairs(fields) do
        local value = text:match(pattern)
        if value then
            out[key] = vim.trim(value)
        end
    end
    return out
end

---@param path string
function M.new(path)
    if fn.filereadable(path) == 1 then
        vim.cmd.edit(fn.fnameescape(path))
        return
    end
    fn.mkdir(fs.dirname(path), 'p')
    fn.writefile(M.author_template(), path)
    vim.cmd.edit(fn.fnameescape(path))
end

---Report an error without throwing. An ERROR-level notification
---emitted during command execution makes nvim_exec2 fail the command
---for API/RPC callers (stock vim.notify echoes with err=true), so the
---notification is scheduled: the command returns cleanly and the
---message still displays.
---@param message string
local function notify_error(message)
    vim.schedule(function()
        vim.notify(message, vim.log.levels.ERROR)
    end)
end

---Read a secret from pass(1), degrading to nil when pass cannot
---decrypt (locked GPG agent) or the entry is absent. Never raises.
---@param pass_path string
---@return string|nil
local function get_pass_secret(pass_path)
    if fn.executable('pass') ~= 1 then
        return nil
    end
    local ok, result = pcall(vim.system, { 'pass', 'show', pass_path }, { text = true })
    if not ok then
        return nil
    end
    ---@cast result vim.SystemObj
    local finished = result:wait(5000)
    if finished.code ~= 0 then
        return nil
    end
    local secret = vim.trim(finished.stdout or '')
    if secret == '' then
        return nil
    end
    return secret
end

---Fill author identity fields from pass ('auth/fullname', 'orcid/id')
---when the caller did not supply them, so templates agree with qsync
---and Zenodo metadata. Unavailable pieces stay blank.
---@param metadata? table
---@return table
local function with_identity(metadata)
    local merged = {}
    for key, value in pairs(metadata or {}) do
        merged[key] = value
    end
    if merged.author_name == nil then
        merged.author_name = get_pass_secret('auth/fullname')
    end
    if merged.orcid == nil then
        merged.orcid = get_pass_secret('orcid/id')
    end
    return merged
end

---Create a manuscript from a per-journal template (research.templates).
---@param path string destination file
---@param journal_key string journal profile key
---@param article_type string article type label or key
---@param format string 'markdown' or 'latex'
---@param metadata? table optional template metadata
---@return boolean ok
function M.new_from_template(path, journal_key, article_type, format, metadata)
    if fn.filereadable(path) == 1 then
        vim.cmd.edit(fn.fnameescape(path))
        return true
    end
    local templates = require('research.templates')
    local lines, err = templates.render(journal_key, article_type, format, with_identity(metadata))
    if not lines then
        notify_error(('ManuscriptNew: %s'):format(err))
        return false
    end
    fn.mkdir(fs.dirname(path), 'p')
    fn.writefile(lines, path)
    vim.cmd.edit(fn.fnameescape(path))
    return true
end

---Parse :ManuscriptNew arguments. Legacy form is a single optional path;
---template form is <journal> <article type...> <format> [path].
---@param args string[]
---@return table|nil parsed { mode = 'path'|'template', ... }
local function parse_new_args(args)
    if #args == 0 then
        return { mode = 'path', path = 'manuscript.md' }
    end
    local journal = require('research.journal')
    local known = {}
    for _, name in ipairs(journal.names()) do
        known[name] = true
    end
    if not known[args[1]:lower()] then
        return { mode = 'path', path = args[1] }
    end
    local format_index = nil
    local format = nil
    for index = 2, #args do
        local token = args[index]:lower()
        if token == 'markdown' or token == 'md' or token == 'latex' or token == 'tex' then
            format_index = index
            format = token
            break
        end
    end
    if not format_index or format_index == 2 then
        return nil
    end
    local type_parts = {}
    for index = 2, format_index - 1 do
        type_parts[#type_parts + 1] = args[index]
    end
    local extension = (format == 'latex' or format == 'tex') and 'tex' or 'md'
    local path = args[format_index + 1] or ('manuscript.' .. extension)
    return {
        article_type = table.concat(type_parts, ' '),
        format = format,
        journal = args[1]:lower(),
        mode = 'template',
        path = path,
    }
end

---@param path string
---@return string
function M.review_name(path)
    local stem = fs.basename(path):gsub('%.%w+$', '')
    return fs.joinpath(fs.dirname(path), stem .. '.review.md')
end

function M.setup()
    api.nvim_create_user_command('ManuscriptNew', function(opts)
        local parsed = parse_new_args(opts.fargs)
        if not parsed then
            vim.notify(
                'ManuscriptNew: usage :ManuscriptNew [path] or '
                    .. ':ManuscriptNew <journal> <article type> <markdown|latex> [path]',
                vim.log.levels.WARN
            )
            return
        end
        if parsed.mode == 'template' then
            M.new_from_template(fs.normalize(parsed.path), parsed.journal, parsed.article_type, parsed.format)
        else
            M.new(fs.normalize(parsed.path))
        end
    end, {
        nargs = '*',
        complete = function(arglead, cmdline)
            local parts = vim.split(vim.trim(cmdline), '%s+')
            if #parts <= 2 and not cmdline:match('%s$') or #parts <= 1 then
                return require('research.journal').names()
            end
            if arglead:match('^m') or arglead:match('^l') or arglead:match('^t') then
                return { 'latex', 'markdown' }
            end
            return {}
        end,
        desc = 'Create a manuscript: [path], or <journal> <type> <format> [path] from a template',
    })

    api.nvim_create_user_command('ManuscriptOutline', function()
        vim.notify(vim.inspect(M.headings()), vim.log.levels.INFO)
    end, { desc = 'Show manuscript section outline' })
end

return M
