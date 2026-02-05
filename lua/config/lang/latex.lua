-- /qompassai/Diver/lua/config/lang/latex.lua
-- Qompass AI Diver LaTeX Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local latex = {}
local autocmd = vim.api.nvim_create_autocmd
local code_action = vim.lsp.buf.code_action
local fmt = vim.lsp.buf.format
---@return string
local function get_relative_path(filepath) ---@param filepath string
  local qompass_idx = filepath:find('/qompassai/')
  if qompass_idx then
    return filepath:sub(qompass_idx + 1)
  else
    return vim.fn.fnamemodify(filepath, ':~:.')
  end
end
local usercmd = vim.api.nvim_create_user_command
---@param filepath string
---@param comment string
---@return string[] header
local function make_header(filepath, comment)
  local relpath = get_relative_path(filepath)
  local description = 'Qompass AI - [ ]'
  local copyright = 'Copyright (C) 2026 Qompass AI, All rights reserved'
  local solid
  if comment == '<!--' then
    solid = '<!-- ' .. string.rep('-', 40) .. ' -->'
    return {
      '<!-- ' .. relpath .. ' -->',
      '<!-- ' .. description .. ' -->',
      '<!-- ' .. copyright .. ' -->',
      solid,
    }
  elseif comment == '/*' then
    solid = '/* ' .. string.rep('-', 40) .. ' */'
    return {
      '/* ' .. relpath .. ' */',
      '/* ' .. description .. ' */',
      '/* ' .. copyright .. ' */',
      solid,
    }
  else
    solid = comment .. ' ' .. string.rep('-', 40)
    return {
      comment .. ' ' .. relpath,
      comment .. ' ' .. description,
      comment .. ' ' .. copyright,
      solid,
    }
  end
end

autocmd('BufNewFile', {
  pattern = { '*.tex' },
  group = vim.api.nvim_create_augroup('qompass_latex_header', {
    clear = true,
  }),
  callback = function()
    local filepath = vim.fn.expand('%:p')
    local comment = '%'
    local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    if first_line == nil or first_line == '' then
      local header = make_header(filepath, comment)
      vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
      vim.cmd('normal! G')
    end
  end,
})
autocmd('BufWritePre', {
  pattern = {
    '*.tex',
    '*.ltx',
  },
  callback = function(args)
    fmt({
      bufnr = args.buf,
      async = false,
    })
    if vim.fn.executable('latexindent') == 1 or vim.fn.executable('latexindent.pl') == 1 then
      local bin = vim.fn.executable('latexindent') == 1 and 'latexindent' or 'latexindent.pl'
      vim.fn.jobstart({
        bin,
        '-w',
        vim.api.nvim_buf_get_name(args.buf),
      }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stderr = function(_, data, _)
          if not data then
            return
          end
          local out = table.concat(data, '')
          if out ~= '' then
            vim.schedule(function()
              vim.notify('latexindent: ' .. out, vim.log.levels.WARN)
            end)
          end
        end,
      })
    end
  end,
})
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = {
    '*.tex',
    '*.ltx',
  },
  callback = function()
    code_action({
      context = {
        diagnostics = {},
        only = {
          'source.fixAll',
        },
      },
      apply = true,
    })
  end,
})
usercmd('TexBuild', function() ---@command TexBuild
  vim.fn.jobstart({
    'latexmk',
    '-pdf',
    vim.fn.expand('%:p'),
  }, {
    detach = true,
  })
end, {})
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.tex',
  callback = function(args)
    fmt({
      bufnr = args.buf,
      async = true,
    })
  end,
})
usercmd('TexQuickfix', function() ---@command TexQuickfix
  local diagnostics = vim.diagnostic.get(0)
  code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix',
      },
      triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
    },
    apply = true,
  })
end, {})
autocmd('BufWritePre', {
  pattern = {
    '*.tex',
    '*.ltx',
  },
  callback = function(args)
    local diagnostics = vim.diagnostic.get(args.buf)
    code_action({
      context = {
        diagnostics = diagnostics,
        only = {
          'source.organizeImports',
          'source.fixAll',
        },
        triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Source,
      },
      apply = true,
      filter = function(_, client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client ~= nil and (client.name == 'texlab' or client.name == 'ltexplus_ls')
      end,
    })
  end,
})
autocmd('BufWritePost', {
  pattern = '*.tex',
  callback = function(args)
    if vim.fn.executable('chktex') == 0 then
      return
    end
    vim.fn.jobstart({
      'chktex',
      '-q',
      vim.api.nvim_buf_get_name(args.buf),
    }, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data, _)
        if not data then
          return
        end
        local out = table.concat(data, '')
        if out ~= '' then
          vim.schedule(function()
            vim.notify('chktex: ' .. out, vim.log.levels.INFO)
          end)
        end
      end,
    })
  end,
})
usercmd('TexCodeAction', function() ---@command TexCodeAction
  local diagnostics = vim.diagnostic.get(0)
  code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix',
        'refactor',
        'source.organizeImports',
        'source.fixAll',
      },
    },
    filter = function(_, client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      return client ~= nil and (client.name == 'texlab' or client.name == 'ltex')
    end,
    apply = true,
  })
end, {})
--- Run range code actions for visual selection in TeX.
usercmd('TexRangeAction', function() ---@command TexRangeAction
  local bufnr = 0
  local diagnostics = vim.diagnostic.get(bufnr)
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
  code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix',
        'refactor.extract',
      },
    },
    range = {
      start = {
        start_pos[1],
        start_pos[2],
      },
      ['end'] = { end_pos[1], end_pos[2] },
    },
    filter = function(_, client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      return client ~= nil and (client.name == 'texlab' or client.name == 'ltex')
    end,
    apply = false,
  })
end, {
  range = true,
})
autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and (client.name == 'texlab' or client.name == 'ltex') then
      vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
    end
  end,
})
return latex