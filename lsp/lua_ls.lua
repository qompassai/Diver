-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Diver Lua_ls LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'lua-language-server',
  },
  filetypes = {
    'lua',
    'luau',
  },
  root_markers = {
    '.emmyrc.json',
    '.git',
    'luacheckrc',
    '.luacheckrc',
    '.luarc.json',
    '.luarc.jsonc',
    '.luarc.json5',
    'selene.toml',
    'selene.yml',
    '.stylua.toml',
  },
  settings = {
    Lua = {
      addonManager = {
        enable = false,
        repositoryBranch = '',
        repositoryPath = '',
      },
      codeLens = {
        enable = true,
      },
      completion = {
        autoRequire = true,
        callSnippet = 'Both',
        displayContext = 1,
        enable = true,
        keywordSnippet = 'Both',
        postfix = '@',
      },
      diagnostics = {
        disable = {
          'lowercase-global',
        },
        disableScheme = {
          'git',
        },
        enable = true,
        globals = {
          'assert',
          'client',
          'Client',
          'describe',
          'it',
          'jit',
          'require',
          'use',
          'vim',
        },
        groupFileStatus = {
          ambiguity = 'Any',
          await = 'Any',
          -- codestyle      = 'Opened',
          duplicate = 'Any',
          global = 'Any',
          luadoc = 'Any',
          redefined = 'Any',
          strict = 'Any',
          -- strong = 'Opened',
          ['type-check'] = 'Any',
          unused = 'Any',
        },
        groupSeverity = {
          ambiguity = 'Warning',
          await = 'Warning',
          -- codestyle      = 'Information',
          duplicate = 'Warning',
          global = 'Error',
          luadoc = 'Warning',
          redefined = 'Warning',
          strict = 'Warning',
          --strong = 'Warning',
          ['type-check'] = 'Error',
          unbalanced = 'Warning',
          unused = 'Hint',
        },
        libraryFiles = 'Opened',
        neededFileStatus = {
          ['deprecated'] = 'Any',
          ['unused-local'] = 'Any',
          ['unused-function'] = 'Any',
          ['unused-vararg'] = 'Any',
        },
        severity = {
          ['action-after-return'] = 'Warning',
          ['ambiguity-1'] = 'Warning',
          ['err-assign-as-eq'] = 'Error',
          ['err-comment-prefix'] = 'Error',
          ['deprecated'] = 'Warning',
          ['unicode-name'] = 'Hint',
          ['undefined-doc-class'] = 'Warning',
          ['undefined-field'] = 'Error',
          ['unused-local'] = 'Hint',
          ['unused-varar'] = 'Hint',
        },
        unusedLocalExclude = {
          '_*',
        },
        workspaceDelay = 3000,
        workspaceEvent = 'OnChange',
        workspaceRate = 100,
      },
      doc = {
        regengine = 'lua',
      },
      format = {
        enable = true,
        defaultConfig = {
          align_array_table = true,
          align_call_args = true,
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
          detect_end_of_line = true,
          end_of_line = 'auto',
          end_statement_with_semicolon = 'keep',
          ignore_space_after_colon = false,
          ignore_spaces_inside_function_call = false,
          indent_size = 4,
          indent_style = 'space',
          insert_final_newline = false,
          keep_indents_on_empty_lines = false,
          line_space_after_comment = 'none',
          line_space_after_do_statement = 'none',
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
          space_after_comma_in_for_statement = false,
          space_after_comment_dash = false,
          space_around_assign_operator = false,
          space_around_logical_operator = false,
          space_around_math_operator = false,
          space_around_table_append_operator = false,
          space_around_table_field_list = false,
          space_before_attribute = false,
          space_before_closure_open_parenthesis = false,
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
        enable = true,
        semicolon = 'All',
        setType = true, ---@type boolean
        paramName = 'All', ---@type string
        paramType = true,
      },
      hover = {
        enable = true,
        enumsLimit = 5,
        expandAlias = true,
        previewFields = 50,
        viewNumber = true,
        viewString = true,
        viewStringMax = 1000,
      },
      language = {
        completeAnnotation = true,
        fixIndent = true,
      },
      misc = {},
      runtime = {
        fileEncoding = 'utf8', ---@type string
        meta = '${version} ${language} ${encoding}',
        nonstandardSymbol = {
          '//',
          '/**/',
          'continue',
        },
        path = {
          'lua/?.lua',
          'lua/?/init.lua',
        },
        unicodeName = false,
        version = 'LuaJIT',
      },
      semantic = {
        annotation = true,
        enable = true,
        keyword = true,
        variable = true,
      },
      signatureHelp = {
        enable = true,
      },
      spell = {},
      telemetry = {
        enable = false,
      },
      type = {
        castNumberToInteger = false,
        checkTableShape = true,
        inferParamType = true,
        inferTableSize = 20,
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
      window = {
        progressBar = true,
        statusBar = true,
      },
      workspace = {
        checkThirdParty = 'Apply',
        ignoreDir = {
          'build',
          'node_modules',
          '.vscode',
        },
        ignoreSubmodules = true,
        library = {
          vim.api.nvim_get_runtime_file('', true),
          vim.fn.stdpath('config') .. '/lua',
          vim.env.VIMRUNTIME,
          '${3rd}/busted/library',
          '${3rd}/luv/library',
          '${3rd}/neodev.nvim/types/nightly',
          '${3rd}/luassert/library',
          '${3rd}/lazy.nvim/library',
          '${3rd}/blink.cmp/library',
        },
        maxPreload = 5000, ---@type integer
        preloadFileSize = 500, ---@type integer
        useGitIgnore = true, ---@type boolean
        userThirdParty = {},
      },
    },
  },
  on_attach = function(client, bufnr) ---@type fun(client: vim.lsp.Client, bufnr: integer): nil
    client.server_capabilities.documentFormattingProvider = true
    vim.api.nvim_create_autocmd(
      'BufWritePre', ---@type NativeAPI
      {
        buffer = bufnr,
        callback = function(args) ---@param args { buf: integer, match?: string, file?: string }
          vim.lsp.buf.format({
            async = false,
            bufnr = args.buf,
            filter = function(c)
              return c.name == 'lua_ls'
            end,
          })
        end,
      }
    )
  end,
}