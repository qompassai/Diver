-- Tests for the research Zotero live-library integration: candidate
-- matching against a library index, Zotero item and BibTeX record
-- construction, and filing through a stubbed transport.
-- Run from the config root:
--   nvim --headless -u NONE -i NONE -l tests/research/research_zotero_api.lua
-- Real vim APIs are used (the runner is headless Neovim). The Zotero
-- transport is stubbed in every case: the network and the real
-- library are never touched.
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

local discover = require('research.discover')
local zotero_api = require('research.zotero_api')

---One fixed candidate used across cases.
local function sample_candidate()
    return {
        abs_url = 'https://arxiv.org/abs/2401.12345',
        authors = { 'Ashish Vaswani', 'Noam Shazeer' },
        doi = nil,
        id = '2401.12345v2',
        pdf_url = 'https://arxiv.org/pdf/2401.12345',
        published = '2024-01-15',
        summary = 'An abstract.',
        title = 'Attention Is All You Need!',
    }
end

---Install a stub transport driven by handler(method, path, body).
---@param handler fun(method: string, path: string, body: table?): integer?, table|string?, string?
local function stub(handler)
    zotero_api._set_transport(function(method, path, body, on_done)
        local status, payload, err = handler(method, path, body)
        on_done(status, payload, err)
    end)
end

---A stub item page: handler for GET item lists.
---@param pages table<integer, table[]> start offset -> items
local function page_handler(pages)
    return function(method, path, _)
        if method == 'GET' then
            local start = tonumber(path:match('start=(%d+)')) or 0
            return 200, pages[start] or {}, nil
        end
        return 405, nil, 'unexpected method ' .. method
    end
end

-- ------------------------------------------------------------------
-- Validation
-- ------------------------------------------------------------------

check(
    zotero_api.normalize_title('  Attention   Is  All You Need! ') == 'attention is all you need',
    'normalize_title collapses case, punctuation, whitespace',
    'validation'
)
check(zotero_api.base_arxiv_id('2401.12345v2') == '2401.12345', 'base_arxiv_id strips version', 'validation')
check(
    zotero_api.base_arxiv_id('hep-th/9901001') == 'hep-th/9901001',
    'base_arxiv_id leaves old-style ids alone',
    'validation'
)

do
    local item, err = zotero_api.build_item(sample_candidate())
    check(err == nil and item ~= nil, 'build_item accepts a well-formed candidate', 'validation')
    check(item.itemType == 'preprint' and item.repository == 'arXiv', 'build_item files a preprint', 'validation')
    check(item.archiveID == '2401.12345', 'build_item stores the base arXiv id', 'validation')
    check(
        item.creators[1].firstName == 'Ashish' and item.creators[1].lastName == 'Vaswani',
        'build_item splits creator names',
        'validation'
    )
    check(
        item.date == '2024-01-15' and item.extra == 'arXiv: 2401.12345',
        'build_item sets date and extra',
        'validation'
    )
end

do
    local bib = zotero_api.bibtex_for(sample_candidate())
    check(bib:find('@misc{vaswani2024attention,', 1, true) ~= nil, 'bibtex_for derives the citekey', 'validation')
    check(bib:find('eprint = {2401.12345}', 1, true) ~= nil, 'bibtex_for carries the eprint', 'validation')
    check(
        bib:find('author = {Ashish Vaswani and Noam Shazeer}', 1, true) ~= nil,
        'bibtex_for joins authors',
        'validation'
    )
end

do
    local index = zotero_api.index_from_items({
        { key = 'KEYA', data = { archiveID = '2401.12345', itemType = 'preprint', title = 'Some Other Title' } },
        { key = 'KEYB', data = { DOI = '10.1000/XYZ', itemType = 'journalArticle', title = 'Journal Paper' } },
        { key = 'KEYC', data = { extra = 'arXiv: 2312.99999', itemType = 'preprint', title = 'Extra Id Paper' } },
        {
            key = 'KEYD',
            data = { itemType = 'preprint', title = 'Attention is all you need', url = 'https://example.org/x' },
        },
    })
    check(index.arxiv['2401.12345'] == 'KEYA', 'index_from_items indexes archiveID', 'validation')
    check(index.arxiv['2312.99999'] == 'KEYC', 'index_from_items indexes the extra arXiv line', 'validation')
    check(index.doi['10.1000/xyz'] == 'KEYB', 'index_from_items lowercases DOIs', 'validation')
    check(
        index.title['attention is all you need'] == 'KEYD',
        'index_from_items indexes normalized titles',
        'validation'
    )
    local candidate = sample_candidate()
    check(zotero_api.match_candidate(candidate, index) == 'KEYA', 'match_candidate hits on arXiv id', 'validation')
    candidate.id = '2401.12345v9'
    check(zotero_api.match_candidate(candidate, index) == 'KEYA', 'match_candidate ignores version drift', 'validation')
    candidate.id = '9999.00000'
    candidate.doi = '10.1000/xyz'
    check(zotero_api.match_candidate(candidate, index) == 'KEYB', 'match_candidate falls back to DOI', 'validation')
    candidate.doi = nil
    check(zotero_api.match_candidate(candidate, index) == 'KEYD', 'match_candidate falls back to title', 'validation')
