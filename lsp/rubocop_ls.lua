-- /qompassai/Diver/lsp/rubocop_ls.lua
-- Qompass AI Ruby RuboCop LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'rubocop',
    '--lsp',
  },
  filetypes = { ---@type string[]
    'ruby',
  },
  root_markers = { ---@type string[]
    'Gemfile',
    'Gemfile.lock',
    '.git',
    '.rubocop.yml',
  },
  settings = {
    rubocop = {
      autocorrect = false,
      config = {
        AllCops = {
          Exclude = {
            'docs/book/book/**/*',
            'fastlane/metadata/**/*',
            'fastlane/report.xml',
            'vendor/bundle/**/*',
          },
          NewCops = 'enable',
          TargetRubyVersion = 3.2,
        },

        ['Layout/EmptyLinesAroundBlockBody'] = {
          Enabled = true,
        },

        ['Layout/EmptyLinesAroundClassBody'] = {
          Enabled = true,
        },

        ['Layout/EmptyLinesAroundMethodBody'] = {
          Enabled = true,
        },

        ['Layout/IndentationConsistency'] = {
          Enabled = true,
        },
        ['Layout/IndentationWidth'] = {
          Enabled = true,
          Width = 2,
        },
        ['Layout/LineLength'] = {
          Enabled = true,
          Max = 100,
        },
        ['Layout/SpaceAroundEqualsInParameterDefault'] = {
          Enabled = true,
        },
        ['Metrics/BlockLength'] = {
          Enabled = true,
          Exclude = {
            'Fastfile',
            'Gemfile',
          },
        },
        ['Metrics/MethodLength'] = {
          Enabled = true,
          Max = 20,
        },
        ['Metrics/ModuleLength'] = {
          Enabled = true,
        },
        ['Metrics/ParameterLists'] = {
          Enabled = true,
        },
        ['Naming/MethodName'] = {
          Enabled = true,
        },
        ['Naming/VariableName'] = {
          Enabled = true,
        },
        ['Style/BlockDelimiters'] = {
          Enabled = true,
          EnforcedStyle = 'braces_for_chaining',
        },
        ['Style/ClassAndModuleChildren'] = {
          Enabled = true,
        },
        ['Style/Documentation'] = {
          Enabled = false,
        },
        ['Style/EmptyMethod'] = {
          Enabled = true,
        },
        ['Style/FrozenStringLiteralComment'] = {
          Enabled = true,
          EnforcedStyle = 'always',
        },
        ['Style/GuardClause'] = {
          Enabled = true,
        },
        ['Style/IfUnlessModifier'] = {
          Enabled = true,
        },
        ['Style/Lambda'] = {
          Enabled = true,
        },
        ['Style/NumericLiteralPrefix'] = {
          Enabled = true,
        },
        ['Style/NumericLiterals'] = {
          Enabled = true,
        },
        ['Style/PercentLiteralDelimiters'] = {
          Enabled = true,
        },
        ['Style/PreferredHashSyntax'] = {
          Enabled = true,
        },
        ['Style/RaiseArgs'] = {
          Enabled = true,
        },
        ['Style/RedundantBegin'] = {
          Enabled = true,
        },
        ['Style/RedundantSelf'] = {
          Enabled = true,
        },
        ['Style/SignalException'] = {
          Enabled = true,
        },
        ['Style/SingleLineBlockParams'] = {
          Enabled = true,
        },
        ['Style/StringLiterals'] = {
          Enabled = true,
          EnforcedStyle = 'single_quotes',
        },
        ['Style/StringLiteralsInInterpolation'] = {
          Enabled = true,
          EnforcedStyle = 'double_quotes',
        },

        ['Style/SymbolProc'] = {
          Enabled = true,
        },

        ['Style/TernaryParentheses'] = {
          Enabled = true,
        },

        ['Style/TrailingCommaInArrayLiteral'] = {
          Enabled = true,
          EnforcedStyleForMultiline = 'consistent_comma',
        },
        ['Style/TrailingCommaInHashLiteral'] = {
          Enabled = true,
          EnforcedStyleForMultiline = 'consistent_comma',
        },
        ['Style/TrailingUnderscoreVariable'] = {
          Enabled = true,
        },
      },
      path = '',
    },
  },
  single_file_support = true,
}
