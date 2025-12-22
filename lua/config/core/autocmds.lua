-- /qompassai/Diver/lua/config/autocmds.lua
-- Qompass AI Diver Autocmds Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'config.core.autocmds'
local M = {} ---@type Autocmds
local augroups = {
  ansible = vim.api.nvim_create_augroup('Ansible',
    {
      clear = true,
    }),
  json = vim.api.nvim_create_augroup('JSON',
    {
      clear = true,
    }),
  lint = vim.api.nvim_create_augroup('lsp_lint_on_save',
    {
      clear = true,
    }),
  lsp = vim.api.nvim_create_augroup('LSP',
    {
      clear = true,
    }),
  markdown = vim.api.nvim_create_augroup('Markdown',
    {
      clear = true,
    }),
  python = vim.api.nvim_create_augroup('Python',
    {
      clear = true,
    }),
  rust = vim.api.nvim_create_augroup('Rust',
    {
      clear = true,
    }),
  yaml = vim.api.nvim_create_augroup('YAML',
    {
      clear = true,
    }),
  zig = vim.api.nvim_create_augroup('Zig',
    {
      clear = true,
    }),
}
local function run_cached_gvm(cmd)
  local handle = io.popen('bash -c \'source ~/.gvm/scripts/gvm && ' .. cmd .. '\'')
  if not handle then
    return nil
  end
  local result = handle:read('*a')
  handle:close()
  return result and vim.trim(result) or nil
end
local function get_go_bin()
  return run_cached_gvm('which go') or 'go'
end
local function get_gopath()
  return run_cached_gvm('go env GOPATH') or os.getenv('GOPATH') or ''
end
local function get_go_version()
  return run_cached_gvm('go version') or ''
end
local lspmap = require('mappings.lspmap') ---@type mappings.lspmap
---@return string
local function get_relative_path(filepath) ---@param filepath string
  local qompass_idx = filepath:find('/qompassai/')
  if qompass_idx then
    return filepath:sub(qompass_idx + 1)
  else
    local rel = vim.fn.fnamemodify(filepath, ':~:.')
    return rel
  end
end
local function make_qompass_header(filepath, comment)
  local relpath = get_relative_path(filepath)
  local description = 'Qompass AI - [ ]' ---@type string
  local copyright = 'Copyright (C) 2025 Qompass AI, All rights reserved' ---@type string
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
local linters = {
  lua = {
    cmd = {
      'luacheck',
      '--formatter',
      'plain',
      '--codes',
      '--ranges',
      '-'
    },
    parse = function(output, bufnr)
      local diags = {}
      for line, col, code, msg in output:gmatch(':(%d+):(%d+): %((.-)%) (.+)') do
        table.insert(diags, {
          lnum = tonumber(line) - 1,
          col = tonumber(col) - 1,
          message = msg .. ' [' .. code .. ']', ---@type string
          severity = vim.diagnostic.severity.WARN,
          source = 'luacheck',
        })
      end
      vim.diagnostic.set(vim.api.nvim_create_namespace('NativeLint'), bufnr, diags, {})
    end,
  },
}
M = M or {}
vim.cmd([[autocmd BufRead,BufNewFile *.hcl set filetype=hcl]])
vim.cmd([[autocmd BufRead,BufNewFile *.tf,*.tfvars set filetype=terraform]])
vim.api.nvim_create_autocmd( ---@type table[] ---Ansible
  {
    'BufRead',
    'BufNewFile',
  },
  {
    group = augroups.ansible,
    pattern = { ---@type table
      '*/ansible/*.yml',
      '*/playbooks/*.yml',
      '*/tasks/*.yml',
      '*/roles/*.yml',
      '*/handlers/*.yml',
    },
    callback = function()
      vim.bo.filetype = 'ansible'
    end,
  })