end

do
    local page_one = {}
    for i = 1, 100 do
        page_one[i] = { key = 'P1_' .. i, data = { itemType = 'preprint', title = 'Paper ' .. i } }
    end
    stub(page_handler({
        [0] = page_one,
        [100] = { { key = 'P2_1', data = { archiveID = '2501.00001', itemType = 'preprint', title = 'Last' } } },
    }))
    local got_index, got_count = nil, nil
    zotero_api.fetch_index(function(index, count_or_err)
        got_index, got_count = index, count_or_err
    end)
    check(got_count == 101, 'fetch_index walks pages until a short page', 'validation')
    check(got_index ~= nil and got_index.arxiv['2501.00001'] == 'P2_1', 'fetch_index indexes later pages', 'validation')
end

do
    stub(page_handler({
        [0] = { { key = 'HELD1', data = { archiveID = '2401.12345', itemType = 'preprint', title = 'Held' } } },
    }))
    local candidates = {
        sample_candidate(),
        { authors = {}, id = '1111.11111', published = '2024-01-01', summary = '', title = 'Not Held' },
    }
    local marked, mark_err = nil, nil
    zotero_api.mark_candidates(candidates, function(results, err)
        marked, mark_err = results, err
    end)
    check(mark_err == nil and marked == candidates, 'mark_candidates returns the candidates', 'validation')
    check(
        candidates[1].in_library == true and candidates[1].zotero_key == 'HELD1',
        'mark_candidates marks the held paper',
        'validation'
    )
    check(candidates[2].in_library == false, 'mark_candidates leaves new papers unmarked', 'validation')
end

