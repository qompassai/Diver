-- /qompassai/Diver/lua/research/journal.lua
-- Qompass AI Diver Journal Profile Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- The journals Matt reviews for or submits to. Every entry carries a
-- `relationship`: 'reviewer' means he reviews there, 'author' means his
-- ORCID record shows a publication there. Portals are reviewer/author
-- login pages he supplied himself; nothing here automates a login.
--
-- Profile schema (fields beyond name/portal/relationship are optional;
-- a missing field means "not recorded", never "not required"):
--   instructions_url  string  the journal's Instructions for Authors page
--   login_route       table   how Matt signs in to the platform:
--                             { route, source, system, system_url,
--                               note }. 'route' is his stated workflow
--                             (with its source); the system facts are
--                             recorded separately and verified against
--                             the journal's pages. Nothing here
--                             automates a login.
--   platform          string  submission platform id, e.g.
--                             'editorialmanager'. Editorial Manager has
--                             no author/reviewer API: the local workflow
--                             prepares everything and the final upload
--                             stays a manual web step by Matt.
--   requirements      table   structured requirements (see below)
--   requirements_source string  provenance: 'verified ...' with a date,
--                             or 'not recorded' for thin profiles.
--
-- requirements table shape:
--   abstract      { headings = string[], max_words = integer|nil,
--                   variants = string[] }
--   article_types table keyed by snake_case article-type key; each entry:
--                   { abstract_max_words = integer|nil,
--                     abstract_required = boolean,
--                     combined_items_max = integer|nil,
--                     label = string,
--                     manuscript_word_limit = { comparator = '<'|'<=',
--                       value = integer,
--                       qualitative_value = integer|nil,
--                       qualitative_comparator = '<'|'<='|nil },
--                     max_authors = integer|nil,
--                     max_references = integer|nil,
--                     notes = string[],
--                     structured_abstract = boolean,
--                     structured_manuscript = boolean }
--   authorship    table   criteria / equal-contribution rules
--   checklist     string[] submission-checklist labels for the journal
--   cover_letter  { elements = string[], required = boolean }
--   figures       table   file/legend/resolution rules (+ flagged notes)
--   formatting    table   file format, spacing, page numbering rules
--   references    table   citation style rules
--   statements    table keyed by statement kind; each entry is
--                   { status = 'required'|'required_conditional'|
--                              'not_stated_by_journal',
--                     location = string|nil, note = string|nil }.
--                   'not_stated_by_journal' is an explicit finding: the
--                   journal's own documents do not state it, so the
--                   preflight checker reports it as not required by the
--                   journal instead of as a missing statement.
--   supplemental  table   supplemental-material rules
--   tables        table   table/box placement rules
--   title_page    string[] title-page fields, in the journal's order
local api = vim.api
local fn = vim.fn
local M = {}

---Normalize an article-type label or key to its snake_case profile key.
---@param label string
---@return string
local function article_type_key(label)
    local key = label:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    local aliases = {
        educational_innovation = 'educational_innovation',
        letter = 'letter_to_the_editor',
        letter_to_the_editor = 'letter_to_the_editor',
        letters = 'letter_to_the_editor',
        original_research = 'original_research',
    }
    return aliases[key] or key
end

---Escape a string for JSON output.
---@param text string
---@return string
local function json_escape(text)
    local escaped = text:gsub('[%z\1-\31\\"]', function(char)
        local replacements = {
            ['"'] = '\\"',
            ['\\'] = '\\\\',
            ['\n'] = '\\n',
            ['\r'] = '\\r',
            ['\t'] = '\\t',
        }
        return replacements[char] or ('\\u%04x'):format(char:byte())
    end)
    return escaped
end

