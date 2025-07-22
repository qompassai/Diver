-- qompassai/Diver/lua/config/lang/python.lua
-- Qompass AI Diver Python Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'config.lang.python'
if vim.fn.has('nvim-0.11') == 1 then vim.opt.shortmess:append({ I = true }) end
local M = {}

function M.nls(opts)
	opts = opts or {}
	local nlsb = require('null-ls').builtins
	local sources = {
		nlsb.formatting.isortd,
		nlsb.formatting.blackd,
		nlsb.code_actions.refactoring.with({ filetypes = { 'python' } }),
		nlsb.hover.dictionary,
		nlsb.completion.spell,
		nlsb.diagnostics.pylint,
		nlsb.diagnostics.mypy.with({
			extra_args = opts.mypy_args or {
				'--ignore-missing-imports', '--disallow-untyped-defs',
				'--check-untyped-defs', '--warn-redundant-casts',
				'--no-implicit-optional'
			},
			cwd = function(params)
				return require('null-ls.utils').root_pattern('mypy.ini', '.mypy.ini')(params.bufname)
			end
		}),
	}
	return sources
end

---@return nil
function M.py_dap()
	---@type table<string, any>
	local dap = require("dap")
	---@type table<string, any>
	local dap_python = require("dap-python")
	local function get_pyenv_python()
		local base = vim.fn.expand("~/.pyenv/versions/")
		local handle = io.popen("ls " .. base)
		if not handle then return nil end
		for line in handle:lines() do
			local python_path = base .. line .. "/bin/python"
			if vim.fn.filereadable(python_path) == 1 then
				handle:close()
				return python_path
			end
		end
		handle:close()
		return nil
	end
	dap.adapters.python = {
		type = "executable",
		command = "uv",
		args = { "run", "python", "-m", "debugpy.adapter" },
	}
	dap.configurations.python = {
		{
			type = "python",
			request = "launch",
			name = "🐞 Launch file",
			program = "${file}",
			---@return string
			pythonPath = function()
				local project_venv = vim.fn.getcwd() .. "/.venv/bin/python"
				if vim.fn.filereadable(project_venv) == 1 then
					return project_venv
				end
				local pyenv_python = get_pyenv_python()
				if pyenv_python then
					return pyenv_python
				end
				return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
			end,
		},
	}
	dap_python.setup(
		vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
	)
	dap_python.test_runner = "pytest"
end

function M.py_jupyter(opts)
	opts = opts or {}
	require('quarto').setup({
		lspFeatures = {
			enabled = opts.quarto_lsp ~= true,
			chunks = opts.quarto_chunks or 'curly',
			languages = opts.quarto_langs or
					{ 'r', 'python', 'julia', 'bash', 'html' },
			diagnostics = {
				enabled = opts.quarto_diagnostics ~= false,
				triggers = opts.quarto_diag_triggers or { 'BufWritePost' }
			}
		},
		codeRunner = {
			enabled = opts.code_runner ~= true,
			default_method = opts.code_runner_method or 'molten',
			ft_runners = opts.code_runner_fts or { python = 'molten' }
		}
	})
	require('jupytext').setup({
		notebook_to_script_cmd = opts.jupytext_to_script or 'jupytext --to py',
		script_to_notebook_cmd = opts.jupytext_to_notebook or
				'jupytext --to ipynb',
		style = opts.jupytext_style or 'hydrogen',
		output_extension = opts.jupytext_ext or 'ipynb',
		force_ft = opts.jupytext_force_ft or 'python'
	})
end

function M.py_notebook_detection(opts)
	opts = opts or {}
	vim.api.nvim_create_autocmd('BufRead', {
		pattern = opts.patterns or { 'python', '*.ipynb', '*.mojo', '*.🔥' },
		callback = function()
			local ext = vim.fn.expand('%:e')
			if ext == 'ipynb' then
				vim.b.is_jupyter_notebook = true
				vim.keymap.set('n', opts.keys.run_cell or '<leader>x',
					'<cmd>JupyterSendCell<cr>', {
						buffer = true,
						desc = opts.desc_run_cell or 'Run cell'
					})
				vim.keymap.set('n', opts.keys.run_all or '<leader>X',
					'<cmd>JupyterSendAll<cr>', {
						buffer = true,
						desc = opts.desc_run_all or 'Run all'
					})
				return
			end
			local markers = opts.markers or
					{
						'^# %%', '^#%%', '^# In%[', '^// %%', '^//%%', '^// CELL'
					}
			for _, m in ipairs(markers) do
				if vim.fn.search(m, 'nw') > 0 then
					vim.b.has_jupyter_cells = true
					local cmd = (vim.bo.filetype == 'mojo') and 'Mojo' or
							'Jupyter'
					vim.keymap.set('n', opts.keys.run_cell or '<leader>x',
						'<cmd>' .. cmd .. 'SendCell<cr>',
						{ buffer = true })
					vim.keymap.set('n', opts.keys.run_all or '<leader>X',
						'<cmd>' .. cmd .. 'SendAll<cr>',
						{ buffer = true })
					break
				end
			end
		end
	})
