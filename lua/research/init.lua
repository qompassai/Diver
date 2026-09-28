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
M.diff = require('research.diff')
M.discover = require('research.discover')
M.docs = require('research.docs')
M.journal = require('research.journal')
M.latex = require('research.latex')
M.license = require('research.license')
M.manuscript = require('research.manuscript')
M.markdown = require('research.markdown')
M.orcid = require('research.orcid')
M.pdf = require('research.pdf')
M.research = require('research.research')
M.review = require('research.review')
M.submission = require('research.submission')

function M.setup()
    M.ama.setup()
    M.docs.setup()
    M.discover.setup()
    M.license.setup()
    M.pdf.setup()
    M.latex.setup()
    M.markdown.setup()
    M.orcid.setup()
    M.citation.setup()
    M.bib.setup()
    M.journal.setup()
    M.manuscript.setup()
    M.review.setup()
    M.research.setup()
    M.diff.setup()
    M.submission.setup()
end

M.setup()

return M