vim.api.nvim_create_autocmd({
  'BufRead',
  'BufNewFile',
}, {
  group = augroups.yaml,
  pattern = {
    '*.yml',
    '*.yaml',
  },
  callback = function()
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, 30, false), '\n')
    if content:match('ansible_') or (content:match('hosts:') and content:match('tasks:')) then
      vim.bo.filetype = 'yaml.ansible'
    elseif content:match('apiVersion:') and content:match('kind:') then
      vim.bo.filetype = 'yaml.kubernetes'
    elseif content:match('version:') and content:match('services:') then
      vim.bo.filetype = 'yaml.docker'
    end
  end,
})
vim.api.nvim_create_autocmd(
  'BufNewFile', ---@type string
  {
    pattern = '*', ---@type string
    callback = function()
      local filepath = vim.fn.expand('%:p')
      local ext = vim.fn.expand('%:e')
      local filetype = vim.bo.filetype
      local comment_map = { ---@type table[]
        arduino = '//',
        asciidoc = '//',
        asm = ';',
        astro = '//',
        avro = '#',
        bash = '#',
        bicep = '//',
        c = '//',
        cf = '#',
        cff = '#',
        cfn = '#',
        clojure = ';',
        cmake = '#',
        compute = '//',
        conf = '#',
        cpp = '//',
        cs = '//',
        css = '/*',
        cuda = '//',
        cue = '//',
        dhall = '--',
        dockerfile = '#',
        dosini = ';',
        elixir = '#',
        fish = '#',
        fix = '#',
        glsl = '//',
        go = '//',
        graphql = '#',
        h = '//',
        haskell = '--',
        hlsl = '//',
        hocon = '#',
        hpp = '//',
        html = '<!--',
        ini = ';',
        java = '//',
        javascript = '//',
        javascriptreact = '//',
        js = '//',
        json = '//',
        jsonc = '//',
        julia = '#',
        kotlin = '//',
        latex = '%',
        less = '/*',
        lua = '--',
        markdown = '<!--',
        md = '<!--',
        mdx = '//',
        meson = '#',
        mlir = '//',
        mojo = '#',
        mql4 = '//',
        mql5 = '//',
        nix = '#',
        opencl = '//',
        openqasm = '//',
        parquet = '#',
        perl = '#',
        php = '//',
        pine = '//',
        pl = '#',
        plsql = '--',
        powershell = '#',
        proto = '//',
        protobuf = '//',
        py = '#',
        python = '#',
        qsharp = '//',
        quil = '#',
        r = '#',
        rb = '#',
        renderdoc = '#',
        rmd = '#',
        rs = '//',
        rst = '..',
        ruby = '#',
        rust = '//',
        sass = '//',
        scala = '//',
        scss = '/*',
        sh = '#',
        sql = '--',
        svelte = '//',
        swift = '//',
        systemverilog = '//',
        terraform = '#',
        tex = '%',
        toml = '#',
        ts = '//',
        typescript = '//',
        typescriptreact = '//',
        unity = '//',
        verilog = '//',
        vhdl = '--',
        vim = '"',
        vue = '//',
        wasm = ';;',
        wat = ';;',
        x86asm = ';',
        xml = '<!--',
        yaml = '#',
        yml = '#',
        zig = '//',
        zsh = '#',
      }
      local comment = comment_map[ext] or comment_map[filetype] or '#'
      if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == '' then
        local header = make_qompass_header(filepath, comment)
        vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
        vim.cmd('normal! G')
      end
    end,
  }
)
vim.api.nvim_create_autocmd({
  'BufRead',
  'BufNewFile',
}, {
  pattern = { ---@type string[]
    'Dockerfile.*',
    '*.Dockerfile',
    'Containerfile',
    '*.containerfile',
  },
  callback = function()
    vim.bo.filetype = 'dockerfile'
  end,
})
vim.api.nvim_create_autocmd(
  {
    'BufNewFile',
    'BufRead'
  },
  {
    pattern = { '*docker-compose*.yml', '*docker-compose*.yaml' },
    callback = function() vim.bo.filetype = 'yaml' end
  })
