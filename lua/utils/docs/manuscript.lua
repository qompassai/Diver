-- /qompassai/Diver/lua/utils/docs/manuscript.lua
-- Qompass AI Diver Manuscript Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@param text string
---@return table
function M.metadata(text)
  local fields = {
    manuscript_number = 'Manuscript Number:%s*([^\r\n]+)',
    full_title = 'Full Title:%s*([^\r\n]+)',
    short_title = 'Short Title:%s*([^\r\n]+)',
    article_type = 'Article Type:%s*([^\r\n]+)',
    keywords = 'Keywords:%s*([^\r\n]+)',
    word_count = 'Word Count:%s*(%d+)',
  }
  local out = {}
  for key, pattern in pairs(fields) do
    local value = text:match(pattern)
    if value then
      out[key] = vim.trim(value)
    end
  end
  return out
end

---@param bufnr? integer
---@return string[]
function M.headings(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local out = {}
  for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local heading
    if ft == 'markdown' then
      heading = line:match('^%s*#+%s+(.+)$')
    elseif ft == 'tex' or ft == 'plaintex' or ft == 'latex' then
      heading = line:match('\\section%*?{(.-)}')
        or line:match('\\subsection%*?{(.-)}')
        or line:match('\\subsubsection%*?{(.-)}')
    end
    if heading then
      out[#out + 1] = vim.trim(heading)
    end
  end
  return out
end

---@param path string
---@return string
function M.review_name(path)
  local stem = fs.basename(path):gsub('%.%w+$', '')
  return fs.joinpath(fs.dirname(path), stem .. '.review.md')
end

---@param metadata? table
---@return string[]
function M.author_template(metadata)
  metadata = metadata or {}
  return {
    '---',
    'title: "' .. (metadata.title or '') .. '"',
    'short-title: "' .. (metadata.short_title or '') .. '"',
    'author:',
    '  - name: ""',
    'bibliography: references.bib',
    'csl: ""',
    '---',
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
    '# References',
    '',
  }
end

---@param path string
function M.new(path)
  if fn.filereadable(path) == 1 then
    vim.cmd.edit(fn.fnameescape(path))
    return
  end
  fn.mkdir(fs.dirname(path), 'p')
  fn.writefile(M.author_template(), path)
  vim.cmd.edit(fn.fnameescape(path))
end

function M.setup()
  api.nvim_create_user_command('ManuscriptNew', function(opts)
    local path = opts.args ~= '' and opts.args or 'manuscript.md'
    M.new(fs.normalize(path))
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Create a manuscript Markdown skeleton',
  })

  api.nvim_create_user_command('ManuscriptOutline', function()
    vim.notify(vim.inspect(M.headings()), vim.log.levels.INFO)
  end, { desc = 'Show manuscript section outline' })
end

return M