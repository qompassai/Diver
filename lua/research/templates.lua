-- /qompassai/Diver/lua/research/templates.lua
-- Qompass AI Diver Manuscript Template Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Per-journal manuscript skeletons in Markdown and LaTeX. A template is
-- a starting skeleton shaped by the journal profile (see
-- research.journal): section order, statement blocks, and legend stubs.
-- Statement blocks are fill-in sections; where a journal does not state
-- a format for a statement, the skeleton says so instead of inventing
-- one. Author identity fields (author_name, orcid) are filled by
-- research.manuscript from pass(1) — 'auth/fullname' and 'orcid/id',
-- the same entries qsync and research.zenodo read — when available,
-- and left blank when pass cannot provide them (locked agent).
-- Templates never submit anything anywhere.
local M = {}

local FORMATS = { latex = 'latex', markdown = 'markdown', md = 'markdown', tex = 'latex' }

---@param metadata table
---@param key string
---@param fallback string
---@return string
local function field(metadata, key, fallback)
    local value = metadata[key]
    if type(value) == 'string' and value ~= '' then
        return value
    end
    return fallback
end

---@param format string 'markdown'|'md'|'latex'|'tex'
---@return string|nil normalized 'markdown' or 'latex'
local function normalize_format(format)
    if type(format) ~= 'string' then
        return nil
    end
    return FORMATS[format:lower()]
end

---@param article_type string label or snake_case key
---@return string
local function normalize_type(article_type)
    return article_type:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
end

---@param metadata table
---@return string[]
local function jgme_original_research_markdown(metadata)
    local lines = {
        '---',
        'title: "' .. field(metadata, 'title', '') .. '"',
        'short-title: "' .. field(metadata, 'short_title', '') .. '"',
        'article-type: "Original Research"',
        'journal: "Journal of Graduate Medical Education"',
        'author:',
        '  - name: "' .. field(metadata, 'author_name', '') .. '"',
        '    degrees: ""',
        '    affiliation: ""',
        '    orcid: "' .. field(metadata, 'orcid', '') .. '"',
        '    role: ""',
        'bibliography: references.bib',
        '---',
        '',
        '# Title Page',
        '',
        '<!-- JGME title page, in order: title; authors with degrees and',
        '     affiliations/roles; prior or related publications (if any);',
        '     prior presentations (if any); acknowledgments; disclaimer;',
        '     corresponding author business address, phone, fax, email;',
        '     word counts (abstract and manuscript). -->',
        '',
        'Title: ' .. field(metadata, 'title', '<title>'),
        '',
        'Authors: <names, degrees, affiliations/roles>',
        '',
        'Prior or related publications: <none / describe>',
        '',
        'Prior presentations: <none / describe>',
        '',
        'Acknowledgments: <text>',
        '',
        'Disclaimer: <text or none>',
        '',
        'Corresponding author: <name, business address, phone, fax, email>',
        '',
        'Word counts: Abstract <n> / Manuscript <n>',
        '',
        '# Abstract',
        '',
        '<!-- Structured abstract (headings count toward the 250-word',
        '     limit): Background, Objective, Methods, Results, Conclusions.',
        '     Include the study year and the response rate in the abstract',
        '     Methods and Results. A QI variant (SQUIRE-EDU) exists. -->',
        '',
        '**Background:** ',
        '',
        '**Objective:** ',
        '',
        '**Methods:** ',
        '',
        '**Results:** ',
        '',
        '**Conclusions:** ',
        '',
        '# Introduction',
        '',
        '# Methods',
        '',
        '## AI Use Disclosure',
        '',
        '<!-- Required for research categories when AI tools were used:',
        '     tool, model, version, company, dates of use, prompts, how',
        '     output was processed, and how it was verified. AI cannot be',
        '     an author. Delete this block if no AI tools were used. -->',
        '',
        '## IRB/Ethics Statement',
        '',
        '<!-- Required at the END of Methods for human-subjects work:',
        '     approving or exempting body, approval or exemption, and',
        '     consent where relevant. Move this block to the end of',
        '     Methods before submission. -->',
        '',
        '# Results',
        '',
        '<!-- Report the response rate: eligible, actual number, percent. -->',
        '',
        '# Discussion',
        '',
        '## Limitations',
        '',
        '# Conclusions',
        '',
        '# Statements',
        '',
        '<!-- JGME states no standalone format for COI, funding, or author',
        '     contributions statements; complete the ICMJE conflict of',
        '     interest form the journal links. Keep completed forms with',
        '     the submission records. -->',
        '',
        '# Figure Legends',
        '',
        '<!-- Figures are separate individual files, cited consecutively;',
        '     legends are 200 words or fewer. Target 300 dpi (the JGME',
        '     checklist PDF states a 200 dpi minimum; see the flagged',
        '     discrepancy in the journal profile). -->',
        '',
        'Figure 1. <legend>',
        '',
        '# Tables',
        '',
        '<!-- Tables go at the end of the manuscript text file; boxes go',
        '     after References. Combined figures/tables/boxes: 5 maximum',
        '     for Original Research. -->',
        '',
        'Table 1. <title>',
        '',
        '# References',
        '',
        '<!-- AMA style: numbered in citation order, superscript in text,',
        '     MEDLINE journal abbreviations, up to 6 authors then et al. -->',
        '',
        '# Supplemental Material',
        '',
        '<!-- Survey/assessment instruments MUST be supplied as',
        '     supplemental material. List all supplemental items',
        '     consecutively here and cite each in the text. -->',
        '',
    }
    return lines
