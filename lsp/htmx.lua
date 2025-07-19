-- /qompassai/Diver/lsp/htmx.lua
-- Qompass AI Htmx LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
	vim.lsp.config('htmx', {
		cmd = { 'htmx-lsp' },
		filetypes = {
			-- html
			'aspnetcorerazor',
			'astro',
			'astro-markdown',
			'blade',
			'clojure',
			'django-html',
			'htmldjango',
			'edge',
			'eelixir', -- vim ft
			'elixir',
			'ejs',
			'erb',
			'eruby', -- vim ft
			'gohtml',
			'gohtmltmpl',
			'haml',
			'handlebars',
			'hbs',
			'html',
			'htmlangular',
			'html-eex',
			'heex',
			'jade',
			'leaf',
			'liquid',
			--	'markdown',
			'mdx',
			'mustache',
			'njk',
			'nunjucks',
			'php',
			'razor',
			'slim',
			'twig',
			-- js
			'javascript',
			'javascriptreact',
			'reason',
			'rescript',
			'typescript',
			'typescriptreact',
			-- mixed
			'vue',
			'svelte',
			'templ',
		},
		root_markers = { '.git' },
	}
	) }
