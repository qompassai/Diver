--- Rust language config — autocmds, crates helpers, and DAP for Rust.
---
--- Plain-language version: when you open a Rust file, this module wires up the Rust-specific extras: automatic
--- commands, crates.io dependency helpers, and debugger settings. It runs on Rust filetypes; cargo and friends must
--- be installed for the helpers to work.
---@module 'config.lang.rust'
-- /qompassai/Diver/lua/config/lang/rust.lua
-- Qompass AI Diver Rust Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------------
local M = {}
local modernize = require('config.lang.modernize')
local api = vim.api
local autocmd = vim.api.nvim_create_autocmd
local code_action = vim.lsp.buf.code_action
local fn = vim.fn
local get = vim.diagnostic.get
local header = require("research.docs")
local protocol = vim.lsp.protocol
local group = api.nvim_create_augroup("Rust", {
	clear = true,
})
---Create a buffer-local user command when a rust buffer opens.
---Lang commands only exist in buffers of their own language: they never
---pollute `:` completion elsewhere.
---@param name string command name
---@param fn function|string command implementation
---@param opts? table nvim_create_user_command options
local function usercmd(name, fn, opts)
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'rust',
        desc = ('Buffer-local command: %s'):format(name),
        callback = function(args)
            vim.api.nvim_buf_create_user_command(args.buf, name, fn, opts or {})
        end,
    })
