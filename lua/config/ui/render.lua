-- /qompassai/Diver/lua/config/markdown/render.lua
-- Qompass AI Diver UI Render Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@module 'config.ui.render'
local M = {}
local ns = vim.api.nvim_create_namespace('render')
---@param bufnr integer
local function clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end
---@param bufnr integer
---@return any|nil parse
local function get_parser(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'markdown')
  if not ok then
    return nil
  end
  return parser
end
local function magick_preview(path) ---@param path string
  local ok, magick = pcall(require, 'magick')
  if not ok then
    return
  end
  local ok_img, img = pcall(magick.load_image, path)
  if not ok_img then
    return
  end
  img:destroy()
end
---@return nil|string
local function render_buffer(bufnr) ---@param bufnr integer
  clear(bufnr)
  local parser = get_parser(bufnr)
  if not parser then
    return
  end
  local tstree = parser:parse()[1] ---@type table
  if not tstree then return end
  local root = tstree:root() ---@type table
  local query = vim.treesitter.query.parse(
    'markdown',
    [[
      (atx_heading) @heading
      (setext_heading) @heading

      (list_item
        (paragraph
          (inline) @list_marker)) @list

      (task_list_marker_unchecked) @checkbox_unchecked
      (task_list_marker_checked)   @checkbox_checked

      (image
        destination: (link_destination) @image_dest) @image
    ]]
  )
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    local sr, sc, er, ec = node:range()
    if name == 'heading' then
      local line = vim.api.nvim_buf_get_lines(bufnr, sr, sr + 1, false)[1] or ''
      local hashes = line:match('^(#+)')
      local level = hashes and #hashes or 1
      vim.api.nvim_buf_set_extmark(bufnr, ns, sr, 0, {
        virt_text = {
          {
            string.rep('▌', level) .. ' ',
            'Title',
          },
        },
        virt_text_pos = 'overlay',
      })
      vim.api.nvim_buf_set_extmark(bufnr, ns, er, 0, {
        virt_lines = {
          {
            {
              string.rep('─', math.max(10, #line)),
              'Comment',
            },
          },
        },
        virt_lines_above = false,
      })
    elseif name == 'list' then
      vim.api.nvim_buf_set_extmark(bufnr, ns, sr, 0, {
        virt_text = {
          {
            '• ',
            'Identifier',
          },
        },
        virt_text_pos = 'overlay',
      })
    elseif name == 'checkbox_unchecked' or name == 'checkbox_checked' then
      local icon = (name == 'checkbox_checked') and ' ' or ' '
      vim.api.nvim_buf_set_extmark(bufnr, ns, sr, sc, {
        virt_text = {
          {
            icon,
            'Identifier',
          },
        },
        virt_text_pos = 'overlay',
        end_col = ec,
      })
    elseif name == 'image' then
      -- Show an inline icon.
      vim.api.nvim_buf_set_extmark(bufnr, ns, sr, sc, {
        virt_text = { { '🖼 ', 'Special' } },
        virt_text_pos = 'overlay',
      })
    elseif name == 'image_dest' then
      local text = vim.treesitter.get_node_text(node, bufnr)
      if text and #text > 0 then
        text = text:gsub('^<', ''):gsub('>$', '') ---@type string
        if not text:match('^https?://') then
          magick_preview(text)
        end
      end
    end
  end
end
---@param bufnr integer
---@return nil
local function attach(bufnr)
  local group = vim.api.nvim_create_augroup('markdown_render_' .. bufnr, {
    clear = true,
  })
  vim.api.nvim_create_autocmd({
    'BufEnter',
    'TextChanged',
    'TextChangedI',
    'InsertLeave',
  }, {
    group = group,
    buffer = bufnr,
    callback = function(args)
      render_buffer(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = bufnr,
    callback = function(args)
      clear(args.buf)
    end,
  })
  render_buffer(bufnr)
end
---@return nil
function M.enable()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  if ft ~= 'markdown' and ft ~= 'markdown.mdx' then
    return
  end
  attach(bufnr)
end

---@return nil
function M.disable()
  local bufnr = vim.api.nvim_get_current_buf()
  local group = 'markdown_render_' .. bufnr
  pcall(vim.api.nvim_del_augroup_by_name, group)
  clear(bufnr)
end

---@return nil
function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  local group = 'markdown_render_' .. bufnr
  local ok = pcall(vim.api.nvim_get_autocmds, {
    group = group,
  })
  if ok then
    M.disable()
  else
    M.enable()
  end
end

return M