-- /qompassai/Diver/lua/research/picker.lua
-- Qompass AI Diver Journal Picker Utils
---@module 'research.picker'
--
-- Picker front-end for the journal workflow: choose a journal (then an
-- article type, then a format) through the native FZF picker
-- (config.nav.fzf's fzf_pick) instead of typing :ManuscriptNew /
-- :SubmissionCheck arguments from memory. When the FZF module is not
-- available, the same flows fall back to vim.ui.select. The picker owns
-- no journal logic of its own: manuscripts come from
-- research.manuscript, preflight reports from research.submission,
-- reviews from research.review, and every fact from the
-- research.journal profiles.
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---Article type labels recorded for a profile: the requirements table's
---labels first, then the profile's plain article_types list.
---@param profile table journal profile (from research.journal)
---@return string[] labels sorted
local function article_type_labels(profile)
    local labels = {}
    local requirements = profile.requirements
    if requirements and requirements.article_types then
        for _, entry in pairs(requirements.article_types) do
            if type(entry) == 'table' and type(entry.label) == 'string' then
                labels[#labels + 1] = entry.label
            end
        end
    end
    if #labels == 0 and profile.article_types then
        for _, label in ipairs(profile.article_types) do
            labels[#labels + 1] = label
        end
    end
    table.sort(labels)
    return labels
end

---Pick one item. Items are { label, value } pairs; the sink receives
---the chosen value, or nil when the user cancels. Uses the native FZF
---picker when available, vim.ui.select otherwise.
---@param items table[] { label = string, value = any }
---@param prompt string
---@param sink fun(value: any)
local function pick(items, prompt, sink)
    local ok, fzf = pcall(require, 'config.nav.fzf')
    if ok and type(fzf) == 'table' and type(fzf.fzf_pick) == 'function' then
        fzf.fzf_pick(items, sink, { prompt = prompt })
        return
    end
    local labels = {}
    local by_label = {}
    for _, item in ipairs(items) do
        labels[#labels + 1] = item.label
        by_label[item.label] = item.value
    end
    vim.ui.select(labels, { prompt = prompt }, function(choice)
        if choice == nil then
            sink(nil)
            return
        end
        sink(by_label[choice])
    end)
end

---Pick an article type for a profile. A profile with no recorded types
---falls back to a free-text prompt; an empty answer cancels. With
---allow_none, a leading '(no article type)' entry yields false.
---@param profile table journal profile
---@param allow_none boolean
---@param sink fun(label: string|false|nil)
local function pick_article_type(profile, allow_none, sink)
    local labels = article_type_labels(profile)
    if #labels == 0 then
        local typed = fn.input('Article type: ')
        if typed == '' then
            sink(nil)
            return
        end
        sink(typed)
        return
    end
    local items = {}
    if allow_none then
        items[#items + 1] = { label = '(no article type)', value = false }
    end
    for _, label in ipairs(labels) do
        items[#items + 1] = { label = label, value = label }
    end
    pick(items, 'Article type', sink)
end

---Pick a journal profile (the generic profile is offered last).
---@param sink fun(key: string|nil, profile: table|nil)
local function pick_journal(sink)
    local journal = require('research.journal')
    local items = {}
    for _, entry in ipairs(journal.list()) do
        items[#items + 1] = {
            label = ('%s (%s)'):format(entry.name, entry.relationship),
            value = entry.key,
        }
    end
    local generic = journal.get('generic')
    items[#items + 1] = {
        label = ('%s (generic)'):format((generic and generic.name) or 'Generic'),
        value = 'generic',
    }
    pick(items, 'Journal', function(key)
        if key == nil then
            sink(nil, nil)
            return
        end
        sink(key, journal.get(key))
    end)
end

---Show lines in a scratch Markdown buffer (the research.submission
---report pattern).
---@param lines string[]
local function show_lines(lines)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = 'markdown'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.cmd.vnew()
    api.nvim_win_set_buf(0, buf)
end

---@param label string
---@return string slug lower-case, non-word runs collapsed to '-'
local function slug(label)
    return (label:lower():gsub('[^%w]+', '-'):gsub('^-+', ''):gsub('-+$', ''))
end

---JournalCheck flow: journal -> article type (or none) -> the
---requirements preflight for the current directory.
local function flow_check()
    pick_journal(function(key, profile)
        if key == nil or profile == nil then
            return
        end
        pick_article_type(profile, true, function(article_type)
            if article_type == nil then
                return
            end
            local root = vim.uv.cwd() or fn.getcwd()
            local lines, err = require('research.submission').requirements_report(root, key, article_type or nil)
            if not lines then
                vim.notify(err or 'requirements report failed', vim.log.levels.ERROR)
                return
            end
            show_lines(lines)
        end)
    end)
end

---JournalNew flow: journal -> article type -> format -> path ->
---research.manuscript.new_from_template.
local function flow_new()
    pick_journal(function(key, profile)
        if key == nil or profile == nil then
            return
        end
        pick_article_type(profile, false, function(article_type)
            if not article_type then
                return
            end
            local items = {}
            for _, format in ipairs(require('research.templates').formats()) do
                items[#items + 1] = { label = format, value = format }
            end
            pick(items, 'Format', function(format)
                if format == nil then
                    return
                end
                local ext = format == 'latex' and 'tex' or 'md'
                local default = ('%s-%s.%s'):format(key, slug(article_type), ext)
                local path = fn.input('Path: ', default, 'file')
                if path == '' then
                    return
                end
                require('research.manuscript').new_from_template(fs.normalize(path), key, article_type, format)
            end)
        end)
    end)
end

---JournalReview flow: journal -> research.review.new with the
---journal pre-selected (manuscript number and title are still
---prompted there, exactly as :ReviewNew does).
---@param path string destination file
local function flow_review(path)
    pick_journal(function(_, profile)
        if profile == nil then
            return
        end
        require('research.review').new(path, profile.name)
    end)
end

function M.setup()
    api.nvim_create_user_command('JournalCheck', function()
        flow_check()
    end, { desc = 'Pick a journal and run its submission preflight for the cwd' })

    api.nvim_create_user_command('JournalNew', function()
        flow_new()
    end, { desc = 'Pick a journal, article type, and format; scaffold a manuscript' })

    api.nvim_create_user_command('JournalReview', function(opts)
        local path = opts.args ~= '' and opts.args or 'review.md'
        flow_review(fs.normalize(path))
    end, {
        nargs = '?',
        complete = 'file',
        desc = 'Pick a journal and start a structured peer review',
    })
end

return M