end

---@param metadata table
---@return string[]
local function jgme_original_research_latex(metadata)
    local lines = {
        '% JGME Original Research skeleton (LaTeX working draft).',
        '% JGME requires a Microsoft Word submission file: use this draft',
        '% for writing, then convert before upload.',
        '\\documentclass[12pt]{article}',
        '\\usepackage[margin=1in]{geometry}',
        '\\usepackage{setspace}',
        '\\doublespacing',
        '',
        '\\title{' .. field(metadata, 'title', '<title>') .. '}',
        '\\author{<names, degrees, affiliations/roles>}',
        '\\date{}',
        '',
        '\\begin{document}',
        '',
        '% Title page (JGME order): title; authors with degrees and',
        '% affiliations/roles; prior or related publications; prior',
        '% presentations; acknowledgments; disclaimer; corresponding',
        '% author business address, phone, fax, email; word counts.',
        '\\maketitle',
        '',
        'Prior or related publications: <none / describe>',
        '',
        'Prior presentations: <none / describe>',
        '',
        'Acknowledgments: <text>',
        '',
        'Disclaimer: <text or none>',
        '',
        'Corresponding author: <name, business address, phone, fax, email>',
        '',
        'Word counts: Abstract <n> / Manuscript <n>',
        '',
        '\\begin{abstract}',
        '% Structured abstract, 250 words maximum (headings count):',
        '\\textbf{Background:} ',
        '',
        '\\textbf{Objective:} ',
        '',
        '\\textbf{Methods:} ',
        '',
        '\\textbf{Results:} ',
        '',
        '\\textbf{Conclusions:} ',
        '\\end{abstract}',
        '',
        '\\section{Introduction}',
        '',
        '\\section{Methods}',
        '',
        '\\subsection{AI Use Disclosure}',
        '% Required when AI tools were used: tool, model, version,',
        '% company, dates, prompts, processing, verification.',
        '',
        '\\subsection{IRB/Ethics Statement}',
        '% Required at the END of Methods for human-subjects work:',
        '% approving/exempting body, approval or exemption, consent.',
        '',
        '\\section{Results}',
        '% Report the response rate: eligible, actual number, percent.',
        '',
        '\\section{Discussion}',
        '',
        '\\subsection{Limitations}',
        '',
        '\\section{Conclusions}',
        '',
        '% JGME states no standalone COI/funding/contributions format;',
        '% complete the ICMJE COI form linked by the journal.',
        '',
        '\\section*{Figure Legends}',
        '% Figures are separate files, cited consecutively, legends of',
        '% 200 words or fewer, 300 dpi target (checklist PDF says 200).',
        'Figure 1. <legend>',
        '',
        '\\section*{Tables}',
        '% Tables at the end of the text file; boxes after References.',
        'Table 1. <title>',
        '',
        '\\section*{References}',
        '% AMA style: numbered in citation order, superscript in text,',
        '% MEDLINE abbreviations, up to 6 authors then et al.',
        '',
        '\\end{document}',
        '',
    }
    return lines
end

