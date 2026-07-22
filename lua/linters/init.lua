-- /qompassai/Diver/linters/init.lua
-- Qompass AI Diver Linter Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
local diagnostic = vim.diagnostic
local fn = vim.fn
local M = {}
M.linters_by_ft = {
	--'abaplint_ls', ---:TODO: ---validate ---@source https://github.com/abaplint/abaplint | https://www.npmjs.com/org/abaplint
	asm = {
		'llvm-mc',
	},
	ansible = {
		'ansible_lint',
	},
	apkbuild = {
		'apkbuild-lint',
		'secfixes-check',
	},
	--astro = {},
	--awk = {},
	bash = {
		'bashlint',
		'shellcheck',
	},
	bazel = 'buildifier',
	bibtex = 'bibclean',
	-- c = {},
	cairo = 'scarb',
	chef = 'cookstyle', ---foodcritic deprecated
	clojure = {
		'clj-kondo',
	},
	cmake = {
		'cmake-lint',
	},
	crystal = {
		'ameba',
	},
	--cpp = {},
	--csharp = {},
	css = {
		'csslint',
		'stylelint',
	},
	cuda = {
		'nvcc',
	},
	-- cypher = 'cypher-lint',
	cython = 'cython-lint',
	-- dart = 'dart-analyze',
	-- dhall = 'dhall-lint',
	desktop = 'desktop-file-validate',
	-- dockerfile = {
	--   'dockerlinter',
	--   'dprint',
	--   'hadolint',
	-- },
	--  ejs = {},
	-- elixir = {},
	-- elm = {},
	-- erlang = {
	--  'dialyzer',
	--  'elvis',
	-- },
	--fish = {
	--'fish -n',
	--'fish_indent',
	--'shellcheck',
	--},
	--gh_cations = 'zizmore',
	-- gleam = 'gleam_format',
	--glsl = {
	--'glslang',
	--'glslls',
	--},
	--go = {},
	--graphql = 'gqlint',
	--groovy = 'npm_groovy_lint',
	handlebars = {
		'djlint',
		'ember-template-lint',
	},
	--haskell = {},
	helm = {},
	htmlangular = {},
	htmldjango = {},
	--html = {
	-- },
	http = {},
	-- inko = 'inko',
	--java = {
	--  'checkstyle',
	--},
	javascript = {},
	javascriptreact = {},
	jinja = {
		'djlint',
		'j2lint',
	},
	--json = {},
	--jsonc = {''},
	jsonnet = {
		'jsonnetlint',
	},
	jsx = {},
	julia = {},
	just = {},
	justfile = {},
	kotlin = {
		--'kotlinc',
		'ktlint',
	},
	latex = {
		'lacheck',
	},
	-- llvm = 'llc',
	lua = {
		'luac',
	},
	luau = {
		'luac',
	},
	--markdown = {
	-- 'mado',
	-- },
	mail = {
		--'alex',
		'proselint',
	},
	matlab = 'mlint',
	mustache = {},
	nix = {
		'deadnix',
		'statix',
	},
	php = {
		'intelephense',
		'phan',
		'php',
		'phpcs',
		'phpmd',
		'phpstan',
		'psalm',
	},
	prisma = {},
	proto = {},
	protobuf = {},
	python = {
		'bandit',
		'vulture',
	},
	powershell = {
		'psscriptanalyzer',
	},
	pug = 'pug-lint',
	--[[qml = {
        'qmllint',
    },
    --]]
	r = {},
	ruby = {
		'sorbet',
	},
	scala = {
		'scalac',
		'scalastyle',
	},
	sass = {
		'sass-lint',
	},
	scss = {},
	--[[
  solidity = {
    'forge',
    'solc',
    'solhint',
    'solium',
  },
  ]]
	--
	sphinx = 'sphinx-lint',
	sql = {
		'sqlfluff',
	},
	sqlite = {},
	svelte = {},
	swift = 'swiftlint',
	terraform = 'tflint',
	--[[
  toml = {
    'dprint',
  },
  --]]
	-- tsx = {},
	typescript = {},
	typescriptreact = {},
	vue = {},
	wgsl = 'naga',
	-- xml = 'xmllint',
	--yaml = {
	--  'yamllint',
	--},
	--yml = {},
	zig = {
		'zlint',
	},
	zine = {
		'zlint',
	},
	zon = {
		'zlint',
	},
	zsh = {
		'shellcheck',
	},
}
---@type table<string, vim.lint.Config>
M.definitions = {
	actionlint = require('linters.actionlint'),
	luac = require('linters.luac'),
	shellcheck = require('linters.shellcheck'),
}

