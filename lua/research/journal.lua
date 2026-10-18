-- /qompassai/Diver/lua/research/journal.lua
-- Qompass AI Diver Journal Profile Utils
---@module 'research.journal'
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
--   review            table   peer-review scaffold data:
--                             { fields = string[] }, the rating field
--                             labels in the journal's order, read by
--                             research.review. Profiles without it fall
--                             back to the generic profile's fields.
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
        article_types = {
            'Original Paper',
            'Case Report',
            'Commentary',
            'Corrigenda and Addenda',
            'Early Reports',
            'Editorial',
            'Extraordinary Lives',
            'Guest Editorial',
            'In Memoriam',
            'Letter to the Editor',
            'Notes from the Field',
            'Open Source/Open Data',
            'Patient Perspective',
            'Personal Perspectives',
            'Rapid Surveillance Report',
            'Research Letter',
            'Review',
            'Short Paper',
            'Tutorial',
            'Viewpoint',
        },
        instructions_url = 'https://formative.jmir.org/author-information/instructions-for-authors',
        name = 'JMIR Formative Research',
        relationship = 'reviewer',
        -- Facts encoded from the JMIR Formative Research Instructions
        -- for Authors and the JMIR Publications article-types and fee
        -- pages, accessed 2026-10-17.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Objectives',
                    'Methods',
                    'Results',
                    'Conclusions',
                },
                max_words = 450,
                variants = {
                    'Viewpoints, Editorials, and Guest Editorials take an unstructured abstract.',
                    'Commentaries take an unstructured abstract of at most 300 words.',
                    'Research Letters have no abstract; a one-sentence summary is recommended.',
                },
            },
            article_types = {
                case_report = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Case Report',
                    notes = {
                        'Structured abstract if the report presents data.',
                    },
                    structured_abstract = false,
                },
                commentary = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    combined_items_max = 1,
                    label = 'Commentary',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                    max_references = 10,
                    structured_abstract = false,
                },
                corrigenda_and_addenda = {
                    label = 'Corrigenda and Addenda',
                },
                early_reports = {
                    label = 'Early Reports',
                },
                editorial = {
                    abstract_required = true,
                    label = 'Editorial',
                    structured_abstract = false,
                },
                extraordinary_lives = {
                    label = 'Extraordinary Lives',
                },
                guest_editorial = {
                    abstract_required = true,
                    label = 'Guest Editorial',
                    structured_abstract = false,
                },
                in_memoriam = {
                    label = 'In Memoriam',
                },
                letter_to_the_editor = {
                    abstract_required = false,
                    label = 'Letter to the Editor',
                },
                notes_from_the_field = {
                    label = 'Notes from the Field',
                },
                open_source_open_data = {
                    label = 'Open Source/Open Data',
                },
                original_paper = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Original Paper',
                    notes = {
                        'No hard word limit is stated for this journal; the guidance aims for a body text '
                            .. 'of at most 10,000 words, and longer articles may incur fees.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                patient_perspective = {
                    label = 'Patient Perspective',
                },
                personal_perspectives = {
                    label = 'Personal Perspectives',
                },
                rapid_surveillance_report = {
                    label = 'Rapid Surveillance Report',
                },
                research_letter = {
                    abstract_required = false,
                    combined_items_max = 2,
                    label = 'Research Letter',
                    manuscript_word_limit = { comparator = '<=', value = 750 },
                    max_references = 10,
                },
                review = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Review',
                    structured_abstract = true,
                },
                short_paper = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Short Paper',
                    manuscript_word_limit = { comparator = '<=', value = 1500 },
                    notes = {
                        'Otherwise follows the Original Paper requirements.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                tutorial = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Tutorial',
                    notes = {
                        'Structured abstract if the tutorial presents evaluative data.',
                    },
                    structured_abstract = false,
                },
                viewpoint = {
                    abstract_required = true,
                    label = 'Viewpoint',
                    notes = {
                        'Abstract is unstructured; no word limit is stated for this article type.',
                    },
                    structured_abstract = false,
                },
            },
            checklist = {
                'Cover letter included',
                'Structured abstract with the journal headings (Original Papers, Reviews)',
                'Reporting-guideline checklist supplied as a Multimedia Appendix where applicable',
                'Tables longer than one and a half pages go in a Multimedia Appendix',
                'Article type stated at the start of the manuscript when it is not a standard type',
                'ORCID iDs for all authors by publication',
            },
            cover_letter = {
                elements = {
                    'Disclosure of any previous or simultaneous Internet publication and of overlap with related work',
                },
                required = true,
            },
            fees = {
                notes = {
                    'Article Processing Fee $2,500 on acceptance (Viewpoint $2,000; Research Letter $1,250); '
                        .. 'optional fast-track fee $450.',
                },
                publication_fee = true,
            },
            references = {
                notes = {
                    'AMA Manual of Style, 11th edition; every reference carries a unique identifier '
                        .. '(DOI, PMID, ISBN, or URL).',
                },
                order = 'citation order',
                style = 'AMA',
            },
            statements = {
                ai_disclosure = {
                    location = 'Manuscript',
                    note = 'Use of AI tools in preparing the work must be disclosed.',
                    status = 'required',
                },
                contributions = {
                    note = 'An Author Contributions section is part of the Original Paper format; the author '
                        .. 'guide also lists contributions (CRediT) as recommended.',
                    status = 'required',
                },
                data_availability = {
                    condition = 'original research reporting data',
                    note = 'A data availability statement is required for original research reporting data.',
                    status = 'required_conditional',
                },
                disclosures_coi = {
                    note = 'Conflicts of interest are declared for every author; state "none declared" '
                        .. 'when there are none.',
                    status = 'required',
                },
                funding = {
                    note = 'All sources of funding are stated in the manuscript.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'human-subjects research',
                    location = 'Methods (Ethical Considerations subheading)',
                    note = 'Ethics approval and consent are covered under an Ethical Considerations '
                        .. 'subheading in Methods, with added detail for vulnerable populations.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = '5-10 keywords; MeSH terms preferred.',
                    status = 'required',
                },
                orcid = {
                    note = 'ORCID iDs for all authors are required by publication.',
                    status = 'required',
                },
                trial_registration = {
                    condition = 'randomized controlled trials',
                    note = 'Trials follow CONSORT; the registration number appears in the abstract and the body.',
                    status = 'required_conditional',
                },
            },
        },
        requirements_source = 'Verified from the JMIR Formative Research '
            .. 'Instructions for Authors and the JMIR Publications '
            .. 'article-types and fee pages, accessed 2026-10-17.',
    },
    journal_of_cardiothoracic_surgery = {
        article_types = {
            'Research',
            'Case Report',
            'Review',
            'Matters Arising',
        },
        instructions_url = 'https://cardiothoracicsurgery.biomedcentral.com/submission-guidelines',
        name = 'Journal of Cardiothoracic Surgery',
        relationship = 'reviewer',
        -- Facts encoded from the Journal of Cardiothoracic Surgery
        -- submission guidelines (BioMed Central / Springer Nature) and
        -- its article-type pages, accessed 2026-10-17.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Methods',
                    'Results',
                    'Conclusions',
                },
                max_words = 350,
                variants = {
                    'Research abstracts add a Trial registration section where applicable.',
                    'Case report abstracts use Background, Case presentation, Conclusions.',
                    'Review abstracts use Background, Main body, Conclusion (or Background, Short conclusion).',
                    'Matters Arising has no abstract.',
                },
            },
            article_types = {
                case_report = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    label = 'Case Report',
                    structured_abstract = true,
                },
                matters_arising = {
                    abstract_required = false,
                    label = 'Matters Arising',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    max_references = 15,
                    notes = {
                        'The journal says Matters Arising should ideally not exceed 1,200 words.',
                    },
                },
                research = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    label = 'Research',
                    structured_abstract = true,
                },
                review = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    label = 'Review',
                    structured_abstract = true,
                },
            },
            checklist = {
                'Full Declarations section with every subheading ("Not applicable" where a section does not apply)',
                'Figure titles of at most 15 words; legends of at most 300 words; figure files of at most 10 MB',
                'Double line spacing with line and page numbering',
                'Editable manuscript file (DOC/DOCX, RTF, or TeX/LaTeX)',
            },
            cover_letter = {
                elements = {
                    'Why the manuscript should be published in the Journal of Cardiothoracic Surgery',
                    'Any issues relating to the journal policies',
                    'Declaration of any competing interests',
                    'Confirmation that all authors have approved the manuscript for submission',
                    'Confirmation that the content has not been published or submitted for publication elsewhere',
                    'Name of the special issue, where applicable',
                },
                required = true,
            },
            fees = {
                notes = {
                    'Article Processing Charge on acceptance: £2,190 / $2,990 / €2,490 '
                        .. '(plus VAT where applicable).',
                },
                publication_fee = true,
            },
            figures = {
                legend_max_words = 300,
                notes = {
                    'Figure titles are limited to 15 words and figure files to 10 MB.',
                },
            },
            formatting = {
                double_spaced = true,
                file_format = 'DOC/DOCX, RTF, or TeX/LaTeX (editable files)',
                line_numbers = true,
                page_numbers = true,
            },
            references = {
                notes = {
                    'Journal names abbreviated per Index Medicus/MEDLINE; only published, in-press, or '
                        .. 'preprint material may be cited.',
                },
                order = 'citation order',
                style = 'Vancouver',
            },
            statements = {
                ai_disclosure = {
                    condition = 'a large language model was used in the work',
                    location = 'Methods (or Acknowledgements/Declarations)',
                    note = 'LLM use is documented in the Methods; an LLM does not meet the authorship criteria.',
                    status = 'required_conditional',
                },
                contributions = {
                    location = "Declarations (Authors' contributions)",
                    note = 'Each author\'s contributions are stated; "Not applicable" where the section '
                        .. 'does not apply.',
                    status = 'required',
                },
                data_availability = {
                    location = 'Declarations (Availability of data and materials)',
                    note = 'Availability of the data and materials is stated for every manuscript.',
                    status = 'required',
                },
                disclosures_coi = {
                    location = 'Declarations (Competing interests)',
                    note = 'Competing interests are declared for every manuscript.',
                    status = 'required',
                },
                funding = {
                    location = 'Declarations (Funding)',
                    note = 'Funding is declared for every manuscript.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'research involving human participants, data, or tissue',
                    location = 'Declarations (Ethics approval and consent to participate; Consent for publication)',
                    note = 'Ethics approval and consent are stated, naming the committee and reference '
                        .. 'number; consent for publication is obtained for individual data and is '
                        .. 'required for all case reports.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Three to ten keywords, in alphabetical order.',
                    status = 'required',
                },
                orcid = {
                    note = 'Not stated by the Journal of Cardiothoracic Surgery in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'a health care intervention on human participants',
                    location = 'Abstract (Trial registration section)',
                    note = 'Registry name, registration number, and date of registration; retrospectively '
                        .. 'registered trials are marked as such in the first paragraph of Methods.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Title (including the study design, where appropriate)',
                'Full names and institutional addresses for all authors',
                'Corresponding author indicated',
            },
        },
        requirements_source = 'Verified from the Journal of '
            .. 'Cardiothoracic Surgery submission guidelines (BioMed '
            .. 'Central / Springer Nature) and its article-type pages, '
            .. 'accessed 2026-10-17.',
    },
    jove = {
        article_types = {
            'Method Articles',
            'Research Articles',
            'Case Reports',
        },
        instructions_url = 'https://www.jove.com/authors/submit',
        name = 'Journal of Visualized Experiments',
        relationship = 'reviewer',
        -- Facts encoded from the JoVE author submission pages
        -- (jove.com), accessed 2026-10-17. The manuscript template and
        -- editorial policies pages could not be fetched, so
        -- template-level limits are not recorded.
        requirements = {
            abstract = {
                max_words = 300,
                variants = {
                    'The abstract is entered in the submission system and must also appear in the manuscript.',
                },
            },
            article_types = {
                case_reports = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    label = 'Case Reports',
                },
                method_articles = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    label = 'Method Articles',
                    notes = {
                        'Protocols are written as step-by-step procedures; JoVE produces the accompanying '
                            .. 'video after acceptance.',
                    },
                },
                research_articles = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    label = 'Research Articles',
                },
            },
            checklist = {
                'Title of no more than 150 characters',
                'Abstract of no more than 300 words, in the submission system and in the manuscript',
                'Video component is optional: JoVE produces the video after acceptance; author-submitted '
                    .. 'videos are accepted when they meet the guidelines',
                'Ethical documentation supplied where applicable',
            },
            fees = {
                notes = {
                    'An Article Publishing Charge applies on acceptance (the amount is given during '
                        .. 'submission; an older journal page lists a $1,400 publication fee for submissions '
                        .. 'after February 2021, plus a $2,500 open-access option).',
                },
                publication_fee = true,
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated by JoVE in the pages reviewed.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'Not stated by JoVE in the pages reviewed.',
                    status = 'not_stated_by_journal',
                },
                data_availability = {
                    note = 'Not stated by JoVE in the pages reviewed.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = 'Authors disclose relevant financial relationships from the 24 months before '
                        .. 'submission, as part of the submission.',
                    status = 'required',
                },
                funding = {
                    note = 'Not stated by JoVE in the pages reviewed.',
                    status = 'not_stated_by_journal',
                },
                irb_ethics = {
                    condition = 'work requiring ethical approval',
                    note = 'Required ethical documentation is supplied where applicable.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated by JoVE in the pages reviewed.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated by JoVE in the pages reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    note = 'Not stated by JoVE in the pages reviewed.',
                    status = 'not_stated_by_journal',
                },
            },
        },
        requirements_source = 'Verified from the JoVE author submission '
            .. 'pages (jove.com), accessed 2026-10-17; the manuscript '
            .. 'template and editorial policies pages could not be '
            .. 'fetched, so template-level limits are not recorded.',
    },
    -- Author venues (publications on ORCID 0000-0002-0302-4812, verified
    -- 2026-09-28). Article types are left empty where not confirmed.
    acta_orthopaedica = {
        article_types = {
            'Original articles',
            'Review articles',
            'Educationals',
            'Case/technical reports',
            'Editorials',
            'Perspectives',
            'Letter to the editor',
        },
        instructions_url = 'https://actaorthop.org/actao/instructionsforauthors',
        name = 'Acta Orthopaedica',
        relationship = 'author',
        -- Facts encoded from the Acta Orthopaedica Instructions for
        -- Authors, Article Types, and Fees pages (actaorthop.org),
        -- accessed 2026-10-17. Where the article-types table and the
        -- prose on the same page disagree, the table value is encoded
        -- and the discrepancy is noted.
        requirements = {
            abstract = {
                headings = {
                    'Background and purpose',
                    'Methods',
                    'Results',
                    'Conclusion',
                },
                max_words = 250,
                variants = {
                    'Trial registration is mentioned in the abstract where the study was pre-registered.',
                },
            },
            article_types = {
                case_technical_reports = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Case/technical reports',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    max_references = 10,
                    notes = {
                        'A short abstract is required in the submitted manuscript; no abstract appears '
                            .. 'in the published report.',
                        'Max 2 figures and max 2 tables per the article-types table; the prose allows '
                            .. 'max 3 figures and max 3 text boxes or tables — discrepancy in the source.',
                    },
                    structured_abstract = true,
                },
                editorials = {
                    abstract_required = false,
                    combined_items_max = 0,
                    label = 'Editorials',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    max_references = 10,
                    notes = {
                        'No figures or tables.',
                    },
                },
                educationals = {
                    abstract_required = false,
                    label = 'Educationals',
                    manuscript_word_limit = { comparator = '<=', value = 3300 },
                    max_references = 25,
                    notes = {
                        'Max 5 figures and max 5 tables per the article-types table; the prose allows up '
                            .. 'to 40 references and max 10 figures, tables or text boxes combined — '
                            .. 'discrepancy in the source.',
                    },
                },
                letter_to_the_editor = {
                    abstract_required = false,
                    combined_items_max = 0,
                    label = 'Letter to the editor',
                    manuscript_word_limit = { comparator = '<=', value = 500 },
                    max_references = 10,
                    notes = {
                        'No figures or tables.',
                    },
                },
                original_articles = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Original articles',
                    manuscript_word_limit = { comparator = '<=', value = 3300 },
                    max_references = 25,
                    notes = {
                        'Max 5 figures and max 5 tables (stated separately in the article-types table).',
                        'The word count excludes the title page, legends, and references.',
                    },
                    structured_abstract = true,
                },
                perspectives = {
                    abstract_required = false,
                    combined_items_max = 0,
                    label = 'Perspectives',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    max_references = 10,
                },
                review_articles = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Review articles',
                    manuscript_word_limit = { comparator = '<=', value = 3300 },
                    max_references = 40,
                    notes = {
                        'The article-types table reference entry reads "No", while the prose on the same '
                            .. 'page allows up to 40 references; 40 is encoded from the prose.',
                        'Max 5 figures and max 5 tables (stated separately in the article-types table).',
                    },
                    structured_abstract = true,
                },
            },
            checklist = {
                'Word counts (total, abstract, introduction) on the title page',
                'Reporting follows the EQUATOR guideline for the study design',
                'No academic titles, postal address, or telephone number on the title page',
                'Tables and figures at the end of the manuscript',
                'American spelling',
            },
            fees = {
                notes = {
                    'Article Processing Charge: €2,400 for Original articles, Review articles, and '
                        .. 'Educationals; €1,200 for Case/technical reports and Perspectives; Editorials, '
                        .. 'Letters, and solicited articles are free. No fee for rejected manuscripts.',
                },
                publication_fee = true,
                submission_fee = false,
            },
            figures = {
                discrepancy_note = 'The article-types table and the prose on the same page state different '
                    .. 'figure/table allowances for Case/technical reports and Educationals; the table '
                    .. 'values are encoded and each discrepancy is noted on the article type.',
            },
            references = {
                notes = {
                    'References numbered consecutively; a DOI is given when available. The journal '
                        .. 'advises limiting references to about 25 except for meta-analyses and reviews.',
                },
                order = 'citation order',
                text_marker = 'parentheses',
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated by Acta Orthopaedica in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'Author contributions are stated by initials.',
                    status = 'required',
                },
                data_availability = {
                    condition = 'clinical trials enrolling on or after 2019-01-01',
                    note = 'A data sharing plan is described; it is required for clinical trials '
                        .. 'enrolling on or after 2019-01-01.',
                    status = 'required_conditional',
                },
                disclosures_coi = {
                    note = 'A conflict-of-interest document is completed during submission.',
                    status = 'required',
                },
                funding = {
                    note = 'Funding is declared for every manuscript.',
                    status = 'required',
                },
                irb_ethics = {
                    note = 'Ethics-committee approval, when appropriate, is stated with its date and '
                        .. 'registration number, and consent is described.',
                    status = 'required',
                },
                keywords = {
                    note = 'The title-page instructions direct authors not to provide keywords.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated by Acta Orthopaedica in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'randomized controlled trials and systematic reviews',
                    note = 'Randomized trials should be registered; systematic reviews are registered '
                        .. 'in PROSPERO.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Title (research design in the latter part)',
                'Author first names, middle initials, last names',
                'Department affiliations',
                'Corresponding author email only',
                'Word counts (total, abstract, introduction)',
            },
        },
        requirements_source = 'Verified from the Acta Orthopaedica '
            .. 'Instructions for Authors, Article Types, and Fees pages '
            .. '(actaorthop.org), accessed 2026-10-17.',
    },
    arthroplasty_today = {
        article_types = {
            'Original Research Articles',
            'Systematic Review',
            'Case Reports',
            'Arthroplasty in Patients With Rare Conditions',
            'Brief Communications',
            'Surgical Technique/Office Tip',
            'Guideline/White Paper',
            'Viewpoint',
            'Editorial and Guest Editorial',
            'Letter to the Editor',
            'Other',
        },
        instructions_url = 'https://www.arthroplastytoday.org/authorinfo',
        name = 'Arthroplasty Today',
        relationship = 'author',
        -- Facts encoded from the Arthroplasty Today Guide for Authors
        -- (arthroplastytoday.org), accessed 2026-10-17. Limits the
        -- guide phrases as "typically fewer than N words" are encoded
        -- with the '<' comparator and a note.
        requirements = {
            article_types = {
                arthroplasty_in_patients_with_rare_conditions = {
                    abstract_max_words = 125,
                    abstract_required = true,
                    label = 'Arthroplasty in Patients With Rare Conditions',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'Three multiple-choice questions with five options, a preferred response, and a '
                            .. 'discussion are required.',
                    },
                    structured_abstract = false,
                },
                brief_communications = {
                    abstract_required = true,
                    label = 'Brief Communications',
                    notes = {
                        'A brief abstract is required; no abstract word count is stated.',
                        'References are limited to fewer than 10; no word limit is stated.',
                    },
                },
                case_reports = {
                    abstract_max_words = 125,
                    abstract_required = true,
                    label = 'Case Reports',
                    manuscript_word_limit = { comparator = '<', value = 2000 },
                    notes = {
                        'Typically fewer than 2,000 words.',
                        'Three multiple-choice questions with five options, a preferred response, and a '
                            .. 'discussion are required.',
                    },
                    structured_abstract = false,
                },
                editorial_and_guest_editorial = {
                    abstract_required = false,
                    label = 'Editorial and Guest Editorial',
                    manuscript_word_limit = { comparator = '<=', value = 500 },
                },
                guideline_white_paper = {
                    abstract_max_words = 125,
                    abstract_required = true,
                    label = 'Guideline/White Paper',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'Stated length 2,000-3,000 words.',
                    },
                    structured_abstract = false,
                },
                letter_to_the_editor = {
                    abstract_required = false,
                    label = 'Letter to the Editor',
                    manuscript_word_limit = { comparator = '<', value = 500 },
                    notes = {
                        'Usually fewer than 500 words.',
                    },
                },
                original_research_articles = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Original Research Articles',
                    manuscript_word_limit = { comparator = '<', value = 4000 },
                    notes = {
                        'Typically fewer than 4,000 words.',
                        'Three multiple-choice questions with five options, a preferred response, and a '
                            .. 'discussion are required.',
                    },
                    structured_abstract = true,
                },
                other = {
                    label = 'Other',
                },
                surgical_technique_office_tip = {
                    abstract_max_words = 125,
                    abstract_required = true,
                    label = 'Surgical Technique/Office Tip',
                    manuscript_word_limit = { comparator = '<', value = 2000 },
                    notes = {
                        'Typically fewer than 2,000 words.',
                    },
                    structured_abstract = false,
                },
                systematic_review = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Systematic Review',
                    manuscript_word_limit = { comparator = '<', value = 4000 },
                    notes = {
                        'Typically fewer than 4,000 words.',
                    },
                    structured_abstract = true,
                },
                viewpoint = {
                    abstract_required = false,
                    label = 'Viewpoint',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                },
            },
            checklist = {
                'Title page prepared from the journal template',
                'Corresponding author contact block',
                'Keywords (maximum 6) after the abstract',
                'Figure captions and tables uploaded with the submission',
                'Reporting checklist for the study type (CONSORT, STROBE, PRISMA, CARE, AGREE)',
                'Three multiple-choice questions for Case Reports, Rare Conditions, and Original Research',
                'Manuscript prepared for double-blind review',
            },
            references = {
                notes = {
                    'DOIs are included; the style matches The Journal of Arthroplasty.',
                },
                order = 'citation order',
                style = 'Vancouver',
                text_marker = 'square brackets',
            },
            statements = {
                ai_disclosure = {
                    condition = 'generative AI was used in preparing the work',
                    location = 'Declaration section before References',
                    note = 'Use of generative AI in manuscript preparation is declared before the References.',
                    status = 'required_conditional',
                },
                contributions = {
                    note = 'The corresponding author provides CRediT contribution roles for all authors.',
                    status = 'required',
                },
                data_availability = {
                    note = 'Data sharing is encouraged by the journal but not required; no statement '
                        .. 'format is stated.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = 'Each author completes a signed disclosure; a combined blinded disclosure '
                        .. 'also accompanies the submission.',
                    status = 'required',
                },
                funding = {
                    location = 'Manuscript (Funding Sources statement)',
                    note = 'A Funding Sources statement is published with the article.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'human- or animal-subjects research',
                    note = 'IRB affiliation and protocol number appear in the last sentence of Methods; '
                        .. 'consent is documented.',
                    status = 'required_conditional',
                },
                keywords = {
                    location = 'After the abstract',
                    note = 'Maximum 6 keywords.',
                    status = 'required',
                },
                orcid = {
                    note = 'Not stated by Arthroplasty Today in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    note = 'Registration is a condition of publication; the number is given at submission '
                        .. 'and on the title page, with a CONSORT checklist.',
                    status = 'required_conditional',
                },
            },
        },
        requirements_source = 'Verified from the Arthroplasty Today '
            .. 'Guide for Authors (arthroplastytoday.org), accessed '
            .. '2026-10-17.',
    },
    corr = {
        article_types = {},
        name = 'Clinical Orthopaedics and Related Research',
        relationship = 'author',
        requirements_source = 'Not verified: the journal moved from '
            .. 'Springer (whose journal page now states it is archived '
            .. 'there and no longer receiving submissions) to Wolters '
            .. "Kluwer, and the current publisher's author guidelines "
            .. 'could not be fetched (HTTP 403) on 2026-10-17, so no '
            .. 'requirements are recorded.',
    },
    cureus = {
        article_types = {
            'Original Article',
            'Review Article',
            'Case Report',
            'Technical Report',
            'Editorial',
        },
        instructions_url = 'https://www.cureus.com/author_guide/author-instructions/submitting-an-article',
        name = 'Cureus',
        relationship = 'author',
        -- Facts encoded from the Cureus Author Guide and FAQ
        -- (cureus.com), accessed 2026-10-17. The author/reference
        -- counts in the notes are free-publication eligibility limits,
        -- not submission caps, so they are not encoded as maxima.
        requirements = {
            abstract = {
                variants = {
                    'The abstract is entered as a submission field and is limited to 3,500 characters '
                        .. '(a character limit, not a word limit).',
                },
            },
            article_types = {
                case_report = {
                    label = 'Case Report',
                    notes = {
                        'No strict word limit for most article types.',
                        'Free-publication eligibility: no more than 5 authors and 20 references '
                            .. '(eligibility limits for free publication, not submission caps).',
                    },
                },
                editorial = {
                    label = 'Editorial',
                    notes = {
                        'Free-publication eligibility: no more than 5 authors and 5 references '
                            .. '(eligibility limits for free publication, not submission caps).',
                    },
                },
                original_article = {
                    label = 'Original Article',
                    notes = {
                        'No strict word limit for most article types.',
                        'Free-publication eligibility: no more than 10 authors and 30 references '
                            .. '(eligibility limits for free publication, not submission caps).',
                    },
                },
                review_article = {
                    label = 'Review Article',
                    notes = {
                        'No strict word limit for most article types.',
                        'All review articles require purchase of Preferred Editing.',
                    },
                },
                technical_report = {
                    label = 'Technical Report',
                    notes = {
                        'No strict word limit for most article types.',
                        'Free-publication eligibility: no more than 5 authors and 20 references '
                            .. '(eligibility limits for free publication, not submission caps).',
                    },
                },
            },
            checklist = {
                'At least five suggested advisers entered at submission',
                'All authors entered at submission (authors cannot be added later)',
                'Conclusions of 1-2 paragraphs (1-2 sentence conclusions are not accepted)',
                'No media in the abstract, introduction, or conclusions (introduction excepted for review articles)',
                'Media items no more than 25 per article',
                'Title in APA title case, one sentence, no terminal period, no acronyms except common ones',
            },
            fees = {
                notes = {
                    'Publication can be free when the article meets all editorial requirements and the '
                        .. 'free-publication author/reference caps; otherwise Preferred Editing (around '
                        .. '$400) is required, and it is mandatory for all review articles. A partial '
                        .. 'refund (less a $50 processing fee) applies if a Preferred Editing article is '
                        .. 'rejected after peer review.',
                },
                publication_fee = true,
            },
            references = {
                notes = {
                    'Journal names abbreviated per Index Medicus; a DOI is required when available, '
                        .. 'otherwise the article URL; unpublished material without a DOI is excluded; '
                        .. 'preprints are marked [PREPRINT].',
                },
                order = 'citation order',
                text_marker = 'square brackets',
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated by Cureus in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = "Each author's contributions are selected at submission; authorship follows ICMJE.",
                    status = 'required',
                },
                data_availability = {
                    note = 'Not stated by Cureus in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = 'The submitting author discloses conflicts of interest for all co-authors at '
                        .. 'submission; Cureus auto-generates the disclosures.',
                    status = 'required',
                },
                funding = {
                    note = 'Not stated by Cureus in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                irb_ethics = {
                    condition = 'human- or animal-subjects research',
                    note = 'IRB names and approval numbers are given, consent is confirmed or waived, '
                        .. 'and documentation is uploaded where the work was reviewed.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = '5-10 keywords, each of at most 3-4 words.',
                    status = 'required',
                },
                orcid = {
                    note = 'Not stated by Cureus in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'clinical trials (Original Articles)',
                    note = 'Registration is captured through the study-design questionnaire for Original Articles.',
                    status = 'required_conditional',
                },
            },
        },
        requirements_source = 'Verified from the Cureus Author Guide ' .. 'and FAQ (cureus.com), accessed 2026-10-17.',
    },
    ijscr = {
        article_types = {
            'Case Report',
            'Case Series',
        },
        name = 'International Journal of Surgery Case Reports',
        relationship = 'author',
        -- Facts encoded from the Elsevier Author Information Pack for
        -- this journal (Guide for Authors), dated 2023-09-15,
        -- accessed 2026-10-17 via a reproduction of the pack; the
        -- live ScienceDirect Guide for Authors page could not be
        -- fetched (HTTP 429).
        requirements = {
            abstract = {
                headings = {
                    'Introduction',
                    'Presentation of Case',
                    'Discussion',
                    'Conclusion',
                },
                max_words = 250,
            },
            article_types = {
                case_report = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Case Report',
                    manuscript_word_limit = { comparator = '<=', value = 1500 },
                    max_authors = 6,
                    max_references = 20,
                    notes = {
                        'No more than 5 figures.',
                        'More than six authors may be discussed with the journal office before submission.',
                    },
                    structured_abstract = true,
                },
                case_series = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Case Series',
                    manuscript_word_limit = { comparator = '<=', value = 1500 },
                    max_references = 20,
                    notes = {
                        'No more than 5 figures.',
                    },
                    structured_abstract = true,
                },
            },
            checklist = {
                'SCARE checklist completed (case reports) or PROCESS checklist (case series), with the '
                    .. 'in-line statement in the Introduction',
                'Authorship form completed (submissions without it are returned without review)',
                'Highlights: 3-5 bullets, max 85 characters each, as a separate editable file',
                'Separate title page with author details (double-anonymized review); anonymized manuscript file',
                'Consent statement included',
            },
            fees = {
                notes = {
                    'An Article Publishing Charge is requested on acceptance (amount not stated in the pack).',
                },
                publication_fee = true,
            },
            manuscript_sections = {
                'Introduction',
                'Presentation of Case',
                'Discussion',
                'Conclusion',
            },
            references = {
                author_list_max = 6,
                et_al_after = 6,
                notes = {
                    'The first six authors are listed, then et al.; page ranges are shortened; the style '
                        .. 'follows the Uniform Requirements.',
                },
                order = 'citation order',
                text_marker = 'superscript',
            },
            statements = {
                ai_disclosure = {
                    condition = 'generative AI was used in preparing the work',
                    location = 'Declaration section before References',
                    note = 'Use of generative AI in manuscript preparation is declared before the References.',
                    status = 'required_conditional',
                },
                contributions = {
                    note = 'The corresponding author provides CRediT roles; a guarantor is listed.',
                    status = 'required',
                },
                data_availability = {
                    note = 'Data sharing is encouraged by the publisher but not required; no statement '
                        .. 'format is stated.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = 'A declaration of interest is given in the title page/manuscript and on a '
                        .. 'separate form; a statement is required even when there is nothing to declare.',
                    status = 'required',
                },
                funding = {
                    note = 'Funding sources are declared for every manuscript.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'work involving patients or volunteers',
                    note = 'Ethics approval and written informed consent are documented.',
                    status = 'required_conditional',
                },
                keywords = {
                    location = 'After the abstract',
                    note = 'Maximum 6 keywords.',
                    status = 'required',
                },
                orcid = {
                    note = 'Not stated by the International Journal of Surgery Case Reports in the '
                        .. 'documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    note = 'Not stated by the International Journal of Surgery Case Reports in the '
                        .. 'documents reviewed.',
                    status = 'not_stated_by_journal',
                },
            },
            title_page = {
                'Title',
                "Authors' names",
                'Affiliations',
                'Acknowledgements',
                'Declaration of Interest statement',
                'Corresponding author complete address including email',
            },
        },
        requirements_source = 'Verified from the Elsevier Author '
            .. 'Information Pack for the International Journal of '
            .. 'Surgery Case Reports (Guide for Authors), dated '
            .. '2023-09-15, accessed 2026-10-17 via a reproduction of '
            .. 'the pack; the live ScienceDirect Guide for Authors page '
            .. 'could not be fetched (HTTP 429).',
    },
    jbjs_case_connector = {
        article_types = {
            'Case Report',
        },
        instructions_url = 'https://sites.jbjs.org/cc/cc_author_submission_checklist.pdf',
        name = 'JBJS Case Connector',
        relationship = 'author',
        -- Facts encoded from the JBJS Case Connector New Submission
        -- Checklist (Rev. 2/23), accessed 2026-10-17. The fuller
        -- Instructions for Authors (Wolters Kluwer) could not be
        -- fetched (HTTP 403), so items the checklist does not state
        -- are recorded as not stated.
        requirements = {
            abstract = {
                headings = {
                    'Case',
                    'Conclusion',
                },
                max_words = 100,
            },
            article_types = {
                case_report = {
                    abstract_max_words = 100,
                    abstract_required = true,
                    label = 'Case Report',
                    manuscript_word_limit = { comparator = '<=', value = 1600 },
                    notes = {
                        'The 1,600-word limit includes the abstract and excludes references and figure legends.',
                        'Reports describe 3 or fewer patients.',
                        'A minimum of 1 year of follow-up since the last clinical intervention must be '
                            .. 'stated, or justified in a cover letter.',
                    },
                    structured_abstract = true,
                },
            },
            checklist = {
                'Unblinded title page and manuscript as individual Word files',
                '12 pt Times New Roman or Calibri, double-spaced, continuous line numbering',
                'Figure/video legend directly after References',
                'All figures, tables, videos, and appendices cited in ascending numerical order',
                'Relevant histopathology included where applicable (tumors, tumor-like lesions, adverse '
                    .. 'local tissue reactions)',
                'Videos uploaded to the Video Submission site with all identifying information blinded',
                'The listed corresponding author is the person submitting the manuscript',
            },
            figures = {
                files = 'separate individual files',
                formats = {
                    'TIFF',
                    'EPS',
                },
            },
            formatting = {
                double_spaced = true,
                file_format = 'Microsoft Word (PDFs are not accepted)',
                line_numbers = true,
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated in the JBJS Case Connector new-submission checklist (Rev. 2/23); '
                        .. 'the fuller Instructions for Authors could not be fetched.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'Not stated in the JBJS Case Connector new-submission checklist (Rev. 2/23); '
                        .. 'the fuller Instructions for Authors could not be fetched.',
                    status = 'not_stated_by_journal',
                },
                data_availability = {
                    note = 'Not stated in the JBJS Case Connector new-submission checklist (Rev. 2/23); '
                        .. 'the fuller Instructions for Authors could not be fetched.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    condition = 'at revision',
                    note = 'Copyright Transfer, Conflict of Interest, and Figure/Video Permission forms '
                        .. 'are optional for new submissions and are requested by the editorial staff if '
                        .. 'a revision is submitted.',
                    status = 'required_conditional',
                },
                funding = {
                    note = 'Not stated in the JBJS Case Connector new-submission checklist (Rev. 2/23); '
                        .. 'the fuller Instructions for Authors could not be fetched.',
                    status = 'not_stated_by_journal',
                },
                irb_ethics = {
                    condition = 'case reports',
                    location = 'After the Introduction, before the case section',
                    note = 'Patient consent for submission is obtained and stated in the manuscript; '
                        .. 'parent/guardian consent for minors. No identifying patient information: dates '
                        .. 'in relative terms and ages over 89 aggregated as 90+ (HIPAA).',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated in the JBJS Case Connector new-submission checklist (Rev. 2/23); '
                        .. 'the fuller Instructions for Authors could not be fetched.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated in the JBJS Case Connector new-submission checklist (Rev. 2/23); '
                        .. 'the fuller Instructions for Authors could not be fetched.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    note = 'Not stated in the JBJS Case Connector new-submission checklist (Rev. 2/23); '
                        .. 'the fuller Instructions for Authors could not be fetched.',
                    status = 'not_stated_by_journal',
                },
            },
            tables = {
                notes = {
                    'Tables are uploaded as individual Word files with titles; they are not embedded '
                        .. 'in the manuscript.',
                },
            },
            title_page = {
                'Title',
                'Author names',
                'Affiliations',
                'Corresponding author name and email',
            },
        },
        requirements_source = 'Verified from the JBJS Case Connector '
            .. 'New Submission Checklist (Rev. 2/23), sites.jbjs.org, '
            .. 'accessed 2026-10-17; the fuller Instructions for '
            .. 'Authors (Wolters Kluwer) could not be fetched (HTTP '
            .. '403), so items the checklist does not state are '
            .. 'recorded as not stated.',
    },
    jim = {
        article_types = {
            'Original Research',
            'Brief Report',
            'Systematic Review',
            'Review',
            'Research Tools and Issues',
            'Experimental Biology Symposia',
            'Letters to the Editor',
        },
        instructions_url = 'https://journals.sagepub.com/author-instructions/IMJ',
        name = 'Journal of Investigative Medicine',
        relationship = 'author',
        -- Facts encoded from the Journal of Investigative Medicine
        -- submission guidelines (SAGE), accessed 2026-10-17.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Purpose',
                    'Study Type',
                    'Population',
                    'Assessment Technique(s) or Outcome(s)',
                    'Statistical Tests',
                    'Results',
                    'Data Conclusion',
                },
                max_words = 350,
                variants = {
                    'Brief Reports and Reviews use an unstructured abstract (max 350 words).',
                },
            },
            article_types = {
                brief_report = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    combined_items_max = 2,
                    label = 'Brief Report',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    structured_abstract = false,
                },
                experimental_biology_symposia = {
                    label = 'Experimental Biology Symposia',
                    manuscript_word_limit = { comparator = '<=', value = 6000 },
                    notes = {
                        'Most manuscripts are anticipated at 2,000-6,000 words.',
                        'A Key Messages summary box is required (3-5 sentences: what is already known; '
                            .. 'what this study adds; how it might affect research, practice or policy).',
                    },
                },
                letters_to_the_editor = {
                    label = 'Letters to the Editor',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                    max_references = 15,
                },
                original_research = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    combined_items_max = 6,
                    label = 'Original Research',
                    manuscript_word_limit = { comparator = '<=', value = 5000 },
                    notes = {
                        'A Key Messages summary box is required after the abstract (3-5 sentences: what '
                            .. 'is already known; what this study adds; how it might affect research, '
                            .. 'practice or policy).',
                    },
                    structured_abstract = true,
                },
                research_tools_and_issues = {
                    label = 'Research Tools and Issues',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                },
                review = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    label = 'Review',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    notes = {
                        'The word limit excludes references. No more than five figures.',
                    },
                    structured_abstract = false,
                },
                systematic_review = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    combined_items_max = 6,
                    label = 'Systematic Review',
                    manuscript_word_limit = { comparator = '<=', value = 5000 },
                    notes = {
                        'Follows the Original Research requirements.',
                    },
                    structured_abstract = true,
                },
            },
            checklist = {
                'Statements and Declarations section at the end of the article (inapplicable declarations '
                    .. 'appear as "Not applicable")',
                'EQUATOR reporting-guideline checklist uploaded at submission',
                'Funder name and grant/award number supplied',
                'Figure, table, and word counts supplied at submission',
                'Preprint DOI entered at submission if posted',
            },
            cover_letter = {
                elements = {
                    'Why the manuscript is suitable for publication in the journal',
                },
                required = true,
            },
            fees = {
                notes = {
                    'Optional open access via SAGE Choice is available for a fee (amount not stated).',
                },
                publication_fee = false,
                submission_fee = false,
            },
            references = {
                notes = {
                    'References numbered consecutively; journal titles abbreviated per the MEDLINE list; '
                        .. 'the style follows the Uniform Requirements.',
                },
                order = 'citation order',
                text_marker = 'superscript',
            },
            statements = {
                ai_disclosure = {
                    note = "AI chatbots may not be listed as authors; the publisher's generative-AI "
                        .. 'policy is referenced but its disclosure format is not stated in the guidelines '
                        .. 'reviewed.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'A contributions section is referenced only as applicable; no standalone '
                        .. 'requirement is stated in the guidelines reviewed.',
                    status = 'not_stated_by_journal',
                },
                data_availability = {
                    note = 'Data sharing is encouraged by the publisher but not required; no statement '
                        .. 'format is stated.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    location = 'Statements and Declarations',
                    note = 'Conflicts of interest are declared for every manuscript.',
                    status = 'required',
                },
                funding = {
                    location = 'Statements and Declarations (separate heading)',
                    note = 'Funding is declared under a separate heading in all articles, even if no '
                        .. 'funding was received.',
                    status = 'required',
                },
                irb_ethics = {
                    location = 'Statements and Declarations',
                    note = 'An ethics statement gives the committee name, institution, and approval '
                        .. 'number, and how consent was obtained (written, verbal, or waived).',
                    status = 'required',
                },
                keywords = {
                    location = 'After the abstract',
                    note = '4-5 keywords.',
                    status = 'required',
                },
                orcid = {
                    note = "The submitting author's ORCID iD is required at submission; co-authors are "
                        .. 'encouraged to link theirs before acceptance.',
                    status = 'required',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    location = 'End of the abstract',
                    note = 'Trials are registered in a WHO-approved registry at or before first '
                        .. 'enrollment; the registry name, URL, and number appear at the end of the abstract.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Title',
                'Author names and affiliations',
                'Corresponding author',
                'Acknowledgements',
                'Running head',
                'Abbreviations',
            },
        },
        requirements_source = 'Verified from the Journal of '
            .. 'Investigative Medicine submission guidelines (SAGE), '
            .. 'accessed 2026-10-17.',
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
        article_types = {
            'Research Article',
            'Review Article',
            'Case Report',
            'Letter to the Editor',
        },
        instructions_url = 'https://journals.healio.com/journal/ortho/information-for-authors?doi=10.3928%2FORTHO&publicationCode=ortho',
        name = 'Orthopedics',
        relationship = 'author',
        -- Facts encoded from the Orthopedics Information for Authors
        -- (Healio) and the SLACK Author Hub, accessed 2026-10-17.
        -- Word maxima exclude the title page, abstract, references,
        -- and figure captions.
        requirements = {
            abstract = {
                headings = {
                    'Background and Objective',
                    'Materials and Methods',
                    'Results',
                    'Conclusion',
                },
                variants = {
                    'Abstract limits differ by article type: 250 words for Research Articles and Case '
                        .. 'Reports; 100 words for Review Articles.',
                },
            },
            article_types = {
                case_report = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Case Report',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    max_references = 15,
                    notes = {
                        'No more than 3 figures; no tables.',
                    },
                    structured_abstract = true,
                },
                letter_to_the_editor = {
                    abstract_required = false,
                    label = 'Letter to the Editor',
                    manuscript_word_limit = { comparator = '<=', value = 500 },
                    max_references = 5,
                    notes = {
                        'No more than 1 figure.',
                    },
                },
                research_article = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Research Article',
                    manuscript_word_limit = { comparator = '<=', value = 2500 },
                    max_references = 40,
                    notes = {
                        'No more than 6 figures and 4 tables (stated separately).',
                    },
                    structured_abstract = true,
                },
                review_article = {
                    abstract_max_words = 100,
                    abstract_required = true,
                    label = 'Review Article',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    max_references = 70,
                    notes = {
                        'No more than 6 figures and 4 tables (stated separately).',
                    },
                    structured_abstract = true,
                },
            },
            checklist = {
                'Double-spaced, 1-inch margins, continuous page and line numbers',
                'Reporting guideline: CONSORT (trials), PRISMA (systematic/scoping reviews and '
                    .. 'meta-analyses), CARE (case reports, strongly recommended)',
            },
            fees = {
                notes = {
                    'Non-refundable $249 submission/processing fee for unsolicited Research Articles, '
                        .. 'Review Articles, Case Reports, and Tips & Techniques; peer review does not '
                        .. 'proceed until it is paid; HINARI Group A/B waivers are available.',
                    'Optional open access APC $2,751.',
                },
                submission_fee = true,
            },
            formatting = {
                double_spaced = true,
            },
            references = {
                notes = {
                    'References are listed numerically in citation order, not alphabetically.',
                },
                order = 'citation order',
                style = 'AMA',
                text_marker = 'superscript',
            },
            statements = {
                ai_disclosure = {
                    condition = 'AI tools were used in preparing the work',
                    location = 'Statement after References',
                    note = 'Use of AI is documented in the SLACK AI chart and in a statement after the '
                        .. 'References giving the tool, version, manufacturer, and dates; grammar, '
                        .. 'spelling, and reference checking are exempt.',
                    status = 'required_conditional',
                },
                contributions = {
                    note = 'Not stated by Orthopedics in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                data_availability = {
                    note = 'Not stated by Orthopedics in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = 'Every author completes an ICMJE conflict-of-interest form, due at revision.',
                    status = 'required',
                },
                funding = {
                    condition = 'funded work',
                    location = 'Title page',
                    note = "Grant support is acknowledged on the title page; the sponsor's role is "
                        .. 'described where the work is sponsored.',
                    status = 'required_conditional',
                },
                irb_ethics = {
                    condition = 'human-subjects research',
                    location = 'Materials and Methods',
                    note = 'IRB/ethics approval, the institution, and consent are stated in Materials '
                        .. 'and Methods.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated by Orthopedics in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated by Orthopedics in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'the manuscript reports a registered trial',
                    location = 'Title page',
                    note = 'Registration information appears on the title page.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Manuscript title',
                "Authors' names (no more than three academic degrees each)",
                'Professional affiliations with city',
                'Grant support acknowledgement, if applicable',
                "Corresponding author's name, address, telephone, email",
                "Corresponding author's or institution's X (Twitter) handle",
            },
        },
        requirements_source = 'Verified from the Orthopedics '
            .. 'Information for Authors (Healio) and the SLACK Author '
            .. 'Hub, accessed 2026-10-17.',
    },
    -- Additional venues profiled 2026-10-17 (no recorded
    -- relationship with Matt).
    academic_medicine = {
        article_types = {},
        name = 'Academic Medicine',
        requirements_source = "Not verified: the journal's author "
            .. 'guidelines could not be fetched on 2026-10-17 (the '
            .. 'Wolters Kluwer author page returned HTTP 403 and the '
            .. 'Oxford Academic page rendered no guideline content), '
            .. 'so no article types or requirements are recorded.',
    },
    artificial_intelligence_in_medicine = {
        article_types = {
            'Original research contributions',
            'Methodological reviews/surveys',
            'Position papers',
            'Editorials',
            'Guest editorials',
            'Letters to the editor',
            'Book reviews',
            'Erratum',
            'Historical perspectives',
            'In memoriam',
            'PhD projects',
        },
        instructions_url = 'https://www.sciencedirect.com/journal/artificial-intelligence-in-medicine/publish/guide-for-authors',
        name = 'Artificial Intelligence in Medicine',
        -- Facts encoded from the Artificial Intelligence in Medicine
        -- Guide for Authors (Elsevier / ScienceDirect), accessed
        -- 2026-10-17. The guide states no per-article-type word,
        -- reference, author, or figure limits, so the article-type
        -- entries carry labels only.
        requirements = {
            abstract = {
                max_words = 250,
                variants = {
                    'References should be avoided in the abstract; non-standard abbreviations are '
                        .. 'defined at first mention.',
                },
            },
            article_types = {
                book_reviews = {
                    label = 'Book reviews',
                },
                editorials = {
                    label = 'Editorials',
                },
                erratum = {
                    label = 'Erratum',
                },
                guest_editorials = {
                    label = 'Guest editorials',
                },
                historical_perspectives = {
                    label = 'Historical perspectives',
                },
                in_memoriam = {
                    label = 'In memoriam',
                },
                letters_to_the_editor = {
                    label = 'Letters to the editor',
                },
                methodological_reviews_surveys = {
                    label = 'Methodological reviews/surveys',
                },
                original_research_contributions = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Original research contributions',
                },
                phd_projects = {
                    label = 'PhD projects',
                },
                position_papers = {
                    label = 'Position papers',
                },
            },
            checklist = {
                'Highlights encouraged: 3-5 bullet points, max 85 characters each',
                'The work combines potential high impact in a medical/healthcare domain with strong '
                    .. 'methodological or theoretical novelty in AI/computer science (journal scope)',
            },
            fees = {
                notes = {
                    'For open access articles the authors are responsible for the Article Publishing '
                        .. 'Charge if the article is accepted (amount not stated in the guide).',
                },
            },
            references = {
                notes = {
                    'Journal names abbreviated per the List of Title Word Abbreviations; any consistent '
                        .. 'style is accepted at submission and the journal style is applied at proof '
                        .. 'stage.',
                },
                order = 'citation order',
                text_marker = 'square brackets',
            },
            statements = {
                ai_disclosure = {
                    condition = 'generative AI was used in preparing the work',
                    location = 'Declaration section before References',
                    note = 'Use of generative AI in manuscript preparation is declared before the '
                        .. 'References; basic tools are exempt.',
                    status = 'required_conditional',
                },
                contributions = {
                    note = 'The corresponding author provides CRediT contribution roles for all authors.',
                    status = 'required',
                },
                data_availability = {
                    note = "Data deposit and citation are encouraged under the publisher's research-data "
                        .. 'Option B; no availability statement is required.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = 'Competing interests are declared for every manuscript.',
                    status = 'required',
                },
                funding = {
                    note = 'Funding sources are declared for every manuscript.',
                    status = 'required',
                },
                irb_ethics = {
                    note = 'Authors confirm at submission whether an ethics statement is needed; where '
                        .. 'one is, it gives the approval date and reference and how consent was '
                        .. 'obtained, or states why none is needed.',
                    status = 'required',
                },
                keywords = {
                    note = '1-7 keywords, in English.',
                    status = 'required',
                },
                orcid = {
                    note = 'Not stated by Artificial Intelligence in Medicine in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    note = 'Trials are registered in a public registry at or before enrollment onset; '
                        .. 'the registration number appears in the manuscript, preferably at the end of '
                        .. 'the abstract.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Article title',
                'Author given and family names',
                'Affiliations (full name and postal address including country)',
                'Corresponding author indicated, with email address on the title page',
                'Present/permanent address as a footnote where applicable',
            },
        },
        requirements_source = 'Verified from the Artificial '
            .. 'Intelligence in Medicine Guide for Authors (Elsevier / '
            .. 'ScienceDirect), accessed 2026-10-17.',
    },
    bmc_medical_education = {
        article_types = {
            'Research article',
            'Review',
            'Database article',
            'Software article',
            'Study protocol',
            'Matters Arising',
            'Comment',
        },
        instructions_url = 'https://bmcmededuc.biomedcentral.com/submission-guidelines',
        name = 'BMC Medical Education',
        -- Facts encoded from the BMC Medical Education submission
        -- guidelines (BioMed Central / Springer Nature), including
        -- the Research article and Review article-type pages,
        -- accessed 2026-10-17.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Methods',
                    'Results',
                    'Conclusions',
                },
                max_words = 350,
                variants = {
                    'Research abstracts add a Trial registration section where applicable.',
                    'Do not cite references in the abstract; minimise abbreviations.',
                },
            },
            article_types = {
                comment = {
                    label = 'Comment',
                    notes = {
                        'Article-type page not reviewed; limits not recorded.',
                    },
                },
                database_article = {
                    label = 'Database article',
                    notes = {
                        'Article-type page not reviewed; limits not recorded.',
                    },
                },
                matters_arising = {
                    label = 'Matters Arising',
                    notes = {
                        'Article-type page not reviewed; limits not recorded.',
                    },
                },
                research_article = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    label = 'Research article',
                    notes = {
                        'Systematic and scoping reviews are submitted as Research articles.',
                    },
                    structured_abstract = true,
                },
                review = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    label = 'Review',
                    notes = {
                        'Narrative reviews are generally commissioned; unsolicited Reviews are '
                            .. "considered only at the Editor's discretion.",
                    },
                },
                software_article = {
                    label = 'Software article',
                    notes = {
                        'Article-type page not reviewed; limits not recorded.',
                    },
                },
                study_protocol = {
                    label = 'Study protocol',
                    notes = {
                        'Article-type page not reviewed; limits not recorded.',
                    },
                },
            },
            checklist = {
                'Full Declarations section with every subheading ("Not applicable" where a section does not apply)',
                'Figure titles of at most 15 words; legends of at most 300 words; figure files of at '
                    .. 'most 10 MB; additional files of at most 20 MB each',
                'Transparent peer review: reviewer reports are published alongside the article if published',
            },
            cover_letter = {
                elements = {
                    'Why the manuscript should be published in BMC Medical Education',
                    'Any issues relating to the journal policies',
                    'Declaration of any competing interests',
                    'Confirmation that all authors have approved the manuscript for submission',
                    'Confirmation that the content has not been published or submitted for publication elsewhere',
                },
                required = true,
            },
            fees = {
                notes = {
                    'Article Processing Charge on acceptance: £2,490 / $3,090 / €2,690 (plus VAT where '
                        .. 'applicable); country-tiered APC pricing pilot applies.',
                },
                publication_fee = true,
            },
            figures = {
                legend_max_words = 300,
            },
            references = {
                notes = {
                    'Journal names abbreviated per Index Medicus/MEDLINE.',
                },
                order = 'citation order',
                style = 'Vancouver',
            },
            statements = {
                ai_disclosure = {
                    condition = 'a large language model was used in the work',
                    location = 'Methods',
                    note = 'LLM use is documented in the Methods; an LLM does not meet the authorship criteria.',
                    status = 'required_conditional',
                },
                contributions = {
                    location = 'Declarations',
                    note = 'Author contributions are stated in the Declarations section.',
                    status = 'required',
                },
                data_availability = {
                    location = 'Declarations (Availability of data and materials)',
                    note = 'Availability of the data and materials is stated for every manuscript.',
                    status = 'required',
                },
                disclosures_coi = {
                    location = 'Declarations (Competing interests)',
                    note = 'Competing interests are declared for every manuscript.',
                    status = 'required',
                },
                funding = {
                    location = 'Declarations (Funding)',
                    note = 'Funding is declared for every manuscript.',
                    status = 'required',
                },
                irb_ethics = {
                    location = 'Declarations (Ethics approval and consent to participate)',
                    note = 'The ethics subsection is mandatory for all manuscripts ("Not applicable" '
                        .. 'if irrelevant); human studies state the approval and consent, naming the '
                        .. 'committee and reference number, even where consent was waived.',
                    status = 'required',
                },
                keywords = {
                    note = 'Three to ten keywords.',
                    status = 'required',
                },
                orcid = {
                    note = 'Not stated by BMC Medical Education in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'a health care intervention on human participants',
                    location = 'Abstract (Trial registration section)',
                    note = 'Registry name, registration number, and date of registration appear in the ' .. 'abstract.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Title (including the study design, where appropriate)',
                'Full names and institutional addresses for all authors',
                'Corresponding author indicated',
                'Collaboration group listed as an author where applicable',
            },
        },
        requirements_source = 'Verified from the BMC Medical '
            .. 'Education submission guidelines (BioMed Central / '
            .. 'Springer Nature), including the Research article and '
            .. 'Review article-type pages, accessed 2026-10-17; '
            .. 'article-type pages for the remaining types were not '
            .. 'reviewed.',
    },
    jama = {
        article_types = {
            'Original Investigation',
            'Caring for the Critically Ill Patient',
            'Brief Report',
            'Research Letter',
            'Systematic Review',
            'Narrative Review',
            'Special Communication',
            'Viewpoint',
            'Perspective',
            'A Piece of My Mind',
            'Poetry',
            'Letter to the Editor',
            'Letter in Reply',
        },
        instructions_url = 'https://jamanetwork.com/journals/jama/pages/instructions-for-authors',
        name = 'JAMA',
        -- Facts encoded from the JAMA Instructions for Authors (JAMA
        -- Network), accessed 2026-10-17. Word counts exclude the
        -- abstract, tables, figures, acknowledgments, references, and
        -- online-only material. Clinical Trial and Meta-analysis are
        -- study-type overlays on Original Investigation, not separate
        -- article types.
        requirements = {
            abstract = {
                headings = {
                    'Importance',
                    'Objective',
                    'Design',
                    'Setting',
                    'Participants',
                    'Intervention(s) or Exposure(s)',
                    'Main Outcome(s) and Measure(s)',
                    'Results',
                    'Conclusions and Relevance',
                },
                max_words = 350,
                variants = {
                    'Meta-analysis abstracts: Importance, Objective, Data Sources, Study Selection, Data '
                        .. 'Extraction and Synthesis, Main Outcome(s) and Measure(s), Results, Conclusions '
                        .. 'and Relevance (max 350 words).',
                    'Systematic review abstracts: Importance, Objective, Evidence Review, Findings, '
                        .. 'Conclusions and Relevance (max 350 words).',
                    'Narrative review abstracts are 3-part structured (Importance, Observations, '
                        .. 'Conclusions and Relevance), max 300 words.',
                    'Trial Registration appears at the end of the abstract for trials.',
                    'Abstracts are not required for Editorials, Viewpoints, and special features.',
                },
            },
            article_types = {
                a_piece_of_my_mind = {
                    abstract_required = false,
                    label = 'A Piece of My Mind',
                    manuscript_word_limit = { comparator = '<=', value = 1600 },
                    max_authors = 3,
                },
                brief_report = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    combined_items_max = 3,
                    label = 'Brief Report',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    max_references = 15,
                    notes = {
                        'The 1,200-word length is the recommended length in the instructions.',
                    },
                    structured_abstract = true,
                },
                caring_for_the_critically_ill_patient = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Caring for the Critically Ill Patient',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    structured_abstract = true,
                },
                letter_in_reply = {
                    abstract_required = false,
                    label = 'Letter in Reply',
                    manuscript_word_limit = { comparator = '<=', value = 500 },
                    max_authors = 3,
                    max_references = 6,
                },
                letter_to_the_editor = {
                    abstract_required = false,
                    label = 'Letter to the Editor',
                    manuscript_word_limit = { comparator = '<=', value = 400 },
                    max_authors = 3,
                    max_references = 5,
                },
                narrative_review = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Narrative Review',
                    manuscript_word_limit = { comparator = '<=', value = 4200 },
                    max_references = 125,
                    notes = {
                        'A Key Points section (Question, Findings, Meaning; 75-100 words) is required.',
                    },
                    structured_abstract = true,
                },
                original_investigation = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Original Investigation',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'A Key Points section (Question, Findings, Meaning; 75-100 words) is required.',
                        'Clinical trials and meta-analyses follow these limits; references of 50-75 '
                            .. 'are typical for those study types.',
                    },
                    structured_abstract = true,
                },
                perspective = {
                    label = 'Perspective',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    max_authors = 4,
                    notes = {
                        'References: 10-25; 0-2 small figures/tables.',
                    },
                },
                poetry = {
                    abstract_required = false,
                    label = 'Poetry',
                    max_authors = 1,
                    notes = {
                        'Maximum 44 lines.',
                    },
                },
                research_letter = {
                    abstract_required = false,
                    combined_items_max = 2,
                    label = 'Research Letter',
                    manuscript_word_limit = { comparator = '<=', value = 800 },
                    max_references = 10,
                    notes = {
                        'Divided into Introduction, Methods, Results, and Discussion; no Abstract or Key '
                            .. 'Points; a supplement is allowed only for brief additional Methods.',
                    },
                },
                special_communication = {
                    abstract_required = true,
                    combined_items_max = 4,
                    label = 'Special Communication',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    max_references = 50,
                    structured_abstract = true,
                },
                systematic_review = {
                    abstract_max_words = 350,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Systematic Review',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'References of 50-75 are typical.',
                        'A Key Points section (Question, Findings, Meaning; 75-100 words) is required.',
                    },
                    structured_abstract = true,
                },
                viewpoint = {
                    abstract_required = false,
                    label = 'Viewpoint',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    max_authors = 4,
                    max_references = 7,
                    notes = {
                        '1,000 words when the manuscript includes 1 small table or figure.',
                        'No more than 2 affiliations per author.',
                    },
                },
            },
            checklist = {
                'Manuscript as a Word document (not PDF), double-spaced, 10-12 point font',
                'Titles limited to 100 characters including spaces (60 for shorter article types and subtitles)',
                'Figures as separate files, one per figure',
                'Presubmission inquiry required for Reviews and Special Communications',
                'Key Points section for research and review manuscripts',
            },
            cover_letter = {
                elements = {
                    'Complete corresponding-author contact information',
                    'Whether the authors have published, posted, or submitted any related papers from '
                        .. 'the same study',
                },
                required = true,
            },
            figures = {
                files = 'separate individual files, one per figure',
            },
            formatting = {
                double_spaced = true,
                file_format = 'Microsoft Word (not PDF)',
            },
            references = {
                notes = {
                    'AMA Manual of Style, 11th edition; manuscripts also follow the ICMJE Recommendations.',
                },
                order = 'citation order',
                style = 'AMA',
            },
            statements = {
                ai_disclosure = {
                    condition = 'AI tools were used in preparing the work',
                    location = 'Acknowledgment',
                    note = 'AI use is reported in the Acknowledgment with the tool, version, '
                        .. 'manufacturer, dates, and a description, with author confirmation of '
                        .. 'responsibility. AI drafting is prohibited for Opinion pieces, Letters, '
                        .. 'Online Comments, A Piece of My Mind, and Poetry; AI may not generate or '
                        .. 'format references; AI-generated clinical images are not permitted unless '
                        .. 'part of a formal research design, disclosed.',
                    status = 'required_conditional',
                },
                contributions = {
                    location = 'Acknowledgment / Authorship Form',
                    note = 'Contributions are stated for every manuscript.',
                    status = 'required',
                },
                data_availability = {
                    location = 'Manuscript (Data Sharing Statement)',
                    note = 'A Data Sharing Statement is required for all research reports; 1-2 named '
                        .. 'authors take responsibility for access to the data.',
                    status = 'required',
                },
                disclosures_coi = {
                    location = 'Acknowledgment and Authorship Form',
                    note = 'Conflicts of interest are disclosed for every author; a statement of none is '
                        .. 'given when there are none.',
                    status = 'required',
                },
                funding = {
                    location = 'Acknowledgment and submission system',
                    note = "Funding is stated for every manuscript, including the funder's role.",
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'human- or animal-subjects research',
                    location = 'Methods',
                    note = 'IRB/ethics approval or waiver is stated in Methods, and consent is described.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated by JAMA in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated by JAMA in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    location = 'End of the abstract and submission form',
                    note = 'Trials are registered in an ICMJE-acceptable registry before submission '
                        .. '(before enrollment for trials starting after July 2005); the registry name, '
                        .. 'number, and URL appear at the end of the abstract; the protocol and a '
                        .. 'CONSORT checklist and flow diagram are submitted.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Manuscript title',
                "Authors' full names, highest academic degrees, and affiliations",
                'Corresponding author name and complete contact information',
                'Manuscript word count (excluding title, abstract, acknowledgment, references, tables, '
                    .. 'figure legends)',
            },
        },
        requirements_source = 'Verified from the JAMA Instructions '
            .. 'for Authors (JAMA Network), accessed 2026-10-17.',
    },
    jamia = {
        article_types = {
            'Research and Applications',
            'Reviews',
            'Brief Communications',
            'Case Reports',
            'Perspectives',
            'Correspondence',
            'Editorials and Highlights',
        },
        instructions_url = 'https://academic.oup.com/jamia/pages/General_Instructions',
        name = 'Journal of the American Medical Informatics Association',
        -- Facts encoded from the JAMIA General Instructions (Oxford
        -- Academic), accessed 2026-10-17. Table and figure caps are
        -- stated separately by the journal, so they are recorded in
        -- notes rather than as combined maxima.
        requirements = {
            abstract = {
                headings = {
                    'Objective',
                    'Materials and Methods',
                    'Results',
                    'Discussion',
                    'Conclusion',
                },
                max_words = 250,
                variants = {
                    'Tutorial abstracts use the headings Objectives, Target Audience, and Scope.',
                    'References should not be included in abstracts.',
                    'Brief Communications, Case Reports, and Perspectives abstracts are limited to 150 words.',
                },
            },
            article_types = {
                brief_communications = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    label = 'Brief Communications',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    notes = {
                        'No more than 2 tables and 3 figures (stated separately); references unlimited.',
                    },
                    structured_abstract = true,
                },
                case_reports = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    label = 'Case Reports',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    notes = {
                        'No more than 2 tables and 3 figures (stated separately); references unlimited.',
                        'Case Reports here describe institutional/consortium experience implementing '
                            .. 'information systems or informatics methods, not single-patient cases.',
                    },
                    structured_abstract = true,
                },
                correspondence = {
                    label = 'Correspondence',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                    max_references = 5,
                    notes = {
                        'No more than 1 table and 1 figure.',
                    },
                },
                editorials_and_highlights = {
                    label = 'Editorials and Highlights',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                    max_references = 5,
                    notes = {
                        'Commissioned.',
                        'No more than 1 table and 1 figure.',
                    },
                },
                perspectives = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    label = 'Perspectives',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    notes = {
                        'No more than 2 tables and 3 figures (stated separately); references unlimited.',
                    },
                    structured_abstract = true,
                },
                research_and_applications = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Research and Applications',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    notes = {
                        'References unlimited; no more than 4 tables and 6 figures (stated separately).',
                        'The main text must include a Background and Significance section.',
                        'Systematic reviews follow this format.',
                    },
                    structured_abstract = true,
                },
                reviews = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    label = 'Reviews',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    notes = {
                        'References unlimited; no more than 4 tables and 6 figures (stated separately).',
                    },
                    structured_abstract = true,
                },
            },
            checklist = {
                'Double-spaced Word document (PDF accepted only with LaTeX source)',
                'Alt text for every image/figure, placed under the figure legend in the manuscript',
                'Related published materials (including conference papers) submitted as appendices for '
                    .. 'review only',
                'All analyses must be repeatable using the archived data; data may be deposited in '
                    .. 'Dryad at no charge',
            },
            fees = {
                notes = {
                    'Subscription publication carries no charge; optional open access is charged after '
                        .. 'acceptance (amount not stated; a society-membership discount is mentioned). '
                        .. 'No submission fee is stated.',
                },
            },
            references = {
                notes = {
                    'References numbered sequentially; journal titles abbreviated per MEDLINE style; '
                        .. 'no named style is stated.',
                },
                order = 'citation order',
            },
            statements = {
                ai_disclosure = {
                    condition = 'AI tools were used in preparing the work',
                    location = 'Cover letter and Methods or Acknowledgements',
                    note = 'AI use is disclosed in the cover letter and in Methods or Acknowledgements; '
                        .. 'AI may not be an author.',
                    status = 'required_conditional',
                },
                contributions = {
                    note = 'CRediT roles for all authors are given at submission.',
                    status = 'required',
                },
                data_availability = {
                    note = 'Inclusion of a Data Availability Statement is a requirement.',
                    status = 'required',
                },
                disclosures_coi = {
                    note = 'Conflicts of interest are confirmed at submission and published as a '
                        .. 'statement, including when none are declared.',
                    status = 'required',
                },
                funding = {
                    note = 'Funding is named at submission and stated after the main text.',
                    status = 'required',
                },
                irb_ethics = {
                    note = 'Not stated by JAMIA in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                keywords = {
                    location = 'Title page',
                    note = 'Up to five keywords; MeSH terms recommended.',
                    status = 'required',
                },
                orcid = {
                    note = 'Not stated by JAMIA in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    note = 'Not stated by JAMIA in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
            },
            title_page = {
                'Article title',
                'Corresponding author full name, postal address, email, telephone',
                'Co-authors: full name, department, institution, city, country, degree',
                'Up to five keywords',
                'Word count excluding title page, abstract, references, figures, and tables',
            },
        },
        requirements_source = 'Verified from the JAMIA General '
            .. 'Instructions (Oxford Academic), accessed 2026-10-17.',
    },
    jmir = {
        article_types = {
            'Original Paper',
            'Short Paper',
            'Review',
            'Research Letter',
            'Viewpoint',
            'Tutorial',
            'Commentary',
            'Editorial',
            'Guest Editorial',
            'Letter to the Editor',
            'Rapid Surveillance Report',
            'Open Source/Open Data',
            'Notes from the Field',
            'Personal Perspectives',
            'Patient Perspective',
            'In Memoriam',
            'Extraordinary Lives',
            'Corrigenda and Addenda',
        },
        instructions_url = 'https://www.jmir.org:443/ojs/index.php/jmir/about/editorialPolicies',
        name = 'Journal of Medical Internet Research',
        -- Facts encoded from the JMIR Editorial Policies /
        -- Instructions for Authors and the JMIR Publications
        -- article-types page, accessed 2026-10-17. Article types the
        -- publisher restricts to sister journals (Case Report,
        -- Implementation Report, Protocol, Proposal, Early Reports)
        -- are not listed for this journal.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Objectives',
                    'Methods',
                    'Results',
                    'Conclusions',
                },
                max_words = 450,
                variants = {
                    'Viewpoints, Editorials, and Guest Editorials take an unstructured abstract.',
                    'Commentaries take an unstructured abstract of at most 300 words.',
                    'Research Letters have no abstract; a one-sentence summary is recommended.',
                },
            },
            article_types = {
                commentary = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    combined_items_max = 1,
                    label = 'Commentary',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                    max_authors = 3,
                    max_references = 10,
                    structured_abstract = false,
                },
                corrigenda_and_addenda = {
                    label = 'Corrigenda and Addenda',
                },
                editorial = {
                    abstract_required = true,
                    label = 'Editorial',
                    structured_abstract = false,
                },
                extraordinary_lives = {
                    label = 'Extraordinary Lives',
                },
                guest_editorial = {
                    abstract_required = true,
                    label = 'Guest Editorial',
                    structured_abstract = false,
                },
                in_memoriam = {
                    label = 'In Memoriam',
                },
                letter_to_the_editor = {
                    abstract_required = false,
                    label = 'Letter to the Editor',
                },
                notes_from_the_field = {
                    label = 'Notes from the Field',
                },
                open_source_open_data = {
                    label = 'Open Source/Open Data',
                },
                original_paper = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Original Paper',
                    notes = {
                        'The word limit for this journal is stated on a linked JMIR page that was not '
                            .. 'reviewed; it is not recorded here.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                patient_perspective = {
                    label = 'Patient Perspective',
                },
                personal_perspectives = {
                    label = 'Personal Perspectives',
                },
                rapid_surveillance_report = {
                    label = 'Rapid Surveillance Report',
                },
                research_letter = {
                    abstract_required = false,
                    combined_items_max = 2,
                    label = 'Research Letter',
                    manuscript_word_limit = { comparator = '<=', value = 750 },
                    max_references = 10,
                },
                review = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Review',
                    structured_abstract = true,
                },
                short_paper = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Short Paper',
                    manuscript_word_limit = { comparator = '<=', value = 1500 },
                    notes = {
                        'Otherwise follows the Original Paper requirements.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                tutorial = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Tutorial',
                    notes = {
                        'Structured abstract if the tutorial presents evaluative data.',
                    },
                    structured_abstract = false,
                },
                viewpoint = {
                    abstract_required = true,
                    label = 'Viewpoint',
                    notes = {
                        'Abstract is unstructured; no word limit is stated for this article type.',
                    },
                    structured_abstract = false,
                },
            },
            checklist = {
                'Cover letter included',
                'Original research data are reported in IMRD format',
                'Reporting-guideline checklists supplied as a Multimedia Appendix where applicable',
                'Article type stated at the start of the manuscript when it is not a standard type',
                'ORCID iDs for all authors by publication',
            },
            cover_letter = {
                elements = {
                    'Essential information about the manuscript',
                    'Disclosure of any previous or simultaneous publication and of preprints',
                },
                required = true,
            },
            fees = {
                notes = {
                    'Article Processing Fee $3,350 on acceptance (Viewpoint $2,680; Research Letter '
                        .. '$1,675); optional fast-track fee $450.',
                },
                publication_fee = true,
                submission_fee = false,
            },
            references = {
                notes = {
                    'AMA Manual of Style, 11th edition (2020).',
                },
                order = 'citation order',
                style = 'AMA',
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated by JMIR in the guidelines reviewed (contrast JMIR Formative '
                        .. 'Research, where disclosure is required).',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'Author contributions are part of the required article format.',
                    status = 'required',
                },
                data_availability = {
                    note = 'A data availability section is part of the required article format.',
                    status = 'required',
                },
                disclosures_coi = {
                    note = 'Conflicts of interest are declared for every author; state "none declared" '
                        .. 'when there are none.',
                    status = 'required',
                },
                funding = {
                    note = 'All sources of funding are stated in the manuscript.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'human-subjects research',
                    location = 'Methods (Ethical Considerations subheading)',
                    note = 'Ethics approval and consent are covered under an Ethical Considerations '
                        .. 'subheading in Methods, with added detail for vulnerable populations.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Keywords are part of the required article format.',
                    status = 'required',
                },
                orcid = {
                    note = 'ORCID iDs for all authors are required by publication.',
                    status = 'required',
                },
                trial_registration = {
                    condition = 'randomized controlled trials',
                    note = 'Trials follow CONSORT; PROSPERO registration is recommended for systematic ' .. 'reviews.',
                    status = 'required_conditional',
                },
            },
        },
        requirements_source = 'Verified from the JMIR Editorial '
            .. 'Policies / Instructions for Authors and the JMIR '
            .. 'Publications article-types page, accessed 2026-10-17; '
            .. "the linked page stating this journal's word limit was "
            .. 'not reviewed.',
    },
    jmir_medical_education = {
        article_types = {
            'Original Paper',
            'Short Paper',
            'Review',
            'Research Letter',
            'Viewpoint',
            'Tutorial',
            'Commentary',
            'Editorial',
            'Guest Editorial',
            'Letter to the Editor',
            'Rapid Surveillance Report',
            'Open Source/Open Data',
            'Notes from the Field',
            'Personal Perspectives',
            'Patient Perspective',
            'In Memoriam',
            'Extraordinary Lives',
            'Corrigenda and Addenda',
        },
        instructions_url = 'https://mededu.jmir.org/author-information/instructions-for-authors',
        name = 'JMIR Medical Education',
        -- Facts encoded from the JMIR Medical Education Instructions
        -- for Authors and Submission Preparation Checklist (JMIR
        -- Publications), accessed 2026-10-17. Article types the
        -- publisher restricts to sister journals are not listed for
        -- this journal.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Objectives',
                    'Methods',
                    'Results',
                    'Conclusions',
                },
                max_words = 450,
                variants = {
                    'Viewpoints, Editorials, and Guest Editorials take an unstructured abstract.',
                    'Commentaries take an unstructured abstract of at most 300 words.',
                    'Research Letters have no abstract; a one-sentence summary is recommended.',
                },
            },
            article_types = {
                commentary = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    combined_items_max = 1,
                    label = 'Commentary',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                    max_references = 10,
                    structured_abstract = false,
                },
                corrigenda_and_addenda = {
                    label = 'Corrigenda and Addenda',
                },
                editorial = {
                    abstract_required = true,
                    label = 'Editorial',
                    structured_abstract = false,
                },
                extraordinary_lives = {
                    label = 'Extraordinary Lives',
                },
                guest_editorial = {
                    abstract_required = true,
                    label = 'Guest Editorial',
                    structured_abstract = false,
                },
                in_memoriam = {
                    label = 'In Memoriam',
                },
                letter_to_the_editor = {
                    abstract_required = false,
                    label = 'Letter to the Editor',
                },
                notes_from_the_field = {
                    label = 'Notes from the Field',
                },
                open_source_open_data = {
                    label = 'Open Source/Open Data',
                },
                original_paper = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Original Paper',
                    notes = {
                        'The word limit for this journal is stated on a linked JMIR page that was not '
                            .. 'reviewed; it is not recorded here.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                patient_perspective = {
                    label = 'Patient Perspective',
                },
                personal_perspectives = {
                    label = 'Personal Perspectives',
                },
                rapid_surveillance_report = {
                    label = 'Rapid Surveillance Report',
                },
                research_letter = {
                    abstract_required = false,
                    combined_items_max = 2,
                    label = 'Research Letter',
                    manuscript_word_limit = { comparator = '<=', value = 750 },
                    max_references = 10,
                },
                review = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Review',
                    structured_abstract = true,
                },
                short_paper = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Short Paper',
                    manuscript_word_limit = { comparator = '<=', value = 1500 },
                    notes = {
                        'Otherwise follows the Original Paper requirements.',
                    },
                    structured_abstract = true,
                    structured_manuscript = true,
                },
                tutorial = {
                    abstract_max_words = 450,
                    abstract_required = true,
                    label = 'Tutorial',
                    notes = {
                        'Structured abstract if the tutorial presents evaluative data.',
                    },
                    structured_abstract = false,
                },
                viewpoint = {
                    abstract_required = true,
                    label = 'Viewpoint',
                    notes = {
                        'Abstract is unstructured; no word limit is stated for this article type.',
                    },
                    structured_abstract = false,
                },
            },
            checklist = {
                'Cover letter included, stating agreement to the Article Processing Fee or requesting ' .. 'a waiver',
                'Manuscript as a Word .doc/.docx file',
                'Figures and tables in portrait orientation, placed inline',
                'Italics for emphasis (not bold or underline)',
                'No URLs in the body text; web resources are cited as references',
                'ORCID iDs for all authors by publication',
            },
            cover_letter = {
                elements = {
                    'Essential information about the manuscript',
                    'Disclosure of any previous or simultaneous publication and of preprints',
                    'Agreement to the Article Processing Fee, or a waiver request',
                },
                required = true,
            },
            fees = {
                notes = {
                    'Article Processing Fee $2,750 on acceptance (Viewpoint $2,200; Research Letter '
                        .. '$1,375); optional fast-track fee $450 (20-working-day decision).',
                },
                publication_fee = true,
                submission_fee = false,
            },
            references = {
                notes = {
                    'AMA Manual of Style, 11th edition (2020).',
                },
                order = 'citation order',
                style = 'AMA',
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated by JMIR Medical Education in the guidelines reviewed (contrast '
                        .. 'JMIR Formative Research, where disclosure is required).',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'Author contributions are part of the required article format.',
                    status = 'required',
                },
                data_availability = {
                    note = 'A data availability section is part of the required article format.',
                    status = 'required',
                },
                disclosures_coi = {
                    note = 'Conflicts of interest are declared for every author; state "none declared" '
                        .. 'when there are none.',
                    status = 'required',
                },
                funding = {
                    note = 'All sources of funding are stated in the manuscript.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'human-subjects research',
                    location = 'Methods (Ethical Considerations subheading)',
                    note = 'Ethics approval and consent are covered under an Ethical Considerations '
                        .. 'subheading in Methods, with added detail for vulnerable populations.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Keywords are part of the required article format.',
                    status = 'required',
                },
                orcid = {
                    note = 'ORCID iDs for all authors are required by publication.',
                    status = 'required',
                },
                trial_registration = {
                    condition = 'randomized controlled trials',
                    note = 'Trials follow CONSORT; PROSPERO registration is recommended for systematic ' .. 'reviews.',
                    status = 'required_conditional',
                },
            },
        },
        requirements_source = 'Verified from the JMIR Medical '
            .. 'Education Instructions for Authors and Submission '
            .. 'Preparation Checklist (JMIR Publications), accessed '
            .. "2026-10-17; the linked page stating this journal's "
            .. 'word limit was not reviewed.',
    },
    journal_of_arthroplasty = {
        article_types = {
            'Original Research Articles',
            'Abbreviated Clinical Follow-up Reports',
            'Review Articles',
        },
        instructions_url = 'https://www.sciencedirect.com/journal/the-journal-of-arthroplasty/publish/guide-for-authors',
        name = 'The Journal of Arthroplasty',
        -- Facts encoded from The Journal of Arthroplasty Guide for
        -- Authors (Elsevier / ScienceDirect), accessed 2026-10-17;
        -- the journal-specific checklist is dated 2025-04-17. Case
        -- Reports are no longer published by this journal (authors
        -- are redirected to Arthroplasty Today).
        requirements = {
            article_types = {
                abbreviated_clinical_follow_up_reports = {
                    label = 'Abbreviated Clinical Follow-up Reports',
                    notes = {
                        'Approximate length five manuscript pages; no word, abstract, or reference '
                            .. 'limits are stated.',
                    },
                },
                original_research_articles = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    combined_items_max = 10,
                    label = 'Original Research Articles',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'The 3,000-word limit includes the abstract and excludes references.',
                        'Systematic reviews and meta-analyses are submitted as Original Research '
                            .. 'Articles and must include a PRISMA checklist and a prospective PROSPERO '
                            .. 'registration number on the title page (or an explanation if not '
                            .. 'prospectively registered).',
                    },
                },
                review_articles = {
                    label = 'Review Articles',
                    notes = {
                        'Solicited by invitation only; no numeric limits are stated.',
                    },
                },
            },
            checklist = {
                'Manuscript fully blinded for double-anonymized review, with continuous line numbers '
                    .. 'and page numbers',
                'No "Abbreviations" or "Highlights" section',
                'Statistics section headed "Data Analyses"',
                'Study written in past tense; default spelling "orthopaedic"; prefer "arthroplasty" '
                    .. 'over "replacement"',
                'Corresponding author designated, with email and full postal address',
            },
            fees = {
                notes = {
                    'Open-access Article Publishing Charge USD 4,540 (excluding taxes); the subscription '
                        .. 'route carries no open-access publication fee.',
                },
            },
            formatting = {
                line_numbers = true,
                page_numbers = true,
            },
            references = {
                notes = {
                    'ICMJE/NLM formats; journal names abbreviated per the List of Title Word '
                        .. 'Abbreviations; no strict format is required at submission.',
                },
                order = 'citation order',
                text_marker = 'square brackets',
            },
            statements = {
                ai_disclosure = {
                    note = 'Use of generative AI in manuscript preparation is declared on submission.',
                    status = 'required',
                },
                contributions = {
                    note = 'The corresponding author provides CRediT contribution roles for all authors.',
                    status = 'required',
                },
                data_availability = {
                    note = "Data sharing is encouraged under the publisher's research-data Option B "
                        .. '(deposit, cite/link, or state why data cannot be shared); no availability '
                        .. 'statement is required.',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = "Disclosures are made through the publisher's declarations tool; a statement "
                        .. 'is required even when there is nothing to declare.',
                    status = 'required',
                },
                funding = {
                    note = "Funding sources and the sponsor's role are stated; a prescribed sentence "
                        .. 'is used when there was no funding.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'human-subjects research',
                    note = 'Current IRB approval must be in place before review for human-subjects '
                        .. 'manuscripts; approval is noted in the cover letter, and documentation is '
                        .. 'available on request.',
                    status = 'required',
                },
                keywords = {
                    location = 'After the abstract',
                    note = '1-6 keywords, in English.',
                    status = 'required',
                },
                orcid = {
                    note = 'Not stated by The Journal of Arthroplasty in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    location = 'Manuscript, preferably the end of the abstract',
                    note = 'The registration number appears in the manuscript.',
                    status = 'required_conditional',
                },
            },
        },
        requirements_source = 'Verified from The Journal of '
            .. 'Arthroplasty Guide for Authors (Elsevier / '
            .. 'ScienceDirect), accessed 2026-10-17.',
    },
    journal_of_bone_and_joint_surgery = {
        article_types = {},
        instructions_url = 'https://sites.jbjs.org/jbjs/jbjs_author_revised_submission_checklist.pdf',
        name = 'The Journal of Bone and Joint Surgery',
        platform = 'editorialmanager',
        -- Facts encoded from the JBJS author submission fees document
        -- and the JBJS Revised Submission Checklist (Rev. 5/25),
        -- sites.jbjs.org, accessed 2026-10-17. The main Instructions
        -- for Authors (Wolters Kluwer) could not be fetched (HTTP
        -- 403), so article types and per-type word limits are not
        -- recorded.
        requirements = {
            abstract = {
                max_words = 325,
                variants = {
                    'The 325-word abstract limit is stated in the Revised Submission Checklist (Rev. '
                        .. '5/25) as "if applicable"; per-article-type word limits appear only in the '
                        .. 'Instructions for Authors, which could not be fetched.',
                },
            },
            checklist = {
                'Author order on the unblinded title page exactly matches Editorial Manager',
                'Figure legend page at the end of the manuscript, after References',
                'All figures, tables, appendices, and videos cited in ascending numerical order',
                'Copyright Transfer Agreement completed for all authors',
            },
            fees = {
                notes = {
                    'Non-refundable $250 submission fee for unsolicited scientific (Clinical and '
                        .. 'Research) manuscripts, payable in full at first submission; a waiver is '
                        .. 'available when all authors reside in listed eligible countries.',
                },
                submission_fee = true,
            },
            figures = {
                formats = {
                    'TIFF',
                    'EPS',
                },
                min_resolution_dpi = 300,
                notes = {
                    'Figures at least 1,500 pixels in width or height; PNG files are not accepted.',
                },
            },
            formatting = {
                double_spaced = true,
                file_format = 'Microsoft Word',
                line_numbers = true,
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated in the JBJS documents reviewed (submission fees document and '
                        .. 'Revised Submission Checklist, Rev. 5/25).',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'CRediT roles are recorded for each author in Editorial Manager.',
                    status = 'required',
                },
                data_availability = {
                    note = 'Not stated in the JBJS documents reviewed (submission fees document and '
                        .. 'Revised Submission Checklist, Rev. 5/25).',
                    status = 'not_stated_by_journal',
                },
                disclosures_coi = {
                    note = 'A separate ICMJE conflict-of-interest form is completed for every author.',
                    status = 'required',
                },
                funding = {
                    note = 'Not stated in the JBJS documents reviewed (submission fees document and '
                        .. 'Revised Submission Checklist, Rev. 5/25).',
                    status = 'not_stated_by_journal',
                },
                irb_ethics = {
                    condition = 'work requiring IRB approval',
                    note = 'IRB approval forms are uploaded where applicable.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated in the JBJS documents reviewed (submission fees document and '
                        .. 'Revised Submission Checklist, Rev. 5/25).',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    location = 'Editorial Manager (Manuscript Data)',
                    note = 'An ORCID iD is recorded for each author in Editorial Manager.',
                    status = 'required',
                },
                trial_registration = {
                    note = 'Not stated in the JBJS documents reviewed (submission fees document and '
                        .. 'Revised Submission Checklist, Rev. 5/25).',
                    status = 'not_stated_by_journal',
                },
            },
            tables = {
                notes = {
                    'Tables are Word files containing titles.',
                },
            },
            title_page = {
                'Title',
                'Author list (order matches Editorial Manager)',
                'Institutional affiliations for each author',
                'Corresponding author labeled with contact information',
            },
        },
        requirements_source = 'Verified from the JBJS author '
            .. 'submission fees document and the JBJS Revised Submission '
            .. 'Checklist (Rev. 5/25), sites.jbjs.org, accessed '
            .. '2026-10-17; the main Instructions for Authors (Wolters '
            .. 'Kluwer) could not be fetched (HTTP 403), so article '
            .. 'types and per-type word limits are not recorded.',
    },
    medical_teacher = {
        article_types = {},
        name = 'Medical Teacher',
        requirements_source = "Not verified: the journal's author "
            .. 'guidelines (Taylor & Francis) could not be fetched on '
            .. '2026-10-17 (HTTP 403), so no article types or '
            .. 'requirements are recorded.',
    },
    nature_medicine = {
        article_types = {
            'Article',
            'Brief Communication',
            'Resource',
            'Analysis',
            'Correspondence',
            'Review',
            'Perspective',
            'Comment',
            'Matters Arising',
            'News & Views',
            'News Features',
        },
        instructions_url = 'https://www.nature.com/nm/about/content',
        name = 'Nature Medicine',
        -- Facts encoded from the Nature Medicine content-types and
        -- editorial-policies pages (nature.com), accessed 2026-10-17.
        -- Reference counts the journal phrases as guidelines are
        -- recorded in notes, not as maxima.
        requirements = {
            abstract = {
                max_words = 150,
                variants = {
                    'Abstracts are unreferenced and carry no section headings.',
                },
            },
            article_types = {
                analysis = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    combined_items_max = 6,
                    label = 'Analysis',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    notes = {
                        'The word limit excludes the abstract, online Methods, references, and legends.',
                        'References: up to about 60 (a guideline, not a strict maximum).',
                    },
                    structured_abstract = false,
                },
                article = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    combined_items_max = 6,
                    label = 'Article',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    notes = {
                        'The word limit excludes the abstract, Methods, references, and legends.',
                        'References: up to about 60 (a guideline, not a strict maximum).',
                    },
                    structured_abstract = false,
                },
                brief_communication = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    combined_items_max = 2,
                    label = 'Brief Communication',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    notes = {
                        'The word limit includes the abstract, references, and legends.',
                        'References: up to about 20 (a guideline, not a strict maximum).',
                    },
                    structured_abstract = false,
                },
                comment = {
                    label = 'Comment',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    notes = {
                        'Stated length 1,500-2,000 words; references up to about 15 (a guideline).',
                    },
                },
                correspondence = {
                    combined_items_max = 2,
                    label = 'Correspondence',
                    manuscript_word_limit = { comparator = '<=', value = 1000 },
                    max_references = 10,
                },
                matters_arising = {
                    label = 'Matters Arising',
                },
                news_views = {
                    label = 'News & Views',
                    notes = {
                        'Commissioned only.',
                    },
                },
                news_features = {
                    label = 'News Features',
                    notes = {
                        'Commissioned only.',
                    },
                },
                perspective = {
                    label = 'Perspective',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    max_references = 100,
                },
                resource = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    combined_items_max = 6,
                    label = 'Resource',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    notes = {
                        'The word limit excludes the abstract, online Methods, references, and legends.',
                        'References: up to about 60 (a guideline, not a strict maximum).',
                    },
                    structured_abstract = false,
                },
                review = {
                    label = 'Review',
                    manuscript_word_limit = { comparator = '<=', value = 4000 },
                    max_references = 100,
                },
            },
            checklist = {
                'Reporting summary/checklists per study type: CONSORT 2025 (trials), STROBE '
                    .. '(observational), PRISMA (systematic reviews/meta-analyses), STARD/REMARK '
                    .. '(diagnostic/biomarker), TRIPOD/TRIPOD-AI (prediction models), CONSORT-AI (AI trials)',
                'Trial submissions include the protocol and statistical analysis plan',
                'Writing must be accessible to non-specialists',
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated by Nature Medicine in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'Not stated by Nature Medicine in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                data_availability = {
                    note = 'A Data Availability statement is required for all original research; a '
                        .. 'separate Code Availability statement is required where custom code was used.',
                    status = 'required',
                },
                disclosures_coi = {
                    location = 'Manuscript (Competing Interests)',
                    note = 'A Competing Interests statement is required; the corresponding author '
                        .. 'submits it for all authors.',
                    status = 'required',
                },
                funding = {
                    note = "Funding is declared, including the sponsor's role, or it is stated that "
                        .. 'there was none.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'case reports and case series outside a trial',
                    note = 'Ethics approval and the consent process are stated for case reports and '
                        .. 'case series outside a trial.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated by Nature Medicine in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated by Nature Medicine in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    note = 'Trials are registered in the WHO ICTRP or ClinicalTrials.gov before first '
                        .. 'enrollment; the number appears in the abstract and Methods; primary results '
                        .. 'of non-registered trials are not considered.',
                    status = 'required_conditional',
                },
            },
        },
        requirements_source = 'Verified from the Nature Medicine '
            .. 'content-types and editorial-policies pages (nature.com), '
            .. 'accessed 2026-10-17.',
    },
    nejm = {
        article_types = {
            'Original Article',
            'Special Article',
            'Brief Report',
            'Clinical Problem-Solving',
            'Clinical Practice Review',
            'Other Review',
            'Editorial',
            'Perspective',
            'Clinical Implications of Basic Research',
            'Letter to the Editor',
            'Images in Clinical Medicine',
            'Videos in Clinical Medicine',
            'Special Report',
            'Health Law, Ethics, and Human Rights or Health Policy Report',
            'Medicine and Society',
            'Sounding Board',
        },
        instructions_url = 'https://www.nejm.org/author-center/article-types',
        name = 'New England Journal of Medicine',
        -- Facts encoded from the NEJM Author Center (article types,
        -- new manuscripts) and Editorial Policies (nejm.org), accessed
        -- 2026-10-17. Word counts include the introduction through
        -- the conclusion and exclude the abstract, figure legends,
        -- and table notes. Cover letters are not required.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Methods',
                    'Results',
                    'Conclusions',
                },
                max_words = 250,
                variants = {
                    'The trial registration number follows the abstract for trials.',
                },
            },
            article_types = {
                brief_report = {
                    abstract_max_words = 100,
                    abstract_required = true,
                    combined_items_max = 3,
                    label = 'Brief Report',
                    manuscript_word_limit = { comparator = '<=', value = 1600 },
                    max_references = 25,
                    notes = {
                        'A summary of at most 100 words replaces the abstract.',
                    },
                },
                clinical_implications_of_basic_research = {
                    label = 'Clinical Implications of Basic Research',
                    manuscript_word_limit = { comparator = '<=', value = 750 },
                    max_authors = 2,
                    max_references = 5,
                    notes = {
                        'No more than one figure.',
                    },
                },
                clinical_practice_review = {
                    label = 'Clinical Practice Review',
                    manuscript_word_limit = { comparator = '<=', value = 2500 },
                    max_authors = 2,
                    max_references = 50,
                    notes = {
                        'A small number of figures/tables.',
                    },
                },
                clinical_problem_solving = {
                    label = 'Clinical Problem-Solving',
                    manuscript_word_limit = { comparator = '<=', value = 2500 },
                    max_authors = 5,
                    max_references = 15,
                },
                editorial = {
                    abstract_required = false,
                    combined_items_max = 1,
                    label = 'Editorial',
                    manuscript_word_limit = { comparator = '<=', value = 750 },
                    max_authors = 2,
                    max_references = 10,
                },
                health_law_ethics_and_human_rights_or_health_policy_report = {
                    label = 'Health Law, Ethics, and Human Rights or Health Policy Report',
                    manuscript_word_limit = { comparator = '<=', value = 2500 },
                },
                images_in_clinical_medicine = {
                    label = 'Images in Clinical Medicine',
                    max_authors = 2,
                    notes = {
                        'No word limit stated (N/A in the article-types table).',
                    },
                },
                letter_to_the_editor = {
                    abstract_required = false,
                    label = 'Letter to the Editor',
                    manuscript_word_limit = { comparator = '<=', value = 400 },
                    max_authors = 3,
                    notes = {
                        '175 words when commenting on an NEJM article published within the most recent '
                            .. '3 weeks; 400 words otherwise.',
                    },
                },
                medicine_and_society = {
                    label = 'Medicine and Society',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                },
                original_article = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Original Article',
                    manuscript_word_limit = { comparator = '<=', value = 2700 },
                    max_references = 40,
                    notes = {
                        'No authorship limit for research articles.',
                    },
                    structured_abstract = true,
                },
                other_review = {
                    combined_items_max = 5,
                    label = 'Other Review',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    max_authors = 3,
                    max_references = 75,
                },
                perspective = {
                    label = 'Perspective',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    max_references = 5,
                    notes = {
                        'One to two authors preferred; usually one figure/table.',
                    },
                },
                sounding_board = {
                    label = 'Sounding Board',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                },
                special_article = {
                    abstract_max_words = 250,
                    abstract_required = true,
                    combined_items_max = 5,
                    label = 'Special Article',
                    manuscript_word_limit = { comparator = '<=', value = 2700 },
                    max_references = 40,
                    structured_abstract = true,
                },
                special_report = {
                    combined_items_max = 5,
                    label = 'Special Report',
                    manuscript_word_limit = { comparator = '<=', value = 2700 },
                    max_references = 40,
                },
                videos_in_clinical_medicine = {
                    label = 'Videos in Clinical Medicine',
                },
            },
            checklist = {
                'Word-count limits include the introduction through the conclusion/discussion and '
                    .. 'exclude abstracts, figure legends, and table notes',
                'Clinical research articles include a representativeness table in the Supplementary ' .. 'Appendix',
                'Presubmission inquiry strongly recommended for unsolicited reviews',
                'Do not discuss the submission with colleagues or journalists',
            },
            formatting = {
                double_spaced = true,
                file_format = 'single double-spaced file (preferably Word) containing text, references, '
                    .. 'figure legends, and tables',
            },
            references = {
                author_list_max = 6,
                et_al_after = 3,
                notes = {
                    'List all authors when six or fewer; with seven or more, list the first three '
                        .. 'followed by et al.',
                    'References are double-spaced and numbered consecutively as cited.',
                },
                order = 'citation order',
            },
            statements = {
                ai_disclosure = {
                    location = 'Cover letter and the submitted work',
                    note = 'AI use is disclosed at submission, in the cover letter and in the submitted '
                        .. 'work, naming the tools and what they produced; AI may not be an author, and '
                        .. 'generative AI may not create or fabricate visual content in scientific or '
                        .. 'medical images.',
                    status = 'required',
                },
                contributions = {
                    note = 'Authors sign an ICMJE authorship attestation before publication; writing '
                        .. 'assistance beyond copy editing is indicated.',
                    status = 'required',
                },
                data_availability = {
                    condition = 'clinical trials',
                    location = 'Manuscript (data-sharing statement)',
                    note = 'An ICMJE data-sharing statement is required of trial investigators; trials '
                        .. 'registered from 2019 carry a data-sharing plan in the registration. At least '
                        .. 'one author must have accessed and verified the primary data, named in the '
                        .. 'Supplementary Appendix.',
                    status = 'required_conditional',
                },
                disclosures_coi = {
                    note = 'Disclosure forms from all authors are posted with the article; authors of '
                        .. 'reviews and editorials are expected to have no significant relevant financial '
                        .. 'interests.',
                    status = 'required',
                },
                funding = {
                    condition = 'funded work',
                    note = 'Research articles list study sponsorship; disclosure forms are posted.',
                    status = 'required_conditional',
                },
                irb_ethics = {
                    condition = 'human- or animal-subjects research',
                    note = 'Protocol approval and written informed consent are stated where applicable.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated by NEJM in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated by NEJM in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    note = 'Trials are registered before enrollment in an acceptable registry; results '
                        .. 'of non-registered trials are turned away before peer review; interventional '
                        .. 'trials submit the protocol and statistical analysis plan.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Manuscript title',
                "Each author's name, highest degree, and affiliation/institution",
                'Contact information for one corresponding author (only one permitted)',
            },
        },
        requirements_source = 'Verified from the NEJM Author Center '
            .. '(article types, new manuscripts) and Editorial Policies '
            .. '(nejm.org), accessed 2026-10-17.',
    },
    npj_digital_medicine = {
        article_types = {
            'Article',
            'Brief Communication',
            'Comment',
            'Editorial',
            'Matters Arising',
            'News and Views',
            'Perspective',
            'Review',
        },
        instructions_url = 'https://www.nature.com/npjdigitalmed/content-types',
        name = 'npj Digital Medicine',
        -- Facts encoded from the npj Digital Medicine content-types
        -- page (nature.com), accessed 2026-10-17. The journal imposes
        -- no strict word limits; reference figures are guides that
        -- are not strictly enforced and are recorded in notes, not as
        -- maxima.
        requirements = {
            abstract = {
                variants = {
                    'No subheadings are permitted in abstracts.',
                    'Article abstracts are limited to 150 words; other types to 70 words.',
                },
            },
            article_types = {
                article = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    label = 'Article',
                    notes = {
                        'No strict manuscript word limit (the journal imposes none); references limited '
                            .. 'to about 60 (not strictly enforced); figure legends limited to 350 words '
                            .. 'per figure.',
                        'Systematic reviews, scoping reviews, and meta-analyses are submitted as '
                            .. 'Articles, not Reviews.',
                    },
                    structured_abstract = false,
                },
                brief_communication = {
                    abstract_max_words = 70,
                    abstract_required = true,
                    label = 'Brief Communication',
                    manuscript_word_limit = { comparator = '<=', value = 1500 },
                    notes = {
                        'Stated length 1,000-1,500 words, excluding abstract, Methods, references, and '
                            .. 'legends; references about 20 (a guide).',
                    },
                    structured_abstract = false,
                },
                comment = {
                    abstract_max_words = 70,
                    abstract_required = true,
                    label = 'Comment',
                    notes = {
                        'Typically 1,000-2,000 words (no hard cap stated); references typically at most 25.',
                    },
                    structured_abstract = false,
                },
                editorial = {
                    abstract_max_words = 70,
                    abstract_required = true,
                    label = 'Editorial',
                    notes = {
                        'Unsolicited Editorials are not considered.',
                    },
                    structured_abstract = false,
                },
                matters_arising = {
                    abstract_max_words = 70,
                    abstract_required = true,
                    label = 'Matters Arising',
                    manuscript_word_limit = { comparator = '<=', value = 1200 },
                    notes = {
                        'References typically at most 15.',
                    },
                    structured_abstract = false,
                },
                news_and_views = {
                    abstract_max_words = 70,
                    abstract_required = true,
                    label = 'News and Views',
                    notes = {
                        'By prior arrangement only; references typically at most 25.',
                    },
                    structured_abstract = false,
                },
                perspective = {
                    abstract_max_words = 70,
                    abstract_required = true,
                    label = 'Perspective',
                    manuscript_word_limit = { comparator = '<=', value = 3000 },
                    notes = {
                        'Should not normally exceed 3,000 words; references about 70 (not strictly enforced).',
                    },
                    structured_abstract = false,
                },
                review = {
                    abstract_max_words = 70,
                    abstract_required = true,
                    label = 'Review',
                    notes = {
                        'Typically 3,000-4,000 words (no hard cap stated); references about 60 (not '
                            .. 'strictly enforced).',
                    },
                    structured_abstract = false,
                },
            },
            checklist = {
                'Title of up to 15 words, with no punctuation, idioms, or puns (title page)',
                'Discussion in Articles contains no subheadings, limitations, or conclusions sections',
                'Supplementary Information is published as submitted, without journal editing',
            },
            cover_letter = {
                required = true,
            },
            figures = {
                legend_max_words = 350,
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated by npj Digital Medicine in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    note = 'Author contributions are stated by initials for every article type.',
                    status = 'required',
                },
                data_availability = {
                    note = 'A Data Availability statement is mandatory for Articles and Brief '
                        .. 'Communications; a Code Availability statement applies where applicable.',
                    status = 'required',
                },
                disclosures_coi = {
                    location = 'Manuscript (Competing Interests)',
                    note = 'A Competing Interests statement is mandatory for every article type.',
                    status = 'required',
                },
                funding = {
                    condition = 'funded work',
                    location = 'Acknowledgments',
                    note = 'Funding is declared in the Acknowledgments; a separate Funding statement is '
                        .. 'expressly not permitted.',
                    status = 'required_conditional',
                },
                irb_ethics = {
                    condition = 'work involving human or animal participants, material, or data',
                    note = 'Ethics approval and consent details are mandatory for such work.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated by npj Digital Medicine in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated by npj Digital Medicine in the documents reviewed.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    note = 'The registration number and date are mandatory; a CONSORT checklist is '
                        .. 'placed in the Supplementary Information for randomized trials.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Title (up to 15 words, no punctuation, idioms, or puns)',
                'Full author list',
                'Affiliations (institution, city, country)',
                'Corresponding author email address',
            },
        },
        requirements_source = 'Verified from the npj Digital '
            .. 'Medicine content-types page (nature.com), accessed '
            .. '2026-10-17.',
    },
    the_bmj = {
        article_types = {
            'Research',
            'Research Methods and Reporting',
            'Analysis',
            'Education',
            'Endgames and Minerva Pictures',
            'Editorials',
            'Rapid Responses',
            'Opinion',
            'BMJ Careers',
            'Obituaries',
            'Christmas issue',
            'Student',
            'Living systematic reviews',
        },
        instructions_url = 'https://www.bmj.com/about-bmj/resources-authors/article-types',
        name = 'The BMJ',
        -- Facts encoded from The BMJ article types, formatting
        -- guidance, and forms/policies/checklists pages (bmj.com /
        -- authors.bmj.com), accessed 2026-10-17. Research articles
        -- have no fixed word limit (stated expressly). The BMJ does
        -- not publish standard case reports (redirected to BMJ Case
        -- Reports) and will not consider tobacco-industry-funded
        -- studies.
        requirements = {
            abstract = {
                headings = {
                    'Objectives',
                    'Design',
                    'Setting',
                    'Participants',
                    'Interventions',
                    'Main outcome measures',
                    'Results',
                    'Conclusions',
                    'Trial registration',
                },
                max_words = 300,
                variants = {
                    'Interventions may be deleted if there were no interventions, but is normally '
                        .. 'included for randomized trials.',
                    'Trial registration (registry and number) is the last line, for clinical trials '
                        .. 'and, if available, observational studies and systematic reviews.',
                    'Abstracts should not include references.',
                    'Abstracts run 250-300 words; up to 400 for a CONSORT- or PRISMA-style abstract.',
                },
            },
            article_types = {
                analysis = {
                    combined_items_max = 3,
                    label = 'Analysis',
                    manuscript_word_limit = { comparator = '<=', value = 2000 },
                    max_references = 20,
                    notes = {
                        'Up to 3 non-text items (tables, boxes, figures).',
                    },
                },
                bmj_careers = {
                    label = 'BMJ Careers',
                },
                christmas_issue = {
                    label = 'Christmas issue',
                },
                education = {
                    label = 'Education',
                },
                endgames_and_minerva_pictures = {
                    label = 'Endgames and Minerva Pictures',
                },
                living_systematic_reviews = {
                    label = 'Living systematic reviews',
                },
                opinion = {
                    label = 'Opinion',
                },
                rapid_responses = {
                    label = 'Rapid Responses',
                },
                research_methods_and_reporting = {
                    label = 'Research Methods and Reporting',
                },
                student = {
                    label = 'Student',
                },
                editorials = {
                    label = 'Editorials',
                    manuscript_word_limit = { comparator = '<=', value = 800 },
                    notes = {
                        'References: 12-20.',
                    },
                },
                obituaries = {
                    label = 'Obituaries',
                    manuscript_word_limit = { comparator = '<=', value = 600 },
                    notes = {
                        'Stated length 500-600 words.',
                    },
                },
                practice_pointer = {
                    label = 'Practice Pointer',
                    manuscript_word_limit = { comparator = '<=', value = 1600 },
                    max_references = 20,
                    notes = {
                        'An Education format; Education content is commissioned and unsolicited '
                            .. 'submissions are not accepted.',
                    },
                },
                research = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    label = 'Research',
                    notes = {
                        'No fixed word-count limit is set for research articles; the main-text word '
                            .. 'count (excluding abstract, references, tables, boxes, figures) is '
                            .. 'declared at submission.',
                        'Abstracts run 250-300 words; up to 400 for a CONSORT- or PRISMA-style abstract.',
                        'A Patient and Public Involvement statement is required in the Methods '
                            .. '(stating explicitly if there was no involvement).',
                        'Research data must be disaggregated by sex and gender, or the impossibility '
                            .. 'explained as a limitation.',
                    },
                    structured_abstract = true,
                },
                state_of_the_art_review = {
                    label = 'State of the Art Review',
                    manuscript_word_limit = { comparator = '<=', value = 1800 },
                    max_references = 40,
                    notes = {
                        'An Education format; Education content is commissioned and unsolicited '
                            .. 'submissions are not accepted.',
                    },
                },
            },
            checklist = {
                'Manuscript as a Word document (PDF is not accepted), ordered: abstract, main text, '
                    .. 'tables in place, statements, references',
                '"What is already known / What this study adds" summary box for research',
                'Transparency declaration by the lead author/guarantor',
                'Licence statement granting The BMJ a worldwide licence inserted in the manuscript on ' .. 'submission',
            },
            cover_letter = {
                elements = {
                    'Previous publications from the same study',
                    'Prior electronic or preprint posting',
                    'Preferred and non-preferred reviewer suggestions',
                    'Good-publication-practice assurances',
                },
                required = true,
            },
            formatting = {
                file_format = 'Microsoft Word (PDF is not accepted)',
            },
            references = {
                author_list_max = 3,
                et_al_after = 3,
                notes = {
                    'First three authors listed, additional authors as et al.',
                },
                order = 'citation order',
                style = 'Vancouver',
            },
            statements = {
                ai_disclosure = {
                    condition = 'AI tools were used in preparing the work',
                    note = "The BMJ's AI policy applies to all authors and content; the detailed "
                        .. 'wording was not in the text reviewed.',
                    status = 'required_conditional',
                },
                contributions = {
                    note = "A contributorship statement names each author's contributions and a "
                        .. 'guarantor; the corresponding author attests that all authors meet the '
                        .. 'criteria and that none are omitted.',
                    status = 'required',
                },
                data_availability = {
                    note = 'A data-sharing statement is required for all research papers; anonymized '
                        .. 'individual participant data for trials submitted on or after 2024-05-01; '
                        .. 'analysis code as a supplemental file for research on or after 2024-05-01.',
                    status = 'required',
                },
                disclosures_coi = {
                    location = 'After the main text',
                    note = 'A competing-interests declaration follows the main text.',
                    status = 'required',
                },
                funding = {
                    note = "All funding sources and the funder's role (design, data, analysis, "
                        .. 'writing, decision) are stated, with confirmation of independence and full '
                        .. 'data access.',
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'research manuscripts',
                    note = 'Research manuscripts state whether approval was obtained or not required, '
                        .. 'name the committee/IRB and approval ID, and describe consent obtained '
                        .. 'before participation.',
                    status = 'required',
                },
                keywords = {
                    note = 'MeSH descriptors.',
                    status = 'required',
                },
                orcid = {
                    condition = 'corresponding authors of research articles',
                    note = 'ORCID iDs are mandated for corresponding authors of research articles; '
                        .. 'co-authors are encouraged.',
                    status = 'required_conditional',
                },
                trial_registration = {
                    condition = 'clinical trials',
                    location = 'Last line of the abstract',
                    note = 'Prospective registration before recruitment (trials starting after '
                        .. '2005-07-01) in the WHO ICTRP or ClinicalTrials.gov; the registry and '
                        .. 'number are the last line of the abstract.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Informative title (research papers: subtitle giving the study design)',
                'Each author: name, affiliation/job title at the time of the work, email',
                'Corresponding author (only one permitted): name, full address, email',
            },
        },
        requirements_source = 'Verified from The BMJ article types, '
            .. 'formatting guidance, and forms/policies/checklists '
            .. 'pages (bmj.com / authors.bmj.com), accessed 2026-10-17.',
    },
    the_lancet_digital_health = {
        article_types = {
            'Articles',
            'Comment',
            'Correspondence',
            'Reviews',
            'Health Policy',
            'Commissions',
            'Series',
            'Viewpoint',
            'Editorial',
        },
        instructions_url = 'https://www.thelancet.com/pb-assets/Lancet/authors/tldh-info-for-authors-1787150930507.pdf',
        name = 'The Lancet Digital Health',
        -- Facts encoded from The Lancet Digital Health Information
        -- for Authors (thelancet.com), accessed 2026-10-17. Word
        -- counts cover manuscript text only.
        requirements = {
            abstract = {
                headings = {
                    'Background',
                    'Methods',
                    'Findings',
                    'Interpretation',
                    'Funding',
                },
                max_words = 300,
                variants = {
                    'Semistructured summary in five paragraphs (Articles); RCT abstracts also follow '
                        .. 'the CONSORT extension for abstracts.',
                    'Reviews take a 150-word unstructured summary instead.',
                },
            },
            article_types = {
                articles = {
                    abstract_max_words = 300,
                    abstract_required = true,
                    label = 'Articles',
                    manuscript_word_limit = { comparator = '<=', value = 3500 },
                    max_references = 30,
                    notes = {
                        '4,500 words for randomised controlled trials; the count covers manuscript ' .. 'text only.',
                        'A "Research in context" panel is required (Evidence before this study; Added '
                            .. 'value of this study; Implications of all the available evidence) with '
                            .. 'no references.',
                    },
                    structured_abstract = true,
                },
                comment = {
                    combined_items_max = 1,
                    label = 'Comment',
                    manuscript_word_limit = { comparator = '<=', value = 750 },
                    max_references = 10,
                    notes = {
                        'Most Comments are commissioned.',
                    },
                },
                commissions = {
                    label = 'Commissions',
                },
                correspondence = {
                    combined_items_max = 1,
                    label = 'Correspondence',
                    manuscript_word_limit = { comparator = '<=', value = 400 },
                    max_authors = 5,
                    max_references = 5,
                    notes = {
                        'Letters responding to published content must arrive within 8 weeks of the '
                            .. "original item's online publication.",
                    },
                },
                editorial = {
                    label = 'Editorial',
                    notes = {
                        'Written in-house.',
                    },
                },
                health_policy = {
                    label = 'Health Policy',
                    notes = {
                        'Follows the Review guidelines; narrative reviews, not original research.',
                    },
                },
                reviews = {
                    abstract_max_words = 150,
                    abstract_required = true,
                    label = 'Reviews',
                    manuscript_word_limit = { comparator = '<=', value = 4500 },
                    max_references = 75,
                    notes = {
                        'The summary is unstructured; 5-6 illustrations are encouraged.',
                    },
                    structured_abstract = false,
                },
                series = {
                    label = 'Series',
                },
                viewpoint = {
                    label = 'Viewpoint',
                    manuscript_word_limit = { comparator = '<=', value = 2500 },
                    max_references = 30,
                },
            },
            checklist = {
                'First submission package: covering letter; manuscript including tables and panels; '
                    .. 'figures; Research in context panel (primary research Articles); author statement '
                    .. 'form; declaration of interests and source of funding statements; in-press papers '
                    .. 'with acceptance letters; protocols and CONSORT details for randomized trials',
                'Reporting: CONSORT 2025 (trials; CONSORT-AI/SPIRIT-AI for AI trials), STARD, STROBE, '
                    .. 'STREGA, PRISMA, GATHER as applicable',
                'Raw data may be required during review and up to 10 years after publication',
            },
            cover_letter = {
                elements = {
                    'Why the paper should be published in The Lancet Digital Health rather than '
                        .. 'elsewhere (entered at the "Enter Comments" stage)',
                },
                required = true,
            },
            fees = {
                notes = {
                    'Submission to all Lancet journals is free; an article processing charge is paid '
                        .. 'after acceptance for this gold open access journal (the amount is on the '
                        .. 'journal open-access page, not stated in the Information for Authors).',
                },
                publication_fee = true,
                submission_fee = false,
            },
            figures = {
                min_resolution_dpi = 300,
                notes = {
                    'Images at least 300 dpi and 107 mm wide; figures may be redrawn by journal ' .. 'illustrators.',
                },
            },
            references = {
                author_list_max = 6,
                et_al_after = 3,
                notes = {
                    'If six authors or fewer give all; if seven or more give the first three followed ' .. 'by et al.',
                },
                order = 'citation order',
                style = 'Vancouver',
                text_marker = 'superscript',
            },
            statements = {
                ai_disclosure = {
                    note = 'Not stated anywhere in The Lancet Digital Health Information for Authors.',
                    status = 'not_stated_by_journal',
                },
                contributions = {
                    location = 'End of the text',
                    note = 'Individual contributions are stated at the end of the text, including '
                        .. 'writers and editors; more than one author must have accessed and verified '
                        .. 'the underlying data, and all authors confirm full access and responsibility '
                        .. 'for publication.',
                    status = 'required',
                },
                data_availability = {
                    condition = 'research Articles',
                    note = 'A data-sharing statement states what data, when, where, and the access '
                        .. 'criteria; "undecided" is not acceptable.',
                    status = 'required_conditional',
                },
                disclosures_coi = {
                    note = 'A declaration of interests is part of the first-submission package; no '
                        .. "paper is published without all authors' signatures on the author statement "
                        .. 'form.',
                    status = 'required',
                },
                funding = {
                    note = 'A source-of-funding statement is part of the first-submission package; '
                        .. "Funding is the abstract's fifth paragraph.",
                    status = 'required',
                },
                irb_ethics = {
                    condition = 'identifiable patient material',
                    note = 'Written consent is obtained for identifiable material, images, and video; '
                        .. 'ethics-approval specifics are not stated in the document.',
                    status = 'required_conditional',
                },
                keywords = {
                    note = 'Not stated anywhere in The Lancet Digital Health Information for Authors.',
                    status = 'not_stated_by_journal',
                },
                orcid = {
                    note = 'Not stated anywhere in The Lancet Digital Health Information for Authors.',
                    status = 'not_stated_by_journal',
                },
                trial_registration = {
                    condition = 'interventional trials',
                    note = 'Trials are registered in a WHO ICTRP primary register or ClinicalTrials.gov '
                        .. 'with the 24-item dataset disclosed before first recruitment; trials '
                        .. 'enrolling from 2019-01-01 include a data-sharing plan in the registration.',
                    status = 'required_conditional',
                },
            },
            title_page = {
                'Brief title',
                'Author names',
                'Preferred degree (one only) per author',
                'Affiliations',
                'Full addresses of the authors',
                'Corresponding author name and address indicated separately, with email and telephone',
            },
        },
        requirements_source = 'Verified from The Lancet Digital '
            .. 'Health Information for Authors (thelancet.com), accessed '
            .. '2026-10-17.',
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

---Look up a journal profile by key. Unknown keys fail loudly
---(nil + error) instead of falling back to the generic profile: a
---silent fallback renders an anonymous scaffold that looks like
---success for a journal the registry knows nothing about. Callers
---that want the generic profile ask for the 'generic' key.
---@param name string profile key
---@return table|nil profile
---@return string|nil err
function M.get(name)
    local profile = M.profiles[name:lower()]
    if not profile then
        return nil, ('unknown journal key: %s'):format(name)
    end
    return profile
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