---@param metadata table
---@return string[]
local function nejm_ai_original_research_markdown(metadata)
    local lines = {
        '---',
        'title: "' .. field(metadata, 'title', '') .. '"',
        'short-title: "' .. field(metadata, 'short_title', '') .. '"',
        'article-type: "Original Research"',
        'journal: "NEJM AI"',
        'author:',
        '  - name: "' .. field(metadata, 'author_name', '') .. '"',
        '    degrees: ""',
        '    affiliation: ""',
        '    orcid: "' .. field(metadata, 'orcid', '') .. '"',
        '    role: ""',
        'bibliography: references.bib',
        '---',
        '',
        '# Short Description',
        '',
        '<!-- Required for every NEJM AI article: 1-2 sentences. -->',
        '',
        '# Title Page',
        '',
        '<!-- NEJM AI title page: title; authors with degrees and',
        '     affiliations; ONE corresponding author during submission',
        '     and revision, with contact information; the corresponding',
        '     author ORCID iD (required at submission). -->',
        '',
        'Title: ' .. field(metadata, 'title', '<title>'),
        '',
        'Authors: <names, degrees, affiliations>',
        '',
        'Corresponding author: <name, address, email, ORCID iD>',
        '',
        'Word counts: Abstract <n> / Manuscript <n>',
        '',
        '# Abstract',
        '',
        '<!-- Structured abstract, 300 words maximum: Background,',
        '     Methods, Results, Conclusions. Report key findings as key',
        '     data. Add the trial registration number when applicable.',
        '     Body limit: 3,000 words, introduction through discussion',
        '     (abstract, figure legends, and table notes excluded). -->',
        '',
        '**Background:** ',
        '',
        '**Methods:** ',
        '',
        '**Results:** ',
        '',
        '**Conclusions:** ',
        '',
        '# Introduction',
        '',
        '# Methods',
        '',
        '## Machine Learning Reporting',
        '',
        '<!-- Report in full: problem statement and clinical relevance;',
        '     dataset source, size, characteristics, collection, and',
        '     preprocessing (with written permission for any dataset or',
        '     database used); algorithms and models with hyperparameters',
        '     and configurations; evaluation metrics and validation',
        '     strategy; limitations, data biases, and clinical',
        '     implications; reproducibility: code availability and',
        '     implementation detail. A reporting checklist is',
        '     recommended: TRIPOD-AI or MI-CLAIM. -->',
        '',
        '## Statistical Analysis',
        '',
        '<!-- All research articles undergo statistical review. State',
        '     sample-size and power considerations, primary and',
        '     secondary analysis methods, and missing-data handling',
        '     (complete-case analysis is generally not acceptable as the',
        '     primary analysis unless missingness is rare). Give',
        '     confidence intervals with significance tests; P values are',
        '     two-sided unless the design requires otherwise. Trials:',
        '     submit the protocol and statistical analysis plan, and',
        '     report the prespecified analyses. -->',
        '',
        '## IRB/Ethics Statement',
        '',
        '<!-- Required for research in human patients or animals: the',
        '     body that approved the work, how informed consent was',
        '     obtained, and the body that approved the consent document;',
        '     conduct accords with the Declaration of Helsinki. -->',
        '',
        '# Results',
        '',
        '# Discussion',
        '',
        '## Limitations',
        '',
        '<!-- Include study limitations, potential biases in the data,',
        '     and clinical implications. -->',
        '',
        '# Statements',
        '',
        '## Funding and Support',
        '',
        '<!-- Required when the work received support, financial or in',
        '     kind: name all sources of support. -->',
        '',
        '## Data Sharing Statement',
        '',
        '<!-- Required (ICMJE): state data availability — whether the',
        '     data are available, where, and under what conditions;',
        '     state code availability the same way. Trial registrations',
        '     carry a data sharing plan. -->',
        '',
        '## Author Contributions',
        '',
        '<!-- Per-author contributions, including who wrote the first',
        '     draft. Writing assistance beyond copy editing is named,',
        '     together with who paid for it. Equal contributions are',
        '     noted at the end of the author list. -->',
        '',
        '## Disclosures',
        '',
        '<!-- NEJM AI does not print a conflict of interest statement',
        '     in the article: every author completes the Convey',
        '     disclosure form (sent by email), and the disclosures are',
        '     published online with the article. Any COI statement',
        '     placed in the manuscript is deleted. Keep this heading as',
        '     the reminder; do not write a statement here. -->',
        '',
        '## AI Use Disclosure',
        '',
        '<!-- Required when artificial intelligence tools were used',
        '     (large language model, chatbot, image creator, ...):',
        '     disclose here AND in the cover letter — the technologies',
        '     used and what they produced. AI tools cannot be authors. -->',
        '',
        '# Figure Legends',
        '',
        '<!-- Figures are separate individual high-resolution files or',
        '     PDFs (uploaded individually even when embedded here), each',
        '     with a legend and a source line, cited in numerical order.',
        '     Figures carry no references and must stand alone.',
        '     Original Research: figures and tables together, 5 max. -->',
        '',
        'Figure 1. <legend>',
        '',
        '# Tables',
        '',
        '<!-- Tables are embedded in this text file, never uploaded as',
        '     separate files; each has a title and a source line and is',
        '     cited in numerical order. -->',
        '',
        'Table 1. <title>',
        '',
        '# References',
        '',
        '<!-- NEJM style: numbered in citation order. List every author',
        '     when there are six or fewer; with seven or more, list the',
        '     first three, then et al. Personal communications and',
        '     unpublished or in-preparation work are not references. -->',
        '',
        '# Supplementary Appendix',
        '',
        '<!-- Paginated, with a table of contents when applicable and a',
        '     self-contained reference list; submitted as PDF, Word, or',
        '     another editable text format. Clinical research studies',
        '     include a representativeness table here, cited in the text. -->',
        '',
    }
    return lines
