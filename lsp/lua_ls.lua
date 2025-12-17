-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Lua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'lua-language-server',
  },
  filetypes = { ---@type string[]
    'lua',
    'luau',
  },
  root_markers = { ---@type string[]
    '.emmyrc.json',
    '.luarc.json',
    '.luarc.jsonc',
    '.luarc.json5',
    'luacheckrc',
    '.luacheckrc',
    '.stylua.toml',
    'selene.toml',
    'selene.yml',
    '.git',
  },
  settings = {
    Lua = {
      addonManager = {
        enable = false, ---@type boolean
        repositoryBranch = '', ---@type string
        repositoryPath = '', ---@type string
      },
      codeLens = { ---@type boolean []
        enable = true,
      },
      completion = { ---@type table<string, boolean|string|integer>
        autoRequire = true, ---@type boolean
        callSnippet = 'Both', ---@type string
        displayContext = 1, ---@type integer
        enable = true, ---@type boolean
        keywordSnippet = 'Both', ---@type string
        postfix = '@', ---@type string
      },
      diagnostics = { ---@type string[]
        disable = {
          'lowercase-global',
          'unused-local',
        },
        enable = true, ---@type boolean
        globals = { ---@type string[]
          'vim',
          'jit',
          'use',
          'require',
        },
        libraryFiles = 'Opened', ---@type string
        neededFileStatus = 'Opened',
        severity = {
          ['ambiguity-1'] = 'Warning',
          ["action-after-return"] = 'Warning',
          ["err-assign-as-eq"] = 'Error',
          ["err-comment-prefix"] = 'Error',
          ['unicode-name'] = 'Hint',
          ['unused-local'] = 'Hint',
        },
        unusedLocalExclude = {
          '_*',
        },
      },
      doc = {
        regengine = 'lua' ---@type string
      },
      format = {
        enable = true,
        defaultConfig = {
          align_array_table = true,
          align_call_args = false,
          align_chain_expr = 'none',
          align_continuous_assign_statement = true,
          align_continuous_inline_comment = true,
          align_continuous_line_space = 2, ---@type integer
          align_continuous_rect_table_field = true,
          align_continuous_similar_call_args = false,
          align_function_params = true,
          align_if_branch = false,
          allow_non_indented_comments = false,
          auto_collapse_lines = false,
          break_all_list_when_line_exceed = false,
          break_before_braces = false,
          call_arg_parentheses = 'keep',
          continuation_indent = 4,
          detect_end_of_line = false,
          end_of_line = 'auto',
          end_statement_with_semicolon = 'keep',
          ignore_space_after_colon = false,
          ignore_spaces_inside_function_call = false,
          indent_size = 4,
          indent_style = 'space',
          insert_final_newline = false,
          keep_indents_on_empty_lines = false,
          line_space_after_comment = 'keep',
          line_space_after_do_statement = 'keep',
          line_space_after_expression_statement = 'keep',
          line_space_after_for_statement = 'keep',
          line_space_after_function_statement = 'fixed(2)',
          line_space_after_if_statement = 'keep',
          line_space_after_local_or_assign_statement = 'keep',
          line_space_after_repeat_statement = 'keep',
          line_space_after_while_statement = 'keep',
          line_space_around_block = 'fixed(1)',
          max_line_length = 120,
          never_indent_before_if_condition = false,
          never_indent_comment_on_if_branch = false,
          quote_style = 'single',
          remove_call_expression_list_finish_comma = false,
          space_after_comma = false,
          space_after_comma_in_for_statement = true,
          space_after_comment_dash = false,
          space_around_assign_operator = false,
          space_around_logical_operator = false,
          space_around_math_operator = false,
          space_around_table_append_operator = false,
          space_around_table_field_list = true,
          space_before_attribute = true,
          space_before_closure_open_parenthesis = true,
          space_before_function_call_open_parenthesis = false,
          space_before_function_call_single_arg = 'none',
          space_before_function_open_parenthesis = false,
          space_before_inline_comment = 'keep',
          space_before_open_square_bracket = false,
          space_inside_function_call_parentheses = false,
          space_inside_function_param_list_parentheses = false,
          space_inside_square_brackets = false,
          table_separator_style = 'none',
          tab_width = 4,
          trailing_table_separator = 'keep',
        },
      },
      hint = {
        arrayIndex = 'Enable',
        await = true,
        enable = true, ---@type boolean
        semicolon = 'All', ---@type string
        setType = true, ---@type boolean
        paramName = 'All', ---@type string
        paramType = true,
      },
      hover = {
        enable = true, ---@type boolean
        previewfields = 50, ---@type integer
      },
      language = { ---@type boolean[]
        completeAnnotation = true,
        fixIndent = true
      },
      misc = {
      },
      runtime = {
        fileEncoding = 'utf8', ---@type string
        path = {
          'lua/?.lua',
          'lua/?/init.lua',
        },
        unicodeName = false,
        version = 'LuaJIT', ---@type string
      },
      semantic = { ---@type boolean[]
        annotation = true,
        enable = true,
        keyword = true,
        variable = true
      },
      signatureHelp = { ---@type boolean[]
        enable = true,
      },
      telemetry = {
        enable = false,
      },
      type = {
        castNumberToInteger = true,
        checkTableShape = true,
        inferParamType = true,
        inferTableSize = 20, ---@type integer
        weakNilCheck = false,
        weakUnionCheck = false,
      },
      typeFormat = {
        enable = true,
        config = {
          auto_complete_end = 'true',
          auto_complete_table_sep = 'true',
          format_line = 'true',
        },
      },
      window = { ---@type boolean[]
        progressBar = true,
        statusBar = true,
      },
      workspace = {
        checkThirdParty = 'Disable', ---@type string
        ignoreDir = { ---@type string[]
          'build',
          'node_modules',
          '.vscode',
        },
        library = {
          vim.api.nvim_get_runtime_file('', true),
          vim.env.VIMRUNTIME,
          --'${3rd}/luv/library',
          '${3rd}/busted/library',
          '${3rd}/neodev.nvim/types/nightly',
          '${3rd}/luassert/library',
          '${3rd}/lazy.nvim/library',
          '${3rd}/blink.cmp/library',
          vim.fn.expand('$HOME') .. '/.config/nvim/lua/',
        },
        maxPreload = 5000, ---@type integer
        preloadFileSize = 500, ---@type integer
        useGitIgnore = true, ---@type boolean
      },
    },
  },
  ---@param client vim.lsp.Client
  ---@param bufnr integer
  on_attach = function(client, bufnr) ---@return nil
    client.server_capabilities.documentFormattingProvider = true
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = bufnr,
      callback = function(args) ---@param args { buf: integer, match?: string, file?: string }
        vim.lsp.buf.format({
          async = false,
          bufnr = args.buf,
          filter = function(c) ---@param c vim.lsp.Client
            return c.name == 'lua_ls'
          end,
        })
      end,
    })
  end,
  on_init = function(client) ---@param client vim.lsp.Client
    if client.workspace_folders then
      local path = client.workspace_folders[1].name ---@type string
      if
          path ~= vim.fn.stdpath('config')
          and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
      then
        return
      end
    end
    client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
      Lua = {
        runtime = { ---@type string[]
          version = 'LuaJIT'
        },
      },
    })
  end,
}