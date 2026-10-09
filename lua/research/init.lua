#!/usr/bin/env lua5.1 JIT
-- /qompassai/Diver/lua/research/init.lua
-- Qompass AI Docs Utils Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}

M.ama = require('research.ama')
M.bib = require('research.bib')
M.citation = require('research.citation')
M.clipboard = require('research.clipboard')
M.deadlines = require('research.deadlines')
M.diff = require('research.diff')
M.discover = require('research.discover')
M.docs = require('research.docs')
M.journal = require('research.journal')
M.latex = require('research.latex')
M.license = require('research.license')
M.manuscript = require('research.manuscript')
M.markdown = require('research.markdown')
M.openalex = require('research.openalex')
M.orcid = require('research.orcid')
M.pdf = require('research.pdf')
M.research = require('research.research')
M.review = require('research.review')
M.submission = require('research.submission')
M.templates = require('research.templates')
M.watchlist = require('research.watchlist')
M.wos = require('research.wos')
M.zenodo = require('research.zenodo')

function M.setup()
    M.ama.setup()
    M.bib.setup()
    M.citation.setup()
    M.deadlines.setup()
    M.diff.setup()
    M.discover.setup()
    M.docs.setup()
    M.journal.setup()
    M.latex.setup()
    M.license.setup()
    M.manuscript.setup()
    M.markdown.setup()
    M.openalex.setup()
    M.orcid.setup()
    M.pdf.setup()
    M.research.setup()
    M.review.setup()
    M.submission.setup()
    M.templates.setup()
    M.watchlist.setup()
    M.wos.setup()
    M.zenodo.setup()
end

M.setup()

return M