local linters = {
  lua = {
    cmd = {
      'luacheck',
      '--formatter', 'plain',
      '--codes',
      '--ranges',
      '-',
    },
    parse = function(output, bufnr)
      local diags = {}
      for line, col, code, msg in output:gmatch(':(%d+):(%d+): %((.-)%) (.+)') do
        table.insert(diags, {
          lnum = tonumber(line) - 1,
          col = tonumber(col) - 1,
          message = msg .. ' [' .. code .. ']',
          severity = vim.diagnostic.severity.WARN,
          source = 'luacheck',
        })
      end
      vim.diagnostic.set(vim.api.nvim_create_namespace('NativeLint'), bufnr, diags, {})
    end,
  },
}
---@param opts? table
function M.nix_autocmds(opts) ---@return nil|string[] ---Nix
  opts = opts or {}
  vim.api.nvim_create_user_command('SetNixFormatter', function(args)
    vim.g.nix_formatter = args.args
  end, {
    nargs = 1,
    complete = function()
      return {
        'alejandra',
        'nixfmt',
        'nixpkgs-fmt',
      }
    end,
  })
end

vim.api.nvim_create_autocmd('FileType',
  {
    pattern = 'nix',
    callback = function()
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.expandtab = true
    end,
  })
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'nix',
  callback = function()
    vim.keymap.set('n',
      '<leader>ne', ':NixEdit<Space>',
      {
        buffer = true,
        desc = 'NixEdit attribute',
      })
  end,
})
vim.api.nvim_create_autocmd('FileType',
  {
    pattern = 'nix',
    callback = function()
      vim.opt_local.conceallevel = 2
    end,
  })
vim.api.nvim_create_autocmd('FileType',
  {
    pattern = {
      'sqlite',
      'pgsql'
    },
    callback = function()
      vim.opt_local.expandtab = true
      vim.opt_local.shiftwidth = 2
      vim.opt_local.softtabstop = 2
      vim.opt_local.omnifunc = 'vim_dadbod_completion#omni'
    end,
  })
vim.api.nvim_create_user_command('PhpStan', function() ---PHP
  if vim.fn.executable('phpstan') == 1 then
    vim.cmd('!phpstan analyse')
  else
    vim.echo('phpstan not found in PATH',
      vim.log.levels.ERROR)
  end
end, {
  desc = 'Run PHPStan analysis',
})
vim.api.nvim_create_user_command('Pint', function()
  if vim.fn.executable('pint') == 1 then
    vim.cmd('!pint')
  else
    vim.echo('pint not found in PATH',
      vim.log.levels.ERROR)
  end
end, {
  desc = 'Run Laravel Pint formatter',
})
---Go
function M.go_autocmds()
  vim.api.nvim_create_user_command('GoEnvInfo', function()
    for label, value in pairs({
      ['Go Binary'] = get_go_bin(),
      ['Go Version'] = get_go_version(),
      ['GOPATH'] = get_gopath(),
    }) do
      vim.echo(string.format(
          '%s: %s',
          label, value
        ),
        vim.log.levels.INFO)
    end
  end, {})
end

vim.api.nvim_create_autocmd('BufWritePost', ---LSP
  {
    callback = function(args)
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
        if client:supports_method(true) and client:supports_method('textDocument/diagnostic') then
          client.request(
            'textDocument/diagnostic',
            vim.lsp.util.make_text_document_params(args.buf),
            function(err, result)
              if err or not result then
                return
              end
              local ns = vim.lsp.diagnostic.get_namespace(client.id)
              local diags = vim.lsp.diagnostic.from_lsp(result.items)
              vim.diagnostic.set(ns, args.buf, diags)
            end,
            args.buf
          )
        end
      end
    end,
  })
vim.api.nvim_create_autocmd(
  'LspAttach',
  {
    callback = lspmap.on_attach,
  })
vim.api.nvim_create_autocmd({
  'BufEnter',
  'CursorHold',
  'InsertLeave',
}, {
  callback = function()
    vim.lsp.codelens.refresh(true)
  end,
})
vim.api.nvim_create_autocmd('LspAttach',
  {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client:supports_method('textDocument/foldingRange') then
        local win = vim.api.nvim_get_current_win()
        vim.wo[win][0].foldexpr = 'v:lua.vim.lsp.foldexpr()'
      end
    end,
  })