end

---@param metadata table
---@return string[]
local function nejm_ai_original_research_latex(metadata)
    local lines = {
        '% NEJM AI Original Research skeleton (LaTeX).',
        '% NEJM AI strongly prefers a Word manuscript file; PDF and',
        '% LaTeX are accepted.',
        '\\documentclass[12pt]{article}',
        '\\usepackage[margin=1in]{geometry}',
        '',
        '\\title{' .. field(metadata, 'title', '<title>') .. '}',
        '\\author{<names, degrees, affiliations>}',
        '\\date{}',
        '',
        '\\begin{document}',
        '',
        '% Title page: title; authors with degrees and affiliations;',
        '% ONE corresponding author during submission and revision,',
        '% with contact information; corresponding author ORCID iD',
        '% (required at submission).',
        '\\maketitle',
        '',
        'Corresponding author: <name, address, email, ORCID iD>',
        '',
        'Word counts: Abstract <n> / Manuscript <n>',
        '',
        '% Short description (required for every article): 1-2 sentences.',
        '',
        '\\begin{abstract}',
        '% Structured abstract, 300 words maximum: Background, Methods,',
        '% Results, Conclusions. Report key findings as key data; add the',
        '% trial registration number when applicable. Body limit: 3,000',
        '% words, introduction through discussion (abstract, figure',
        '% legends, and table notes excluded).',
        '\\textbf{Background:} ',
        '',
        '\\textbf{Methods:} ',
        '',
        '\\textbf{Results:} ',
        '',
        '\\textbf{Conclusions:} ',
        '\\end{abstract}',
        '',
        '\\section{Introduction}',
        '',
        '\\section{Methods}',
        '',
        '\\subsection{Machine Learning Reporting}',
        '% Dataset (source, size, characteristics, collection,',
        '% preprocessing, permissions), model and hyperparameters,',
        '% evaluation metrics and validation strategy, limitations and',
        '% data biases, reproducibility and code availability.',
        '% Recommended checklists: TRIPOD-AI or MI-CLAIM.',
        '',
        '\\subsection{Statistical Analysis}',
        '% Statistical review is applied to all research articles:',
        '% sample-size/power, analysis methods, missing-data handling,',
        '% confidence intervals, two-sided P values unless the design',
        '% requires otherwise; trials add protocol and analysis plan.',
        '',
        '\\subsection{IRB/Ethics Statement}',
        '% Human or animal research: approving body, how consent was',
        '% obtained, body that approved the consent document;',
        '% Declaration of Helsinki.',
        '',
        '\\section{Results}',
        '',
        '\\section{Discussion}',
        '',
        '\\subsection{Limitations}',
        '',
        '\\section*{Funding and Support}',
        '% Support statement required when the work is funded.',
        '',
        '\\section*{Data Sharing Statement}',
        '% ICMJE data sharing statement: data availability and code',
        '% availability, where and under what conditions.',
        '',
        '\\section*{Author Contributions}',
        '% Per-author contributions; who wrote the first draft; paid',
        '% writing assistance named with its payer.',
        '',
        '\\section*{Disclosures}',
        '% No COI statement is printed in the article: every author',
        '% completes the Convey disclosure form sent by email; any COI',
        '% statement in the manuscript is deleted.',
        '',
        '\\section*{AI Use Disclosure}',
        '% When artificial intelligence tools were used (large language',
        '% model, chatbot, image creator): disclose here and in the',
        '% cover letter. AI tools cannot be authors.',
        '',
        '\\section*{Figure Legends}',
        '% Figures are separate individual high-resolution files or PDFs,',
        '% each with a legend and a source line, cited in order.',
        '% Original Research: figures and tables together, 5 maximum.',
        'Figure 1. <legend>',
        '',
        '\\section*{Tables}',
        '% Tables embedded in the text file, each with title and source',
        '% line, cited in numerical order.',
        'Table 1. <title>',
        '',
        '\\section*{References}',
        '% NEJM style: numbered in citation order; all authors when six',
        '% or fewer, first three then et al. when seven or more.',
        '',
        '\\end{document}',
        '',
    }
    return lines