end
local WARN = vim.log.levels.WARN
---Register Rust autocmds (format, inlay hints) for rust_analyzer clients.
---The three save-time BufWritePre hooks are registered as format stages so
---the single pipeline owner runs them; they are only registered when this
---function is invoked (the module is dormant until M.rust_cfg is called).
---@return nil
function M.rust_autocmds()
	autocmd("BufNewFile", {
		group = group,
		pattern = { "*.rs" },
		callback = function()
			if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= "" then
				return
			end
			local filepath = fn.expand("%:p")
			local hdr = header.make_header(filepath, "//")
			api.nvim_buf_set_lines(0, 0, 0, false, hdr)
			vim.cmd("normal! G")
		end,
	})
	local formatters = require("formatters")
	-- Idempotent: registering twice is an error, so skip if already done.
	if formatters.get_stage("rust_lsp_format") == nil then
		formatters.register_stage({
			name = "rust_lsp_format",
			priority = 435,
			patterns = { "*.rs" },
			desc = "Format Rust sources with the attached LSP client before save",
			run = function(bufnr)
				vim.lsp.buf.format({
					bufnr = bufnr,
					async = true,
				})
			end,
		})
	end
	if formatters.get_stage("rust_fixall_organize") == nil then
		formatters.register_stage({
			name = "rust_fixall_organize",
			priority = 436,
			patterns = { "*.rs" },
			desc = "Apply source.fixAll and source.organizeImports to Rust sources before save",
			run = function(bufnr)
				local diagnostics = get(bufnr)
				code_action({
					context = {
						diagnostics = diagnostics,
						only = {
							"source.fixAll",
							"source.organizeImports",
						},
						triggerKind = protocol.CodeActionTriggerKind.Source,
					},
					apply = true,
					filter = function(_, client_id)
						local client = vim.lsp.get_client_by_id(client_id)
						return client ~= nil and client.name == "rust_analyzer"
					end,
				})
			end,
		})
	end
	usercmd("RustQuickfix", function()
		local diagnostics = get(0)
		code_action({
			context = {
				diagnostics = diagnostics,
				only = {
					"quickfix",
				},
				triggerKind = protocol.CodeActionTriggerKind.Invoked,
			},
			apply = true,
			filter = function(_, client_id)
				local client = vim.lsp.get_client_by_id(client_id)
				return client ~= nil and client.name == "rust_analyzer"
			end,
		})
	end, {})
	usercmd("RustCodeAction", function()
		local diagnostics = get(0)
		code_action({
			context = {
				diagnostics = diagnostics,
				only = {
					"quickfix",
					"refactor",
					"source.organizeImports",
					"source.fixAll",
				},
			},
			filter = function(_, client_id)
				local client = vim.lsp.get_client_by_id(client_id)
				return client ~= nil and client.name == "rust_analyzer"
			end,
			apply = true,
		})
	end, {})
	usercmd("RustRangeAction", function()
		local bufnr = 0
		local diagnostics = get(bufnr)
		local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
		local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
		code_action({
			context = {
				diagnostics = diagnostics,
				only = {
					"quickfix",
					"refactor.extract",
				},
			},
			range = {
				start = {
					start_pos[1],
					start_pos[2],
				},
				["end"] = {
					end_pos[1],
					end_pos[2],
				},
			},
			filter = function(_, client_id)
				local client = vim.lsp.get_client_by_id(client_id)
				return client ~= nil and client.name == "rust_analyzer"
			end,
			apply = false,
		})
	end, {
		range = true,
	})
	usercmd("RustCheck", function()
		local ok, cargo = pcall(require, "dev.cargo")
		if ok and cargo then
			local info, err = cargo.run({ subcommand = "check" })
			if err then
				vim.notify("RustCheck: " .. err, WARN)
			end
			assert(info ~= nil or err ~= nil, "cargo.run returned neither info nor error")
		else
			vim.notify("RustCheck: dev.cargo not available", WARN)
		end
	end, { desc = "cargo check via dev.cargo (float + quickfix)" })
	usercmd("RustClippy", function()
		local ok, cargo = pcall(require, "dev.cargo")
		if ok and cargo then
			local info, err = cargo.run({ subcommand = "clippy" })
			if err then
				vim.notify("RustClippy: " .. err, WARN)
			end
			assert(info ~= nil or err ~= nil, "cargo.run returned neither info nor error")
		else
			vim.notify("RustClippy: dev.cargo not available", WARN)
		end
	end, { desc = "cargo clippy via dev.cargo (float + quickfix)" })
	usercmd("BevyLint", function()
		-- bevy_lint links against the pinned nightly's private librustc_driver,
		-- so it must run through `rustup run <nightly>`; update the toolchain
		-- name here when reinstalling the linter for a new Bevy version.
		local toolchain = "nightly-2026-04-16"
		if fn.executable("bevy_lint") ~= 1 then
			vim.notify(
				"BevyLint: bevy_lint is not installed. Install it with its pinned nightly toolchain (see TheBevyFlock/bevy_cli) and re-run.",
				WARN
			)
			return
		end
		vim.cmd("botright split | terminal rustup run " .. toolchain .. " bevy_lint --workspace --all-targets")
	end, { desc = "Run bevy_lint on the workspace in a terminal split" })
	if formatters.get_stage("rust_lsp_format_current") == nil then
		formatters.register_stage({
			name = "rust_lsp_format_current",
			priority = 437,
			patterns = { "*.rs" },
			desc = "Async LSP format pass for Rust sources before save",
			run = function()
				vim.lsp.buf.format({
					async = true,
				})
			end,
		})
	end
	autocmd("FileType", {
		pattern = "rust",
		callback = function()
			local ok, rustmap = pcall(require, "mappings.rustmap")
			if ok and rustmap and type(rustmap.setup) == "function" then
				rustmap.setup()
			end
		end,
	})
end

---Set up crates.io helpers for Rust dependencies.
---@return nil
function M.rust_crates()
	local ok, crates = pcall(require, "crates")
	if not ok then
		vim.notify("crates.nvim not available, skipping crates setup", vim.log.levels.WARN)
		return
	end
	crates.setup({
		autoload = true,
		autoupdate = true,
		autoupdate_throttle = 250,
		smart_insert = true,
		insert_closing_quote = true,
		loading_indicator = true,
		date_format = "%Y-%m-%d",
		thousands_separator = ".",
		notification_title = "crates.nvim",
		popup = {
			autofocus = false,
			hide_on_select = false,
			border = "none",
			show_version_date = true,
		},
		lsp = {
			enabled = true,
			name = "crates.nvim",
			actions = true,
			completion = true,
		},
	})
	api.nvim_create_autocmd("BufRead", {
		group = group,
		pattern = "Cargo.toml",
		callback = function()
			vim.defer_fn(crates.show, 300)
		end,
	})
