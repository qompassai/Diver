-- /qompassai/Diver/lua/utils/docs/markdown.lua
-- Qompass AI Diver Markdown Authoring Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@param path? string
---@return string?
function M.current(path)
  path = path or api.nvim_buf_get_name(0)
  return path ~= '' and fs.normalize(path) or nil
end

---@param text string
---@return integer
function M.word_count_text(text)
  local count = 0
  for _ in text:gmatch('%S+') do
    count = count + 1
  end
  return count
end

---@param bufnr? integer
---@return integer
function M.word_count(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local text = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  text = text:gsub('```.-```', ' ')
  text = text:gsub('`[^`]+`', ' ')
  text = text:gsub('<[^>]+>', ' ')
  text = text:gsub('%[[^%]]+%]%([^%)]+%)', ' ')
  text = text:gsub('[#>*_~%-]', ' ')
  return M.word_count_text(text)
end

---@param path string
---@param output? string
function M.to_pdf(path, output)
  if fn.executable('pandoc') ~= 1 then
    vim.notify('pandoc is not executable', vim.log.levels.ERROR)
    return
  end
  output = output or path:gsub('%.md$', '') .. '.pdf'
  local engine = fn.executable('xelatex') == 1 and 'xelatex'
    or (fn.executable('lualatex') == 1 and 'lualatex')
    or nil

  local cmd = {
    'pandoc',
    path,
    '--from=markdown+yaml_metadata_block+implicit_figures+link_attributes',
    '--citeproc',
    '--metadata',
    'link-citations=true',
  }
  if engine then
    vim.list_extend(cmd, { '--pdf-engine=' .. engine })
  end
  vim.list_extend(cmd, { '-o', output })
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify('PDF written to ' .. output, vim.log.levels.INFO)
      else
        vim.notify(vim.trim(result.stderr or 'Pandoc failed'), vim.log.levels.ERROR)
      end
    end)
  end)
end

---@param path string
---@param output? string
function M.to_tex(path, output)
  if fn.executable('pandoc') ~= 1 then
    vim.notify('pandoc is not executable', vim.log.levels.ERROR)
    return
  end
  output = output or path:gsub('%.md$', '') .. '.tex'
  vim.system({
    'pandoc',
    path,
    '--from=markdown+yaml_metadata_block',
    '--to=latex',
    '--citeproc',
    '-o',
    output,
  }, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify('LaTeX written to ' .. output, vim.log.levels.INFO)
      else
        vim.notify(vim.trim(result.stderr or 'Pandoc failed'), vim.log.levels.ERROR)
      end
    end)
  end)
end

---@param line string
---@return string?
function M.heading_slug(line)
  local heading = line:match('^%s*#+%s+(.+)$')
  if not heading then
    return nil
  end
  return heading:lower()
    :gsub('`', '')
    :gsub('[^%w%s%-]', '')
    :gsub('%s+', '-')
    :gsub('%-+', '-')
    :gsub('^%-', '')
    :gsub('%-$', '')
end

function M.setup()
  api.nvim_create_user_command('MarkdownWords', function()
    vim.notify(('Markdown word count: %d'):format(M.word_count()), vim.log.levels.INFO)
  end, { desc = 'Count Markdown manuscript words' })

  api.nvim_create_user_command('MarkdownPdf', function(opts)
    local path = opts.args ~= '' and opts.args or M.current()
    if path then
      M.to_pdf(path)
    end
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Convert Markdown manuscript to PDF with Pandoc',
  })

  api.nvim_create_user_command('MarkdownTex', function(opts)
    local path = opts.args ~= '' and opts.args or M.current()
    if path then
      M.to_tex(path)
    end
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Convert Markdown manuscript to LaTeX with Pandoc',
  })
end

return M