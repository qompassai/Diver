-- /qompassai/Diver/lua/config/autocmds.lua
-- Qompass AI Diver Doc Utils Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local cmd = vim.cmd
local bo = vim.bo
local b = vim.b
local v = vim.v
local notify = vim.notify
local inspect = vim.inspect
local decode = vim.json.decode
local split = vim.split
local treesitter = vim.treesitter
local levels = vim.log.levels
local map = vim.keymap.set

-- New-file header generation. The lang configs' BufNewFile templates call
-- `require('research.docs').make_header(filepath, comment)`; it lives here
-- (rather than a new module) so those 19 call sites keep working unchanged.
-- Shape ports the local helper in lua/config/lang/latex.lua, except the
-- relative path keeps its leading slash so generated headers match the
-- repo's own (`-- /qompassai/Diver/...`, not `-- qompassai/Diver/...`).
local HEADER_RULE_WIDTH = 40
local HEADER_DESCRIPTION = 'Qompass AI - [ ]'
local HEADER_COPYRIGHT = 'Copyright (C) 2026 Qompass AI, All rights reserved'
local QOMPASSAI_MARKER = '/qompassai/'
---@param bufnr integer?
---@return integer
local function current_buf(bufnr)
    return bufnr or api.nvim_get_current_buf()
end
---@param bufnr integer?
---@return string
local function filetype(bufnr)
    local buf = current_buf(bufnr)
    return bo[buf] and bo[buf].filetype or ''
end
---@param filepath string absolute path of the file being created
---@return string path as shown in the header's first line
local function header_relpath(filepath)
    local idx = filepath:find(QOMPASSAI_MARKER, 1, true)
    if idx ~= nil then
        return filepath:sub(idx)
    end
    return fn.fnamemodify(filepath, ':~:.')
end
---Build the four-line comment header stamped into new files.
---
---Plain-language version: every new file starts with a little name tag --
---where it lives, a one-line description placeholder, the copyright line,
---and a row of dashes. This writes that name tag in whatever comment style
---the file's language needs: `#` for shell, `--` for Lua, `//` for C-like
---languages, and `<!--` / `/*` wrapped as block comments for HTML/CSS.
---
---Both arguments are programmer-supplied (call sites pass
---`vim.fn.expand('%:p')` and a literal), so bad input is a programmer error
---and raises via assert; the return is always a fresh four-line list.
---@param filepath string absolute path of the file being created
---@param comment string comment opener for the file's language
---@return string[] header_lines exactly four lines, ready for nvim_buf_set_lines
function M.make_header(filepath, comment)
    assert(type(filepath) == 'string' and filepath ~= '', 'make_header: filepath must be a non-empty string')
    assert(type(comment) == 'string' and comment ~= '', 'make_header: comment must be a non-empty string')
    local relpath = header_relpath(filepath)
    local solid
    if comment == '<!--' then
        solid = '<!-- ' .. string.rep('-', HEADER_RULE_WIDTH) .. ' -->'
        return {
            '<!-- ' .. relpath .. ' -->',
            '<!-- ' .. HEADER_DESCRIPTION .. ' -->',
            '<!-- ' .. HEADER_COPYRIGHT .. ' -->',
            solid,
        }
    elseif comment == '/*' then
        solid = '/* ' .. string.rep('-', HEADER_RULE_WIDTH) .. ' */'
        return {
            '/* ' .. relpath .. ' */',
            '/* ' .. HEADER_DESCRIPTION .. ' */',
            '/* ' .. HEADER_COPYRIGHT .. ' */',
            solid,
        }
    end
    solid = comment .. ' ' .. string.rep('-', HEADER_RULE_WIDTH)
    return {
        comment .. ' ' .. relpath,
        comment .. ' ' .. HEADER_DESCRIPTION,
        comment .. ' ' .. HEADER_COPYRIGHT,
        solid,
    }
end
---@return string
function M.foldexpr()
    local buf = api.nvim_get_current_buf()
    if b[buf].ts_folds == nil then
        local ft = filetype(buf)
        if ft == '' then
            return '0'
        end
        if ft:find('dashboard', 1, true) then
            b[buf].ts_folds = false
        else
            b[buf].ts_folds = pcall(treesitter.get_parser, buf)
        end
    end
    return b[buf].ts_folds and treesitter.foldexpr() or '0'
end
---@return string
function M.foldtext()
    local lines = api.nvim_buf_get_lines(0, v.lnum - 1, v.lnum, false)
    return lines[1] or ''
end

