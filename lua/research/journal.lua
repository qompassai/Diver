-- /qompassai/Diver/lua/research/journal.lua
-- Qompass AI Diver Journal Profile Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- The journals Matt reviews for or submits to. Every entry carries a
-- `relationship`: 'reviewer' means he reviews there, 'author' means his
-- ORCID record shows a publication there. Portals are reviewer/author
-- login pages he supplied himself; nothing here automates a login.
local api = vim.api
local fn = vim.fn
local M = {}

M.profiles = {
    -- Reviewer venues (named by Matt).
    jgme = {
        name = 'Journal of Graduate Medical Education',
        relationship = 'reviewer',
        portal = 'https://www.editorialmanager.com/jgme/default.aspx',
        article_types = {
            'Original Research',
            'Perspectives',
            'Educational Innovation',
            'Brief Report',
            'Review',
            'Letter to the Editor',
        },
        review = {
            fields = {
                'Reviewer Recommendation',
                'Overall Manuscript Rating',
                'Topic importance',
                'Conclusions supported',
                'Novelty',
                'Additional statistical review',
            },
        },
    },
    jmir_formative = {
        name = 'JMIR Formative Research',
        relationship = 'reviewer',
        article_types = {},
    },
    jove = {
        name = 'Journal of Visualized Experiments',
        relationship = 'reviewer',
        article_types = {},
    },
    -- Author venues (publications on ORCID 0000-0002-0302-4812, verified
    -- 2026-09-28). Article types are left empty where not confirmed.
    corr = {
        name = 'Clinical Orthopaedics and Related Research',
        relationship = 'author',
        article_types = {},
    },
    orthopedics = {
        name = 'Orthopedics',
        relationship = 'author',
        article_types = {},
    },
    arthroplasty_today = {
        name = 'Arthroplasty Today',
        relationship = 'author',
        article_types = {},
    },
    jbjs_case_connector = {
        name = 'JBJS Case Connector',
        relationship = 'author',
        article_types = {},
    },
    cureus = {
        name = 'Cureus',
        relationship = 'author',
        article_types = {},
    },
    acta_orthopaedica = {
        name = 'Acta Orthopaedica',
        relationship = 'author',
        article_types = {},
    },
    jim = {
        name = 'Journal of Investigative Medicine',
        relationship = 'author',
        article_types = {},
    },
    ijscr = {
        name = 'International Journal of Surgery Case Reports',
        relationship = 'author',
        article_types = {},
    },
    generic = {
        name = 'Journal',
        article_types = {},
        review = {
            fields = {
                'Recommendation',
                'Overall rating',
                'Importance',
                'Validity',
                'Novelty',
            },
        },
    },
}

---@param name string
---@return table
function M.get(name)
    return M.profiles[name:lower()] or M.profiles.generic
end

---@param name string
---@param profile table
function M.register(name, profile)
    assert(type(name) == 'string' and name ~= '', 'journal profile name must be a string')
    assert(type(profile) == 'table', 'journal profile must be a table')
    M.profiles[name:lower()] = vim.deepcopy(profile)
end

---@return string[]
function M.names()
    local names = {}
    for name in pairs(M.profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

---@return table[] sorted { key, name, relationship, portal }
function M.list()
    local out = {}
    for key, profile in pairs(M.profiles) do
        if key ~= 'generic' then
            out[#out + 1] = {
                key = key,
                name = profile.name or key,
                relationship = profile.relationship or 'unknown',
                portal = profile.portal,
            }
        end
    end
    table.sort(out, function(a, b)
        return a.name < b.name
    end)
    return out
end

---@param url string
local function open(url)
    if fn.executable('xdg-open') == 1 then
        vim.system({ 'xdg-open', url }, { detach = true })
    else
        vim.notify(url, vim.log.levels.INFO)
    end
end

---Open a journal's portal in the browser. Opens the page only; it never
---fills in credentials or submits anything.
---@param key? string profile key (defaults to 'jgme')
function M.open_portal(key)
    key = (key and key ~= '' and key:lower()) or 'jgme'
    local profile = M.profiles[key]
    if not profile then
        vim.notify(('Unknown journal: %s'):format(key), vim.log.levels.ERROR)
        return
    end
    if not profile.portal then
        vim.notify(('No portal recorded for %s'):format(profile.name), vim.log.levels.WARN)
        return
    end
    open(profile.portal)
end

function M.setup()
    api.nvim_create_user_command('JournalList', function()
        local lines = { 'Journals', '' }
        for _, entry in ipairs(M.list()) do
            local line = ('- %s [%s]'):format(entry.name, entry.relationship)
            if entry.portal then
                line = line .. '  ' .. entry.portal
            end
            lines[#lines + 1] = line
        end
        local bufnr = api.nvim_create_buf(false, true)
        api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        api.nvim_buf_set_option(bufnr, 'modifiable', false)
        vim.cmd('botright split')
        api.nvim_win_set_buf(0, bufnr)
        api.nvim_buf_set_name(bufnr, 'Journals')
    end, { desc = 'List journals reviewed for or published in' })

    api.nvim_create_user_command('JournalPortal', function(opts)
        M.open_portal(opts.args ~= '' and opts.args or nil)
    end, {
        nargs = '?',
        complete = function()
            return M.names()
        end,
        desc = 'Open a journal portal in the browser (login is manual)',
    })
end

return M