end

---@return string|nil
local function get_pyenv_python(version)
	local base = vim.fn.expand("~/.pyenv/versions/")
	if version then
		local path = base .. version .. "/bin/python"
		return vim.fn.filereadable(path) == 1 and path or nil
	end
	local handle = io.popen("ls " .. base)
	if not handle then return nil end
	for line in handle:lines() do
		local path = base .. line .. "/bin/python"
		if vim.fn.filereadable(path) == 1 then
			handle:close()
			return path
		end
	end
	handle:close()
	return nil
end

function M.py_project_tools(opts)
	opts = opts or {}

	local default_python = opts.python_host_prog or
			get_pyenv_python() or
			vim.fn.expand("~/.venv/nvim/bin/python")

	vim.g.python3_host_prog = default_python

	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*.py",
		callback = function()
			local root = vim.fn.findfile("pyproject.toml", vim.fn.getcwd() .. ";")
			if root ~= "" then
				local proj_venv = vim.fn.fnamemodify(root, ":p:h") .. "/.venv/bin/python"
				if vim.fn.filereadable(proj_venv) == 1 then
					vim.g.python3_host_prog = proj_venv
					return
				end
			end
			local fallback_pyenv = get_pyenv_python()
			if fallback_pyenv then
				vim.g.python3_host_prog = fallback_pyenv
			end
		end
	})
	if opts.enable_poetry then
		vim.api.nvim_create_user_command("PoetryInstall", function()
			vim.fn.system("poetry install")
			vim.notify("✅ Poetry dependencies installed", vim.log.levels.INFO)
		end, {})

		vim.api.nvim_create_user_command("PoetryUpdate", function()
			vim.fn.system("poetry update")
			vim.notify("♻️ Poetry dependencies updated", vim.log.levels.INFO)
		end, {})
	end
end

function M.py_venv(version)
	local base = vim.fn.expand("~/.pyenv/versions/")
	if version then
		local path = base .. version .. "/bin/python"
		return vim.fn.filereadable(path) == 1 and path or nil
	end
	local handle = io.popen("ls " .. base)
	if not handle then return nil end
	for line in handle:lines() do
		local path = base .. line .. "/bin/python"
		if vim.fn.filereadable(path) == 1 then
			handle:close()
			return path
		end
	end
	handle:close()
	return nil
end

function M.py_lsp(opts)
	opts = opts or {}
	return {
		on_new_config = function(new_config)
			local diver_python = M.py_venv()
			if diver_python then
				new_config.settings.python.pythonPath = diver_python
				return
			end
			local venv = vim.fn.finddir(".venv*", vim.fn.getcwd() .. ";", 1)
			if venv ~= "" then
				local python_path = venv .. "/bin/python"
				if vim.fn.executable(python_path) == 1 then
					new_config.settings.python.pythonPath = python_path
				end
			end
		end,
		before_init = function(_, config)
			config.settings.python.analysis.typeInformationMode = "standard"
		end,
		capabilities = {
			workspace = {
				fileOperations = {
					didRename = true,
					willRename = true,
				}
			}
		},
		settings = {
			python = {
				pythonPath = M.py_venv(),
				venvPath = vim.fn.expand("~/.pyenv/versions"),
				venv = ".",
				workspace = {
					symbolIndex = true,
					symbolMaxWorkspace = 5000,
					enableSourceMap = true,
				},
				analysis = {
					typeCheckingMode = opts.typeCheckingMode or "strict",
					diagnosticMode = opts.diagnosticMode or "openFilesOnly",
					autoSearchPaths = true,
					useLibraryCodeForTypes = true,
					diagnosticSeverityOverrides = opts.diagnosticSeverityOverrides or {
						reportUnusedImport = "warning",
						reportUnusedVariable = "warning",
						reportUnusedClass = "warning",
					},
					strictListInference = true,
					strictDictionaryInference = true,
					strictSetInference = true,
					strictParameterNoneValue = true,
					autoImportCompletions = true,
					importFormat = opts.importFormat or "absolute",
					stubPath = opts.stubPath or "typings",
					logLevel = opts.logLevel or "Information",
					typeEvaluationMode = "standard",
					indexing = true,
					inlayHints = {
						variableTypes = opts.variableTypesInlay or true,
						functionReturnTypes = opts.functionReturnTypesInlay or true,
						callArgumentNames = opts.callArgumentNames or "all",
						pytestParameters = true,
					}
				}
			}
		}
	}
end

---@return table
function M.python_treesitter()
	return {
		ensure_installed = {},
		highlight = {
			enable = true,
			disable = {},
		},
		indent = {
			enable = true,
		},
	}
end

---@param opts table
function M.python_cfg(_, opts)
	opts = opts or {}
	M.nls(opts)
	M.py_dap()
	M.py_jupyter(opts.jupyter)
	M.py_notebook_detection(opts.notebook)
	M.py_project_tools(opts.tools)
	M.py_lsp(opts)
end

return M
