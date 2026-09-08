-- /qompassai/Diver/lua/utils/docs/submission.lua
-- Qompass AI Diver Journal Submission Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@param root string
---@return table
function M.scan(root)
  local result = {
    manuscript = {},
    bibliography = {},
    figures = {},
    tables = {},
    supplements = {},
    cover_letters = {},
  }
  local files = vim.fs.find(function(name)
    return not name:match('^%.')
  end, {
    path = root,
    type = 'file',
    limit = math.huge,
  })
  for _, path in ipairs(files) do
    local name = fs.basename(path):lower()
    local ext = name:match('%.([^.]+)$') or ''
    if ext == 'bib' then
      result.bibliography[#result.bibliography + 1] = path
    elseif name:match('cover') and (ext == 'md' or ext == 'tex' or ext == 'docx') then
      result.cover_letters[#result.cover_letters + 1] = path
    elseif name:match('supp') then
      result.supplements[#result.supplements + 1] = path
    elseif name:match('table') then
      result.tables[#result.tables + 1] = path
    elseif ext == 'png' or ext == 'jpg' or ext == 'jpeg' or ext == 'tif' or ext == 'tiff' or ext == 'svg' or ext == 'pdf' then
      if name:match('fig') then
        result.figures[#result.figures + 1] = path
      end
    elseif ext == 'md' or ext == 'tex' or ext == 'docx' then
      result.manuscript[#result.manuscript + 1] = path
    end
  end
  return result
end

---@param root string
---@return string[]
function M.checklist(root)
  local scan = M.scan(root)
  local lines = {
    '# Submission Checklist',
    '',
    '- [ ] Manuscript title and short title verified',
    '- [ ] Author names, degrees, affiliations, and corresponding author verified',
    '- [ ] Abstract/keywords comply with journal article type',
    '- [ ] Word count verified',
    '- [ ] Tables cited in order and supplied in required format',
    '- [ ] Figures cited in order and supplied at required resolution',
    '- [ ] Figure legends present',
    '- [ ] References checked against DOI/PubMed/Crossref records',
    '- [ ] Duplicate references removed',
    '- [ ] Ethics/IRB statement included when applicable',
    '- [ ] Funding statement included',
    '- [ ] Conflict-of-interest statement included',
    '- [ ] Data/code availability statement included when applicable',
    '- [ ] Reporting guideline checklist included when applicable',
    '- [ ] Author contribution statement included when required',
    '- [ ] Cover letter prepared',
    '- [ ] Supplemental files named consistently',
    '- [ ] Final PDF inspected visually',
    '',
    '## Detected Files',
    '',
    ('- Manuscript candidates: %d'):format(#scan.manuscript),
    ('- Bibliography files: %d'):format(#scan.bibliography),
    ('- Figures: %d'):format(#scan.figures),
    ('- Tables: %d'):format(#scan.tables),
    ('- Supplements: %d'):format(#scan.supplements),
    ('- Cover letters: %d'):format(#scan.cover_letters),
  }
  return lines
end

function M.setup()
  api.nvim_create_user_command('SubmissionChecklist', function(opts)
    local root = opts.args ~= '' and fs.normalize(opts.args) or (vim.uv.cwd() or fn.getcwd())
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, M.checklist(root))
    vim.bo[buf].filetype = 'markdown'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.cmd.vnew()
    api.nvim_win_set_buf(0, buf)
  end, {
    nargs = '?',
    complete = 'dir',
    desc = 'Generate journal submission checklist',
  })
end

return M