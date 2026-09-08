-- /qompassai/Diver/lua/utils/docs/citation.lua
-- Qompass AI Diver Citation Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local M = {}

local patterns = {
  doi = '10%.%d%d%d%d+/%S+',
  pmid = '[Pp][Mm][Ii][Dd]%s*[:=]?%s*(%d+)',
  arxiv = '[Aa][Rr][Xx][Ii][Vv]%s*[:=]?%s*([%w%.%-/]+)',
}

---@param text string
---@return string?
function M.doi(text)
  local doi = text:match(patterns.doi)
  if not doi then
    return nil
  end
  return doi:gsub('[%]%[%)%}>,;%.]+$', '')
end

---@param text string
---@return string?
function M.pmid(text)
  return text:match(patterns.pmid)
end

---@param text string
---@return string?
function M.arxiv(text)
  return text:match(patterns.arxiv)
end

---@param doi string
---@return string
function M.doi_url(doi)
  return 'https://doi.org/' .. doi
end

---@param pmid string
---@return string
function M.pubmed_url(pmid)
  return 'https://pubmed.ncbi.nlm.nih.gov/' .. pmid .. '/'
end

---@param id string
---@return string
function M.arxiv_url(id)
  return 'https://arxiv.org/abs/' .. id
end

---@param url string
local function open(url)
  if fn.executable('xdg-open') == 1 then
    vim.system({ 'xdg-open', url }, { detach = true })
  else
    vim.notify(url, vim.log.levels.INFO)
  end
end

---@param text? string
function M.open_under_cursor(text)
  text = text or api.nvim_get_current_line()
  local doi = M.doi(text)
  if doi then
    open(M.doi_url(doi))
    return
  end
  local pmid = M.pmid(text)
  if pmid then
    open(M.pubmed_url(pmid))
    return
  end
  local arxiv = M.arxiv(text)
  if arxiv then
    open(M.arxiv_url(arxiv))
    return
  end
  vim.notify('No DOI, PMID, or arXiv identifier found', vim.log.levels.WARN)
end

---@param bufnr? integer
---@return table
function M.scan(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local out = { dois = {}, pmids = {}, arxiv = {} }
  local seen = { dois = {}, pmids = {}, arxiv = {} }
  for lnum, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local doi = M.doi(line)
    if doi and not seen.dois[doi] then
      seen.dois[doi] = true
      out.dois[#out.dois + 1] = { value = doi, lnum = lnum }
    end
    local pmid = M.pmid(line)
    if pmid and not seen.pmids[pmid] then
      seen.pmids[pmid] = true
      out.pmids[#out.pmids + 1] = { value = pmid, lnum = lnum }
    end
    local arxiv = M.arxiv(line)
    if arxiv and not seen.arxiv[arxiv] then
      seen.arxiv[arxiv] = true
      out.arxiv[#out.arxiv + 1] = { value = arxiv, lnum = lnum }
    end
  end
  return out
end

function M.setup()
  api.nvim_create_user_command('CitationOpen', function()
    M.open_under_cursor()
  end, { desc = 'Open DOI, PMID, or arXiv identifier under cursor' })

  api.nvim_create_user_command('CitationScan', function()
    local result = M.scan()
    vim.notify(vim.inspect(result), vim.log.levels.INFO)
  end, { desc = 'Scan current buffer for scholarly identifiers' })
end

return M