vim.api.nvim_create_autocmd('LspAttach',
  {
    callback = function(ev)
      vim.diagnostic.show(vim.api.nvim_create_namespace('my_diagnostics'),
        ev.buf, nil, {
          virtual_text = {
            spacing = 2,
            source = 'if_many', ---@type string
            severity = {
              min = vim.diagnostic.severity.WARN,
            },
            prefix = function(diag, i, total) ---@function diag vim.Diagnostic
              ---@cast diag vim.Diagnostic
              ---@cast i integer
              ---@cast total integer
              local icons = {
                [vim.diagnostic.severity.ERROR] = ' ',
                [vim.diagnostic.severity.WARN] = ' ',
                [vim.diagnostic.severity.INFO] = ' ',
                [vim.diagnostic.severity.HINT] = ' ',
              }
              return string.format('%s%d/%d ',
                icons[diag.severity], i, total)
            end,
          },
          signs = true,
          severity_sort = true,
          virtual_lines = true,
          underline = true,
        })
    end,
  })
vim.api.nvim_create_autocmd('LspDetach',
  {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client:supports_method('textDocument/formatting') then
        vim.api.nvim_clear_autocmds({
          event = 'BufWritePre',
          buffer = args.buf,
        })
      end
    end,
  })
vim.api.nvim_create_autocmd('LspProgress',
  {
    callback = function(ev)
      local value = ev.data.params.value
      if value.kind == 'begin' then
        vim.api.nvim_ui_send('\027]9;4;1;0\027\\')
      elseif value.kind == 'end' then
        vim.api.nvim_ui_send('\027]9;4;0\027\\')
      elseif value.kind == 'report' then
        vim.api.nvim_ui_send(string.format('\027]9;4;1;%d\027\\',
          value.percentage or 0))
      end
    end,
  })
vim.api.nvim_create_autocmd('LspTokenUpdate',
  {
    callback = function(args)
      local token = args.data.token
      if token.type == 'variable' and not token.modifiers.readonly then
        vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id,
          'MyMutableVariableHighlight')
      end
    end,
  })

function M.md_autocmds() ---Markdown
  vim.api.nvim_create_autocmd('FileType',
    {
      pattern = { ---@type string[]
        'markdown',
        'md',
      },
      callback = function()
        vim.g.mkdp_auto_start = 0
        vim.g.mkdp_auto_close = 0
        vim.g.mkdp_refresh_slow = 1
        vim.g.mkdp_port = ''
        vim.g.mkdp_command_for_global = 0
        vim.g.mkdp_open_to_the_world = 0
        vim.g.mkdp_open_ip = ''
        vim.g.mkdp_combine_preview = 1
        vim.g.mkdp_browser = ''
        vim.g.mkdp_echo_preview_url = 1
        vim.g.mkdp_page_title = '${name}'
        vim.g.mkdp_filetypes = {
          'markdown'
        }
      end,
    })
  vim.api.nvim_create_autocmd('FileType',
    {
      pattern = { ---@type string[]
        'markdown',
        'md',
      },
      callback = function()
        vim.keymap.set( ---@type table
          'n', '<leader>mp',
          ':MarkdownPreview<CR>', {
            buffer = true,
            desc = 'Markdown Preview',
          })
        vim.keymap.set( ---@type table
          'n',
          '<leader>ms',
          ':MarkdownPreviewStop<CR>',
          {
            buffer = true,
            desc = 'Stop Markdown Preview'
          }
        )
        vim.keymap.set( ---@type table
          'n', '<leader>mt', ':TableModeToggle<CR>', {
            buffer = true,
            desc = 'Toggle Table Mode',
          })
        vim.keymap.set( ---@type table
          'n', '<leader>mi',
          ':KittyScrollbackGenerateImage<CR>',
          {
            buffer = true,
            desc = 'Generate image from code block',
          })
        vim.keymap.set('v', '<leader>mr', ':SnipRun<CR>',
          {
            buffer = true, desc = 'Run selected code'
          })
      end,
    })
  vim.api.nvim_create_user_command('MarkdownToPDF', function()
    local input_file = vim.fn.expand('%:p')
    local tex_file = vim.fn.expand('%:r') .. '.tex'
    local pdf_file = vim.fn.expand('%:r') .. '.pdf'
    vim.echo('Converting markdown to LaTeX...', ---@type string
      vim.log.levels.INFO)
    local convert_cmd = 'pandoc ' .. input_file .. ' -o ' .. tex_file
    vim.fn.jobstart(convert_cmd, {
      on_exit = function(_, code)
        if code == 0 then
          vim.echo('Running lualatex...',
            vim.log.levels.INFO)
          vim.fn.jobstart('lualatex -interaction=nonstopmode ' .. tex_file,
            {
              on_exit = function(_, compile_code)
                if compile_code == 0 then
                  vim.echo('PDF created: ' .. pdf_file, vim.log.levels.INFO)
                else
                  vim.echo('lualatex failed to compile', ---@type string
                    vim.log.levels.ERROR)
                end
              end,
            })
        else
          vim.echo('Failed to convert Markdown to LaTeX', ---@type string
            vim.log.levels.ERROR)
        end
      end,
    })
  end, {})
