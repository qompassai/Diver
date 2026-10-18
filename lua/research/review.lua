-- /qompassai/Diver/lua/research/review.lua
-- Qompass AI Diver Journal Review Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---Score-cell hint per review field label, where the journal's form
---uses a scale; labels not listed get an empty score cell.
local FIELD_SCORES = {
    ['Conclusions supported'] = '/5',
    ['Novelty'] = '/5',
    ['Overall Manuscript Rating'] = '/100',
    ['Topic importance'] = '/5',
}

---Resolve a journal preset — a registry key ('jgme') or a display
---name ('Journal of Graduate Medical Education', as the picker
---passes) — to its journal profile; nil when nothing matches.
---@param preset string
---@return table|nil
local function resolve_profile(preset)
    local journal = require('research.journal')
    local profile = journal.get(preset)
    if profile then
        return profile
    end
    local wanted = preset:lower()
    for _, entry in ipairs(journal.list()) do
        if entry.name:lower() == wanted then
            return journal.get(entry.key)
        end
    end
    return nil
end

---The review rating fields for a profile: its own review.fields
---when recorded, else the generic profile's fields.
---@param profile? table
---@return string[]
local function review_fields_for(profile)
    if profile and profile.review and profile.review.fields then
        return profile.review.fields
    end
    local generic = require('research.journal').get('generic')
    if generic and generic.review and generic.review.fields then
        return generic.review.fields
    end
    return {}
end

---@class ReviewAnchor
---@field page integer
---@field lines string
---@field title? string

---@param number integer
---@param anchor ReviewAnchor
---@return string[]
function M.comment_block(number, anchor)
    local title = anchor.title and (' — ' .. anchor.title) or ''
    return {
        ('## Comment %d%s — manuscript p. %d | lines %s'):format(number, title, anchor.page, anchor.lines),
        '',
        '',
    }
end

---@param page integer
---@param lines string
---@param title? string
function M.insert_comment(page, lines, title)
    local bufnr = api.nvim_get_current_buf()
    local number = M.next_comment_number(bufnr)
    local row = api.nvim_win_get_cursor(0)[1]
    api.nvim_buf_set_lines(
        bufnr,
        row,
        row,
        false,
        M.comment_block(number, {
            page = page,
            lines = lines,
            title = title,
        })
    )
    api.nvim_win_set_cursor(0, { row + 2, 0 })
end

---@param path string
---@param preset_journal? string journal key or display name; skips the Journal prompt when given
function M.new(path, preset_journal)
    local given = preset_journal or fn.input('Journal: ')
    if given == '' then
        return
    end
    local profile = resolve_profile(given)
    local manuscript_number = fn.input('Manuscript number: ')
    local title = fn.input('Title: ')
    fn.mkdir(fs.dirname(path), 'p')
    fn.writefile(
        M.template({
            fields = review_fields_for(profile),
            journal = profile and profile.name or given,
            manuscript_number = manuscript_number,
            title = title,
        }),
        path
    )
    vim.cmd.edit(fn.fnameescape(path))
end

---@param bufnr? integer
---@return integer
function M.next_comment_number(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    local highest = 0
    for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        local digits = line:match('^##%s+Comment%s+(%d+)')
        -- %d+ guarantees an integral string; math.tointeger does not exist on
        -- LuaJIT, so the cast recovers the integer type the pattern guarantees.
        local number = digits and tonumber(digits) --[[@as integer?]]
        if number and number > highest then
            highest = number
        end
    end
    return highest + 1
end

---@param bufnr? integer
---@return table
function M.summary(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    local out = {
        comments = 0,
        minor_comments = 0,
        rating = nil,
        recommendation = nil,
        sources = 0,
    }
    local in_minor = false
    local in_sources = false
    for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        out.recommendation = out.recommendation or line:match('|%s*Reviewer Recommendation%s*|%s*%*%*([^*]+)%*%*%s*|')
        out.rating = out.rating or tonumber(line:match('|%s*Overall Manuscript Rating%s*|%s*%*%*(%d+)/100%*%*%s*|'))
        if line:match('^##%s+Comment%s+%d+') then
            out.comments = out.comments + 1
        end
        if line:match('^##%s+Minor Comments') then
            in_minor = true
            in_sources = false
        elseif line:match('^##%s+Key External Sources') then
            in_minor = false
            in_sources = true
        elseif line:match('^##%s+') then
            in_minor = false
            in_sources = false
        elseif in_minor and line:match('^%d+%.%s+') then
            out.minor_comments = out.minor_comments + 1
        elseif in_sources and line:match('^%-%s+') then
            out.sources = out.sources + 1
        end
    end
    return out
end

---@param metadata table { journal, manuscript_number, title, fields? }
---@return string[]
function M.template(metadata)
    local journal = metadata.journal or ''
    local number = metadata.manuscript_number or ''
    local title = metadata.title or ''
    local fields = metadata.fields or review_fields_for(nil)
    local lines = {
        '# Peer Review',
        '',
        '## ' .. journal,
        '',
        '### Manuscript Number: ' .. number,
        '',
        '### Title: *' .. title .. '*',
        '',
        '---',
        '',
        '## Review Scores',
        '',
        '| Category | Score |',
        '|---|---|',
    }
    for _, label in ipairs(fields) do
        lines[#lines + 1] = ('| %s | %s |'):format(label, FIELD_SCORES[label] or '')
    end
    vim.list_extend(lines, {
        '',
        '---',
        '',
        '## Confidential Comments to the Editor',
        '',
        '',
        '---',
        '',
        '## General Comments to Authors',
        '',
        '',
        '---',
        '',
        '## Major Comments',
        '',
        '',
        '---',
        '',
        '## Minor Comments',
        '',
        '',
        '---',
        '',
        '## Suggested Editorial Disposition',
        '',
        '',
        '---',
        '',
        '## Key External Sources Used in This Review',
        '',
    })
    return lines
end

function M.setup()
    api.nvim_create_user_command('ReviewComment', function(opts)
        local page, lines, title = opts.args:match('^(%d+)%s+(%S+)%s*(.*)$')
        if not page or not lines then
            vim.notify('Usage: ReviewComment {page} {lines} [title]', vim.log.levels.ERROR)
            return
        end
        -- math.tointeger does not exist on LuaJIT; tonumber plus the integrality
        -- check preserves its nil-on-non-integer contract.
        local raw_num = tonumber(page)
        local page_num = raw_num and raw_num % 1 == 0 and raw_num --[[@as integer?]]
            or nil
        if not page_num then
            vim.notify('Invalid page number.', vim.log.levels.ERROR)
            return
        end
        M.insert_comment(page_num, lines, title ~= '' and title or nil)
    end, {
        nargs = '+',
        desc = 'Insert numbered review comment anchored to manuscript page/lines',
    })

    api.nvim_create_user_command('ReviewNew', function(opts)
        local path = opts.args ~= '' and opts.args or 'review.md'
        M.new(fs.normalize(path))
    end, {
        nargs = '?',
        complete = 'file',
        desc = 'Create a structured journal peer review',
    })

    api.nvim_create_user_command('ReviewSummary', function()
        vim.notify(vim.inspect(M.summary()), vim.log.levels.INFO)
    end, { desc = 'Summarize current peer review' })
end

return M