end

---Configure the codelldb debug adapter and Rust launch configurations.
---@return nil
function M.rust_dap()
	local dap = require("dap")
	local ok, dapui = pcall(require, "dapui")
	if not ok then
		vim.notify("nvim-dap-ui not available, skipping dapui setup", vim.log.levels.WARN)
		return
	end
	dap.adapters.codelldb = {
		type = "server",
		port = "${port}",
		executable = {
			command = fn.exepath("codelldb") or "/usr/bin/codelldb",
			args = {
				"--port",
				"${port}",
			},
		},
	}
	dap.configurations.rust = {
		{
			name = "Launch",
			type = "codelldb",
			request = "launch",
			program = function()
				return fn.input("Path to executable: " .. fn.getcwd() .. "/")
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = {},
		},
	}
	dap.listeners.after.event_exited.dapui_config = function()
		dapui.close()
	end
end

---RPC workbench for developing the phlow msgpack shim.
---These are global (not buffer-local): RPC state is editor-wide.

---Tail the Neovim log for RPC traffic. For the full frame log, restart with
---NVIM_LOG_FILE=/tmp/nvim-rpc.log in the environment.
api.nvim_create_user_command("RpcLog", function()
	local logfile = vim.env.NVIM_LOG_FILE
	if not logfile or logfile == "" then
		vim.notify(
			"NVIM_LOG_FILE not set. Restart with:\nNVIM_LOG_FILE=/tmp/nvim-rpc.log nvim",
			vim.log.levels.WARN
		)
		return
	end
	vim.cmd("split | terminal tail -n 100 -F " .. fn.shellescape(logfile))
end, { desc = "Tail the Neovim RPC log (shim development)" })

---Show the RPC server address and API surface the shim can target.
api.nvim_create_user_command("RpcInfo", function()
	local info = vim.fn.api_info()
	local n_fns = (info and info.functions and #info.functions) or 0
	vim.notify(
		("server: %s\napi functions: %d\nversion: %s"):format(
			vim.v.servername or "(embedded)",
			n_fns,
			tostring(vim.version())
		),
	vim.log.levels.INFO
	)
end, { desc = "Show RPC server address and API surface (shim development)" })

---Fuzzy-find a Neovim API function and show its exact signature, as the
---shim must call it. Signatures come from nvim --api-info metadata.
api.nvim_create_user_command("NvimApi", function()
	local info = vim.fn.api_info()
	if not info or not info.functions then
		vim.notify("api_info unavailable", vim.log.levels.ERROR)
		return
	end
	local by_name = {}
	local names = {}
	for _, f in ipairs(info.functions) do
		by_name[f.name] = f
		names[#names + 1] = f.name
	end
	table.sort(names)
	vim.ui.select(names, { prompt = "Neovim API function:" }, function(choice)
		if not choice then
			return
		end
		local f = by_name[choice]
		local params = {}
		for _, p in ipairs(f.parameters or {}) do
			params[#params + 1] = ("%s: %s"):format(p[2], p[1])
		end
		local ret = type(f.return_type) == "string" and f.return_type or "?"
		local sig = ("%s(%s) -> %s"):format(f.name, table.concat(params, ", "), ret)
		local buf = api.nvim_create_buf(false, true)
		api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(sig, "\n"))
		vim.bo[buf].filetype = "lua"
		vim.bo[buf].modifiable = false
		api.nvim_open_win(buf, true, { split = "right" })
	end)
end, { desc = "Show a Neovim API function signature (shim development)" })

---Apply the Rust language configuration.
---@param _opts? table unused option overrides
---@return nil
function M.rust_cfg(_opts)
	M.rust_autocmds()
	M.rust_dap()
	M.rust_crates()
end


local REPLACEMENTS = {
    { "\\btry!\\s*\\(", "/* try! -> ? */ (" },
}

---Modernize deprecated rust syntax in the current buffer.
function M.modernize()
    modernize.buffer('rust', REPLACEMENTS, 'rust')
end

return M