end

vim.api.nvim_create_autocmd('FileType', ---Python
  {
    group = augroups.python,
    pattern = 'python',
    callback = function()
      vim.opt_local.autoindent = true
      vim.opt_local.smartindent = true
      vim.api.nvim_buf_create_user_command(
        0,
        'PythonLint',
        function()
          vim.lsp.buf.format()
          vim.cmd('write')
          vim.echo('Python code linted and formatted',
            vim.log.levels.INFO)
        end, {})
      vim.api.nvim_buf_create_user_command(0, 'PyTestFile', function()
        local file = vim.fn.expand('%:p')
        vim.cmd('split | terminal pytest ' .. file)
      end, {})
      vim.api.nvim_buf_create_user_command(0, 'PyTestFunc', function()
        local file = vim.fn.expand('%:p')
        local cmd = 'pytest ' .. file .. '::' .. vim.fn.expand('<cword>') .. ' -v'
        vim.cmd('split | terminal ' .. cmd)
      end, {})
    end,
  })
vim.api.nvim_create_autocmd('BufWritePre',
  {
    pattern = {
      '*.py'
    },
    callback = function(args)
      vim.lsp.buf.format({
        async = false,
        bufnr = args.buf,
        filter = function(client)
          return client.name == 'ruff_lsp' or client.name == 'ruff'
        end,
      })
    end,
  })
vim.api.nvim_create_autocmd('BufWritePre', ---Ruby
  {
    pattern = {
      '*.rb',
      '*.rake',
      'Gemfile',
      'Rakefile'
    },
    callback = function(args) ---@param args { buf: integer }
      vim.lsp.buf.format({
        async = false,
        bufnr = args.buf,
        filter = function(client)
          return client.name == 'ruby-lsp'
        end,
      })
    end,
  })

vim.api.nvim_create_user_command('VitestFile', function() ---Vite
  local file = vim.fn.expand('%:p')
  vim.fn.jobstart({ 'vitest', 'run', file }, { detach = true })
end, {})

vim.api.nvim_create_user_command('ZigTest', function() ---Zig
  vim.fn.jobstart(
    { 'zig', 'test', vim.fn.expand('%:p') },
    {
      detach = true
    })
end, {})
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.zig',
  callback = function(args)
    vim.lsp.buf.format({ bufnr = args.buf, async = false })
  end,
})
vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = '*.zig',
  callback = function(args)
    vim.fn.jobstart(
      { 'zlint', vim.api.nvim_buf_get_name(args.buf)
      },
      {
        stdout_buffered = true,
        on_stdout = function(_, data, _)
          if not data then
            return
          end
          local out = table.concat(data, ''
          )
          if out ~= '' then
            vim.schedule(function()
              vim.notify('zlint: ' .. out,
                vim.log.levels.INFO)
            end)
          end
        end,
      }
    )
  end,
})
vim.api.nvim_create_user_command('ZiggyCheck', function()
  local file = vim.fn.expand('%:p')
  vim.fn.jobstart({ 'ziggy', file }, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if not data then return end
      local out = table.concat(data, ''
      )
      if out ~= '' then
        vim.schedule(function()
          vim.echo('ziggy:'
            .. out, vim.log.levels.INFO)
        end)
      end
    end,
  })
end, {})
return M