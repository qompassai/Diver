--- Journal submission helpers — checklists for submitting papers.
---
--- Plain-language version: submitting an academic paper means satisfying a long checklist (formatting, files,
--- metadata). This module holds helpers for that workflow. It runs when you invoke its commands.
---@module 'research.submission'
-- /qompassai/Diver/lua/research/submission.lua
-- Qompass AI Diver Journal Submission Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@param root string
---@return string[]
function M.checklist(root)
    local scan = M.scan(root)
    local lines = {
        '# Submission Checklist',
        '',
        '- [ ] Manuscript title and short title verified',
        '- [ ] Author names, degrees, affiliations, and corresponding author verified',
        '- [ ] Abstract/keywords comply with journal article type',
        '- [ ] Word count verified',
        '- [ ] Tables cited in order and supplied in required format',
        '- [ ] Figures cited in order and supplied at required resolution',
        '- [ ] Figure legends present',
        '- [ ] References checked against DOI/PubMed/Crossref records',
        '- [ ] Duplicate references removed',
        '- [ ] Ethics/IRB statement included when applicable',
        '- [ ] Funding statement included',
        '- [ ] Conflict-of-interest statement included',
        '- [ ] Data/code availability statement included when applicable',
        '- [ ] Reporting guideline checklist included when applicable',
        '- [ ] Author contribution statement included when required',
        '- [ ] Cover letter prepared',
        '- [ ] Supplemental files named consistently',
        '- [ ] Final PDF inspected visually',
        '',
        '## Detected Files',
        '',
        ('- Manuscript candidates: %d'):format(#scan.manuscript),
        ('- Bibliography files: %d'):format(#scan.bibliography),
        ('- Figures: %d'):format(#scan.figures),
        ('- Tables: %d'):format(#scan.tables),
        ('- Supplements: %d'):format(#scan.supplements),
        ('- Cover letters: %d'):format(#scan.cover_letters),
    }
    return lines
end

---@param root string
---@return table
function M.scan(root)
    local result = {
        bibliography = {},
        cover_letters = {},
        figures = {},
        manuscript = {},
        supplements = {},
        tables = {},
    }
    local files = vim.fs.find(function(name)
        return not name:match('^%.')
    end, {
        path = root,
        type = 'file',
        limit = math.huge,
    })
    for _, path in ipairs(files) do
        local name = fs.basename(path):lower()
        local ext = name:match('%.([^.]+)$') or ''
        if ext == 'bib' then
            result.bibliography[#result.bibliography + 1] = path
        elseif name:match('cover') and (ext == 'md' or ext == 'tex' or ext == 'docx') then
            result.cover_letters[#result.cover_letters + 1] = path
        elseif name:match('supp') then
            result.supplements[#result.supplements + 1] = path
        elseif name:match('table') then
            result.tables[#result.tables + 1] = path
        elseif
            ext == 'png'
            or ext == 'jpg'
            or ext == 'jpeg'
            or ext == 'tif'
            or ext == 'tiff'
            or ext == 'svg'
            or ext == 'pdf'
        then
            if name:match('fig') then
                result.figures[#result.figures + 1] = path
            end
        elseif ext == 'md' or ext == 'tex' or ext == 'docx' then
            result.manuscript[#result.manuscript + 1] = path
        end
    end
    return result
end

local READ_BYTES_MAX = 1000000
local READ_FILES_MAX = 20

local STATEMENT_MARKERS = {
    ai_disclosure = {
        'artificial intelligence',
        'ai use disclosure',
        'generative ai',
        'large language model',
    },
    contributions = { 'author contributions', 'contributions' },
    data_availability = { 'data availability', 'code availability' },
    disclosures_coi = {
        'conflict of interest',
        'conflicts of interest',
        'competing interests',
        'disclosures',
    },
    funding = { 'funding', 'financial support', 'grant support' },
    irb_ethics = {
        'institutional review board',
        'irb',
        'ethics committee',
        'ethical approval',
        'exempt determination',
    },
}

---@param paths string[]
---@return string concatenated text of readable .md/.tex files (bounded)
local function read_manuscript_text(paths)
    local chunks = {}
    local read_count = 0
    for _, path in ipairs(paths) do
        if read_count >= READ_FILES_MAX then
            break
        end
        if path:match('%.md$') or path:match('%.tex$') then
            local ok, lines = pcall(fn.readfile, path)
            if ok then
                local text = table.concat(lines, '\n')
                if #text > READ_BYTES_MAX then
                    text = text:sub(1, READ_BYTES_MAX)
                end
                chunks[#chunks + 1] = text
                read_count = read_count + 1
            end
        end
    end
    return table.concat(chunks, '\n')
end

---@param text string
---@return integer
local function count_words(text)
    local body = text
    if body:sub(1, 3) == '---' then
        local closing = body:find('\n%-%-%-', 4)
        if closing then
            body = body:sub(closing + 4)
        end
    end
    body = body:gsub('<!%-%-.-%-%->', ' ')
    body = body:gsub('\\[a-zA-Z]+%*?', ' ')
    local count = 0
    for _ in body:gmatch('%S+') do
        count = count + 1
    end
    return count
end

---@param text string
---@return string|nil abstract section text when present
local function extract_abstract(text)
    local abstract = text:match('# Abstract%s*\n(.-)\n# ')
        or text:match('# Abstract%s*\n(.*)$')
        or text:match('\\begin{abstract}(.-)\\end{abstract}')
    return abstract
end

---@param text string lowercase manuscript text
---@param markers string[]
---@return boolean
local function has_marker(text, markers)
    for _, marker in ipairs(markers) do
        if text:find(marker, 1, true) then
            return true
        end
    end
    return false
end

---@param text string
---@return table<string, boolean> unique figure numbers referenced
local function figure_references(text)
    local refs = {}
    for number in text:gmatch('[Ff]igure%s+(%d+)') do
        refs[number] = true
    end
    for number in text:gmatch('[Ff]ig%.?%s*(%d+)') do
        refs[number] = true
    end
    return refs
end

---@param results table[]
---@param status string 'pass'|'warn'|'missing'|'fail'|'not_recorded'|'not_required'
---@param label string
---@param detail string
local function add_result(results, status, label, detail)
    results[#results + 1] = { detail = detail, label = label, status = status }
end

---Check a manuscript directory against a journal profile's recorded
---requirements. Every check that depends on a requirement the profile
---does not record reports 'not_recorded' rather than passing silently;
---requirements a journal explicitly does not state (JGME's
---'not_stated_by_journal' entries) report 'not_required'. Word counts
---are approximate full-text counts: journal word limits exclude front
---matter, headings, abstract, references, and display items, so an
---over-limit screening count is a warning, not a verdict.
---@param root string manuscript directory
---@param journal_key string journal profile key
---@param article_type? string override (else read from the manuscript)
---@return table[] results
---@return table profile
function M.check_requirements(root, journal_key, article_type)
    local journal = require('research.journal')
    local profile = journal.get(journal_key)
    local requirements = profile.requirements
    local results = {}
    local scan = M.scan(root)
    local text = read_manuscript_text(scan.manuscript)
    local lower = text:lower()

    if #scan.manuscript > 0 then
        add_result(results, 'pass', 'Manuscript file', ('%d candidate(s) found'):format(#scan.manuscript))
    else
        add_result(results, 'missing', 'Manuscript file', 'no manuscript file in directory')
    end

    local cover_required = requirements and requirements.cover_letter and requirements.cover_letter.required
    if #scan.cover_letters > 0 then
        add_result(results, 'pass', 'Cover letter', 'cover letter file found')
    elseif cover_required then
        add_result(results, 'missing', 'Cover letter', 'required by the journal profile')
    elseif requirements then
        add_result(results, 'warn', 'Cover letter', 'not recorded as required for this journal')
    else
        add_result(results, 'not_recorded', 'Cover letter', 'not recorded for this journal')
    end

    local metadata = require('research.manuscript').metadata(text)
    local type_label = article_type or metadata.article_type
    local type_req = nil
    if requirements and type_label then
        type_req = journal.article_requirement(profile, type_label)
    end

    local word_count = count_words(text)
    if not requirements then
        add_result(results, 'not_recorded', 'Word count', 'no requirements recorded for this journal')
    elseif not type_label then
        add_result(
            results,
            'warn',
            'Word count',
            (
                'approximately %d words (screening count); article type not '
                .. 'recorded in the manuscript, and limits are per article '
                .. 'type'
            ):format(word_count)
        )
    elseif requirements and not type_req then
        add_result(
            results,
            'not_recorded',
            'Word count',
            ('no recorded limits for article type "%s" at this journal'):format(type_label)
        )
    elseif type_req then
        local limit = type_req.manuscript_word_limit
        if limit then
            local basis = 'quantitative'
            local value = limit.value
            local comparator = limit.comparator
            if limit.qualitative_value and lower:find('qualitative', 1, true) then
                basis = 'qualitative'
                value = limit.qualitative_value
                comparator = limit.qualitative_comparator or comparator
            end
            local over = (comparator == '<' and word_count >= value) or (comparator == '<=' and word_count > value)
            if over then
                add_result(
                    results,
                    'warn',
                    'Word count',
                    (
                        'screening count approximately %d words vs %s %d '
                        .. '(%s limit; journal exclusions may reduce the '
                        .. 'official count)'
                    ):format(word_count, comparator, value, basis)
                )
            else
                add_result(
                    results,
                    'pass',
                    'Word count',
                    ('screening count approximately %d words, within %s %d ' .. '(%s limit)'):format(
                        word_count,
                        comparator,
                        value,
                        basis
                    )
                )
            end
        end
        if type_req.abstract_required == false then
            add_result(results, 'pass', 'Abstract', 'no abstract for this article type at this journal')
        elseif type_req.abstract_max_words then
            local abstract = extract_abstract(text)
            if not abstract then
                add_result(results, 'missing', 'Abstract', 'no abstract section found')
            else
                local abstract_words = count_words(abstract)
                if abstract_words > type_req.abstract_max_words then
                    add_result(
                        results,
                        'fail',
                        'Abstract',
                        ('%d words exceeds the %d-word limit'):format(abstract_words, type_req.abstract_max_words)
                    )
                else
                    add_result(
                        results,
                        'pass',
                        'Abstract',
                        ('%d of %d words'):format(abstract_words, type_req.abstract_max_words)
                    )
                end
            end
        end
        if type_req.max_references then
            local references_section = text:match('# References%s*\n(.*)$')
                or text:match('\\section%*?{References}(.*)$')
                or ''
            local reference_count = 0
            for line in references_section:gmatch('[^\n]+') do
                if line:match('^%s*%d+[%.%)]') or line:match('^%s*%-') then
                    reference_count = reference_count + 1
                end
            end
            if reference_count > type_req.max_references then
                add_result(
                    results,
                    'fail',
                    'References',
                    ('%d references exceeds the maximum of %d'):format(reference_count, type_req.max_references)
                )
            else
                add_result(
                    results,
                    'pass',
                    'References',
                    ('%d of at most %d references'):format(reference_count, type_req.max_references)
                )
            end
        end
    end

    local statement_keys = {}
    for key in pairs(STATEMENT_MARKERS) do
        statement_keys[#statement_keys + 1] = key
    end
    table.sort(statement_keys)
    for _, key in ipairs(statement_keys) do
        local label = 'Statement: ' .. key
        local recorded = requirements and requirements.statements and requirements.statements[key]
        if not requirements then
            add_result(results, 'not_recorded', label, 'not recorded for this journal')
        elseif recorded and recorded.status == 'not_stated_by_journal' then
            add_result(results, 'not_required', label, 'not stated by this journal (not required by the journal)')
        elseif recorded and recorded.status == 'required' then
            if has_marker(lower, STATEMENT_MARKERS[key]) then
                add_result(results, 'pass', label, 'marker text found in manuscript')
            else
                add_result(
                    results,
                    'missing',
                    label,
                    ('required; expected location: %s'):format(recorded.location or 'manuscript')
                )
            end
        elseif recorded and recorded.status == 'required_conditional' then
            local applies = lower:find('human subject', 1, true)
                or lower:find('participant', 1, true)
                or lower:find('survey', 1, true)
            if has_marker(lower, STATEMENT_MARKERS[key]) then
                add_result(results, 'pass', label, 'marker text found in manuscript')
            elseif applies then
                add_result(
                    results,
                    'missing',
                    label,
                    ('required for %s; expected location: %s'):format(
                        recorded.condition or 'applicable work',
                        recorded.location or 'manuscript'
                    )
                )
            else
                add_result(
                    results,
                    'warn',
                    label,
                    ('required for %s; applicability not detected in text'):format(
                        recorded.condition or 'applicable work'
                    )
                )
            end
        else
            add_result(results, 'not_recorded', label, 'not recorded for this journal')
        end
    end

    local refs = figure_references(text)
    local ref_count = 0
    for _ in pairs(refs) do
        ref_count = ref_count + 1
    end
    if ref_count > 0 and #scan.figures == 0 then
        add_result(
            results,
            'missing',
            'Figures',
            ('%d figure(s) referenced in text but no figure files found'):format(ref_count)
        )
    elseif ref_count > 0 and #scan.figures < ref_count then
        add_result(
            results,
            'warn',
            'Figures',
            ('%d figure(s) referenced, %d figure file(s) found'):format(ref_count, #scan.figures)
        )
    elseif #scan.figures > 0 and ref_count == 0 then
        add_result(results, 'warn', 'Figures', 'figure files present but no in-text figure references detected')
    elseif ref_count > 0 then
        add_result(
            results,
            'pass',
            'Figures',
            ('%d figure(s) referenced and %d file(s) present'):format(ref_count, #scan.figures)
        )
    else
        add_result(results, 'pass', 'Figures', 'no figures referenced or supplied')
    end

    if type_req and type_req.combined_items_max then
        local box_refs = {}
        for number in text:gmatch('[Bb]ox%s+(%d+)') do
            box_refs[number] = true
        end
        local box_count = 0
        for _ in pairs(box_refs) do
            box_count = box_count + 1
        end
        local combined = #scan.figures + #scan.tables + box_count
        if combined > type_req.combined_items_max then
            add_result(
                results,
                'fail',
                'Combined display items',
                ('%d figures/tables/boxes exceeds the maximum of %d'):format(combined, type_req.combined_items_max)
            )
        else
            add_result(
                results,
                'pass',
                'Combined display items',
                ('%d of at most %d figures/tables/boxes'):format(combined, type_req.combined_items_max)
            )
        end
    end

    return results, profile
end

---Render M.check_requirements as report lines for display.
---@param root string
---@param journal_key string
---@param article_type? string
---@return string[]
function M.requirements_report(root, journal_key, article_type)
    local results, profile = M.check_requirements(root, journal_key, article_type)
    local source = profile.requirements_source or 'not recorded'
    local lines = {
        ('# Submission Check — %s'):format(profile.name or journal_key),
        '',
        ('Requirements source: %s'):format(source),
        '',
    }
    local labels = {
        fail = 'FAIL',
        missing = 'MISSING',
        not_recorded = 'NOT RECORDED',
        not_required = 'NOT REQUIRED',
        pass = 'PASS',
        warn = 'WARN',
    }
    for _, result in ipairs(results) do
        lines[#lines + 1] = ('- [%s] %s — %s'):format(
            labels[result.status] or result.status,
            result.label,
            result.detail
        )
    end
    return lines
end

---Register the :SubmissionChecklist user command.
---@return nil
function M.setup()
    api.nvim_create_user_command('SubmissionChecklist', function(opts)
        local root = opts.args ~= '' and fs.normalize(opts.args) or (vim.uv.cwd() or fn.getcwd())
        local buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_lines(buf, 0, -1, false, M.checklist(root))
        vim.bo[buf].filetype = 'markdown'
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.cmd.vnew()
        api.nvim_win_set_buf(0, buf)
    end, {
        nargs = '?',
        complete = 'dir',
        desc = 'Generate journal submission checklist',
    })

    api.nvim_create_user_command('SubmissionCheck', function(opts)
        local args = opts.fargs
        if #args == 0 then
            vim.notify('SubmissionCheck: usage :SubmissionCheck <journal> [dir]', vim.log.levels.WARN)
            return
        end
        local journal_key = args[1]
        local root = args[2] and fs.normalize(args[2]) or (vim.uv.cwd() or fn.getcwd())
        local buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_lines(buf, 0, -1, false, M.requirements_report(root, journal_key))
        vim.bo[buf].filetype = 'markdown'
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.cmd.vnew()
        api.nvim_win_set_buf(0, buf)
    end, {
        nargs = '+',
        complete = function()
            return require('research.journal').names()
        end,
        desc = 'Check a manuscript dir against a journal profile (requirements preflight)',
    })
end

return M
