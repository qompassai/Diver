-- /qompassai/Diver/lua/utils/docs/research.lua
-- Qompass AI Diver Scholarly Research Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local M = {}

---@param text string
---@return string
local function urlencode(text)
  return (text:gsub('\n', ' '):gsub('([^%w%-_%.~ ])', function(c)
    return ('%%%02X'):format(c:byte())
  end):gsub(' ', '%%20'))
end

---@param url string
local function open(url)
  if fn.executable('xdg-open') == 1 then
    vim.system({ 'xdg-open', url }, { detach = true })
  else
    vim.notify(url, vim.log.levels.INFO)
  end
end

---@param query string
function M.pubmed(query)
  open('https://pubmed.ncbi.nlm.nih.gov/?term=' .. urlencode(query))
end

---@param query string
function M.crossref(query)
  open('https://search.crossref.org/?q=' .. urlencode(query))
end

---@param query string
function M.scholar(query)
  open('https://scholar.google.com/scholar?q=' .. urlencode(query))
end

---@param query string
function M.medrxiv(query)
  open('https://www.medrxiv.org/search/' .. urlencode(query))
end

---@param query string
function M.arxiv(query)
  open('https://arxiv.org/search/?query=' .. urlencode(query) .. '&searchtype=all')
end

---@return string
function M.selection_or_word()
  local mode = fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local start_pos = fn.getpos("'<")
    local end_pos = fn.getpos("'>")
    local lines = api.nvim_buf_get_text(
      0,
      start_pos[2] - 1,
      start_pos[3] - 1,
      end_pos[2] - 1,
      end_pos[3],
      {}
    )
    return table.concat(lines, ' ')
  end
  return fn.expand('<cword>')
end

function M.setup()
  api.nvim_create_user_command('PubMed', function(opts)
    M.pubmed(opts.args ~= '' and opts.args or M.selection_or_word())
  end, { nargs = '*', desc = 'Search PubMed' })

  api.nvim_create_user_command('Crossref', function(opts)
    M.crossref(opts.args ~= '' and opts.args or M.selection_or_word())
  end, { nargs = '*', desc = 'Search Crossref' })

  api.nvim_create_user_command('Scholar', function(opts)
    M.scholar(opts.args ~= '' and opts.args or M.selection_or_word())
  end, { nargs = '*', desc = 'Search Google Scholar' })

  api.nvim_create_user_command('MedRxiv', function(opts)
    M.medrxiv(opts.args ~= '' and opts.args or M.selection_or_word())
  end, { nargs = '*', desc = 'Search medRxiv' })

  api.nvim_create_user_command('ArxivSearch', function(opts)
    M.arxiv(opts.args ~= '' and opts.args or M.selection_or_word())
  end, { nargs = '*', desc = 'Search arXiv' })
end

return M