end

---@param metadata table
---@return string[]
local function nejm_ai_letter_markdown(metadata)
    local lines = {
        '---',
        'title: "' .. field(metadata, 'title', '') .. '"',
        'article-type: "Letter to the Editor"',
        'journal: "NEJM AI"',
        'author:',
        '  - name: "' .. field(metadata, 'author_name', '') .. '"',
        '    degrees: ""',
        '    affiliation: ""',
        '    orcid: "' .. field(metadata, 'orcid', '') .. '"',
        'bibliography: references.bib',
        '---',
        '',
        '# Title Page',
        '',
        '<!-- Title; authors with degrees and affiliations; one',
        '     corresponding author with contact information and ORCID',
        '     iD. Letters carry no abstract. -->',
        '',
        'Title: ' .. field(metadata, 'title', '<title>'),
        '',
        'Authors: <names, degrees, affiliations>',
        '',
        'Corresponding author: <name, address, email, ORCID iD>',
        '',
        '# Letter',
        '',
        '<!-- 400 words maximum. At most one display item (figure or',
        '     table). Disclosures: every author completes the Convey',
        '     form sent by email; no COI statement goes in the letter.',
        '     Disclose any use of artificial intelligence tools here and',
        '     in the cover letter. -->',
        '',
        '# References',
        '',
        '<!-- 5 references maximum. The first reference is the article',
        '     this letter discusses. NEJM style: numbered in citation',
        '     order; all authors when six or fewer, first three then',
        '     et al. when seven or more. -->',
        '',
        '1. <article discussed>',
        '',
    }
    return lines
end

---@param metadata table
---@return string[]
local function nejm_ai_letter_latex(metadata)
    local lines = {
        '% NEJM AI Letter to the Editor skeleton (LaTeX).',
        '% NEJM AI strongly prefers a Word manuscript file; PDF and',
        '% LaTeX are accepted.',
        '\\documentclass[12pt]{article}',
        '\\usepackage[margin=1in]{geometry}',
        '',
        '\\title{' .. field(metadata, 'title', '<title>') .. '}',
        '\\author{<names, degrees, affiliations>}',
        '\\date{}',
        '',
        '\\begin{document}',
        '',
        '\\maketitle',
        '',
        'Corresponding author: <name, address, email, ORCID iD>',
        '',
        '% Letters carry no abstract. 400 words maximum; at most one',
        '% display item. Every author completes the Convey disclosure',
        '% form sent by email; no COI statement goes in the letter.',
        '% Disclose any use of artificial intelligence tools here and',
        '% in the cover letter.',
        '',
        '\\section*{Letter}',
        '',
        '\\section*{References}',
        '% 5 references maximum; the first is the article discussed.',
        '% NEJM style: numbered in citation order.',
        '1. <article discussed>',
        '',
        '\\end{document}',
        '',
    }
    return lines
end