local function json_to_lua()
    local lines = api.nvim_buf_get_lines(0, 0, -1, false)
    local json = table.concat(lines, '\n')
    json = json:gsub('//[^\n]*', '')
    json = json:gsub('/%*.-%*/', '')
    json = json:gsub(',(%s*[}%]])', '%1')

    local ok, result = pcall(decode, json)
    if not ok then
        notify('Failed to parse JSON: ' .. tostring(result), levels.ERROR)
        return
    end
    cmd('vnew')
    api.nvim_buf_set_lines(0, 0, -1, false, split(inspect(result), '\n'))
    bo[0].filetype = 'lua'
end
local function jsonc_to_lua()
    local lines = api.nvim_buf_get_lines(0, 0, -1, false)
    local jsonc = table.concat(lines, '\n')

    jsonc = jsonc:gsub('//[^\n]*\n', '\n')
    jsonc = jsonc:gsub('/%*.-%*/', '')
    jsonc = jsonc:gsub(',(%s*[}%]])', '%1')

    local ok, result = pcall(decode, jsonc)
    if not ok then
        notify('JSON parse error: ' .. tostring(result), levels.ERROR)
        cmd('vnew')
        api.nvim_buf_set_lines(0, 0, -1, false, split(jsonc, '\n'))
        bo[0].filetype = 'json'
        return
    end
    cmd('vnew')
    api.nvim_buf_set_lines(0, 0, -1, false, split('return ' .. inspect(result), '\n'))
    bo[0].filetype = 'lua'
    notify('Converted to Lua', levels.INFO)
end
--[[
---@param infile string
local function markdown_pdf(infile)
  if infile == '' then
    notify('No markdown file to convert', levels.ERROR)
    return
  end
  local outfile = infile:gsub('%.%w+$', '') .. '.pdf'
  local args = {
    'pandoc',
    infile,
    '--from=markdown+yaml_metadata_block+implicit_figures+link_attributes',
    '--pdf-engine=xelatex',
    '--toc',
    '--metadata',
    'link-citations=true',
    '-o',
    outfile,
  }
  fn.jobstart(args, {
    on_exit = function(_, code)
      if code == 0 then
        notify('PDF written to ' .. outfile, levels.INFO)
      else
        notify('Pandoc failed for ' .. infile, levels.ERROR)
      end
    end,
  })
end
--]]
function M.setup()
    local group = api.nvim_create_augroup('docs', {
        clear = true,
    })

    api.nvim_create_autocmd('CmdlineChanged', {
        group = group,
        pattern = {
            ':',
            '/',
            '?',
        },
        callback = function()
            fn.wildtrigger()
        end,
    })

    api.nvim_create_autocmd({
        'FocusGained',
        'BufEnter',
        'CursorHold',
        'CursorHoldI',
    }, {
        group = group,
        callback = function(args)
            if not args or not args.buf then
                return
            end

            local ft = filetype(args.buf)
            if ft ~= '' and ft ~= 'vim' and fn.mode() ~= 'c' then
                cmd('checktime')
            end
        end,
    })
    api.nvim_create_user_command('Align', function(opts)
        local buf = api.nvim_get_current_buf()
        for lnum = opts.line1, opts.line2 do
            local lines = api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)
            local line = lines[1] or ''
            local annotation, description = line:match('^(%s*%-%-%-@%S+%s+%S+)%s+(.*)$')
            if annotation and description then
                api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, {
                    string.format('%-58s %s', annotation, description),
                })
            end
        end
    end, {
        range = true,
        desc = 'Align Lua annotation descriptions',
    })
    api.nvim_create_user_command('Json2Lua', json_to_lua, {
        desc = 'Convert current JSON buffer to Lua',
    })
    api.nvim_create_user_command('JsonC2Lua', jsonc_to_lua, {
        desc = 'Convert current JSONC buffer to Lua',
    })
    --[[
  api.nvim_create_user_command('MarkdownPdf', function(opts)
    local infile = opts.args ~= '' and opts.args or api.nvim_buf_get_name(0)
    markdown_pdf(infile)
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Convert current markdown file or given file to PDF',
  })
  --]]
    map('n', '<leader>cj', json_to_lua, {
        desc = 'Convert JSON to Lua',
        silent = true,
    })
    map('n', '<leader>cJ', jsonc_to_lua, {
        desc = 'Convert JSONC to Lua',
        silent = true,
    })
    --[[
  map('n', '<leader>cp', function()
    markdown_pdf(api.nvim_buf_get_name(0))
  end, {
    desc = 'Convert Markdown to PDF',
    silent = true,
  })
  --]]
end

return M
