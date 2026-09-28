-- qompassai/Diver/lua/dev/ansible.lua
-- Qompass AI Diver Ansible Tooling (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Native Ansible workflow: lint, syntax-check, run playbooks, manage
-- vault secrets, and inspect inventory — all through argv-form subprocess
-- calls. DAP debugging lives in dap.ansible; this module is the
-- day-to-day operator toolkit.
---@module 'dev.ansible'

local M = {}

local api = vim.api

local setup_done = false

---Default configuration. Override via M.setup().
local config = {
	inventory = nil, -- default inventory path; nil = ansible auto-discovery
	vault_password_file = nil, -- path to vault password file; nil = prompt
	lint_on_save = true, -- run ansible-lint on BufWritePost for playbooks
}

local group = api.nvim_create_augroup("DevAnsible", { clear = true })

---Check that a binary exists and is executable.
---@param bin string Binary name.
---@return boolean ok
local function has_bin(bin)
	return vim.fn.executable(bin) == 1
end

---Run a command async and show output in a scratch float.
---@param cmd string[] Argv-form command.
---@param title string Float title.
local function run_in_float(cmd, title)
	assert(type(cmd) == "table" and #cmd > 0, "cmd must be a non-empty argv table")
	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(buf, 0, -1, false, { "Running: " .. table.concat(cmd, " "), "" })
	local win = api.nvim_open_win(buf, true, {
		relative = "editor",
		width = math.floor(vim.o.columns * 0.9),
		height = math.floor(vim.o.lines * 0.8),
		col = math.floor(vim.o.columns * 0.05),
		row = math.floor(vim.o.lines * 0.1),
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
	})
	vim.system(cmd, { text = true }, function(result)
		vim.schedule(function()
			if not api.nvim_buf_is_valid(buf) then
				return
			end
			local lines = vim.split(result.stdout or "", "\n")
			if result.stderr and result.stderr ~= "" then
				lines[#lines + 1] = ""
				lines[#lines + 1] = "--- stderr ---"
				for _, l in ipairs(vim.split(result.stderr, "\n")) do
					lines[#lines + 1] = l
				end
			end
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format("(exit %d — press q to close)", result.code)
			api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.keymap.set("n", "q", function()
				if api.nvim_win_is_valid(win) then
					api.nvim_win_close(win, true)
				end
			end, { buffer = buf, silent = true })
		end)
	end)
end

---Build base ansible-playbook args (inventory, vault).
---@return string[] args
local function base_args()
	local args = {}
	if config.inventory then
		args[#args + 1] = "-i"
		args[#args + 1] = config.inventory
	end
	if config.vault_password_file then
		args[#args + 1] = "--vault-password-file"
		args[#args + 1] = config.vault_password_file
	end
	return args
end

---Syntax-check a playbook.
---@param playbook string|nil Path (default: current buffer).
function M.syntax_check(playbook)
	playbook = playbook or api.nvim_buf_get_name(0)
	assert(playbook and playbook ~= "", "No playbook file")
	if not has_bin("ansible-playbook") then
		vim.notify("ansible-playbook not found", vim.log.levels.ERROR)
		return
	end
	local cmd = { "ansible-playbook", "--syntax-check", playbook }
	for _, a in ipairs(base_args()) do
		cmd[#cmd + 1] = a
	end
	run_in_float(cmd, "Ansible Syntax Check")
end

---Run a playbook.
---@param playbook string|nil Path (default: current buffer).
---@param extra_args string[]|nil Additional ansible-playbook flags.
function M.run_playbook(playbook, extra_args)
	playbook = playbook or api.nvim_buf_get_name(0)
	assert(playbook and playbook ~= "", "No playbook file")
	if not has_bin("ansible-playbook") then
		vim.notify("ansible-playbook not found", vim.log.levels.ERROR)
		return
	end
	local cmd = { "ansible-playbook", playbook }
	for _, a in ipairs(base_args()) do
		cmd[#cmd + 1] = a
	end
	for _, a in ipairs(extra_args or {}) do
		cmd[#cmd + 1] = a
	end
	run_in_float(cmd, "Ansible Run: " .. vim.fn.fnamemodify(playbook, ":t"))
end

---Run ansible-lint on a file and populate the quickfix list.
---@param path string|nil File path (default: current buffer).
function M.lint(path)
	path = path or api.nvim_buf_get_name(0)
	assert(path and path ~= "", "No file to lint")
	if not has_bin("ansible-lint") then
		vim.notify("ansible-lint not found", vim.log.levels.WARN)
		return
	end
	vim.system({ "ansible-lint", "--parseable", path }, { text = true }, function(result)
		vim.schedule(function()
			-- Parseable format: path:line:col: rule message
			local items = {}
			for _, line in ipairs(vim.split(result.stdout or "", "\n")) do
				local f, l, c, msg = line:match("^([^:]+):(%d+):(%d+):%s*(.+)$")
				if f and l then
					items[#items + 1] = {
						filename = f,
						lnum = tonumber(l),
						col = tonumber(c) or 1,
						text = msg,
						type = "W",
					}
				end
			end
			if #items == 0 and result.code == 0 then
				vim.notify("ansible-lint: clean", vim.log.levels.INFO)
				return
			end
			vim.fn.setqflist(items, "r")
			vim.cmd("copen")
			vim.notify(string.format("ansible-lint: %d issue(s)", #items), vim.log.levels.WARN)
		end)
	end)
end

---Encrypt the current buffer (or selection) with ansible-vault.
function M.vault_encrypt()
	if not has_bin("ansible-vault") then
		vim.notify("ansible-vault not found", vim.log.levels.ERROR)
		return
	end
	local path = api.nvim_buf_get_name(0)
	if path == "" then
		vim.notify("Save the file first", vim.log.levels.WARN)
		return
	end
	vim.cmd("write")
	local cmd = { "ansible-vault", "encrypt", path }
	if config.vault_password_file then
		cmd[#cmd + 1] = "--vault-password-file"
		cmd[#cmd + 1] = config.vault_password_file
	end
	vim.system(cmd, { text = true }, function(result)
		vim.schedule(function()
			if result.code == 0 then
				vim.cmd("edit!")
				vim.notify("Vault encrypted", vim.log.levels.INFO)
			else
				vim.notify("Vault encrypt failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
			end
		end)
	end)
end

---Decrypt the current buffer with ansible-vault.
function M.vault_decrypt()
	if not has_bin("ansible-vault") then
		vim.notify("ansible-vault not found", vim.log.levels.ERROR)
		return
	end
	local path = api.nvim_buf_get_name(0)
	if path == "" then
		return
	end
	local cmd = { "ansible-vault", "decrypt", path }
	if config.vault_password_file then
		cmd[#cmd + 1] = "--vault-password-file"
		cmd[#cmd + 1] = config.vault_password_file
	end
	vim.system(cmd, { text = true }, function(result)
		vim.schedule(function()
			if result.code == 0 then
				vim.cmd("edit!")
				vim.notify("Vault decrypted", vim.log.levels.INFO)
			else
				vim.notify("Vault decrypt failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
			end
		end)
	end)
end

---Show inventory hosts in a float.
---@param inventory string|nil Inventory path (default: config.inventory).
function M.show_inventory(inventory)
	inventory = inventory or config.inventory
	if not has_bin("ansible-inventory") then
		vim.notify("ansible-inventory not found", vim.log.levels.ERROR)
		return
	end
	local cmd = { "ansible-inventory", "--list" }
	if inventory then
		cmd[#cmd + 1] = "-i"
		cmd[#cmd + 1] = inventory
	end
	run_in_float(cmd, "Ansible Inventory")
end

---Configure the module.
---@param opts table|nil { inventory, vault_password_file, lint_on_save }
function M.setup(opts)
	if setup_done then
		return M
	end
	assert(opts == nil or type(opts) == "table", "setup expects a table")
	config = vim.tbl_deep_extend("force", config, opts or {})

	-- 2-space indent for Ansible YAML.
	api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = { "yaml.ansible" },
		callback = function()
			vim.opt_local.shiftwidth = 2
			vim.opt_local.tabstop = 2
			vim.opt_local.expandtab = true
		end,
	})

	-- Lint on save.
	if config.lint_on_save then
		api.nvim_create_autocmd("BufWritePost", {
			group = group,
			pattern = { "*.yml", "*.yaml" },
			callback = function()
				-- Only lint if it looks like a playbook.
				local first = api.nvim_buf_get_lines(0, 0, 10, false)
				for _, line in ipairs(first) do
					if line:match("^%s*-%s+hosts:") or line:match("^%s*hosts:") then
						M.lint()
						break
					end
				end
			end,
		})
	end

	api.nvim_create_user_command("AnsibleRun", function(cmd_opts)
		M.run_playbook(cmd_opts.args ~= "" and cmd_opts.args or nil)
	end, { nargs = "?", complete = "file", desc = "Run Ansible playbook" })

	api.nvim_create_user_command("AnsibleCheck", function(cmd_opts)
		M.syntax_check(cmd_opts.args ~= "" and cmd_opts.args or nil)
	end, { nargs = "?", complete = "file", desc = "Syntax-check Ansible playbook" })

	api.nvim_create_user_command("AnsibleLint", function()
		M.lint()
	end, { desc = "Lint current file with ansible-lint" })

	api.nvim_create_user_command("AnsibleVaultEncrypt", function()
		M.vault_encrypt()
	end, { desc = "Encrypt current file with ansible-vault" })

	api.nvim_create_user_command("AnsibleVaultDecrypt", function()
		M.vault_decrypt()
	end, { desc = "Decrypt current file with ansible-vault" })

	api.nvim_create_user_command("AnsibleInventory", function(cmd_opts)
		M.show_inventory(cmd_opts.args ~= "" and cmd_opts.args or nil)
	end, { nargs = "?", complete = "file", desc = "Show Ansible inventory" })

	setup_done = true
	return M
end

-- Backward compat: the old stub ansible_cfg() now applies config.
---@param opts table|nil
---@return table opts
function M.ansible_cfg(opts)
	return M.setup(opts)
end

return M
