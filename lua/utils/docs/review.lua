-- /qompassai/Diver/lua/utils/docs/review.lua
-- Qompass AI Diver Journal Review Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@class ReviewAnchor
---@field page integer
---@field lines string
---@field title? string

---@param number integer
---@param anchor ReviewAnchor
---@return string[]
function M.comment_block(number, anchor)
  local title = anchor.title and (' — ' .. anchor.title) or ''
  return {
    ('## Comment %d%s — manuscript p. %d | lines %s'):format(
      number,
      title,
      anchor.page,
      anchor.lines
    ),
    '',
    '',
  }
end

---@param bufnr? integer
---@return integer
function M.next_comment_number(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local highest = 0
  for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local number = tonumber(line:match('^##%s+Comment%s+(%d+)'))
    if number and number > highest then
      highest = number
    end
  end
  return highest + 1
end

---@param page integer
---@param lines string
---@param title? string
function M.insert_comment(page, lines, title)
  local bufnr = api.nvim_get_current_buf()
  local number = M.next_comment_number(bufnr)
  local row = api.nvim_win_get_cursor(0)[1]
  api.nvim_buf_set_lines(bufnr, row, row, false, M.comment_block(number, {
    page = page,
    lines = lines,
    title = title,
  }))
  api.nvim_win_set_cursor(0, { row + 2, 0 })
end

---@param metadata table
---@return string[]
function M.template(metadata)
  local journal = metadata.journal or ''
  local number = metadata.manuscript_number or ''
  local title = metadata.title or ''
  return {
    '# Peer Review',
    '',
    '## ' .. journal,
    '',
    '### Manuscript Number: ' .. number,
    '',
    '### Title: *' .. title .. '*',
    '',
    '---',
    '',
    '## Review Scores',
    '',
    '| Category | Score |',
    '|---|---|',
    '| Reviewer Recommendation |  |',
    '| Overall Manuscript Rating | /100 |',
    '| Topic importance | /5 |',
    '| Conclusions supported | /5 |',
    '| Novelty | /5 |',
    '| Additional statistical review |  |',
    '',
    '---',
    '',
    '## Confidential Comments to the Editor',
    '',
    '',
    '---',
    '',
    '## General Comments to Authors',
    '',
    '',
    '---',
    '',
    '## Major Comments',
    '',
    '',
    '---',
    '',
    '## Minor Comments',
    '',
    '',
    '---',
    '',
    '## Suggested Editorial Disposition',
    '',
    '',
    '---',
    '',
    '## Key External Sources Used in This Review',
    '',
  }
end

---@param path string
function M.new(path)
  local journal = fn.input('Journal: ')
  if journal == '' then
    return
  end
  local manuscript_number = fn.input('Manuscript number: ')
  local title = fn.input('Title: ')
  fn.mkdir(fs.dirname(path), 'p')
  fn.writefile(M.template({
    journal = journal,
    manuscript_number = manuscript_number,
    title = title,
  }), path)
  vim.cmd.edit(fn.fnameescape(path))
end

---@param bufnr? integer
---@return table
function M.summary(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local out = {
    recommendation = nil,
    rating = nil,
    comments = 0,
    minor_comments = 0,
    sources = 0,
  }
  local in_minor = false
  local in_sources = false
  for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    out.recommendation = out.recommendation
      or line:match('|%s*Reviewer Recommendation%s*|%s*%*%*([^*]+)%*%*%s*|')
    out.rating = out.rating
      or tonumber(line:match('|%s*Overall Manuscript Rating%s*|%s*%*%*(%d+)/100%*%*%s*|'))
    if line:match('^##%s+Comment%s+%d+') then
      out.comments = out.comments + 1
    end
    if line:match('^##%s+Minor Comments') then
      in_minor = true
      in_sources = false
    elseif line:match('^##%s+Key External Sources') then
      in_minor = false
      in_sources = true
    elseif line:match('^##%s+') then
      in_minor = false
      in_sources = false
    elseif in_minor and line:match('^%d+%.%s+') then
      out.minor_comments = out.minor_comments + 1
    elseif in_sources and line:match('^%-%s+') then
      out.sources = out.sources + 1
    end
  end
  return out
end

function M.setup()
  api.nvim_create_user_command('ReviewNew', function(opts)
    local path = opts.args ~= '' and opts.args or 'review.md'
    M.new(fs.normalize(path))
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Create a structured journal peer review',
  })

  api.nvim_create_user_command('ReviewComment', function(opts)
    local page, lines, title = opts.args:match('^(%d+)%s+(%S+)%s*(.*)$')
    if not page or not lines then
      vim.notify('Usage: ReviewComment {page} {lines} [title]', vim.log.levels.ERROR)
      return
    end
    M.insert_comment(tonumber(page), lines, title ~= '' and title or nil)
  end, {
    nargs = '+',
    desc = 'Insert numbered review comment anchored to manuscript page/lines',
  })

  api.nvim_create_user_command('ReviewSummary', function()
    vim.notify(vim.inspect(M.summary()), vim.log.levels.INFO)
  end, { desc = 'Summarize current peer review' })
end

return M