-- /qompassai/Diver/lsp/ltexplus_ls.lua
-- Qompass AI Ltex_plus LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@source https://ltex-plus.github.io/ltex-plus/index.html
local language_id_mapping = {
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

return ---@type vim.lsp.Config
{
	cmd = {
		'ltex-ls-plus',
	},
	filetypes = {
		'bibtex',
		'context',
		'gitcommit',
		'html',
		'org',
		'lualatex',
		--   'markdown',
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
				enablePickyRules = false,
				languageModel = vim.fn.expand('$XDG_DATA_HOME/ltex/language-model'),
				motherTongue = {
					'en-US',
				},
			},
			bibtex = {
				fields = {
					maintitle = true,
					seealso = true,
				},
			},
			checkFrequency = 'save',
			clearDiagnosticsWhenClosingFile = true,
			completionEnabled = true,
			configurationTarget = {
				dictionary = 'workspaceFolderExternalFile',
				disabledRules = 'workspaceFolderExternalFile',
				hiddenFalsePositives = 'workspaceFolderExternalFile',
			},
			diagnosticSeverity = {
				PASSIVE_VOICE = 'hint',
				default = 'information',
			},
			dictionary = {
				['en-US'] = {
					'$XDG_DATA_HOME/nvim/spell/dictionary.txt',
					'$XDG_DATA_HOME/nvim/utils/docs/dictionary/words.txt',
				},
			},
			disabledRules = {
				'EN_QUOTES',
				'MORFOLOGIK_RULE_EN_US',
				'UPPERCASE_SENTENCE_START',
			},
			enabled = {
				'asciidoc',
				'bibtex',
				'context',
				'context.tex',
				'gitcommit',
				'html',
				'latex',
				'lualatex',
				'mail',
				'markdown',
				'mdx',
				'neorg',
				'org',
				'plaintex',
				'quarto',
				'rmd',
				'rnoweb',
				'rst',
				'rsweave',
				'tex',
				'text',
				'typst',
				'xhtml',
			},
			enabledRules = {
				['en-US'] = {
					'PASSIVE_VOICE',
				},
			},
			language = 'en-US',
		},
		hiddenFailPositives = {},
		languageToolHttpServerUri = {},
		languageToolOrg = {
			apiKey = {},
			username = {},
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
				nodes = { ---@source https://javadoc.io/static/com.vladsch.flexmark/flexmark/0.62.2/com/vladsch/flexmark/ast/package-summary.html
					AutoLink = 'dummy',
					Code = 'dummy',
					CodeBlock = 'ignore',
					FencedCodeBlock = 'ignore',
				},
			},
			paragraphCacheEnabled = true,
			paragraphCacheTtlMinutes = 30,
			sentenceCacheSize = 2000,
			statusBarItem = true,
		},
		['ltex-ls'] = {
			logllevel = 'finest', ---"severe", "warning", "info", "config", "fine", "finer", "finest"
			path = vim.fn.expand('$XDG_DATA_HOME/ltex/ltex-ls-plus'),
		},
		java = {
			initializeHeapSize = 64,
			maximumHeapSize = 2048,
			path = {},
		},
		maxRequestSize = 20000,
		statuBarItem = true,
		trace = {
			server = 'verbose',
		},
	},
}
