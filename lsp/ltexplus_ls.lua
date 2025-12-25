-- /qompassai/Diver/lsp/ltexplus_ls.lua
-- Qompass AI Ltex_plus LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local function read_spellfile_words()
  local words = {}
  local path = vim.fn.stdpath('config') .. '/nvim/spell/en.utf-8.add'
  local f = io.open(path, 'r')
  if not f then
    return words
  end
  for line in f:lines() do
    if line ~= '' then
      table.insert(words, line)
    end
  end
  f:close()
  return words
end
local spell_words = read_spellfile_words()
local dict_en = vim.list_extend(vim.deepcopy(spell_words), {
  'HuggingFace',
  'Steilacoom',
  'Orthopaedics',
  'Shikany',
  'Zimmer',
  'Biomet',
  'CUDA',
  'Podman',
  'baselineskip',
  'Vulkan',
  'Mil',
  'Edu',
  'Noto',
  'NetOps',
  'PathFinder',
  'Pixorize',
  'MedAll',
  'Multicare',
  'Pseudarthrosis',
  'Allenmore',
  'USMAPS',
  'CORR',
  'ACDF',
  'Redis',
  'Qompass',
  'MSOS',
  'Eppich',
  'Telis',
  'Rusev',
  'Pseudoarthrosis',
  'MultiCare',
  'Valkey',
  'PMCID',
  'Cureus',
  'Frolov',
  'Orthopaedic',
  'Laporte',
  'Rowshan',
  'PRECICE',
  'Mechtly',
  'PharmD',
  'Schaetzel',
  'Kyber',
  'Aiyer',
  'NEJM',
  'Zig',
})
local language_id_mapping = {
  bib = 'bibtex',
  lualatex = 'markdown',
  plaintex = 'tex',
  rnoweb = 'rsweave',
  rst = 'restructuredtext',
  tex = 'latex',
  text = 'plaintext',
}
local function get_language_id(_, filetype)
  return language_id_mapping[filetype] or filetype
end
---@type vim.lsp.Config
return {
  cmd = {
    'ltex-ls-plus',
  },
  filetypes = {
    'bib',
    'context',
    'gitcommit',
    'html',
    'markdown',
    'org',
    'lualatex',
    'plaintex',
    'quarto',
    'mail',
    'mdx',
    'rmd',
    'rnoweb',
    'rst',
    'tex',
    'text',
    'typst',
    'xhtml',
  },
  root_markers = {
    '.git',
  },
  get_language_id = get_language_id,
  settings = {
    ltex = {
      additionalRules = {
        languageModel = vim.fn.expand('~/.local/share/ltex/language-model'),
        enablePickyRules = false,
      },
      bibtex = {
        fields = {
          maintitle = false,
          seealso = true,
        },
      },
      checkFrequency = 'edit',
      clearDiagnosticsWhenClosingFile = true,
      completionEnabled = true,
      diagnosticSeverity = {
        PASSIVE_VOICE = 'hint',
        default = 'information',
      },
      dictionary = {
        ['en-US'] = dict_en,
      },
      disabledRules = {
        'MORFOLOGIK_RULE_EN_US',
        'EN_QUOTES',
        'UPPERCASE_SENTENCE_START',
      },
      enabled = {
        'bib',
        'context',
        'gitcommit',
        'html',
        'markdown',
        'org',
        'lualatex',
        'plaintex',
        'quarto',
        'mail',
        'mdx',
        'rmd',
        'rnoweb',
        'rst',
        'tex',
        'latex',
        'text',
        'typst',
        'xhtml',
      },
      language = 'en-US',
    },
    latex = {
      commands = {
        ['\\label{}'] = 'ignore',
        ['\\documentclass[]{}'] = 'ignore',
        ['\\cite{}'] = 'dummy',
        ['\\cite[]{}'] = 'dummy',
      },
      environments = {
        lstlisting = 'ignore',
        verbatim = 'ignore',
      },
      markdown = {
        nodes = {
          CodeBlock = 'ignore',
          FencedCodeBlock = 'ignore',
          AutoLink = 'dummy',
          Code = 'dummy',
        },
      },
      statusBarItem = true,
      trace = {
        server = 'messages',
      },
    },
  },
}