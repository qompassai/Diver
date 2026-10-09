-- Tests for the research journal workflow: journal requirements
-- profiles, per-journal templates, submission preflight, Zenodo token
-- handling, and the JSON registry export.
-- Run from the config root:
--   nvim --headless -u NONE -i NONE -l tests/research/research_journal_workflow.lua
-- Real vim APIs are used (the runner is headless Neovim). Network is
-- never touched: Zenodo cases run with no usable token by construction.
-- Validation and adversarial cases are counted separately.
local here = debug.getinfo(1, 'S').source:sub(2)
if here:sub(1, 1) ~= '/' then
    here = vim.fn.getcwd() .. '/' .. here
end
local dir = here:match('^(.*)/[^/]*$')
local root = dir:match('^(.*)/tests/[^/]*$')
assert(root ~= nil, 'cannot locate config root from ' .. dir)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local passed = 0
local total = 0
local validation_passed = 0
local validation_total = 0
local adversarial_passed = 0
local adversarial_total = 0

local function check(condition, label, kind)
    total = total + 1
    if kind == 'adversarial' then
        adversarial_total = adversarial_total + 1
    else
        validation_total = validation_total + 1
    end
    if condition then
        passed = passed + 1
        if kind == 'adversarial' then
            adversarial_passed = adversarial_passed + 1
        else
            validation_passed = validation_passed + 1
        end
    else
        print('FAIL [' .. kind .. ']: ' .. label)
    end
end

local function contains(lines, needle)
    local text = type(lines) == 'table' and table.concat(lines, '\n') or lines
    return text:find(needle, 1, true) ~= nil
end