---@type table<string, integer>
local namespaces = {}

---@type table<string, vim.SystemObj>
local jobs = {}

---Used to prevent a cancelled job from publishing stale diagnostics.
---@type table<string, integer>
local job_generations = {}

---@type table<string, vim.diagnostic.Severity>
local severity_by_type = {
	E = diagnostic.severity.ERROR,
	W = diagnostic.severity.WARN,
	I = diagnostic.severity.INFO,
	N = diagnostic.severity.HINT,
	S = diagnostic.severity.HINT,
}

---@param name string
---@return integer
local function namespace(name)
	local existing = namespaces[name]

	if existing then
		return existing
	end

	local created = api.nvim_create_namespace('qompass.linter.' .. name)
	namespaces[name] = created

	return created
end

---@param bufnr integer
---@return string[]
local function configured_linters(bufnr)
	local configured = M.linters_by_ft[vim.bo[bufnr].filetype]

	if type(configured) == 'string' then
		return { configured }
	end

	return configured or {}
end

---@param definition vim.lint.Config
---@return string?
local function resolve_errorformat(definition)
	local errorformat = definition.errorformat

	if type(errorformat) == 'table' then
		return table.concat(errorformat, ',')
	end

	return errorformat
end

---@param result vim.SystemCompleted
---@param stream? vim.lint.Stream
---@return string
local function resolve_output(result, stream)
	if stream == 'stdout' then
		return result.stdout or ''
	end

	if stream == 'both' then
		return table.concat({
			result.stdout or '',
			result.stderr or '',
		}, '\n')
	end

	return result.stderr or ''
end

---@param name string
---@param definition vim.lint.Config
---@param output string
---@param bufnr integer
local function parse_diagnostics(name, definition, output, bufnr)
	local ns = namespace(name)

	if definition.parser then
		local diagnostics = definition.parser(output, bufnr)
		diagnostic.set(ns, bufnr, diagnostics)
		return
	end

	local errorformat = resolve_errorformat(definition)

	if not errorformat then
		diagnostic.reset(ns, bufnr)

		vim.notify(('Linter %q has neither a parser nor an errorformat'):format(name), vim.log.levels.WARN)
		return
	end

	local parsed = fn.getqflist({
		lines = vim.split(output, '\n', {
			plain = true,
			trimempty = true,
		}),
		efm = errorformat,
	})

	---@type vim.Diagnostic.Set[]
	local diagnostics = {}

	for _, item in ipairs(parsed.items or {}) do
		if item.valid == 1 then
			local end_lnum = item.end_lnum or 0
			local end_col = item.end_col or 0
			local diagnostic_number = item.nr or 0
			local item_type = item.type or 'E'

			diagnostics[#diagnostics + 1] = {
				lnum = math.max((item.lnum or 1) - 1, 0),
				col = math.max((item.col or 1) - 1, 0),
				end_lnum = end_lnum > 0 and end_lnum - 1 or nil,
				end_col = end_col > 0 and end_col - 1 or nil,
				message = item.text or 'Unknown diagnostic',
				severity = severity_by_type[item_type] or diagnostic.severity.ERROR,
				source = name,
				code = diagnostic_number > 0 and diagnostic_number or nil,
			}
		end
	end

	diagnostic.set(ns, bufnr, diagnostics)
end

