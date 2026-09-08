#!/usr/bin/env lua5.1 JIT
-- /qompassai/Diver/lua/utils/docs/init.lua
-- Qompass AI Docs Utils Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}

M.bib = require('utils.docs.bib')
M.bounty = require('utils.docs.bounty')
M.citation = require('utils.docs.citation')
M.clipboard = require('utils.docs.clipboard')
M.diff = require('utils.docs.diff')
M.docs = require('utils.docs.docs')
M.journal = require('utils.docs.journal')
M.latex = require('utils.docs.latex')
M.license = require('utils.docs.license')
M.mail = require('utils.docs.mail')
M.manuscript = require('utils.docs.manuscript')
M.markdown = require('utils.docs.markdown')
M.mime = require('utils.docs.mime')
M.pdf = require('utils.docs.pdf')
M.research = require('utils.docs.research')
M.review = require('utils.docs.review')
M.submission = require('utils.docs.submission')

function M.setup()
  M.docs.setup()
  M.license.setup()
  M.pdf.setup()
  M.latex.setup()
  M.markdown.setup()
  M.citation.setup()
  M.bib.setup()
  M.manuscript.setup()
  M.review.setup()
  M.research.setup()
  M.diff.setup()
  M.submission.setup()
end

M.setup()

return M