local notifications = {}
vim.notify = function(message, _level, _opts)
    notifications[#notifications + 1] = message
end

local journal = require('research.journal')
local manuscript = require('research.manuscript')
local submission = require('research.submission')
local templates = require('research.templates')
local wos = require('research.wos')
local zenodo = require('research.zenodo')

local function result_by_label(results, label)
    for _, result in ipairs(results) do
        if result.label == label then
            return result
        end
    end
    return nil
end

local function write_file(path, lines)
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.fn.writefile(lines, path)
end

local function repeat_words(count)
    local words = {}
    for index = 1, count do
        words[index] = 'word'
    end
    return table.concat(words, ' ')
end

-- ================= VALIDATION =================

do
    local requirements, source = journal.requirements_for('jgme')
    check(requirements ~= nil, 'JGME requirements recorded', 'validation')
    check(source:find('Verified', 1, true) ~= nil, 'JGME source is the verified one', 'validation')
    local profile = journal.get('jgme')
    check(profile.platform == 'editorialmanager', 'JGME platform is Editorial Manager', 'validation')
    local original = journal.article_requirement(profile, 'Original Research')
    check(
        original.manuscript_word_limit.value == 2500
            and original.manuscript_word_limit.comparator == '<'
            and original.manuscript_word_limit.qualitative_value == 3500,
        'Original Research word limits (<2500, qualitative <3500)',
        'validation'
    )
    check(original.abstract_max_words == 250, 'Original Research abstract limit 250', 'validation')
    local letter = journal.article_requirement(profile, 'Letter to the Editor')
    check(
        letter.max_authors == 3 and letter.max_references == 5 and letter.abstract_required == false,
        'Letter limits (3 authors, 5 references, no abstract)',
        'validation'
    )
    check(
        requirements.statements.funding.status == 'not_stated_by_journal',
        'JGME funding statement is explicitly not stated by the journal',
        'validation'
    )
    check(
        requirements.statements.irb_ethics.status == 'required_conditional'
            and requirements.statements.irb_ethics.location == 'end of Methods',
        'JGME IRB statement required at end of Methods',
        'validation'
    )
    check(
        requirements.figures.min_resolution_dpi == 300
            and requirements.figures.discrepancy_note:find('200 dpi', 1, true) ~= nil,
        'Figure resolution 300 dpi with the 200 dpi checklist discrepancy flagged',
        'validation'
    )
end

do
    local json_text, err = journal.export_json()
    check(json_text ~= nil, 'export_json returns JSON: ' .. tostring(err), 'validation')
    local decoded = vim.json.decode(json_text)
    local exported_keys = {}
    for key in pairs(decoded.profiles) do
        exported_keys[#exported_keys + 1] = key
    end
    table.sort(exported_keys)
    check(vim.deep_equal(exported_keys, journal.names()), 'exported journal key set matches M.names()', 'validation')
    local again = journal.export_json()
    check(again == json_text, 'export_json is deterministic (byte-identical)', 'validation')
    local out_path = vim.fn.tempname() .. '/journals.json'
    local ok = journal.export_json(out_path)
    local reread = vim.json.decode(table.concat(vim.fn.readfile(out_path), '\n'))
    check(
        ok == true and reread.profiles.jgme.requirements.figures.min_resolution_dpi == 300,
        'export written to disk re-parses with requirements intact',
        'validation'
    )
end

do
    local md = templates.render('jgme', 'Original Research', 'markdown', { title = 'T' })
    check(
        contains(md, '**Background:**')
            and contains(md, '# IRB/Ethics Statement')
            and contains(md, 'Figure 1.')
            and contains(md, 'Word counts'),
        'JGME markdown template carries structured abstract, IRB block, legends',
        'validation'
    )
    local tex = templates.render('jgme', 'original_research', 'latex', {})
    check(
        contains(tex, '\\section{Methods}') and contains(tex, '\\begin{abstract}'),
        'JGME LaTeX template carries sections and abstract',
        'validation'
    )
    local generic = templates.render('generic', 'Article', 'markdown', {})
    check(
        contains(generic, '# Disclosures') and contains(generic, '# Funding'),
        'generic markdown template carries statement blocks',
        'validation'
    )
end

do
    local fixture = vim.fn.tempname()
    write_file(fixture .. '/manuscript.md', {
        'Full Title: A Study of Things',
        'Article Type: Original Research',
        '',
        '# Abstract',
        '',
        '**Background:** x **Objective:** y **Methods:** z **Results:** r **Conclusions:** c',
        '',
        '# Methods',
        '',
        'We surveyed participants. This study used a large language model for drafting.',
        'The institutional review board approved this study.',
        '',
        '# Results',
        '',
        'See Figure 1 for the main result.',
    })
    write_file(fixture .. '/cover_letter.md', { 'Dear Editor,' })
    vim.fn.writefile({ 'PNG' }, fixture .. '/fig1.png')
    local results = submission.check_requirements(fixture, 'jgme')
    check(result_by_label(results, 'Manuscript file').status == 'pass', 'preflight: manuscript pass', 'validation')
    check(result_by_label(results, 'Cover letter').status == 'pass', 'preflight: cover letter pass', 'validation')
    check(result_by_label(results, 'Abstract').status == 'pass', 'preflight: abstract pass', 'validation')
    check(
        result_by_label(results, 'Statement: irb_ethics').status == 'pass',
        'preflight: IRB statement found',
        'validation'
    )
    check(
        result_by_label(results, 'Statement: ai_disclosure').status == 'pass',
        'preflight: AI disclosure found',
        'validation'
    )
    check(
        result_by_label(results, 'Statement: funding').status == 'not_required',
        'preflight: JGME funding reported not required, not missing',
        'validation'
    )
    check(result_by_label(results, 'Figures').status == 'pass', 'preflight: figures pass', 'validation')
end

do
    local target = vim.fn.tempname() .. '/manuscript.md'
    local ok = manuscript.new_from_template(target, 'jgme', 'Original Research', 'markdown', {
        title = 'My Title',
    })
    local text = table.concat(vim.fn.readfile(target), '\n')
    check(
        ok and text:find('My Title', 1, true) ~= nil and text:find('Graduate Medical Education', 1, true) ~= nil,
        'ManuscriptNew template mode creates a JGME file with metadata',
        'validation'
    )
end

do
    local requirements, source = journal.requirements_for('nejm_ai')
    check(requirements ~= nil, 'NEJM AI requirements recorded', 'validation')
    check(source:find('Verified', 1, true) ~= nil, 'NEJM AI source is the verified one', 'validation')
    local profile = journal.get('nejm_ai')
    check(profile.platform == 'scholarone', 'NEJM AI platform is ScholarOne', 'validation')
    check(
        profile.portal == 'https://mc05.manuscriptcentral.com/nejmai',
        'NEJM AI portal is the ScholarOne site',
        'validation'
    )
    check(
        profile.login_route ~= nil
            and profile.login_route.route:find('Web of Science', 1, true) ~= nil
            and profile.login_route.system:find('ScholarOne', 1, true) ~= nil
            and profile.login_route.source:find('Matt', 1, true) ~= nil,
        'NEJM AI login route records the stated WoS workflow and the verified system',
        'validation'
    )
    local original = journal.article_requirement(profile, 'Original Research')
    check(
        original.manuscript_word_limit.value == 3000 and original.manuscript_word_limit.comparator == '<=',
        'NEJM AI Original Research word limit (<=3000)',
        'validation'
    )
    check(
        original.abstract_max_words == 300 and original.combined_items_max == 5,
        'NEJM AI Original Research abstract 300 and 5 display items',
        'validation'
    )
    local letter = journal.article_requirement(profile, 'Letter to the Editor')
    check(
        letter.abstract_required == false and letter.max_references == 5 and letter.manuscript_word_limit.value == 400,
        'NEJM AI Letter limits (no abstract, 5 references, 400 words)',
        'validation'
    )
    check(
        requirements.statements.data_availability.status == 'required',
        'NEJM AI data sharing statement is required',
        'validation'
    )
    check(
        requirements.statements.disclosures_coi.location:find('Convey', 1, true) ~= nil,
        'NEJM AI disclosures run through Convey, not the manuscript',
        'validation'
    )
    check(
        requirements.fees.submission_fee == false and requirements.fees.publication_fee == false,
        'NEJM AI charges no submission or publication fees',
        'validation'
    )
    check(#journal.names() == 13, 'registry now holds 13 profiles', 'validation')
end

do
    local md = templates.render('nejm_ai', 'Original Research', 'markdown', { title = 'T' })
    check(
        contains(md, '**Background:**')
            and contains(md, 'Data Sharing Statement')
            and contains(md, 'Convey')
            and contains(md, '# Short Description'),
        'NEJM AI markdown template carries structured abstract, data sharing, Convey note',
        'validation'
    )
    local tex = templates.render('nejm_ai', 'original_research', 'latex', {})
    check(
        contains(tex, '\\section{Methods}') and contains(tex, 'Data Sharing Statement'),
        'NEJM AI LaTeX template carries sections and the data sharing block',
        'validation'
    )
    local letter_md = templates.render('nejm_ai', 'Letter to the Editor', 'markdown', {})
    check(
        contains(letter_md, '400 words') and not contains(letter_md, '# Abstract'),
        'NEJM AI letter template states the 400-word limit and has no abstract',
        'validation'
    )
end

do
    local fixture = vim.fn.tempname()
    write_file(fixture .. '/manuscript.md', {
        'Full Title: A Complete NEJM AI Study',
        'Article Type: Original Research',
        '',
        '# Abstract',
        '',
        '**Background:** x **Methods:** y **Results:** z **Conclusions:** c',
        '',
        '# Methods',
        '',
        'We enrolled participants and followed them. The institutional review board approved the protocol.',
        'Author contributions: the first author designed the study. Funding: supported by a grant.',
        'Disclosures were filed by all authors. A large language model assisted with drafting.',
        'Data availability: data are available on request. Code availability: code is public.',
        '',
        '# Results',
        '',
        'See Figure 1 for the primary outcome.',
    })
    write_file(fixture .. '/cover_letter.md', { 'Dear Editor,' })
    vim.fn.writefile({ 'PNG' }, fixture .. '/fig1.png')
    local results = submission.check_requirements(fixture, 'nejm_ai')
    check(
        result_by_label(results, 'Cover letter').status == 'pass',
        'NEJM AI preflight: cover letter pass',
        'validation'
    )
    check(result_by_label(results, 'Abstract').status == 'pass', 'NEJM AI preflight: abstract pass', 'validation')
    check(
        result_by_label(results, 'Statement: data_availability').status == 'pass',
        'NEJM AI preflight: data sharing statement found',
        'validation'
    )
    check(
        result_by_label(results, 'Statement: disclosures_coi').status == 'pass',
        'NEJM AI preflight: disclosures addressed',
        'validation'
    )
    check(
        result_by_label(results, 'Combined display items').status == 'pass',
        'NEJM AI preflight: combined display items within 5',
        'validation'
    )
end

do
    local target = vim.fn.tempname() .. '/manuscript.md'
    local ok = manuscript.new_from_template(target, 'nejm_ai', 'Original Research', 'markdown', {
        title = 'My NEJM AI Title',
    })
    local text = table.concat(vim.fn.readfile(target), '\n')
    check(
        ok and text:find('My NEJM AI Title', 1, true) ~= nil and text:find('NEJM AI', 1, true) ~= nil,
        'ManuscriptNew template mode creates a NEJM AI file with metadata',
        'validation'
    )
end

do
    -- WoS Starter API happy paths, driven through the setup() HTTP
    -- seam so no test reaches the network. The fixture mirrors the
    -- verified Swagger example shape (developer.clarivate.com,
    -- /apis/wos-starter) — a documents list wrapping one document,
    -- and the bare document for the UID route.
    local hit = {
        uid = 'WOS:000282418500002',
        title = 'Wild bird indicators',
        types = { 'Article' },
        source = {
            sourceTitle = 'ORNITHOLOGICAL SCIENCE',
            publishYear = 2010,
            volume = '9',
            issue = '1',
            pages = { range = '3-22', begin = '3', ['end'] = '22', count = 20 },
        },
        names = { authors = { { displayName = 'Gregory, Richard D.', researcherId = 'AAG-1843-2020' } } },
        links = { record = 'https://www.webofscience.com/api/gateway?KeyUT=WOS:000282418500002' },
        citations = { { db = 'WOS', count = 145 } },
        identifiers = { doi = '10.2326/osj.9.3', issn = '1347-0558' },
    }
    local list_body = vim.json.encode({ metadata = { total = 1, page = 1, limit = 1 }, hits = { hit } })
    local empty_body = vim.json.encode({ metadata = { total = 0, page = 1, limit = 1 }, hits = {} })
    local document_body = vim.json.encode(hit)
    local function stub_transport(url)
        if url:find('/documents/WOS:', 1, true) then
            return 200, document_body
        end
        if url:find('missing', 1, true) then
            return 200, empty_body
        end
        if url:find('documents?', 1, true) then
            return 200, list_body
        end
        return 404, '{"error":{"status":404,"title":"not found","details":"nope"}}'
    end
    wos.setup({ api_key = 'test-key', transport = stub_transport })
    local record = wos.lookup('10.2326/osj.9.3')
    check(
        record ~= nil and record.title == 'Wild bird indicators' and record.uid == 'WOS:000282418500002',
        'WoS lookup parses the record title and UID',
        'validation'
    )
    check(
        record.source == 'ORNITHOLOGICAL SCIENCE'
            and record.year == 2010
            and record.volume == '9'
            and record.issue == '1'
            and record.pages == '3-22',
        'WoS lookup parses source, year, volume, issue, pages',
        'validation'
    )
    check(
        record.authors[1] == 'Gregory, Richard D.'
            and record.doi == '10.2326/osj.9.3'
            and record.url:find('webofscience.com', 1, true) ~= nil,
        'WoS lookup parses authors, DOI, and the record URL',
        'validation'
    )
    check(record.times_cited == 145, 'WoS lookup parses the times-cited count', 'validation')
    local by_uid = wos.lookup('WOS:000282418500002')
    check(by_uid ~= nil and by_uid.times_cited == 145, 'WoS lookup by UID uses the document route', 'validation')
    local count = wos.times_cited('10.2326/osj.9.3')
    check(count == 145, 'WoS times_cited returns the count', 'validation')
    local via_url = wos.lookup('https://doi.org/10.2326/osj.9.3')
    check(
        via_url ~= nil and via_url.uid == 'WOS:000282418500002',
        'WoS lookup strips a doi.org prefix before searching',
        'validation'
    )
    wos.setup({
        works_provider = function()
            return {
                {
                    doi = '10.2326/osj.9.3',
                    title = 'Wild bird indicators',
                    year = '2010',
                    journal = 'Ornithological Science',
                },
                { doi = '10.9999/missing', title = 'Not in WoS', year = '2021' },
                { title = 'No DOI work', year = '2019' },
            },
                nil
        end,
    })
    local entries = wos.works_with_citations()
    check(entries ~= nil and #entries == 3, 'WoS batch returns one entry per ORCID work', 'validation')
    check(
        entries[1].times_cited == 145 and entries[1].error == nil,
        'WoS batch attaches the count to the found work',
        'validation'
    )
    check(
        entries[2].times_cited == nil and entries[2].error:find('no Web of Science record', 1, true) ~= nil,
        'WoS batch records a per-work miss without sinking the batch',
        'validation'
    )
    check(entries[3].error == 'no DOI on the ORCID record', 'WoS batch flags a DOI-less work in place', 'validation')
end

-- ================= ADVERSARIAL =================

do
    local requirements, source = journal.requirements_for('no_such_journal')
    check(
        requirements == nil and source == 'not recorded',
        'unknown journal: requirements not recorded (no silent fallback)',
        'adversarial'
    )
    local generic = journal.get('no_such_journal')
    check(
        generic.requirements_source == 'not recorded',
        'unknown journal falls back to generic thin profile',
        'adversarial'
    )
end

do
    local fixture = vim.fn.tempname()
    write_file(fixture .. '/manuscript.md', {
        'Full Title: Incomplete Brief',
        'Article Type: Brief Report',
        '',
        '# Abstract',
        '',
        repeat_words(300),
        '',
        '# Methods',
        '',
        'We ran a survey of participants about teaching.',
        '',
        '# Results',
        '',
        'See Figure 2 for details.',
    })
    local results = submission.check_requirements(fixture, 'jgme')
    check(
        result_by_label(results, 'Cover letter').status == 'missing',
        'preflight names the missing cover letter',
        'adversarial'
    )
    check(
        result_by_label(results, 'Statement: ai_disclosure').status == 'missing',
        'preflight names the missing AI disclosure',
        'adversarial'
    )
    check(
        result_by_label(results, 'Statement: irb_ethics').status == 'missing',
        'preflight names the missing IRB statement for survey work',
        'adversarial'
    )
    check(
        result_by_label(results, 'Figures').status == 'missing',
        'preflight names referenced figures with no files',
        'adversarial'
    )
    check(
        result_by_label(results, 'Abstract').status == 'fail',
        'preflight fails a 300-word abstract against 250',
        'adversarial'
    )
end

do
    local empty = vim.fn.tempname()
    vim.fn.mkdir(empty, 'p')
    local results = submission.check_requirements(empty, 'jgme')
    check(
        result_by_label(results, 'Manuscript file').status == 'missing',
        'empty directory: manuscript reported missing',
        'adversarial'
    )
    local thin = submission.check_requirements(empty, 'cureus')
    check(
        result_by_label(thin, 'Statement: funding').status == 'not_recorded',
        'thin profile: statements report not recorded, never a silent pass',
        'adversarial'
    )
    check(
        result_by_label(thin, 'Word count').status == 'not_recorded',
        'thin profile: word count reports not recorded',
        'adversarial'
    )
end

do
    local fixture = vim.fn.tempname()
    write_file(fixture .. '/manuscript.md', {
        'Full Title: Long One',
        'Article Type: Original Research',
        '',
        '# Introduction',
        '',
        repeat_words(3600),
    })
    local results = submission.check_requirements(fixture, 'jgme')
    check(
        result_by_label(results, 'Word count').status == 'warn',
        'over-limit screening count warns (journal exclusions may apply)',
        'adversarial'
    )
    vim.fn.writefile({ 'PNG' }, fixture .. '/fig1.png')
    local with_fig = submission.check_requirements(fixture, 'jgme')
    check(
        result_by_label(with_fig, 'Figures').status == 'warn',
        'figure file without in-text reference warns',
        'adversarial'
    )
end

do
    local fixture = vim.fn.tempname()
    local lines = {
        'Full Title: Too Many Items',
        'Article Type: Brief Report',
        '',
        '# Results',
        '',
        'Figure 1 and Figure 2 and Figure 3.',
    }
    write_file(fixture .. '/manuscript.md', lines)
    for index = 1, 3 do
        vim.fn.writefile({ 'PNG' }, fixture .. '/fig' .. index .. '.png')
    end
    local results = submission.check_requirements(fixture, 'jgme')
    check(
        result_by_label(results, 'Combined display items').status == 'fail',
        'Brief Report with 3 display items fails the combined maximum of 2',
        'adversarial'
    )
end

do
    local lines, err = templates.render('jgme', 'Original Research', 'docx', {})
    check(
        lines == nil and err:find('unknown template format', 1, true) ~= nil,
        'template render rejects an unknown format with an error',
        'adversarial'
    )
    local fallback = templates.render('jgme', 'Nonexistent Type', 'markdown', {})
    check(contains(fallback, '# Disclosures'), 'unknown article type falls back to the generic skeleton', 'adversarial')
end

do
    journal.register('tmp_bad_profile', {
        name = 'Bad',
        bad_value = function()
            return 1
        end,
    })
    local exported, export_err = journal.export_json()
    journal.profiles.tmp_bad_profile = nil
    check(
        exported == nil and export_err ~= nil and export_err:find('not JSON-serializable', 1, true) ~= nil,
        'registry with a function value fails export cleanly instead of crashing',
        'adversarial'
    )
end

do
    -- No-token Zenodo behaviour. The environment token is neutralized
    -- and the pass path points at a nonexistent entry, so no code path
    -- can reach the network. When the GPG agent is locked this also
    -- exercises the 'secret unavailable' degradation end to end.
    local saved_env = vim.fn.getenv('ZENODO_TOKEN')
    vim.fn.setenv('ZENODO_TOKEN', '')
    zenodo.setup({ pass_path = 'bogus/nonexistent-entry-for-tests' })
    local depositions, list_err = zenodo.list_depositions()
    check(
        depositions == nil and list_err:find('Zenodo token', 1, true) ~= nil,
        'Zenodo list without a token fails with a clear message: ' .. tostring(list_err),
        'adversarial'
    )
    -- Tier degradation: a research-secret field that does not exist
    -- degrades to the same structured 'secret unavailable' outcome --
    -- and while the tier still holds REPLACE_ME placeholders, the real
    -- zenodo_token field exercised above takes exactly that path too.
    zenodo.setup({ secret_field = 'bogus_field_for_tests' })
    local tier_depositions, tier_err = zenodo.list_depositions()
    check(
        tier_depositions == nil and tier_err:find('unavailable', 1, true) ~= nil,
        'Zenodo list with an unavailable research-secret tier degrades cleanly: ' .. tostring(tier_err),
        'adversarial'
    )
    zenodo.setup({ secret_field = 'zenodo_token' })
    local entry, show_err = zenodo.get_deposition('not-a-number')
    check(
        entry == nil and show_err:find('invalid', 1, true) ~= nil,
        'Zenodo show rejects a non-numeric id before any request',
        'adversarial'
    )
    local uploaded, upload_err = zenodo.upload_file('1', '/nonexistent/file.png')
    check(
        uploaded == nil and upload_err:find('not readable', 1, true) ~= nil,
        'Zenodo upload rejects an unreadable file',
        'adversarial'
    )
    if saved_env ~= vim.NIL and saved_env ~= '' then
        vim.fn.setenv('ZENODO_TOKEN', saved_env)
    end
end

do
    -- Template creation must succeed even when pass cannot provide the
    -- author identity (locked agent): fields degrade to blank, no crash.
    local target = vim.fn.tempname() .. '/degraded.md'
    local ok = manuscript.new_from_template(target, 'generic', 'Article', 'markdown', {})
    check(
        ok and vim.fn.filereadable(target) == 1,
        'template creation degrades gracefully without pass identity',
        'adversarial'
    )
end

do
    local fixture = vim.fn.tempname()
    write_file(fixture .. '/manuscript.md', {
        'Full Title: No Sharing Statement',
        'Article Type: Original Research',
        '',
        '# Abstract',
        '',
        '**Background:** x **Methods:** y **Results:** z **Conclusions:** c',
        '',
        '# Methods',
        '',
        'We studied participants. The institutional review board approved this study.',
        'A large language model helped draft the text. Author contributions are listed.',
        'Funding came from a grant. Disclosures were collected from all authors.',
        '',
        '# Results',
        '',
        'Done.',
    })
    local results = submission.check_requirements(fixture, 'nejm_ai')
    check(
        result_by_label(results, 'Statement: data_availability').status == 'missing',
        'NEJM AI preflight names the missing data sharing statement',
        'adversarial'
    )
    check(
        result_by_label(results, 'Statement: irb_ethics').status == 'pass',
        'NEJM AI preflight still finds the IRB statement in the same fixture',
        'adversarial'
    )
end

do
    local fixture = vim.fn.tempname()
    write_file(fixture .. '/manuscript.md', {
        'Full Title: A Long Abstract',
        'Article Type: Original Research',
        '',
        '# Abstract',
        '',
        repeat_words(301),
        '',
        '# Introduction',
        '',
        'Body.',
    })
    local results = submission.check_requirements(fixture, 'nejm_ai')
    check(
        result_by_label(results, 'Abstract').status == 'fail',
        'NEJM AI preflight fails a 301-word abstract against 300',
        'adversarial'
    )
end

do
    local fixture = vim.fn.tempname()
    write_file(fixture .. '/manuscript.md', {
        'Full Title: A Letter With Too Many References',
        'Article Type: Letter to the Editor',
        '',
        '# Letter',
        '',
        'Short text.',
        '',
        '# References',
        '',
        '1. One',
        '2. Two',
        '3. Three',
        '4. Four',
        '5. Five',
        '6. Six',
    })
    local results = submission.check_requirements(fixture, 'nejm_ai')
    check(
        result_by_label(results, 'References').status == 'fail',
        'NEJM AI letter with 6 references fails the maximum of 5',
        'adversarial'
    )
end

do
    local fallback = templates.render('nejm_ai', 'Nonexistent Type', 'markdown', {})
    check(
        contains(fallback, '# Disclosures'),
        'NEJM AI unknown article type falls back to the generic skeleton',
        'adversarial'
    )
end

do
    -- WoS failure shapes, all through the setup() HTTP seam. The setup
    -- key from the validation block is still in config here, so key
    -- resolution succeeds until the secret-chain cases at the end
    -- deliberately neutralize it.
    wos.setup({
        transport = function()
            return 401, '{"error":"invalid_request","error_description":"The access token is missing"}'
        end,
    })
    local record, auth_err = wos.lookup('10.2326/osj.9.3')
    check(
        record == nil and auth_err.code == 'auth' and auth_err.status == 401,
        'WoS 401 degrades to a structured auth error',
        'adversarial'
    )
    wos.setup({
        transport = function()
            return 200, 'this is not json'
        end,
    })
    local bad, bad_err = wos.lookup('10.2326/osj.9.3')
    check(
        bad == nil and bad_err.code == 'invalid_response',
        'WoS malformed JSON degrades to invalid_response',
        'adversarial'
    )
    wos.setup({
        transport = function()
            return 200, '{"metadata":{"total":0,"page":1,"limit":1},"hits":[]}'
        end,
    })
    local none, none_err = wos.lookup('10.2326/osj.9.3')
    check(none == nil and none_err.code == 'not_found', 'WoS empty result set degrades to not_found', 'adversarial')
    local no_citations = vim.json.encode({
        metadata = { total = 1, page = 1, limit = 1 },
        hits = {
            {
                uid = 'WOS:000282418500002',
                title = 'Wild bird indicators',
                identifiers = { doi = '10.2326/osj.9.3' },
            },
        },
    })
    wos.setup({
        transport = function()
            return 200, no_citations
        end,
    })
    local no_count, count_err = wos.times_cited('10.2326/osj.9.3')
    check(
        no_count == nil and count_err.code == 'times_cited_unavailable',
        'WoS record without citations reports times_cited_unavailable, never a fabricated zero',
        'adversarial'
    )
    local empty, empty_err = wos.lookup('')
    check(empty == nil and empty_err.code == 'invalid_argument', 'WoS lookup rejects a missing argument', 'adversarial')
    local garbage, garbage_err = wos.lookup('not-a-doi')
    check(
        garbage == nil and garbage_err.code == 'invalid_argument',
        'WoS lookup rejects a non-DOI argument',
        'adversarial'
    )
    -- Secret chain: neutralize the environment and the setup key, then
    -- point the tier at a fake tier program answering REPLACE_ME (so
    -- this block stays valid after Matt populates the real field) and
    -- at a bogus field. The transport must never fire in either case.
    local saved_env = vim.fn.getenv('WOS_API_KEY')
    vim.fn.setenv('WOS_API_KEY', '')
    local fake_tier_program = vim.fn.tempname()
    vim.fn.writefile({ '#!/bin/sh', 'printf REPLACE_ME' }, fake_tier_program)
    vim.fn.setfperm(fake_tier_program, 'rwx------')
    local transport_calls = 0
    wos.setup({
        api_key = '',
        secret_field = 'wos_api_key',
        secret_tier_program = fake_tier_program,
        transport = function()
            transport_calls = transport_calls + 1
            return 200, '{}'
        end,
    })
    local no_key, key_err = wos.lookup('10.2326/osj.9.3')
    check(
        no_key == nil and key_err.code == 'secret_unavailable' and transport_calls == 0,
        'WoS REPLACE_ME tier degrades to secret_unavailable before any request',
        'adversarial'
    )
    check(
        key_err.sources_tried[1] == 'env' and key_err.sources_tried[2] == 'tier',
        'WoS secret error names the sources tried',
        'adversarial'
    )
    wos.setup({ secret_field = 'bogus_field_for_tests' })
    local bogus, bogus_err = wos.lookup('10.2326/osj.9.3')
    check(
        bogus == nil and bogus_err.code == 'secret_unavailable',
        'WoS missing tier field degrades to secret_unavailable',
        'adversarial'
    )
    if saved_env ~= vim.NIL and saved_env ~= '' then
        vim.fn.setenv('WOS_API_KEY', saved_env)
    end
end

-- ================= DEADLINES (validation) =================
local deadlines = require('research.deadlines')
do
    local fixture_dir = vim.fn.tempname()
    vim.fn.mkdir(fixture_dir, 'p')
    local main_path = fixture_dir .. '/deadlines.json'
    local main_entries = {
        {
            id = 'future-grant',
            title = 'Future Grant',
            kind = 'grant',
            deadline = '2026-10-18',
            url = 'https://example.org/grant',
            verified = true,
        },
        { id = 'today-cfp', title = 'Today CFP', kind = 'cfp', closes = '2026-10-08' },
        { id = 'past-contest', title = 'Past Contest', kind = 'contest', deadline = '2026-10-07' },
        { id = 'cycle-event', title = 'Cycle Event', kind = 'event', cycle = 'Annual; dates vary' },
        { id = 'opens-only', title = 'Opens Only', kind = 'grant', opens = '2026-09-01', cycle = 'Rolling' },
    }
    write_file(main_path, { vim.json.encode(main_entries) })
    local result, load_err = deadlines.upcoming({ data_path = main_path, today = '2026-10-08' })
    check(result ~= nil and load_err == nil, 'Deadlines fixture loads', 'validation')
    assert(result ~= nil, 'fixture must load')
    check(result.state == 'ok' and result.total == 5, 'Deadlines fixture: state ok, 5 entries', 'validation')
    check(
        #result.dated == 3
            and result.dated[1].entry.id == 'past-contest'
            and result.dated[2].entry.id == 'today-cfp'
            and result.dated[3].entry.id == 'future-grant',
        'Deadlines dated entries sorted by days remaining',
        'validation'
    )
    check(
        result.dated[1].days_remaining == -1
            and result.dated[2].days_remaining == 0
            and result.dated[3].days_remaining == 10,
        'Deadlines days_remaining: yesterday -1, today 0, +10 days',
        'validation'
    )
    check(
        result.dated[1].past_due and not result.dated[2].past_due and not result.dated[3].past_due,
        'Deadlines past_due flags only the yesterday entry',
        'validation'
    )
    check(result.dated[2].date == '2026-10-08', 'Deadlines effective date falls back to closes', 'validation')
    check(
        #result.dateless == 2 and result.dateless[1].id == 'cycle-event' and result.dateless[2].id == 'opens-only',
        'Deadlines dateless entries (cycle-only, opens-only) sorted by id',
        'validation'
    )
    local lines = deadlines.format_upcoming(result)
    check(
        contains(lines, 'TODAY') and contains(lines, 'PAST DUE by 1 day(s)') and contains(lines, 'in 10 days'),
        'Deadlines render: TODAY / PAST DUE / in N days',
        'validation'
    )
    check(
        contains(lines, 'Cycle known — date unverified'),
        'Deadlines render has the cycle-only section',
        'validation'
    )
    check(contains(lines, '(unverified)'), 'Deadlines render tags unverified entries', 'validation')
    local missing = deadlines.upcoming({ data_path = fixture_dir .. '/nope.json', today = '2026-10-08' })
    check(
        missing ~= nil and missing.state == 'missing' and #missing.dated == 0,
        'Deadlines missing file is a clean state, not an error',
        'validation'
    )
    check(
        contains(deadlines.format_upcoming(missing), 'No deadlines file'),
        'Deadlines missing-file render explains itself',
        'validation'
    )
    check(
        deadlines.marker_for('future-grant') == 'research-deadline:future-grant',
        'Deadlines marker shape',
        'validation'
    )
    local by_id = deadlines.markers_in_items({
        { description = 'research-deadline:today-cfp https://example.org', date = '10/08/26' },
        { description = 'unrelated event', date = '10/08/26' },
        { description = '', date = '10/08/26' },
    })
    check(
        by_id['today-cfp'] ~= nil and by_id['future-grant'] == nil,
        'Deadlines marker scan finds ids in descriptions',
        'validation'
    )
    local record = { entry = result.dated[3].entry, date = '2026-10-18' }
    local argv = deadlines.event_argv(record, nil)
    local argv_text = table.concat(argv, '\n')
    check(
        contains(argv_text, '10/18/26')
            and contains(argv_text, 'research-deadline:future-grant https://example.org/grant')
            and contains(argv_text, '--url'),
        'Deadlines event argv: khal date, marker description, --url',
        'validation'
    )
    local argv_cal = deadlines.event_argv(record, 'scratch')
    check(
        argv_cal[4] == 'new' and argv_cal[5] == '-a' and argv_cal[6] == 'scratch',
        'Deadlines event argv: -a calendar follows new',
        'validation'
    )

    local agenda_items = {
        { description = 'research-deadline:today-cfp', date = '10/08/26', title = 'Today CFP' },
    }
    local created = {}
    local function stub_search(done)
        done(agenda_items, nil)
    end
    local function stub_create(rec, _calendar_name, done)
        created[#created + 1] = rec.entry.id
        done('created', nil)
    end
    local sync_result, sync_err = nil, nil
    deadlines.sync(
        { data_path = main_path, today = '2026-10-08', search_impl = stub_search, create_impl = stub_create },
        function(res, err)
            sync_result, sync_err = res, err
        end
    )
    check(sync_err == nil and sync_result ~= nil, 'Deadlines sync completes against stubs', 'validation')
    assert(sync_result ~= nil, 'sync must produce a result')
    check(
        #sync_result.created == 1 and sync_result.created[1] == 'future-grant' and #created == 1,
        'Deadlines sync creates only the missing id',
        'validation'
    )
    check(
        #sync_result.skipped == 1 and sync_result.skipped[1] == 'today-cfp',
        'Deadlines sync skips the id already on the calendar',
        'validation'
    )
    check(sync_result.past_due_count == 1, 'Deadlines sync counts the past-due entry without syncing it', 'validation')
    agenda_items[#agenda_items + 1] =
        { description = 'research-deadline:future-grant', date = '10/18/26', title = 'Future Grant' }
    created = {}
    local rerun_result = nil
    deadlines.sync(
        { data_path = main_path, today = '2026-10-08', search_impl = stub_search, create_impl = stub_create },
        function(res)
            rerun_result = res
        end
    )
    check(
        rerun_result ~= nil and #rerun_result.created == 0 and #rerun_result.skipped == 2 and #created == 0,
        'Deadlines sync is idempotent on a second run',
        'validation'
    )
    agenda_items[1] = { description = 'research-deadline:today-cfp', date = '10/09/26', title = 'Today CFP' }
    local changed_result = nil
    deadlines.sync(
        { data_path = main_path, today = '2026-10-08', search_impl = stub_search, create_impl = stub_create },
        function(res)
            changed_result = res
        end
    )
    check(
        changed_result ~= nil
            and #changed_result.changed == 1
            and changed_result.changed[1].id == 'today-cfp'
            and changed_result.changed[1].calendar_date == '2026-10-09'
            and changed_result.changed[1].data_date == '2026-10-08',
        'Deadlines sync reports a moved event as changed (US date normalized to ISO)',
        'validation'
    )
    check(
        contains(deadlines.format_sync_report(changed_result), 'left untouched'),
        'Deadlines sync report states changed events are left untouched',
        'validation'
    )
    local leap_path = fixture_dir .. '/leap.json'
    write_file(
        leap_path,
        { vim.json.encode({ { id = 'leap', title = 'Leap', kind = 'event', deadline = '2028-02-29' } }) }
    )
    local leap = deadlines.upcoming({ data_path = leap_path, today = '2028-02-28' })
    check(
        leap ~= nil and leap.dated[1].days_remaining == 1,
        'Deadlines day math honors Feb 29 in a leap year',
        'validation'
    )
end

-- ================= DEADLINES (adversarial) =================
do
    local fixture_dir = vim.fn.tempname()
    vim.fn.mkdir(fixture_dir, 'p')
    local function fixture_with(entries, name)
        local path = fixture_dir .. '/' .. name
        write_file(path, { vim.json.encode(entries) })
        return path
    end
    local bad_json_path = fixture_dir .. '/bad.json'
    write_file(bad_json_path, { '{not json' })
    local bad_result, bad_err = deadlines.upcoming({ data_path = bad_json_path, today = '2026-10-08' })
    check(
        bad_result == nil and bad_err ~= nil and bad_err:find('not valid JSON', 1, true) ~= nil,
        'Deadlines malformed JSON is a structured error',
        'adversarial'
    )
    local dup_path = fixture_with({
        { id = 'dup', title = 'One', kind = 'grant', deadline = '2027-01-01' },
        { id = 'dup', title = 'Two', kind = 'grant', deadline = '2027-02-01' },
    }, 'dup.json')
    local dup_result, dup_err = deadlines.upcoming({ data_path = dup_path, today = '2026-10-08' })
    check(
        dup_result == nil and dup_err ~= nil and dup_err:find('duplicate id', 1, true) ~= nil,
        'Deadlines duplicate ids reject the file',
        'adversarial'
    )
    local bad_date_path =
        fixture_with({ { id = 'x', title = 'X', kind = 'grant', deadline = '2026-02-30' } }, 'baddate.json')
    local bd_result, bd_err = deadlines.upcoming({ data_path = bad_date_path, today = '2026-10-08' })
    check(bd_result == nil and bd_err ~= nil, 'Deadlines rejects the nonexistent date 2026-02-30', 'adversarial')
    local bad_kind_path =
        fixture_with({ { id = 'x', title = 'X', kind = 'webinar', deadline = '2027-01-01' } }, 'badkind.json')
    local bk_result, bk_err = deadlines.upcoming({ data_path = bad_kind_path, today = '2026-10-08' })
    check(bk_result == nil and bk_err ~= nil, 'Deadlines rejects an unknown kind', 'adversarial')
    local bad_url_path = fixture_with({
        { id = 'x', title = 'X', kind = 'grant', deadline = '2027-01-01', url = 'ftp://example.org' },
    }, 'badurl.json')
    local bu_result, bu_err = deadlines.upcoming({ data_path = bad_url_path, today = '2026-10-08' })
    check(bu_result == nil and bu_err ~= nil, 'Deadlines rejects a non-http(s) URL', 'adversarial')
    local bad_id_path =
        fixture_with({ { id = 'bad id', title = 'X', kind = 'grant', deadline = '2027-01-01' } }, 'badid.json')
    local bi_result, bi_err = deadlines.upcoming({ data_path = bad_id_path, today = '2026-10-08' })
    check(bi_result == nil and bi_err ~= nil, 'Deadlines rejects an id with spaces (marker safety)', 'adversarial')
    local big_path = fixture_dir .. '/big.json'
    write_file(big_path, { (' '):rep(262145) })
    local big_result, big_err = deadlines.upcoming({ data_path = big_path, today = '2026-10-08' })
    check(
        big_result == nil and big_err ~= nil and big_err:find('byte cap', 1, true) ~= nil,
        'Deadlines oversized data file is refused',
        'adversarial'
    )
    local many = {}
    for index = 1, 257 do
        many[index] = { id = 'e' .. index, title = 'E', kind = 'grant', deadline = '2027-01-01' }
    end
    local many_path = fixture_with(many, 'many.json')
    local many_result, many_err = deadlines.upcoming({ data_path = many_path, today = '2026-10-08' })
    check(many_result == nil and many_err ~= nil, 'Deadlines refuses more entries than the cap', 'adversarial')
    local nulls_path = fixture_dir .. '/nulls.json'
    write_file(nulls_path, {
        vim.json.encode({
            {
                id = 'null-dates',
                title = 'Null Dates',
                kind = 'grant',
                opens = vim.NIL,
                closes = vim.NIL,
                deadline = vim.NIL,
                cycle = 'Annual',
                url = vim.NIL,
            },
        }),
    })
    local nulls = deadlines.upcoming({ data_path = nulls_path, today = '2026-10-08' })
    check(
        nulls ~= nil and #nulls.dateless == 1 and #nulls.dated == 0,
        'Deadlines explicit JSON nulls count as absent (dateless)',
        'adversarial'
    )
    local search_calls = 0
    local null_sync = nil
    deadlines.sync({
        data_path = nulls_path,
        today = '2026-10-08',
        search_impl = function(done)
            search_calls = search_calls + 1
            done({}, nil)
        end,
        create_impl = function(_rec, _cal, done)
            done('created', nil)
        end,
    }, function(res)
        null_sync = res
    end)
    check(
        null_sync ~= nil and #null_sync.created == 0 and search_calls == 0,
        'Deadlines all-null-dates entry never reaches the calendar seams',
        'adversarial'
    )
    local missing_sync, missing_sync_err = nil, nil
    deadlines.sync({
        data_path = fixture_dir .. '/absent.json',
        today = '2026-10-08',
        search_impl = function(done)
            done({}, nil)
        end,
        create_impl = function(_rec, _cal, done)
            done('created', nil)
        end,
    }, function(res, err)
        missing_sync, missing_sync_err = res, err
    end)
    check(
        missing_sync ~= nil and missing_sync_err == nil and #missing_sync.created == 0,
        'Deadlines sync over a missing data file is a clean no-op',
        'adversarial'
    )
    local dated_path =
        fixture_with({ { id = 'solo', title = 'Solo', kind = 'event', deadline = '2026-12-01' } }, 'solo.json')
    local fail_search_result, fail_search_err = nil, nil
    deadlines.sync({
        data_path = dated_path,
        today = '2026-10-08',
        search_impl = function(done)
            done(nil, 'boom')
        end,
        create_impl = function(_rec, _cal, done)
            done('created', nil)
        end,
    }, function(res, err)
        fail_search_result, fail_search_err = res, err
    end)
    check(
        fail_search_result == nil and fail_search_err ~= nil and fail_search_err:find('marker search', 1, true) ~= nil,
        'Deadlines a failed marker search aborts the sync with an error',
        'adversarial'
    )
    local create_fail_result = nil
    deadlines.sync({
        data_path = dated_path,
        today = '2026-10-08',
        search_impl = function(done)
            done({}, nil)
        end,
        create_impl = function(_rec, _cal, done)
            done(nil, 'khal exploded')
        end,
    }, function(res)
        create_fail_result = res
    end)
    check(
        create_fail_result ~= nil
            and #create_fail_result.errors == 1
            and create_fail_result.errors[1].id == 'solo'
            and #create_fail_result.created == 0,
        'Deadlines a failed create is collected, not fatal',
        'adversarial'
    )
end

-- ================= OPENALEX (validation) =================
local openalex = require('research.openalex')
do
    -- OpenAlex happy paths through the setup() HTTP seam; no test
    -- reaches the network. Fixture shapes mirror the documented API
    -- objects (docs.openalex.org): singleton work/author/source
    -- objects, list bodies with meta + results, group_by bodies.
    local work_main = {
        id = 'https://openalex.org/W2741809807',
        doi = 'https://doi.org/10.7717/peerj.4375',
        title = 'The state of OA: a large-scale analysis',
        display_name = 'The state of OA: a large-scale analysis',
        publication_year = 2017,
        type = 'article',
        cited_by_count = 452,
        referenced_works = { 'https://openalex.org/W1000000001', 'https://openalex.org/W1000000002' },
        referenced_works_count = 2,
        authorships = {
            { author = { id = 'https://openalex.org/A5006060960', display_name = 'Heather Piwowar' } },
            { author = { id = 'https://openalex.org/A5006060961', display_name = 'Jason Priem' } },
        },
        primary_location = { source = { id = 'https://openalex.org/S1983995261', display_name = 'PeerJ' } },
    }
    local work_body = vim.json.encode(work_main)
    local uncited_body = vim.json.encode({
        id = 'https://openalex.org/W9999999999',
        title = 'Uncited Work',
        publication_year = 2025,
        cited_by_count = 0,
        referenced_works = {},
        referenced_works_count = 0,
        authorships = {},
    })
    local ref_one = {
        id = 'https://openalex.org/W1000000001',
        title = 'Reference One',
        publication_year = 2010,
        cited_by_count = 10,
        authorships = {},
    }
    local ref_two = {
        id = 'https://openalex.org/W1000000002',
        title = 'Reference Two',
        publication_year = 2012,
        cited_by_count = 20,
        authorships = {},
    }
    -- Deliberately reversed: the module must restore reference order.
    local refs_body = vim.json.encode({ meta = { count = 2 }, results = { ref_two, ref_one } })
    local author_body = vim.json.encode({
        id = 'https://openalex.org/A5006060960',
        display_name = 'Matthew Porter',
        orcid = 'https://orcid.org/0000-0002-0302-4812',
        works_count = 12,
        cited_by_count = 34,
    })
    local author_works_body = vim.json.encode({
        meta = { count = 2, next_cursor = vim.NIL },
        results = {
            {
                id = 'https://openalex.org/W4000000001',
                title = 'Author Work One',
                publication_year = 2024,
                cited_by_count = 7,
                authorships = { { author = { display_name = 'Matthew Porter' } } },
            },
            {
                id = 'https://openalex.org/W4000000002',
                title = 'Author Work Two',
                publication_year = 2023,
                cited_by_count = 3,
                authorships = { { author = { display_name = 'Matthew Porter' } } },
            },
        },
    })
    local cited_by_body = vim.json.encode({
        meta = { count = 1, next_cursor = vim.NIL },
        results = {
            {
                id = 'https://openalex.org/W3000000001',
                title = 'Citing Work',
                publication_year = 2021,
                cited_by_count = 5,
                authorships = {},
            },
        },
    })
    local empty_list_body = vim.json.encode({ meta = { count = 0, next_cursor = vim.NIL }, results = {} })
    local search_page1_body = vim.json.encode({
        meta = { count = 3, next_cursor = 'CURSORPAGE2' },
        results = {
            {
                id = 'https://openalex.org/W2000000001',
                title = 'Search Hit One',
                publication_year = 2020,
                authorships = {},
            },
            {
                id = 'https://openalex.org/W2000000002',
                title = 'Search Hit Two',
                publication_year = 2019,
                authorships = {},
            },
        },
    })
    local search_page2_body = vim.json.encode({
        meta = { count = 3, next_cursor = vim.NIL },
        results = {
            {
                id = 'https://openalex.org/W2000000003',
                title = 'Search Hit Three',
                publication_year = 2018,
                authorships = {},
            },
        },
    })
    local source_fixture = {
        id = 'https://openalex.org/S137773608',
        display_name = 'Fixture Journal of Testing',
        issn_l = '1234-5679',
        issn = { '1234-5679', '1234-5687' },
        type = 'journal',
        works_count = 3200,
        cited_by_count = 9100,
        is_oa = false,
        homepage_url = 'https://example.org/fjt',
        summary_stats = { h_index = 42, ['2yr_mean_citedness'] = 1.85 },
    }
    local source_body = vim.json.encode(source_fixture)
    local sources_body = vim.json.encode({ meta = { count = 1, next_cursor = vim.NIL }, results = { source_fixture } })
    local group_body = vim.json.encode({
        meta = { count = 2 },
        group_by = {
            { key = 'https://openalex.org/S111', key_display_name = 'Fixture Journal A', count = 17 },
            { key = 'https://openalex.org/S222', key_display_name = 'Fixture Journal B', count = 9 },
        },
    })
    local function stub_transport(url)
        if url:find('/works/doi:10.7717/peerj.4375', 1, true) then
            return 200, work_body
        end
        if url:find('/works/doi:10.9999/uncited', 1, true) then
            return 200, uncited_body
        end
        if url:find('/works/W2741809807', 1, true) then
            return 200, work_body
        end
        if url:find('/works/W9999999999', 1, true) then
            return 200, uncited_body
        end
        if url:find('/authors/https://orcid.org/', 1, true) then
            return 200, author_body
        end
        if url:find('filter=cites:W2741809807', 1, true) then
            return 200, cited_by_body
        end
        if url:find('filter=cites:W9999999999', 1, true) then
            return 200, empty_list_body
        end
        if url:find('filter=openalex:', 1, true) then
            return 200, refs_body
        end
        if url:find('authorships.author.id:A5006060960', 1, true) then
            return 200, author_works_body
        end
        if url:find('cursor=CURSORPAGE2', 1, true) then
            return 200, search_page2_body
        end
        if url:find('/works?search=', 1, true) then
            return 200, search_page1_body
        end
        if url:find('/sources/issn:1234-5679', 1, true) then
            return 200, source_body
        end
        if url:find('/sources?search=', 1, true) then
            return 200, sources_body
        end
        if url:find('group_by=primary_location.source.id', 1, true) then
            return 200, group_body
        end
        return 404, '{"error":"not found","message":"no such entity"}'
    end
    openalex.setup({ api_key = 'test-key', transport = stub_transport })
    local record = openalex.lookup('10.7717/peerj.4375')
    check(
        record ~= nil
            and record.title == 'The state of OA: a large-scale analysis'
            and record.id == 'W2741809807'
            and record.doi == '10.7717/peerj.4375',
        'OpenAlex lookup parses title, ID key, and the bare DOI',
        'validation'
    )
    check(
        record.year == 2017 and record.cited_by_count == 452 and record.referenced_count == 2,
        'OpenAlex lookup parses year, cited-by count, and reference count',
        'validation'
    )
    check(
        record.authors[1] == 'Heather Piwowar' and record.source == 'PeerJ' and record.source_id == 'S1983995261',
        'OpenAlex lookup parses authorships and the primary source',
        'validation'
    )
    local by_id = openalex.lookup('W2741809807')
    check(
        by_id ~= nil and by_id.id == 'W2741809807',
        'OpenAlex lookup by work ID uses the singleton route',
        'validation'
    )
    local via_url = openalex.lookup('https://doi.org/10.7717/peerj.4375')
    check(via_url ~= nil and via_url.id == 'W2741809807', 'OpenAlex lookup strips a doi.org prefix', 'validation')
    local search = openalex.search('open access')
    check(
        search ~= nil and search.total == 3 and #search.works == 3 and search.truncated == false,
        'OpenAlex search follows the cursor across pages to the API total',
        'validation'
    )
    check(
        search.works[3].title == 'Search Hit Three',
        'OpenAlex search keeps page order across the cursor boundary',
        'validation'
    )
    local author = openalex.author()
    check(
        author ~= nil
            and author.name == 'Matthew Porter'
            and author.orcid == '0000-0002-0302-4812'
            and author.works_count == 12,
        'OpenAlex author resolves the default ORCID and parses the record',
        'validation'
    )
    local own_works = openalex.author_works()
    check(
        own_works ~= nil and own_works.author.id == 'A5006060960' and #own_works.works == 2 and own_works.total == 2,
        'OpenAlex author_works lists the resolved author works',
        'validation'
    )
    local citing = openalex.cited_by('W2741809807')
    check(
        citing ~= nil and citing.seed_id == 'W2741809807' and #citing.works == 1 and citing.total == 1,
        'OpenAlex cited_by returns the citing works for the seed',
        'validation'
    )
    local no_citers = openalex.cited_by('10.9999/uncited')
    check(
        no_citers ~= nil and #no_citers.works == 0 and no_citers.total == 0,
        'OpenAlex cited_by with zero citers is an empty success, not an error',
        'validation'
    )
    local references = openalex.references('10.7717/peerj.4375')
    check(
        references ~= nil and references.referenced_total == 2 and #references.works == 2,
        'OpenAlex references resolves the referenced works',
        'validation'
    )
    check(
        references.works[1].id == 'W1000000001' and references.works[2].id == 'W1000000002',
        'OpenAlex references restores reference order (the stub returns them reversed)',
        'validation'
    )
    local no_refs = openalex.references('10.9999/uncited')
    check(
        no_refs ~= nil and #no_refs.works == 0 and no_refs.referenced_total == 0 and no_refs.truncated == false,
        'OpenAlex references with an empty reference list is a clean empty result',
        'validation'
    )
    local source = openalex.source('1234-5679')
    check(
        source ~= nil
            and source.name == 'Fixture Journal of Testing'
            and source.issn_l == '1234-5679'
            and source.works_count == 3200,
        'OpenAlex source by ISSN parses name, ISSN-L, and works count',
        'validation'
    )
    check(
        source.h_index == 42 and source.mean_citedness_2yr == 1.85 and source.is_oa == false,
        'OpenAlex source parses summary stats and the OA flag',
        'validation'
    )
    local sources = openalex.search_sources('fixture journal')
    check(
        sources ~= nil and #sources.sources == 1 and sources.sources[1].id == 'S137773608',
        'OpenAlex source search returns parsed sources',
        'validation'
    )
    local ranking = openalex.venue_ranking({ filter = 'type:article' })
    check(
        ranking ~= nil
            and #ranking.venues == 2
            and ranking.venues[1].source_name == 'Fixture Journal A'
            and ranking.venues[1].count == 17
            and ranking.total_groups == 2,
        'OpenAlex venue ranking parses group_by counts',
        'validation'
    )
end

-- ================= OPENALEX (adversarial) =================
do
    -- OpenAlex failure shapes, all through the setup() HTTP seam. The
    -- setup key from the validation block is still in config here, so
    -- key resolution succeeds until the secret-chain cases at the end
    -- deliberately neutralize it.
    openalex.setup({
        transport = function(url)
            if url:find('/works/W7777777777', 1, true) then
                return 200,
                    vim.json.encode({
                        id = 'https://openalex.org/W7777777777',
                        title = 'Null Fields Work',
                        doi = vim.NIL,
                        primary_location = vim.NIL,
                        cited_by_count = vim.NIL,
                        authorships = {},
                    })
            end
            return 404, '{"error":"not found","message":"no such entity"}'
        end,
    })
    local missing, missing_err = openalex.lookup('10.5555/absent')
    check(
        missing == nil and missing_err.code == 'not_found' and missing_err.status == 404,
        'OpenAlex unknown DOI degrades to a structured not_found',
        'adversarial'
    )
    local nulls = openalex.lookup('W7777777777')
    check(
        nulls ~= nil and nulls.doi == nil and nulls.source == nil and nulls.cited_by_count == nil,
        'OpenAlex JSON null fields normalize to nil without crashing',
        'adversarial'
    )
    openalex.setup({
        transport = function()
            return 429, '{"error":"rate limited","message":"Daily budget exceeded"}'
        end,
    })
    local limited, limited_err = openalex.search('anything')
    check(
        limited == nil and limited_err.code == 'rate_limited' and limited_err.status == 429,
        'OpenAlex 429 degrades to rate_limited',
        'adversarial'
    )
    openalex.setup({
        transport = function()
            return 403, '{"error":"forbidden","message":"Invalid API key"}'
        end,
    })
    local forbidden, forbidden_err = openalex.lookup('10.7717/peerj.4375')
    check(
        forbidden == nil and forbidden_err.code == 'auth' and forbidden_err.status == 403,
        'OpenAlex 403 degrades to a structured auth error',
        'adversarial'
    )
    openalex.setup({
        transport = function()
            return 200, 'this is not json'
        end,
    })
    local bad, bad_err = openalex.lookup('10.7717/peerj.4375')
    check(
        bad == nil and bad_err.code == 'invalid_response',
        'OpenAlex malformed JSON degrades to invalid_response',
        'adversarial'
    )
    openalex.setup({
        transport = function()
            return 200, '{"meta":{"count":5}}'
        end,
    })
    local shapeless, shapeless_err = openalex.search('anything')
    check(
        shapeless == nil and shapeless_err.code == 'invalid_response',
        'OpenAlex list response without a results array is invalid_response, never a fabricated empty page',
        'adversarial'
    )
    local empty, empty_err = openalex.lookup('')
    check(
        empty == nil and empty_err.code == 'invalid_argument',
        'OpenAlex lookup rejects a missing argument',
        'adversarial'
    )
    local garbage, garbage_err = openalex.lookup('not-a-doi')
    check(
        garbage == nil and garbage_err.code == 'invalid_argument',
        'OpenAlex lookup rejects a non-DOI argument',
        'adversarial'
    )
    local bad_orcid, bad_orcid_err = openalex.author('1234')
    check(
        bad_orcid == nil and bad_orcid_err.code == 'invalid_argument',
        'OpenAlex author rejects a malformed ORCID before any request',
        'adversarial'
    )
    local zero_limit, zero_limit_err = openalex.search('anything', { limit = 0 })
    check(
        zero_limit == nil and zero_limit_err.code == 'invalid_argument',
        'OpenAlex search rejects a non-positive limit',
        'adversarial'
    )
    local page_calls = 0
    openalex.setup({
        transport = function()
            page_calls = page_calls + 1
            return 200,
                vim.json.encode({
                    meta = { count = 10, next_cursor = vim.NIL },
                    results = {
                        { id = 'https://openalex.org/W2000000001', title = 'Only Page', authorships = {} },
                        { id = 'https://openalex.org/W2000000002', title = 'Only Page Two', authorships = {} },
                    },
                })
        end,
    })
    local one_page = openalex.search('anything')
    check(
        one_page ~= nil and #one_page.works == 2 and page_calls == 1,
        'OpenAlex a null next_cursor stops paging after one request (no loop)',
        'adversarial'
    )
    check(
        one_page.truncated == true and one_page.total == 10,
        'OpenAlex a short page against a larger API total reports truncated with the real total',
        'adversarial'
    )
    openalex.setup({
        transport = function()
            return nil, { code = 'http', message = 'connection refused' }
        end,
    })
    local down, down_err = openalex.lookup('10.7717/peerj.4375')
    check(
        down == nil and down_err.code == 'http' and down_err.message:find('connection refused', 1, true) ~= nil,
        'OpenAlex transport failure propagates as a structured http error',
        'adversarial'
    )
    -- Secret chain: neutralize the environment and the setup key,
    -- then exercise the real tier field. Its content is Matt's, not
    -- the suite's: an unpopulated field (missing or REPLACE_ME) must
    -- degrade before any request, while a populated field must be
    -- used. (The block assumed REPLACE_ME until Matt added a live
    -- OpenAlex key on 2026-10-08; it now probes the tier first. The
    -- bogus-field case below covers degradation unconditionally.)
    local saved_env = vim.fn.getenv('OPENALEX_API_KEY')
    vim.fn.setenv('OPENALEX_API_KEY', '')
    local tier_value = vim.fn.system({ vim.fn.expand('~/.local/bin/research-secret'), 'openalex_api_key' })
    if vim.v.shell_error ~= 0 then
        tier_value = ''
    end
    tier_value = vim.trim(tier_value)
    local transport_calls = 0
    openalex.setup({
        api_key = '',
        secret_field = 'openalex_api_key',
        transport = function()
            transport_calls = transport_calls + 1
            return 200, '{"id": "https://openalex.org/W2741809807"}'
        end,
    })
    local no_key, key_err = openalex.lookup('10.7717/peerj.4375')
    if tier_value == '' or tier_value == 'REPLACE_ME' then
        check(
            no_key == nil and key_err.code == 'secret_unavailable' and transport_calls == 0,
            'OpenAlex unpopulated tier degrades to secret_unavailable before any request',
            'adversarial'
        )
        check(
            key_err.sources_tried[1] == 'env' and key_err.sources_tried[2] == 'tier',
            'OpenAlex secret error names the sources tried',
            'adversarial'
        )
    else
        check(
            no_key ~= nil and transport_calls == 1,
            'OpenAlex populated tier key is used for the request',
            'validation'
        )
    end
    openalex.setup({ secret_field = 'bogus_field_for_tests' })
    local bogus, bogus_err = openalex.lookup('10.7717/peerj.4375')
    check(
        bogus == nil and bogus_err.code == 'secret_unavailable',
        'OpenAlex missing tier field degrades to secret_unavailable',
        'adversarial'
    )
    if saved_env ~= vim.NIL and saved_env ~= '' then
        vim.fn.setenv('OPENALEX_API_KEY', saved_env)
    end
end

-- ================= WATCHLIST (validation) =================
local watchlist = require('research.watchlist')

local function grants_opp(id, title, close_date)
    return {
        opportunity_id = id,
        opportunity_number = 'OPP-' .. id,
        opportunity_title = title,
        opportunity_status = 'posted',
        close_date = close_date,
        post_date = '2026-09-01',
    }
end

local function grants_body(items, total_records)
    return vim.json.encode({
        message = 'Success',
        data = items,
        pagination_info = {
            page_offset = 1,
            page_size = 50,
            total_pages = 1,
            total_records = total_records or #items,
        },
    })
end

local function kaggle_comp(slug, deadline, reward)
    return {
        id = 12345,
        ref = 'https://www.kaggle.com/competitions/' .. slug,
        title = 'Comp ' .. slug,
        deadline = deadline,
        category = 'Featured',
        reward = reward,
        teamCount = 42,
    }
end

local function count_alerts(result, kind)
    local found = 0
    for _, alert in ipairs(result.alerts) do
        if alert.kind == kind then
            found = found + 1
        end
    end
    return found
end

local function find_alert(result, watch_id, kind)
    for _, alert in ipairs(result.alerts) do
        if alert.watch_id == watch_id and alert.kind == kind then
            return alert
        end
    end
    return nil
end

do
    local seeds = watchlist.default_watches()
    check(#seeds == 6, 'Watchlist seeds six default watches', 'validation')
    local aln_watch = nil
    for _, seed in ipairs(seeds) do
        if seed.assistance_listing == '12.420' then
            aln_watch = seed
        end
    end
    check(aln_watch ~= nil and aln_watch.source == 'grants', 'Watchlist seeds the CDMRP 12.420 watch', 'validation')
end

do
    -- Baseline: a first check records snapshots silently; a second
    -- identical check stays silent; changed payloads then alert once.
    local state_path = vim.fn.tempname()
    local grants_payload = grants_body({
        grants_opp('opp-1', 'Alpha Trial', '2027-03-01'),
        grants_opp('opp-2', 'Beta Study', nil),
    })
    local kaggle_payload = vim.json.encode({ kaggle_comp('health-ai', '2027-01-15T00:00:00Z', '10,000 Usd') })
    local seen_bodies = {}
    local seen_urls = {}
    watchlist.setup({
        state_path = state_path,
        grants_api_key = 'test-grants-key',
        kaggle_username = 'test-user',
        kaggle_key = 'test-key',
        transport = function(request)
            if request.method == 'POST' then
                seen_bodies[#seen_bodies + 1] = request.body
                return 200, grants_payload
            end
            seen_urls[#seen_urls + 1] = request.url
            if request.url:match('page=(%d+)') ~= '1' then
                return 200, '[]'
            end
            return 200, kaggle_payload
        end,
    })
    local first = watchlist.check()
    check(first ~= nil and #first.watches == 6, 'Watchlist first check covers all seeded watches', 'validation')
    local all_ok = first ~= nil
    for _, watch_result in ipairs(first.watches) do
        all_ok = all_ok and watch_result.status == 'ok' and watch_result.baseline
    end
    check(all_ok, 'Watchlist first check is an all-baseline run', 'validation')
    check(
        first ~= nil and #first.alerts == 0 and first.saved,
        'Watchlist baseline alerts nothing and saves state',
        'validation'
    )
    local first_body = vim.json.decode(seen_bodies[1])
    check(
        first_body.filters.assistance_listing_number.one_of[1] == '12.420',
        'Watchlist CDMRP request carries the 12.420 assistance listing filter',
        'validation'
    )
    check(
        seen_urls[1]:find('sortBy=recentlyCreated', 1, true) ~= nil,
        'Watchlist Kaggle request sorts by recentlyCreated',
        'validation'
    )
    local loaded = watchlist.load_state()
    local cdmrp_snapshot = nil
    local kaggle_snapshot = nil
    for _, watch in ipairs(loaded.watches) do
        if watch.id == 'cdmrp-12420' then
            cdmrp_snapshot = watch.snapshot
        end
        if watch.id == 'kaggle-recent' then
            kaggle_snapshot = watch.snapshot
        end
    end
    check(
        cdmrp_snapshot ~= nil and #cdmrp_snapshot.items == 2 and cdmrp_snapshot.items[1].closes == '2027-03-01',
        'Watchlist grants items normalize into the snapshot',
        'validation'
    )
    check(
        kaggle_snapshot ~= nil
            and #kaggle_snapshot.items == 1
            and kaggle_snapshot.items[1].id == 'health-ai'
            and kaggle_snapshot.items[1].closes == '2027-01-15'
            and kaggle_snapshot.items[1].reward == '10,000 Usd',
        'Watchlist kaggle items normalize slug, date, and reward',
        'validation'
    )
    local second = watchlist.check()
    check(second ~= nil and #second.alerts == 0, 'Watchlist unchanged diff never re-alerts', 'validation')
    grants_payload = grants_body({
        grants_opp('opp-1', 'Alpha Trial', '2027-04-01'),
        grants_opp('opp-2', 'Beta Study', nil),
        grants_opp('opp-3', 'Gamma Grant', '2027-05-01'),
    })
    kaggle_payload = vim.json.encode({ kaggle_comp('health-ai', '2027-01-15T00:00:00Z', '20,000 Usd') })
    local third = watchlist.check()
    check(third ~= nil and count_alerts(third, 'new') == 4, 'Watchlist new items alert once per watch', 'validation')
    check(
        third ~= nil and count_alerts(third, 'date_changed') == 4,
        'Watchlist moved close dates alert once per watch',
        'validation'
    )
    check(
        third ~= nil and count_alerts(third, 'reward_changed') == 2,
        'Watchlist reward changes alert once per kaggle watch',
        'validation'
    )
    local moved = third ~= nil and find_alert(third, 'cdmrp-12420', 'date_changed') or nil
    check(
        moved ~= nil and moved.previous_closes == '2027-03-01' and moved.closes == '2027-04-01',
        'Watchlist date alert carries the old and new dates',
        'validation'
    )
    local fourth = watchlist.check()
    check(fourth ~= nil and #fourth.alerts == 0, 'Watchlist alerts fire exactly once', 'validation')
    local lines = watchlist.format_check(third)
    check(lines[1]:find('alerts', 1, true) ~= nil, 'Watchlist check formats a summary line', 'validation')
end

do
    -- Closed classification: a vanished grants item on a complete
    -- fetch is closed; a vanished kaggle item counts only once its
    -- deadline has passed (the recent-first listing rotates).
    local state_path = vim.fn.tempname()
    watchlist.setup({
        state_path = state_path,
        grants_api_key = 'test-grants-key',
        kaggle_username = 'test-user',
        kaggle_key = 'test-key',
        transport = function(request)
            if request.method == 'POST' then
                return 200, grants_body({ grants_opp('keep-1', 'Kept Study', '2027-01-01') })
            end
            return 200, '[]'
        end,
    })
    local seeded, seed_err = watchlist.save_state({
        schema_version = 1,
        watches = {
            {
                id = 'g1',
                source = 'grants',
                label = 'G1',
                query = 'trial',
                snapshot = {
                    checked_at = '2026-10-01T00:00:00Z',
                    items = {
                        { id = 'gone-1', title = 'Gone Study', closes = '2027-02-01' },
                        { id = 'keep-1', title = 'Kept Study', closes = '2027-01-01' },
                    },
                },
            },
            {
                id = 'k1',
                source = 'kaggle',
                label = 'K1',
                search = '',
                snapshot = {
                    checked_at = '2026-10-01T00:00:00Z',
                    items = {
                        { id = 'kgone-future', title = 'Future Comp', closes = '2999-01-01' },
                        { id = 'kgone-past', title = 'Past Comp', closes = '2020-01-01' },
                    },
                },
            },
        },
    })
    check(
        seeded == true,
        'Watchlist test state seeds cleanly: ' .. tostring(seed_err and seed_err.message),
        'validation'
    )
    local result = watchlist.check()
    check(
        result ~= nil and find_alert(result, 'g1', 'closed') ~= nil,
        'Watchlist vanished grants item is closed',
        'validation'
    )
    local closed_ids = {}
    for _, alert in ipairs(result.alerts) do
        if alert.kind == 'closed' then
            closed_ids[alert.item_id] = true
        end
    end
    check(
        closed_ids['gone-1'] == true and closed_ids['kgone-past'] == true,
        'Watchlist past-deadline kaggle item is closed',
        'validation'
    )
    check(
        closed_ids['kgone-future'] == nil,
        'Watchlist future-deadline kaggle item is not closed by rotation',
        'validation'
    )
    local shown = watchlist.format_watchlist(watchlist.load_state())
    check(
        shown[2]:find('%[grants%] g1', 1, false) ~= nil or shown[2]:find('g1', 1, true) ~= nil,
        'Watchlist state formats for display',
        'validation'
    )
end

-- ================= WATCHLIST (adversarial) =================
do
    -- Per-source degradation: no credentials anywhere must degrade
    -- every watch to a structured secret_unavailable, never fire the
    -- transport, and never write a state file.
    local saved_grants = vim.fn.getenv('SIMPLE_GRANTS_API_KEY')
    local saved_kuser = vim.fn.getenv('KAGGLE_USERNAME')
    local saved_kkey = vim.fn.getenv('KAGGLE_KEY')
    vim.fn.setenv('SIMPLE_GRANTS_API_KEY', '')
    vim.fn.setenv('KAGGLE_USERNAME', '')
    vim.fn.setenv('KAGGLE_KEY', '')
    local fake_tier_program = vim.fn.tempname()
    vim.fn.writefile({ '#!/bin/sh', 'printf REPLACE_ME' }, fake_tier_program)
    vim.fn.setfperm(fake_tier_program, 'rwx------')
    local state_path = vim.fn.tempname()
    local transport_calls = 0
    watchlist.setup({
        state_path = state_path,
        grants_api_key = '',
        kaggle_username = '',
        kaggle_key = '',
        secret_tier_program = fake_tier_program,
        transport = function()
            transport_calls = transport_calls + 1
            return 200, '{}'
        end,
    })
    local degraded = watchlist.check()
    check(
        degraded ~= nil and #degraded.errors == 6,
        'Watchlist keyless check degrades per watch, not wholesale',
        'adversarial'
    )
    local codes_ok = degraded ~= nil
    local grants_sources = nil
    local kaggle_sources = nil
    for _, watch_result in ipairs(degraded.watches) do
        codes_ok = codes_ok and watch_result.status == 'error' and watch_result.error.code == 'secret_unavailable'
        if watch_result.source == 'grants' and grants_sources == nil then
            grants_sources = watch_result.error.sources_tried
        end
        if watch_result.source == 'kaggle' and kaggle_sources == nil then
            kaggle_sources = watch_result.error.sources_tried
        end
    end
    check(codes_ok, 'Watchlist keyless watches all report secret_unavailable', 'adversarial')
    check(
        grants_sources ~= nil and grants_sources[1] == 'env' and grants_sources[2] == 'tier',
        'Watchlist grants secret error names the sources tried',
        'adversarial'
    )
    check(
        kaggle_sources ~= nil and kaggle_sources[2] == 'file' and kaggle_sources[3] == 'tier',
        'Watchlist kaggle secret error names env, file, and tier',
        'adversarial'
    )
    check(transport_calls == 0, 'Watchlist secret failure fires no request', 'adversarial')
    check(vim.fn.filereadable(state_path) == 0, 'Watchlist failed check writes no state file', 'adversarial')
    -- One source keyed: grants runs, kaggle still degrades.
    watchlist.setup({
        grants_api_key = 'test-grants-key',
        transport = function(request)
            if request.method == 'POST' then
                return 200, grants_body({ grants_opp('opp-9', 'Solo Grant', '2027-06-01') })
            end
            return 200, '[]'
        end,
    })
    local partial = watchlist.check()
    local grants_ok = partial ~= nil
    local kaggle_down = partial ~= nil
    for _, watch_result in ipairs(partial.watches) do
        if watch_result.source == 'grants' then
            grants_ok = grants_ok and watch_result.status == 'ok'
        else
            kaggle_down = kaggle_down
                and watch_result.status == 'error'
                and watch_result.error.code == 'secret_unavailable'
        end
    end
    check(grants_ok and kaggle_down, 'Watchlist one keyed source still runs the other', 'adversarial')
    if saved_grants ~= vim.NIL and saved_grants ~= '' then
        vim.fn.setenv('SIMPLE_GRANTS_API_KEY', saved_grants)
    end
    if saved_kuser ~= vim.NIL and saved_kuser ~= '' then
        vim.fn.setenv('KAGGLE_USERNAME', saved_kuser)
    end
    if saved_kkey ~= vim.NIL and saved_kkey ~= '' then
        vim.fn.setenv('KAGGLE_KEY', saved_kkey)
    end
end

do
    -- Malformed responses and HTTP failures classify structurally,
    -- and a failed fetch never overwrites a good snapshot.
    local state_path = vim.fn.tempname()
    local function setup_with(transport)
        watchlist.setup({
            state_path = state_path,
            grants_api_key = 'test-grants-key',
            kaggle_username = 'test-user',
            kaggle_key = 'test-key',
            transport = transport,
        })
    end
    setup_with(function()
        return 200, '{}'
    end)
    local seeded = watchlist.save_state({
        schema_version = 1,
        watches = {
            {
                id = 'g1',
                source = 'grants',
                label = 'G1',
                query = 'trial',
                snapshot = {
                    checked_at = '2026-10-01T00:00:00Z',
                    items = { { id = 'old-1', title = 'Old Study', closes = '2027-01-01' } },
                },
            },
        },
    })
    check(seeded == true, 'Watchlist adversarial state seeds cleanly', 'adversarial')
    local function only_error()
        local result = watchlist.check()
        if result == nil or #result.watches ~= 1 then
            return nil
        end
        return result.watches[1].error
    end
    setup_with(function()
        return 200, 'this is not json'
    end)
    local bad_json = only_error()
    check(
        bad_json ~= nil and bad_json.code == 'invalid_response',
        'Watchlist non-JSON body is invalid_response',
        'adversarial'
    )
    local preserved = watchlist.load_state()
    check(
        preserved.watches[1].snapshot ~= nil and preserved.watches[1].snapshot.items[1].id == 'old-1',
        'Watchlist failed fetch preserves the previous snapshot',
        'adversarial'
    )
    setup_with(function()
        return 200, '{"data": {"unexpected": 1}, "pagination_info": {"total_records": 1}}'
    end)
    local bad_shape = only_error()
    check(
        bad_shape ~= nil and bad_shape.code == 'invalid_response',
        'Watchlist non-array data is invalid_response',
        'adversarial'
    )
    setup_with(function()
        return 401, '{"message": "Unauthorized"}'
    end)
    local auth_err = only_error()
    check(auth_err ~= nil and auth_err.code == 'auth', 'Watchlist HTTP 401 classifies as auth', 'adversarial')
    setup_with(function()
        return 429, '{"message": "Too Many Requests"}'
    end)
    local rate_err = only_error()
    check(
        rate_err ~= nil and rate_err.code == 'rate_limited',
        'Watchlist HTTP 429 classifies as rate_limited',
        'adversarial'
    )
    setup_with(function()
        return nil, 'connection refused'
    end)
    local http_err = only_error()
    check(http_err ~= nil and http_err.code == 'http', 'Watchlist transport failure classifies as http', 'adversarial')
    setup_with(function()
        return 200,
            '{"data": [{"opportunity_title": "No Id"}, '
                .. '{"opportunity_id": "n1", "opportunity_title": "Null Date", "close_date": null}],'
                .. ' "pagination_info": {"total_records": 2}}'
    end)
    local hygiene = watchlist.check()
    check(
        hygiene ~= nil and hygiene.watches[1].items_found == 1,
        'Watchlist drops items without an identifier',
        'adversarial'
    )
    local reloaded = watchlist.load_state()
    check(
        reloaded.watches[1].snapshot.items[1].closes == nil,
        'Watchlist JSON null close date normalizes to no date',
        'adversarial'
    )
end

do
    -- State file discipline: corrupt, duplicated, firehose, oversized,
    -- and wrong-schema states are structured errors, never crashes.
    local state_path = vim.fn.tempname()
    watchlist.setup({
        state_path = state_path,
        grants_api_key = 'test-grants-key',
        kaggle_username = 'test-user',
        kaggle_key = 'test-key',
        transport = function()
            return 200, '{}'
        end,
    })
    local function expect_invalid(contents, label)
        vim.fn.writefile({ contents }, state_path)
        local state, err = watchlist.load_state()
        check(state == nil and err ~= nil and err.code == 'invalid_state', label, 'adversarial')
    end
    expect_invalid('{not json', 'Watchlist corrupt state file is invalid_state')
    expect_invalid('{"schema_version": 2, "watches": []}', 'Watchlist wrong schema version is invalid_state')
    expect_invalid(
        '{"schema_version": 1, "watches": ['
            .. '{"id": "g1", "source": "grants", "query": "x"},'
            .. ' {"id": "g1", "source": "grants", "query": "y"}]}',
        'Watchlist duplicate watch ids are invalid_state'
    )
    expect_invalid(
        '{"schema_version": 1, "watches": [{"id": "g1", "source": "grants"}]}',
        'Watchlist unfiltered grants watch is invalid_state'
    )
    vim.fn.writefile({ string.rep('x', 600000) }, state_path)
    local big_state, big_err = watchlist.load_state()
    check(
        big_state == nil and big_err ~= nil and big_err.code == 'invalid_state',
        'Watchlist oversized state is invalid_state',
        'adversarial'
    )
    vim.fn.delete(state_path)
    local blocked, blocked_err = watchlist.check()
    check(blocked ~= nil and blocked_err == nil, 'Watchlist missing state file is a clean first run', 'validation')
end

do
    -- Truncation honesty: a capped fetch reports truncated, keeps the
    -- total visible, and suppresses closed classification; the
    -- per-check request budget is a hard bound.
    local state_path = vim.fn.tempname()
    local transport_calls = 0
    watchlist.setup({
        state_path = state_path,
        grants_api_key = 'test-grants-key',
        kaggle_username = 'test-user',
        kaggle_key = 'test-key',
        transport = function(request)
            transport_calls = transport_calls + 1
            if request.method == 'GET' then
                return 200, '[]'
            end
            local body = vim.json.decode(request.body)
            local page = body.pagination.page_offset
            local items = {}
            for index = 1, 50 do
                items[#items + 1] =
                    grants_opp('p' .. page .. '-' .. index, 'Paged ' .. page .. '-' .. index, '2027-01-01')
            end
            return 200, grants_body(items, 5000)
        end,
    })
    watchlist.save_state({
        schema_version = 1,
        watches = {
            {
                id = 'g1',
                source = 'grants',
                label = 'G1',
                query = 'trial',
                snapshot = {
                    checked_at = '2026-10-01T00:00:00Z',
                    items = { { id = 'vanished-1', title = 'Vanished Study', closes = '2027-02-01' } },
                },
            },
        },
    })
    local capped = watchlist.check()
    local g1 = capped ~= nil and capped.watches[1] or nil
    check(
        g1 ~= nil and g1.truncated == true and g1.total == 5000,
        'Watchlist capped fetch reports truncated with its total',
        'validation'
    )
    check(g1 ~= nil and g1.items_found == 200, 'Watchlist snapshot stops at the per-watch item cap', 'validation')
    check(
        capped ~= nil and find_alert(capped, 'g1', 'closed') == nil,
        'Watchlist truncated fetch suppresses closed classification',
        'adversarial'
    )
    -- Budget: sixteen always-full watches cannot exceed the cap.
    local budget_path = vim.fn.tempname()
    local budget_calls = 0
    watchlist.setup({
        state_path = budget_path,
        grants_api_key = 'test-grants-key',
        transport = function(request)
            budget_calls = budget_calls + 1
            local body = vim.json.decode(request.body)
            local page = body.pagination.page_offset
            local items = {}
            for index = 1, 50 do
                items[#items + 1] =
                    grants_opp('b' .. page .. '-' .. index, 'Budget ' .. page .. '-' .. index, '2027-01-01')
            end
            return 200, grants_body(items, 5000)
        end,
    })
    local many = { schema_version = 1, watches = {} }
    for index = 1, 16 do
        many.watches[#many.watches + 1] = {
            id = 'w' .. index,
            source = 'grants',
            label = 'W' .. index,
            query = 'trial',
        }
    end
    watchlist.save_state(many)
    local budgeted = watchlist.check()
    local budget_hit = false
    for _, watch_result in ipairs(budgeted.watches) do
        if watch_result.error ~= nil and watch_result.error.code == 'request_budget' then
            budget_hit = true
        end
    end
    check(budget_calls <= 40 and budget_hit, 'Watchlist per-check request budget is a hard bound', 'adversarial')
end

print(
    ('journal workflow: %d/%d checks passed (validation %d/%d, adversarial %d/%d)'):format(
        passed,
        total,
        validation_passed,
        validation_total,
        adversarial_passed,
        adversarial_total
    )
)
assert(passed == total, 'some checks failed')