---@param bufnr integer
---@return string?
local function buffer_input(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return nil
	end

	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local input = table.concat(lines, '\n')

	if vim.bo[bufnr].endofline then
		input = input .. '\n'
	end

	return input
end

---@param definition vim.lint.Config
---@param context vim.lint.Context
---@return string
local function resolve_cwd(definition, context)
	local configured_cwd = definition.cwd

	if type(configured_cwd) == 'function' then
		return configured_cwd(context)
	end

	if type(configured_cwd) == 'string' then
		return configured_cwd
	end

	return context.cwd
end

---@param definition vim.lint.Config
---@param context vim.lint.Context
---@return string[]
local function build_command(definition, context)
	local command = {
		definition.cmd,
	}

	local configured_args = definition.args

	if type(configured_args) == 'function' then
		local resolved_args = configured_args(context)
		vim.list_extend(command, resolved_args)
	elseif type(configured_args) == 'table' then
		vim.list_extend(command, configured_args)
	end

	if definition.append_fname then
		command[#command + 1] = context.filename
	end

	return command
end

---@param name string
---@param bufnr? integer
function M.run_linter(name, bufnr)
	if bufnr == nil or bufnr == 0 then
		bufnr = api.nvim_get_current_buf()
	end

	if not api.nvim_buf_is_valid(bufnr) then
		return
	end

	local definition = M.definitions[name]

	if not definition then
		vim.notify(('No definition exists for linter %q'):format(name), vim.log.levels.WARN)
		return
	end

	if fn.executable(definition.cmd) ~= 1 then
		diagnostic.reset(namespace(name), bufnr)

		vim.notify(('Linter executable not found: %s'):format(definition.cmd), vim.log.levels.WARN)
		return
	end

	local filename = api.nvim_buf_get_name(bufnr)

	if filename == '' then
		return
	end

	local default_cwd = vim.fs.dirname(filename) or vim.uv.cwd() or '.'

	---@type vim.lint.Context
	local context = {
		bufnr = bufnr,
		cwd = default_cwd,
		filename = filename,
		filetype = vim.bo[bufnr].filetype,
	}

	local command = build_command(definition, context)
	local cwd = resolve_cwd(definition, context)
	local job_key = ('%d:%s'):format(bufnr, name)

	local previous_job = jobs[job_key]

	if previous_job then
		pcall(previous_job.kill, previous_job, 15)
	end

	local generation = (job_generations[job_key] or 0) + 1
	job_generations[job_key] = generation

	local changedtick = api.nvim_buf_get_changedtick(bufnr)

	---@type string?
	local stdin

	if definition.stdin then
		stdin = buffer_input(bufnr)
	end

	---@param result vim.SystemCompleted
	local function on_exit(result)
		vim.schedule(function()
			if job_generations[job_key] ~= generation then
				return
			end

			jobs[job_key] = nil

			if not api.nvim_buf_is_valid(bufnr) then
				return
			end

			if api.nvim_buf_get_changedtick(bufnr) ~= changedtick then
				return
			end

			local output = resolve_output(result, definition.stream)

			if result.code ~= 0 and not definition.ignore_exitcode and output == '' then
				diagnostic.reset(namespace(name), bufnr)

				vim.notify(('%s failed with exit code %d'):format(name, result.code), vim.log.levels.ERROR)
				return
			end

			parse_diagnostics(name, definition, output, bufnr)
		end)
	end

	jobs[job_key] = vim.system(command, {
		cwd = cwd,
		env = definition.env,
		stdin = stdin,
		text = true,
		timeout = definition.timeout,
	}, on_exit)
end

---@param bufnr? integer
function M.run(bufnr)
	if bufnr == nil or bufnr == 0 then
		bufnr = api.nvim_get_current_buf()
	end

	if not api.nvim_buf_is_valid(bufnr) then
		return
	end

	for _, name in ipairs(configured_linters(bufnr)) do
		M.run_linter(name, bufnr)
	end
end

function M.setup()
        local group = api.nvim_create_augroup('qompass.linters', { clear = true })

        api.nvim_create_autocmd('FileType', {
                group = group,
                desc = 'Run linters when filetype is detected',
                callback = function(event)
                        M.run(event.buf)
                end,
        })

        api.nvim_create_autocmd('BufWritePost', {
                group = group,
                desc = 'Redetect filetype if needed, then lint on save',
                callback = function(event)
                        local bufnr = event.buf
                        if not api.nvim_buf_is_valid(bufnr) then
                                return
                        end

                        if vim.bo[bufnr].filetype == '' then
                                vim.cmd('silent! filetype detect')
                        end

                        M.run(bufnr)
                end,
        })

        api.nvim_create_user_command('Lint', function()
                M.run(0)
        end, {
                desc = 'Run configured linters for the current buffer',
        })
end

)
		end,
	})

return M