do
    local posts = {}
    stub(function(method, path, body)
        if method == 'GET' then
            return 200, {}, nil
        end
        posts[#posts + 1] = { body = body, method = method, path = path }
        if body[1].itemType == 'note' then
            return 201, { successful = { ['0'] = { key = 'NOTEKEY1' } } }, nil
        end
        return 201, { successful = { ['0'] = { key = 'ITEMKEY1' } } }, nil
    end)
    local filed, file_err = nil, nil
    zotero_api.file_candidate(sample_candidate(), function(result, err)
        filed, file_err = result, err
    end)
    check(file_err == nil and filed ~= nil and filed.filed == true, 'file_candidate files a new paper', 'validation')
    check(filed ~= nil and filed.key == 'ITEMKEY1', 'file_candidate returns the new item key', 'validation')
    check(#posts == 2, 'file_candidate posts the item then the note', 'validation')
    check(posts[2].body[1].parentItem == 'ITEMKEY1', 'file_candidate parents the note to the item', 'validation')
    check(
        posts[2].body[1].note:find('@misc{vaswani2024attention,', 1, true) ~= nil,
        'file_candidate attaches the BibTeX record as the note',
        'validation'
    )
end

do
    local feed = table.concat({
        '<feed xmlns="http://www.w3.org/2005/Atom" xmlns:arxiv="http://arxiv.org/schemas/atom">',
        '<entry>',
        '<id>http://arxiv.org/abs/2401.12345v2</id>',
        '<title>Some Paper Title</title>',
        '<published>2024-01-15T00:00:00Z</published>',
        '<summary>Abstract text.</summary>',
        '<author><name>Ashish Vaswani</name></author>',
        '<arxiv:doi>10.1000/182</arxiv:doi>',
        '</entry>',
        '<entry>',
        '<id>http://arxiv.org/abs/2401.99999v1</id>',
        '<title>Undated DOI-less Paper</title>',
        '<published>2024-02-01T00:00:00Z</published>',
        '<summary>Other text.</summary>',
        '<author><name>Jane Doe</name></author>',
        '</entry>',
        '</feed>',
    }, '\n')
    local results = discover.parse_feed(feed)
    check(#results == 2 and results[1].doi == '10.1000/182', 'parse_feed captures the arXiv DOI', 'validation')
    check(results[2].doi == nil, 'parse_feed leaves a missing DOI nil', 'validation')
end

-- ------------------------------------------------------------------
-- Adversarial
-- ------------------------------------------------------------------

do
    local posts = 0
    stub(function(method, _, _)
        if method == 'GET' then
            return 200,
                {
                    { key = 'HELD1', data = { archiveID = '2401.12345', itemType = 'preprint', title = 'Held' } },
                },
                nil
        end
        posts = posts + 1
        return 201, { successful = { ['0'] = { key = 'DUP' } } }, nil
    end)
    local filed, file_err = nil, nil
    zotero_api.file_candidate(sample_candidate(), function(result, err)
        filed, file_err = result, err
    end)
    check(
        file_err == nil and filed ~= nil and filed.filed == false and filed.key == 'HELD1',
        'file_candidate reports an already-filed paper instead of duplicating it',
        'adversarial'
    )
    check(posts == 0, 'file_candidate issues no write for a duplicate', 'adversarial')
end

do
    local calls = 0
    stub(function(_, _, _)
        calls = calls + 1
        return nil, nil, 'Zotero unreachable: connection refused'
    end)
    local filed, file_err = nil, nil
    zotero_api.file_candidate(sample_candidate(), function(result, err)
        filed, file_err = result, err
    end)
    check(filed == nil and file_err ~= nil, 'file_candidate degrades when the library is down', 'adversarial')
    local candidates = { sample_candidate() }
    local marked, mark_err = nil, nil
    zotero_api.mark_candidates(candidates, function(results, err)
        marked, mark_err = results, err
    end)
    check(marked == nil and mark_err ~= nil, 'mark_candidates degrades when the library is down', 'adversarial')
    check(candidates[1].in_library == nil, 'mark_candidates leaves candidates untouched on failure', 'adversarial')
end

do
    local calls = 0
    stub(function(_, _, _)
        calls = calls + 1
        return 200, {}, nil
    end)
    local filed, file_err = nil, 'unset'
    zotero_api.file_candidate({ id = '2401.12345' }, function(result, err)
        filed, file_err = result, err
    end)
    check(filed == nil and file_err ~= nil, 'file_candidate rejects a candidate without a title', 'adversarial')
    zotero_api.file_candidate({ authors = 'not-a-table', id = '2401.12345', title = 'Titled' }, function(result, err)
        filed, file_err = result, err
    end)
    check(filed == nil and file_err ~= nil, 'file_candidate rejects malformed authors', 'adversarial')
    check(calls == 0, 'file_candidate validates before any transport call', 'adversarial')
end

do
    local item = zotero_api.build_item({
        authors = { 'Plato' },
        id = '2401.00001',
        published = '2024-03-01',
        summary = '',
        title = 'Single Name Author',
    })
    check(
        item.creators[1].lastName == 'Plato' and item.creators[1].firstName == nil,
        'build_item keeps single-name authors as last name only',
        'adversarial'
    )
    local bib = zotero_api.bibtex_for({
        authors = { 'Jane Doe' },
        id = '2401.00001',
        published = '2024-03-01',
        title = 'On {Special} Tokens',
    })
    check(
        bib:find('title = {On Special Tokens}', 1, true) ~= nil,
        'bibtex_for strips braces from field values',
        'adversarial'
    )
end

do
    stub(function(method, _, body)
        if method == 'GET' then
            return 200, {}, nil
        end
        if body[1].itemType == 'note' then
            return 500, 'server error', nil
        end
        return 201, { successful = { ['0'] = { key = 'ITEMKEY9' } } }, nil
    end)
    local filed, file_err = nil, nil
    zotero_api.file_candidate(sample_candidate(), function(result, err)
        filed, file_err = result, err
    end)
    check(
        file_err == nil and filed ~= nil and filed.filed == true and filed.note_error ~= nil,
        'file_candidate reports a failed BibTeX note honestly instead of hiding it',
        'adversarial'
    )
end

do
    stub(function(_, _, _)
        return 401, 'Invalid or expired API key', nil
    end)
    local got_index, got_err = 'unset', nil
    zotero_api.fetch_index(function(index, count_or_err)
        got_index, got_err = index, count_or_err
    end)
    check(
        got_index == nil and tostring(got_err):find('401', 1, true) ~= nil,
        'fetch_index surfaces an HTTP 401 with its status',
        'adversarial'
    )
end

do
    local index = zotero_api.index_from_items({
        { key = 'ATT1', data = { archiveID = '2401.12345', itemType = 'attachment', title = 'Attachment' } },
        { key = 'NOTE1', data = { itemType = 'note', title = 'Attention Is All You Need!' } },
        { key = 'NODATA' },
        { data = { archiveID = '2401.12345', itemType = 'preprint', title = 'No Key' } },
        'not-even-a-table',
    })
    check(index.arxiv['2401.12345'] == nil, 'index_from_items never indexes attachments', 'adversarial')
    check(
        index.title['attention is all you need'] == nil,
        'index_from_items never indexes notes or keyless items',
        'adversarial'
    )
    check(
        zotero_api.match_candidate({ id = '0000.00000', title = 'Unrelated Title' }, index) == nil,
        'match_candidate returns nil against an empty effective index',
        'adversarial'
    )
end

do
    local index = zotero_api.index_from_items({
        { key = 'VER9', data = { archiveID = '2401.12345v9', itemType = 'preprint', title = 'Versioned' } },
    })
    check(
        zotero_api.match_candidate({ id = '2401.12345v1', title = 'Anything' }, index) == 'VER9',
        'match_candidate matches across version numbers on both sides',
        'adversarial'
    )
end

do
    stub(page_handler({ [0] = {} }))
    local marked, mark_err = 'unset', 'unset'
    zotero_api.mark_candidates({}, function(results, err)
        marked, mark_err = results, err
    end)
    check(
        mark_err == nil and type(marked) == 'table' and #marked == 0,
        'mark_candidates accepts an empty candidate list',
        'adversarial'
    )
end

do
    local title_only = zotero_api.index_from_items({
        { key = 'TIT1', data = { itemType = 'journalArticle', title = 'Attention Is All You Need!' } },
    })
    check(
        zotero_api.match_candidate(sample_candidate(), title_only) == 'TIT1',
        'match_candidate trusts the title when the library copy has no arXiv id',
        'adversarial'
    )
    local posts = 0
    stub(function(method, _, _)
        if method == 'GET' then
            return 200,
                {
                    { key = 'TIT1', data = { itemType = 'journalArticle', title = 'Attention Is All You Need!' } },
                },
                nil
        end
        posts = posts + 1
        return 201, { successful = { ['0'] = { key = 'DUP' } } }, nil
    end)
    local filed = nil
    zotero_api.file_candidate(sample_candidate(), function(result, _)
        filed = result
    end)
    check(
        filed ~= nil and filed.filed == false and posts == 0,
        'file_candidate treats a title-only match as a duplicate',
        'adversarial'
    )
end

do
    stub(function(method, _, _)
        if method == 'GET' then
            return 200, {}, nil
        end
        return 200, { failed = { ['0'] = 'rejected' } }, nil
    end)
    local filed, file_err = 'unset', nil
    zotero_api.file_candidate(sample_candidate(), function(result, err)
        filed, file_err = result, err
    end)
    check(filed == nil and file_err ~= nil, 'file_candidate fails loudly when the create returns no key', 'adversarial')
end

do
    stub(function(_, _, _)
        return 200, 'this is not a json array', nil
    end)
    local got_index, got_err = 'unset', nil
    zotero_api.fetch_index(function(index, count_or_err)
        got_index, got_err = index, count_or_err
    end)
    check(got_index == nil and got_err ~= nil, 'fetch_index rejects a non-table page body', 'adversarial')
end

do
    local _, empty_err = zotero_api.build_item({ id = '2401.12345', title = '' })
    check(empty_err ~= nil, 'build_item rejects an empty title', 'adversarial')
    local _, type_err = zotero_api.build_item('not-a-table')
    check(type_err ~= nil, 'build_item rejects a non-table candidate', 'adversarial')
    check(zotero_api.normalize_title('!!!') == '', 'normalize_title survives a punctuation-only title', 'adversarial')
    check(
        zotero_api.bibtex_key({}) == 'unknownndpaper',
        'bibtex_key falls back to a stable key for empty candidates',
        'adversarial'
    )
end

zotero_api._set_transport(nil)

print(
    ('zotero api: %d/%d checks passed (validation %d/%d, adversarial %d/%d)'):format(
        passed,
        total,
        validation_passed,
        validation_total,
        adversarial_passed,
        adversarial_total
    )
)
assert(passed == total, 'some checks failed')