---Serialize a plain-data value to JSON with sorted object keys, so the
---output is deterministic byte-for-byte for the same registry content.
---Arrays keep their order. Functions/userdata raise an error (caught by
---M.export_json and reported), because the registry must stay pure data.
---@param value any
---@return string
local function json_encode_sorted(value)
    local kind = type(value)
    if kind == 'string' then
        return '"' .. json_escape(value) .. '"'
    elseif kind == 'number' then
        if value % 1 == 0 then
            return ('%d'):format(value)
        end
        return ('%.14g'):format(value)
    elseif kind == 'boolean' then
        return tostring(value)
    elseif kind == 'table' then
        local count = #value
        local is_array = count > 0
        if is_array then
            local parts = {}
            for index = 1, count do
                parts[index] = json_encode_sorted(value[index])
            end
            return '[' .. table.concat(parts, ',') .. ']'
        end
        local keys = {}
        for key in pairs(value) do
            assert(type(key) == 'string', 'JSON object keys must be strings')
            keys[#keys + 1] = key
        end
        table.sort(keys)
        local parts = {}
        for _, key in ipairs(keys) do
            parts[#parts + 1] = '"' .. json_escape(key) .. '":' .. json_encode_sorted(value[key])
        end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    error('value of type ' .. kind .. ' is not JSON-serializable')
end

M.profiles = {
    -- Reviewer venues (named by Matt).
    jgme = {
        article_types = {
            'Original Research',
            'Perspectives',
            'Educational Innovation',
            'Brief Report',
            'Review',
            'Letter to the Editor',
            'On Teaching',
            'New Ideas',
        },
        instructions_url = 'https://jgme.kglmeridian.com/page/Instructions-for-Authors',
        name = 'Journal of Graduate Medical Education',
        platform = 'editorialmanager',
        portal = 'https://www.editorialmanager.com/jgme/default.aspx',
        relationship = 'reviewer',
        -- Facts encoded from the JGME Instructions for Authors and the
        -- Manuscript Submission Checklist, accessed 2026-10-08. Word
        -- counts exclude title page, headings, acknowledgments,
        -- figures/tables/boxes, abstract, references, and supplemental
        -- material; abstract counts include their headings.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Objective',
                    'Methods',
                    'Results',
                    'Conclusions',
                },
                variants = {
                    'Quality improvement reports use a QI variant of the '
                        .. 'structured abstract (SQUIRE-EDU framing).',
                },
                word_count_includes_headings = true,
            },
            article_types = {
                brief_report = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    combined_items_max = 2,
                    label = 'Brief Report',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                educational_innovation = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Educational Innovation',
                    manuscript_word_limit = { comparator = '<', value = 2000 },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                letter_to_the_editor = {
                    abstract_max_words = nil,
                    abstract_required = false,
                    combined_items_max = 2,
                    label = 'Letter to the Editor',
                    manuscript_word_limit = { comparator = '<=', value = 500 },
                    max_authors = 3,
                    max_references = 5,
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                new_ideas = {
                    abstract_max_words = nil,
                    abstract_required = false,
                    combined_items_max = nil,
                    label = 'New Ideas',
                    manuscript_word_limit = { comparator = '<=', value = 600 },
                    notes = {
                        'Annual category: call issued in summer, deadline in fall.',
                        'Required format: setting/problem, then intervention, ' .. 'then outcomes to date.',
                    },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                on_teaching = {
                    abstract_max_words = nil,
                    abstract_required = false,
                    combined_items_max = nil,
                    combined_items_note = 'Figures/tables/boxes listed as N/A '
                        .. 'in the journal table for this category.',
                    label = 'On Teaching',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                original_research = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Original Research',
                    manuscript_word_limit = {
                        comparator = '<',
                        qualitative_comparator = '<',
                        qualitative_value = 3500,
                        value = 2500,
                    },
                    notes = {
                        'The higher qualitative allowance applies only to '
                            .. 'rigorous qualitative methods; studies of '
                            .. 'open-ended responses are not classed as '
                            .. 'qualitative.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                perspectives = {
                    abstract_max_words = nil,
                    abstract_required = false,
                    combined_items_max = 2,
                    combined_items_note = 'Usually no more than 2 combined.',
                    label = 'Perspectives',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                review = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Review',
                    manuscript_word_limit = { comparator = '<', value = 3000 },
                    notes = {
                        'Structured abstract and manuscript required for all '
                            .. 'review types; the review type is stated in the '
                            .. 'abstract and in the article Methods.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
            },
            authorship = {
                co_first_max = 2,
                co_last_max = 2,
                criteria = 'ICMJE 4 criteria',
                equal_contribution_marker = 'asterisk',
            },
            checklist = {
                'Title page: degrees, affiliations, roles',
                'Corresponding author contact block',
                'Word counts on title page',
                'Double-spaced, numbered pages',
                'References consecutive in text and graphics',
                'Legends with superscript-letter footnotes',
                'All tables, figures, boxes, supplement cited in text',
                'Abbreviations list if used',
                'Structured abstract and manuscript (research categories)',
                'Study year in Methods (abstract and manuscript)',
                'Response rate (eligible, actual, percent) in Results',
                'IRB statement at end of Methods',
                'Limitations in Discussion',
                'Survey/assessment instrument as supplement',
                'Figure files separate, at resolution',
            },
            cover_letter = {
                elements = {
                    'Brief introduction to the manuscript',
                    'Request and reasons when exceeding a word limit',
                    'Attestation: not previously published and not under ' .. 'consideration elsewhere',
                },
                required = true,
            },
            fees = {
                publication_fee = false,
                submission_fee = false,
            },
            figures = {
                cited_consecutively = true,
                discrepancy_note = 'FLAGGED DISCREPANCY: the Instructions '
                    .. 'for Authors state figure resolution of 300 dpi or '
                    .. 'higher; the Manuscript Submission Checklist PDF '
                    .. 'states a minimum of 200 dpi and its figure-file '
                    .. 'examples are grayscale office formats. The profile '
                    .. 'encodes 300 dpi; preflight warns below 300 and '
                    .. 'notes the checklist figure of 200.',
                files = 'separate individual files',
                formats = {
                    'Word',
                    'PDF',
                    'Excel',
                    'PowerPoint',
                    'JPG',
                    'TIFF',
                    'GIF',
                },
                legend_max_words = 200,
                min_resolution_dpi = 300,
            },
            formatting = {
                double_spaced = true,
                file_format = 'Microsoft Word',
                line_numbers = false,
                page_numbers = true,
                text_alignment = 'left',
            },
            manuscript_sections = {
                'Introduction',
                'Methods',
                'Results',
                'Discussion',
                'Conclusions',
            },
            references = {
                author_list_max = 6,
                et_al_after = 6,
                journal_abbreviations = 'MEDLINE',
                order = 'citation order',
                style = 'AMA',
                text_marker = 'superscript',
            },
            scope = {
                audience = 'Graduate medical education (residents and fellows)',
                minimum_specialties_interested = 2,
            },
            statements = {
                ai_disclosure = {
                    location = 'Research categories: detailed disclosure in '
                        .. 'Methods (tool, model, version, company, dates, '
                        .. 'prompts, processing, verification). Perspectives, '
                        .. 'Letters, and On Teaching: Disclosure section of '
                        .. 'the title page.',
                    note = 'Required whenever AI tools were used in ' .. 'preparing the work; AI cannot be an author.',
                    status = 'required',
                },
                blinding = {
                    note = 'Not stated by JGME in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'No standalone author-contributions statement '
                        .. 'format is stated by JGME; authorship follows '
                        .. 'the ICMJE criteria.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = 'No standalone COI statement format is stated by '
                        .. 'JGME; the journal links the ICMJE conflict of '
                        .. 'interest form.',
                    status = 'not_stated_by_journal',
                },
                funding = {
                    note = 'No standalone funding statement format is stated ' .. 'by JGME in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                irb_ethics = {
                    condition = 'human-subjects work',
                    location = 'end of Methods',
                    note = 'Names the approving or exempting body, the '
                        .. 'approval or exemption, and consent where '
                        .. 'relevant.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated by JGME in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated by JGME in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
            },
            supplemental = {
                cited_in_text = true,
                instruments_as_supplement = true,
                listing = 'All supplemental items listed consecutively at ' .. 'the end of the manuscript.',
            },
            tables = {
                boxes_placement = 'after References',
                placement = 'end of the manuscript text file',
            },
            title_page = {
                'Title',
                'Authors with degrees and affiliations/roles',
                'Prior or related publications, if any',
                'Prior presentations, if any',
                'Acknowledgments',
                'Disclaimer',
                'Corresponding author business address, phone, fax, email',
                'Word counts (abstract and manuscript)',
            },
        },
        requirements_source = 'Verified from the JGME Instructions for '
            .. 'Authors and Manuscript Submission Checklist, accessed '
            .. '2026-10-08.',
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
        article_types = {},
        name = 'JMIR Formative Research',
        relationship = 'reviewer',
        requirements_source = 'not recorded',
    },
    jove = {
        article_types = {},
        name = 'Journal of Visualized Experiments',
        relationship = 'reviewer',
        requirements_source = 'not recorded',
    },
    -- Author venues (publications on ORCID 0000-0002-0302-4812, verified
    -- 2026-09-28). Article types are left empty where not confirmed.
    acta_orthopaedica = {
        article_types = {},
        name = 'Acta Orthopaedica',
        relationship = 'author',
        requirements_source = 'not recorded',
    },
    arthroplasty_today = {
        article_types = {},
        name = 'Arthroplasty Today',
        relationship = 'author',
        requirements_source = 'not recorded',
    },
    corr = {
        article_types = {},
        name = 'Clinical Orthopaedics and Related Research',
        relationship = 'author',
        requirements_source = 'not recorded',
    },
    cureus = {
        article_types = {},
        name = 'Cureus',
        relationship = 'author',
        requirements_source = 'not recorded',
    },
    ijscr = {
        article_types = {},
        name = 'International Journal of Surgery Case Reports',
        relationship = 'author',
        requirements_source = 'not recorded',
    },
    jbjs_case_connector = {
        article_types = {},
        name = 'JBJS Case Connector',
        relationship = 'author',
        requirements_source = 'not recorded',
    },
    jim = {
        article_types = {},
        name = 'Journal of Investigative Medicine',
        relationship = 'author',
        requirements_source = 'not recorded',
    },
    nejm_ai = {
        article_types = {
            'Original Research',
            'Datasets, Benchmarks, and Protocols',
            'Case Study',
            'Review',
            'Perspective',
            'Policy Corner',
            'Editorial',
            'Letter to the Editor',
        },
        instructions_url = 'https://ai.nejm.org/author-center',
        login_route = {
            note = 'The journal pages name its ScholarOne submission '
                .. 'system (a Clarivate platform, as is Web of Science) '
                .. 'and require the corresponding author ORCID iD at '
                .. 'submission; they do not describe a Web of Science '
                .. 'sign-in button. No login is automated here.',
            route = 'Web of Science (Clarivate account) linked to ORCID',
            source = 'Stated by Matt, 2026-10-08',
            system = 'ScholarOne Manuscripts (Clarivate)',
            system_url = 'https://mc05.manuscriptcentral.com/nejmai',
        },
        name = 'NEJM AI',
        platform = 'scholarone',
        portal = 'https://mc05.manuscriptcentral.com/nejmai',
        relationship = 'author',
        -- Facts encoded from the NEJM AI Author Center, its Editorial
        -- Policies, and its Formatting Guide for Authors (ai.nejm.org),
        -- accessed 2026-10-08; per-article-type limits as published in
        -- the journal's Article Types page (captured 2026-06-14). Word
        -- counts run from the introduction through the discussion and
        -- exclude the abstract, figure legends, and table notes.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Methods',
                    'Results',
                    'Conclusions',
                },
                variants = {
                    'Article types other than original research take a '
                        .. 'non-structured (narrative) abstract instead.',
                    'Every article also carries a short description of '
                        .. '1-2 sentences; abstract content may be reused.',
                },
            },
            article_types = {
                case_study = {
                    abstract_max_words = nil,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Case Study',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    notes = {
                        'First-hand account of an AI deployment: the '
                            .. 'problem, the approach taken, and lessons '
                            .. 'learned.',
                    },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                datasets_benchmarks_and_protocols = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    combined_items_max = nil,
                    label = 'Datasets, Benchmarks, and Protocols',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'Freely available immediately on publication ' .. '(the journal open-access article type).',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                editorial = {
                    abstract_max_words = nil,
                    abstract_required = true,
                    combined_items_max = 0,
                    label = 'Editorial',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                    notes = {
                        'Usually solicited.',
                        'No display items; at least one reference.',
                    },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                letter_to_the_editor = {
                    abstract_max_words = nil,
                    abstract_required = false,
                    combined_items_max = 1,
                    label = 'Letter to the Editor',
                    manuscript_word_limit = { comparator = '<=', value = 400 },
                    max_references = 5,
                    notes = {
                        'No abstract. The first reference is the article ' .. 'the letter discusses.',
                    },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                original_research = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Original Research',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'Report key findings in the abstract as key ' .. 'data, not unsupported statements.',
                        'All research articles undergo statistical ' .. 'review by the journal statistical editors.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                perspective = {
                    abstract_max_words = nil,
                    abstract_required = true,
                    combined_items_max = 1,
                    combined_items_note = 'One central display item.',
                    label = 'Perspective',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    notes = {
                        'Usually solicited.',
                    },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                policy_corner = {
                    abstract_max_words = nil,
                    abstract_required = true,
                    combined_items_max = 2,
                    combined_items_note = 'Up to two central display items.',
                    label = 'Policy Corner',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
                review = {
                    abstract_max_words = nil,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Review',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'Usually solicited.',
                    },
                    structured_abstract = false,
                    structured_manuscript = false,
                },
            },
            authorship = {
                corresponding_authors_max = 1,
                criteria = 'ICMJE 4 criteria',
                equal_contribution_marker = 'note at the end of the ' .. 'author list (contributed equally)',
                notes = {
                    'The single corresponding author is the manuscript '
                        .. 'guarantor; more reader contacts may be named '
                        .. 'only after acceptance.',
                    'Authors are asked who wrote the first draft; '
                        .. 'writing help beyond copy editing is named, '
                        .. 'with who paid for it.',
                },
                orcid = 'Corresponding author ORCID iD required at '
                    .. 'submission (kept current); ORCID iDs for all '
                    .. 'authors required once accepted, before '
                    .. 'publication.',
            },
            checklist = {
                'One corresponding author, ORCID iD on file for them',
                'Structured abstract and short description (research)',
                'Data sharing statement',
                'AI-use disclosure in cover letter and manuscript',
                'Convey disclosure form from every author',
                'Support statement when the work is funded',
                'Ethics approval and consent statement (human/animal work)',
                'Trial registration (AI-intervention trials, post-2025 enrollment)',
                'Protocol and SAP for trials; CONSORT flow diagram',
                'Representativeness table in the supplement (clinical studies)',
                'ML methods fully reported (TRIPOD-AI / MI-CLAIM recommended)',
                'Figures as separate high-resolution files with legends',
                'Tables embedded in the text file, title and source line each',
                'Full manuscript only; the journal takes no presubmission inquiries',
            },
            cover_letter = {
                elements = {
                    'AI-use disclosure when AI tools were used: the '
                        .. 'technologies used and what they produced '
                        .. '(mirrors the in-manuscript disclosure)',
                },
                required = true,
            },
            fees = {
                publication_fee = false,
                submission_fee = false,
            },
            figures = {
                cited_consecutively = true,
                files = 'separate individual files (also when a copy ' .. 'is embedded in the manuscript)',
                formats = {
                    'graphic files (high resolution)',
                    'PDF',
                },
                notes = {
                    'A legend and a source line are required for every ' .. 'figure.',
                    'Figures carry no references: each must be ' .. 'understood on its own.',
                    'Permissions for reused figures are the authors ' .. 'responsibility.',
                },
            },
            formatting = {
                file_format = 'Microsoft Word (strongly preferred); ' .. 'PDF and LaTeX accepted',
                headings_max_levels = 3,
                single_file = 'Text, references, figure legends, and '
                    .. 'tables compiled into one manuscript text file',
            },
            manuscript_sections = {
                'Introduction',
                'Methods',
                'Results',
                'Discussion',
            },
            references = {
                author_list_max = 6,
                et_al_after = 3,
                journal_abbreviations = 'MEDLINE (Index Medicus)',
                notes = {
                    'List every author when there are six or fewer; '
                        .. 'with seven or more, list the first three '
                        .. 'followed by et al.',
                    'Personal communications, unpublished data, and '
                        .. 'manuscripts in preparation or submitted '
                        .. 'elsewhere are not allowed as references; '
                        .. 'cite them in the text when essential.',
                    'AI-generated material cannot be cited as a ' .. 'primary source.',
                },
                order = 'citation order',
                style = 'NEJM (Vancouver)',
            },
            scope = {
                audience = 'Practicing physicians and clinician '
                    .. 'leaders, computer scientists, policy makers '
                    .. 'and regulators',
                focus = 'State-of-the-art applications of AI to '
                    .. 'clinical medicine; pre-clinical and clinical '
                    .. 'articles are intentionally paired',
            },
            statements = {
                ai_disclosure = {
                    location = 'Cover letter AND the submitted manuscript',
                    note = 'Disclose at submission whether AI-assisted '
                        .. 'technologies (large language models, '
                        .. 'chatbots, image creators) were used, '
                        .. 'describing the tools and what they '
                        .. 'produced. AI tools cannot be authors; '
                        .. 'authors review and stand behind all '
                        .. 'AI-produced material.',
                    status = 'required',
                },
                contributions = {
                    location = 'Manuscript (authorship information)',
                    note = 'Authors indicate who wrote the first '
                        .. 'draft; writing assistance beyond copy '
                        .. 'editing is named, together with who paid '
                        .. 'for it.',
                    status = 'required',
                },
                data_availability = {
                    location = 'Manuscript (data sharing statement)',
                    note = 'An ICMJE data sharing statement is '
                        .. 'required; trial registrations carry a '
                        .. 'data sharing plan. NIH-funded work follows '
                        .. 'NIH data sharing policy; other work '
                        .. 'follows its funder and data-country '
                        .. 'policies.',
                    status = 'required',
                },
                disclosures_coi = {
                    location = 'Convey online disclosure form (sent to ' .. 'each author by email); NOT the manuscript',
                    note = 'Every author of every article type '
                        .. 'completes the Convey form; disclosures are '
                        .. 'published online with the article. The '
                        .. 'journal prints no COI statement in the '
                        .. 'article, and any COI statement placed in '
                        .. 'the manuscript is deleted. Original '
                        .. 'articles also state all sources of '
                        .. 'support.',
                    status = 'required',
                },
                funding = {
                    condition = 'funded work',
                    location = 'Manuscript (support statement)',
                    note = 'An article that received support, '
                        .. 'financial or in kind, provides a support '
                        .. 'statement in the manuscript.',
                    status = 'required_conditional',
                },
                irb_ethics = {
                    condition = 'research in human patients or animals',
                    location = 'Manuscript',
                    note = 'Statement that the appropriate governing '
                        .. 'body approved the work, how informed '
                        .. 'consent was obtained, and which body '
                        .. 'approved the consent document; conduct '
                        .. 'accords with the Declaration of Helsinki.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated by NEJM AI in the documents ' .. 'reviewed.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    location = 'Submission record',
                    note = 'Required for the corresponding author at '
                        .. 'submission; required for all authors once '
                        .. 'accepted, before publication. See the '
                        .. 'authorship block.',
                    status = 'required',
                },
                trial_registration = {
                    condition = 'trials of AI interventions enrolling ' .. 'patients after 2025-01-01',
                    location = 'Manuscript and trial registry',
                    note = 'Register before enrollment in a registry '
                        .. 'meeting the WHO ICTRP specification '
                        .. '(ICMJE clinical-trial definition).',
                    status = 'required_conditional',
                },
            },
            supplemental = {
                format = 'PDF, Microsoft Word, or another editable ' .. 'text format',
                listing = 'Supplementary Appendix is paginated, '
                    .. 'carries a table of contents when applicable, '
                    .. 'and keeps its own self-contained reference '
                    .. 'list; it is not style-edited.',
                notes = {
                    'Clinical research studies include a '
                        .. 'representativeness table in the '
                        .. 'Supplementary Appendix, referenced in the '
                        .. 'text.',
                    'Supplementary tables are labeled Table S1, '
                        .. 'Table S2, and so on; supplementary figures '
                        .. 'carry title and legend on the same page.',
                },
            },
            tables = {
                notes = {
                    'Every table is cited in the text in numerical '
                        .. 'order and carries a title and a source '
                        .. 'line.',
                    'Build tables with the word processor table '
                        .. 'function: every column headed, first '
                        .. 'column filled in every cell.',
                },
                placement = 'embedded in the manuscript text file ' .. '(not separate files)',
            },
            title_page = {
                'Title',
                'Authors with degrees and affiliations',
                'Corresponding author (one during submission and revision) with contact information',
                'ORCID iD of the corresponding author',
            },
        },
        requirements_source = 'Verified from the NEJM AI Author Center, '
            .. 'Editorial Policies, and Formatting Guide for Authors '
            .. '(ai.nejm.org), accessed 2026-10-08; per-article-type '
            .. 'limits as published in the journal Article Types page '
            .. '(captured 2026-06-14).',
    },
    orthopedics = {
        article_types = {},
        name = 'Orthopedics',
        relationship = 'author',
        requirements_source = 'not recorded',
    },
    generic = {
        article_types = {},
        name = 'Journal',
        requirements_source = 'not recorded',
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

---The structured requirements recorded for a journal, plus provenance.
---@param name string profile key
---@return table|nil requirements
---@return string source provenance string ('not recorded' when unknown)
function M.requirements_for(name)
    local profile = M.profiles[name:lower()]
    if not profile then
        return nil, 'not recorded'
    end
    return profile.requirements, profile.requirements_source or 'not recorded'
end

---The requirements entry for one article type within a profile.
---@param profile table journal profile (from M.get)
---@param article_type string label ('Original Research') or key
---@return table|nil
function M.article_requirement(profile, article_type)
    if type(profile) ~= 'table' or type(article_type) ~= 'string' then
        return nil
    end
    local requirements = profile.requirements
    if not requirements or not requirements.article_types then
        return nil
    end
    return requirements.article_types[article_type_key(article_type)]
end

---Serialize the whole registry to stable, sorted JSON. This is the data
---contract for external consumers (a future research MCP server, phlow,
---plain scripts): they read the export instead of running the Neovim UI.
---With no path, returns the JSON string. With a path, writes it there
---(parent directories created) and returns true.
---@param path? string
---@return string|boolean|nil result JSON string, or true after writing
---@return string|nil err
function M.export_json(path)
    if path ~= nil then
        assert(type(path) == 'string' and path ~= '', 'export path must be a string')
    end
    local payload = {
        profiles = M.profiles,
        schema_version = 1,
        source = 'research.journal',
    }
    local ok, encoded = pcall(json_encode_sorted, payload)
    if not ok then
        return nil, ('journal registry is not JSON-serializable: %s'):format(encoded)
    end
    if path == nil then
        return encoded
    end
    local directory = vim.fs.dirname(path)
    if directory and directory ~= '' then
        fn.mkdir(directory, 'p')
    end
    fn.writefile({ encoded }, path)
    return true
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

---@return string[]
function M.names()
    local names = {}
    for name in pairs(M.profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
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
        notify_error(('Unknown journal: %s'):format(key))
        return
    end
    if not profile.portal then
        vim.notify(('No portal recorded for %s'):format(profile.name), vim.log.levels.WARN)
        return
    end
    open(profile.portal)
end

---@param name string
---@param profile table
function M.register(name, profile)
    assert(type(name) == 'string' and name ~= '', 'journal profile name must be a string')
    assert(type(profile) == 'table', 'journal profile must be a table')
    M.profiles[name:lower()] = vim.deepcopy(profile)
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

    api.nvim_create_user_command('JournalExport', function(opts)
        local path = opts.args ~= '' and opts.args or (fn.stdpath('data') .. '/research/journals.json')
        local result, err = M.export_json(path)
        if not result then
            notify_error(('JournalExport: %s'):format(err))
            return
        end
        vim.notify(('JournalExport: wrote %s'):format(path), vim.log.levels.INFO)
    end, {
        nargs = '?',
        complete = 'file',
        desc = 'Export the journal registry to sorted JSON (data contract for agents/tools)',
    })
end

return M
