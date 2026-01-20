-- /qompassai/Diver/lua/config/autocmds.lua
-- Qompass AI Diver Autocmds Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'config.core.autocmds'
local M = {} ---@type Autocmds
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
local function make_header(filepath, comment)
  local relpath = get_relative_path(filepath)
  local description = 'Qompass AI - [ ]' ---@type string
  local copyright = 'Copyright (C) 2026 Qompass AI, All rights reserved' ---@type string
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
M = M or {}
vim.cmd([[autocmd BufRead,BufNewFile *.hcl set filetype=hcl]])
vim.cmd([[autocmd BufRead,BufNewFile *.tf,*.tfvars set filetype=terraform]])
vim.api.nvim_create_autocmd('CmdlineChanged', {
  pattern = {
    ':',
    '/',
    '?',
  },
  callback = function()
    vim.fn.wildtrigger()
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
        scm = ';',
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
        local header = make_header(filepath, comment)
        vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
        vim.cmd('normal! G')
      end
    end,
  }
)

vim.api.nvim_create_autocmd('FileType', {
  pattern = {
    'tex',
    'plaintex',
  },
  callback = function()
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.breakindent = true
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  pattern = {
    'sqlite',
    'pgsql',
  },
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.omnifunc = 'vim_dadbod_completion#omni'
  end,
})
function M.md_autocmds() ---Markdown
  vim.api.nvim_create_autocmd('FileType', {
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
        'markdown',
      }
    end,
  })
  local ok, md_pdf = pcall(require, 'md-pdf')
  vim.api.nvim_create_autocmd('FileType', {
    pattern = {
      'markdown',
      'md',
    },
    callback = function()
      vim.keymap.set('n', '<leader>,', function()
        if ok and md_pdf and md_pdf.convert_md_to_pdf then
          md_pdf.convert_md_to_pdf()
        else
          vim.cmd('MarkdownToPDF')
        end
      end, {
        buffer = true,
        desc = 'Convert Markdown to PDF',
      })
    end,
  })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { ---@type string[]
      'markdown',
      'md',
    },
    callback = function()
      vim.keymap.set( ---@type table
        'n',
        '<leader>mp',
        ':MarkdownPreview<CR>',
        {
          buffer = true,
          desc = 'Markdown Preview',
        }
      )
      vim.keymap.set( ---@type table
        'n',
        '<leader>ms',
        ':MarkdownPreviewStop<CR>',
        {
          buffer = true,
          desc = 'Stop Markdown Preview',
        }
      )
      vim.keymap.set( ---@type table
        'n',
        '<leader>mt',
        ':TableModeToggle<CR>',
        {
          buffer = true,
          desc = 'Toggle Table Mode',
        }
      )
      vim.keymap.set( ---@type table
        'n',
        '<leader>mi',
        ':KittyScrollbackGenerateImage<CR>',
        {
          buffer = true,
          desc = 'Generate image from code block',
        }
      )
      vim.keymap.set('v', '<leader>mr', ':SnipRun<CR>', {
        buffer = true,
        desc = 'Run selected code',
      })
    end,
  })
  vim.api.nvim_create_user_command('MarkdownToPDF', function()
    local input_file = vim.fn.expand('%:p')
    local tex_file = vim.fn.expand('%:r') .. '.tex'
    local pdf_file = vim.fn.expand('%:r') .. '.pdf'
    vim.echo(
      'Converting markdown to LaTeX...', ---@type string
      vim.log.levels.INFO
    )
    local convert_cmd = 'pandoc ' .. input_file .. ' -o ' .. tex_file
    vim.fn.jobstart(convert_cmd, {
      on_exit = function(_, code)
        if code == 0 then
          vim.echo('Running lualatex...', vim.log.levels.INFO)
          vim.fn.jobstart('lualatex -interaction=nonstopmode ' .. tex_file, {
            on_exit = function(_, compile_code)
              if compile_code == 0 then
                vim.echo('PDF created: ' .. pdf_file, vim.log.levels.INFO)
              else
                vim.echo(
                  'lualatex failed to compile', ---@type string
                  vim.log.levels.ERROR
                )
              end
            end,
          })
        else
          vim.echo(
            'Failed to convert Markdown to LaTeX', ---@type string
            vim.log.levels.ERROR
          )
        end
      end,
    })
  end, {})
end

local largefile_group = vim.api.nvim_create_augroup('LargeFile', {})
vim.api.nvim_create_autocmd({
  'BufReadPre',
  'FileReadPre',
}, {
  group = largefile_group,
  callback = function(args)
    local ok, stat = pcall(vim.loop.fs_stat, args.file)
    if not ok or not stat then
      return
    end
    local limit = 20 * 1024 * 1024
    if stat.size < limit then
      return
    end
    vim.b.large_file = true
    vim.opt_local.swapfile = false
    vim.opt_local.undofile = false
    vim.opt_local.foldmethod = 'manual'
    vim.opt_local.syntax = 'off'
    pcall(vim.treesitter.stop, args.buf)
    for _, client in
    ipairs(vim.lsp.get_clients({
      bufnr = args.buf,
    }))
    do
      vim.lsp.buf_detach_client(args.buf, client.id)
    end
  end,
})
vim.api.nvim_create_user_command('VitestFile', function()
  local file = vim.fn.expand('%:p')
  vim.fn.jobstart({ 'vitest', 'run', file }, {
    detach = true,
  })
end, {})
vim.api.nvim_create_user_command('ConfigSelfCheck', function()
  require('tests.selfcheck').run()
end, {})
local function strip_ansi()
  vim.cmd([[%s/[\x1b]\[[0-9;]*m//g]])
end
vim.api.nvim_create_autocmd('BufReadPost', {
  pattern = '*',
  callback = function()
    if vim.bo.filetype == 'nvimpager' then
      strip_ansi()
    end
  end,
})
return M