---@param metadata table
---@param journal_name string
---@return string[]
local function generic_markdown(metadata, journal_name)
    local lines = {
        '---',
        'title: "' .. field(metadata, 'title', '') .. '"',
        'short-title: "' .. field(metadata, 'short_title', '') .. '"',
        'journal: "' .. journal_name .. '"',
        'author:',
        '  - name: "' .. field(metadata, 'author_name', '') .. '"',
        '    orcid: "' .. field(metadata, 'orcid', '') .. '"',
        'bibliography: references.bib',
        'csl: ""',
        '---',
        '',
        '# Title Page',
        '',
        'Title: ' .. field(metadata, 'title', '<title>'),
        '',
        'Authors: <names, degrees, affiliations>',
        '',
        'Corresponding author: <name, address, email>',
        '',
        'Word counts: Abstract <n> / Manuscript <n>',
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
        '# Disclosures',
        '',
        '<!-- Conflicts of interest for all authors. -->',
        '',
        '# IRB/Ethics Statement',
        '',
        '<!-- Approving or exempting body and approval/exemption, where',
        '     the work involves human subjects, animals, or records. -->',
        '',
        '# Funding',
        '',
        '<!-- Funders and grant numbers, or "None". -->',
        '',
        '# Author Contributions',
        '',
        '<!-- Per-author contributions. -->',
        '',
        '# Data Availability',
        '',
        '# Figure Legends',
        '',
        'Figure 1. <legend>',
        '',
        '# Tables',
        '',
        'Table 1. <title>',
        '',
        '# References',
        '',
    }
    return lines
end

---@param metadata table
---@param journal_name string
---@return string[]
local function generic_latex(metadata, journal_name)
    local lines = {
        '% Generic journal manuscript skeleton (LaTeX).',
        '% Target journal: ' .. journal_name,
        '\\documentclass[12pt]{article}',
        '\\usepackage[margin=1in]{geometry}',
        '',
        '\\title{' .. field(metadata, 'title', '<title>') .. '}',
        '\\author{<names, degrees, affiliations>}',
        '\\date{}',
        '',
        '\\begin{document}',
        '',
        '\\maketitle',
        '',
        'Corresponding author: <name, address, email>',
        '',
        'Word counts: Abstract <n> / Manuscript <n>',
        '',
        '\\begin{abstract}',
        '',
        '\\end{abstract}',
        '',
        '\\section{Introduction}',
        '',
        '\\section{Methods}',
        '',
        '\\section{Results}',
        '',
        '\\section{Discussion}',
        '',
        '\\section{Conclusions}',
        '',
        '\\section*{Disclosures}',
        '',
        '\\section*{IRB/Ethics Statement}',
        '',
        '\\section*{Funding}',
        '',
        '\\section*{Author Contributions}',
        '',
        '\\section*{Data Availability}',
        '',
        '\\section*{Figure Legends}',
        'Figure 1. <legend>',
        '',
        '\\section*{Tables}',
        'Table 1. <title>',
        '',
        '\\section*{References}',
        '',
        '\\end{document}',
        '',
    }
    return lines
end

---Render a manuscript skeleton.
---@param journal_key string profile key ('jgme', 'generic', ...)
---@param article_type string label ('Original Research') or key
---@param format string 'markdown'|'md'|'latex'|'tex'
---@param metadata? table optional { title, short_title }
---@return string[]|nil lines
---@return string|nil err
function M.render(journal_key, article_type, format, metadata)
    assert(type(journal_key) == 'string' and journal_key ~= '', 'journal key must be a string')
    assert(type(article_type) == 'string' and article_type ~= '', 'article type must be a string')
    local normalized_format = normalize_format(format)
    if not normalized_format then
        return nil, ('unknown template format: %s (expected markdown or latex)'):format(tostring(format))
    end
    metadata = metadata or {}
    local key = journal_key:lower()
    local type_key = normalize_type(article_type)
    if key == 'jgme' and type_key == 'original_research' then
        if normalized_format == 'markdown' then
            return jgme_original_research_markdown(metadata)
        end
        return jgme_original_research_latex(metadata)
    end
    if key == 'nejm_ai' and type_key == 'original_research' then
        if normalized_format == 'markdown' then
            return nejm_ai_original_research_markdown(metadata)
        end
        return nejm_ai_original_research_latex(metadata)
    end
    if key == 'nejm_ai' and type_key == 'letter_to_the_editor' then
        if normalized_format == 'markdown' then
            return nejm_ai_letter_markdown(metadata)
        end
        return nejm_ai_letter_latex(metadata)
    end
    local journal = require('research.journal')
    local profile = journal.get(key)
    local journal_name = profile.name or key
    if normalized_format == 'markdown' then
        return generic_markdown(metadata, journal_name)
    end
    return generic_latex(metadata, journal_name)
end

---@return string[] sorted supported format names
function M.formats()
    return { 'latex', 'markdown' }
end

---Templates register no commands of their own; :ManuscriptNew renders
---them (see research.manuscript).
---@return nil
function M.setup()
    return nil
end

return M
