-- /qompassai/Diver/lua/git/init.lua
-- Qompass AI Diver Git Integration (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Native git + git-lfs + git-xet integration: graph log, signoff/GPG
-- commits, branch-aware push/pull, gutter signs, cursor-line blame, and
-- per-tool validation/update checks. Requiring this module registers
-- nothing and performs no I/O; M.setup() creates the user commands and
-- the gutter-sign autocmds. Every subprocess goes through
-- security.rce.safe_exec in argv form. A missing tool reports
-- "unavailable", never an error.
---@module 'dev.git'

local M = {}

local api = vim.api

local rce = require("security.rce")

local setup_done = false

-- Forward declaration: xet module table is assigned below (folded from dev/git/xet.lua).
-- M.setup() command callbacks reference it; the local must be in scope at definition.
local xet

---Oldest git this module supports. Also the config default.
M.GIT_VERSION_MIN = "2.40.0"

local DIFF_LINES_MAX = 4096 -- diff lines parsed per buffer per refresh.
local LOG_LINES_CAP = 1000 -- hard cap on --max-count for :GitLog.
local OUTPUT_LINES_MAX = 4000 -- output lines kept for any float view.
local SIGNS_PER_BUFFER_MAX = 512 -- extmark cap per buffer.

---@class git.Check
---@field name string Tool or aspect probed, e.g. 'git-xet'.
---@field status 'ok'|'unavailable'|'below minimum'
---@field detail string One-line human summary.

---@class git.Sign
---@field lnum integer 1-based buffer line for the sign.
---@field kind 'add'|'change'|'delete'

M.default_config = {
	-- Max rows of the :GitBlame floating window.
	blame_float_height = 12,
	-- Max cols of the :GitBlame floating window.
	blame_float_width = 72,
	-- Canonical upstream git reference home (verified: git-scm.com/docs).
	docs_url = "https://git-scm.com/docs",
	-- Oldest supported git; see M.GIT_VERSION_MIN.
	git_version_min = "2.40.0",
	-- Show add/change/delete gutter signs on tracked buffers.
	gutter_sign_column = true,
	-- Oldest supported git-lfs (git-xet requires git-lfs).
	lfs_version_min = "3.0.0",
	-- Rows of the :GitLog floating window.
	log_float_height = 24,
	-- Cols of the :GitLog floating window.
	log_float_width = 100,
	-- Commit rows fetched by :GitLog (clamped to LOG_LINES_CAP).
	log_lines_max = 200,
	-- Wall-clock cap for each `pass show` probe.
	pass_timeout_ms = 5000,
	-- :Gpush behaves like his gitpush alias: push -u origin <branch>.
	push_set_upstream = true,
	-- --concurrency offered to `git xet install` (nil-safe upstream default).
	xet_concurrency = 8,
	-- Default patterns offered by :GitXetTrack, alphabetical.
	xet_track_patterns = {
		"*.bin",
		"*.ckpt",
		"*.gguf",
		"*.h5",
		"*.onnx",
		"*.pkl",
		"*.pt",
		"*.safetensors",
	},
	-- Oldest supported git-xet (verified tag: git-xet-v0.2.0 upstream).
	xet_version_min = "0.2.0",
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

---Placeholder migrations: no upstream config-key rename is known for any
---of these tools, so each entry documents the migration shape as a
---clearly-marked template (no-op apply). Replace with a real migration
---when upstream renames a key we depend on.
local MIGRATIONS_TEMPLATE_NOTE = "[template] no upstream config rename known; shape only, no-op"

---@type utils.toolmgr.Migration[]
local MIGRATIONS_GIT = {
	{
		version = "2.40.0",
		description = MIGRATIONS_TEMPLATE_NOTE,
		apply = function()
			return true, "template migration: no changes applied"
		end,
	},
}

---@type utils.toolmgr.Migration[]
local MIGRATIONS_LFS = {
	{
		version = "3.0.0",
		description = MIGRATIONS_TEMPLATE_NOTE,
		apply = function()
			return true, "template migration: no changes applied"
		end,
	},
}

---@type utils.toolmgr.Migration[]
local MIGRATIONS_XET = {
	{
		version = "0.2.0",
		description = MIGRATIONS_TEMPLATE_NOTE,
		apply = function()
			return true, "template migration: no changes applied"
		end,
	},
}

---Type-check one config option. Mirrors the house pattern in
---config.ui.icons: programmer errors raise, expected absences stay nil.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
---@param optional? boolean When true, nil is allowed.
local function check_type(name, value, expected, optional)
	if value == nil and optional then
		return
	end
	if type(value) ~= expected then
		error(("git: option %s must be %s, got %s"):format(name, expected, type(value)), 2)
	end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
	check_type("config", config, "table", true)
	local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.default_config), config or {})
	check_type("blame_float_height", merged.blame_float_height, "number")
	check_type("blame_float_width", merged.blame_float_width, "number")
	check_type("docs_url", merged.docs_url, "string")
	check_type("git_version_min", merged.git_version_min, "string")
	check_type("gutter_sign_column", merged.gutter_sign_column, "boolean")
	check_type("lfs_version_min", merged.lfs_version_min, "string")
	check_type("log_float_height", merged.log_float_height, "number")
	check_type("log_float_width", merged.log_float_width, "number")
	check_type("log_lines_max", merged.log_lines_max, "number")
	check_type("pass_timeout_ms", merged.pass_timeout_ms, "number")
	check_type("push_set_upstream", merged.push_set_upstream, "boolean")
	check_type("xet_concurrency", merged.xet_concurrency, "number")
	check_type("xet_track_patterns", merged.xet_track_patterns, "table")
	check_type("xet_version_min", merged.xet_version_min, "string")
	return merged
end

---Notify a command failure in one canonical shape.
---@param what string Command name for the message.
---@param err any Failure reason.
local function notify_failed(what, err)
	vim.notify(what .. " failed: " .. tostring(err), vim.log.levels.ERROR)
end

---Run git with an argv tail. Refuses before spawning when git is absent.
---@param argv_tail string[] argv words after 'git'.
---@param opts? { cwd?: string, timeout_ms?: integer }
---@return vim.SystemCompleted|nil result
---@return string|nil err
local function run_git(argv_tail, opts)
	local toolmgr = require("utils.toolmgr")
	if not toolmgr.binary_present("git") then
		return nil, "git is unavailable on PATH"
	end
	local argv = { "git" }
	for _, word in ipairs(argv_tail) do
		argv[#argv + 1] = word
	end
	return rce.safe_exec(argv, opts or {})
end

---Repo root for cwd, or nil + reason when not inside a work tree.
---@param cwd? string Directory to probe (default: current).
---@return string|nil root
---@return string|nil err
function M.repo_root(cwd)
	local probe = cwd or vim.fn.getcwd()
	local result, exec_err = rce.safe_exec(
		{ "git", "rev-parse", "--show-toplevel" },
		{ cwd = probe, timeout_ms = 10000 }
	)
	if exec_err ~= nil then
		return nil, exec_err
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		return nil, "not inside a git work tree"
	end
	local root = vim.trim(result.stdout or "")
	if root == "" then
		return nil, "git rev-parse returned an empty root"
	end
	return root, nil
end

---Whether cwd sits inside a git work tree.
---@param cwd? string Directory to probe (default: current).
---@return boolean
function M.in_repo(cwd)
	return M.repo_root(cwd) ~= nil
end

---Current branch name, or nil + reason (e.g. detached HEAD).
---@param cwd? string Directory to probe (default: current).
---@return string|nil branch
---@return string|nil err
function M.current_branch(cwd)
	local result, exec_err = run_git({ "branch", "--show-current" }, { cwd = cwd })
	if exec_err ~= nil then
		return nil, exec_err
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		return nil, "git branch failed: " .. vim.trim(result.stderr or "")
	end
	local branch = vim.trim(result.stdout or "")
	if branch == "" then
		return nil, "detached HEAD: no current branch to push"
	end
	return branch, nil
end

---GPG signing key, sourced the way his fish config does: $GIT_SIGNINGKEY
---first, then `pass show git/signk`. Never hardcoded; nil when neither
---source yields a key, and the caller degrades to signoff-only.
---@return string|nil key
---@return string|nil source 'env' | 'pass'
function M.signing_key()
	local from_env = vim.env.GIT_SIGNINGKEY
	if type(from_env) == "string" and vim.trim(from_env) ~= "" then
		return vim.trim(from_env), "env"
	end
	local toolmgr = require("utils.toolmgr")
	if not toolmgr.binary_present("pass") then
		return nil, nil
	end
	local result, exec_err = rce.safe_exec({ "pass", "show", "git/signk" }, { timeout_ms = M.config.pass_timeout_ms })
	if exec_err ~= nil or result == nil or result.code ~= 0 then
		return nil, nil
	end
	local key = vim.trim(result.stdout or "")
	if key == "" then
		return nil, nil
	end
	return key, "pass"
end

---Commit with --signoff (his gitcom), plus -S<key> when a pass-sourced
---key is available (his gitcomm). Never commits an empty message.
---@param message string Commit message; must be non-empty.
---@param opts? { cwd?: string }
---@return boolean ok
---@return string|nil err
function M.commit(message, opts)
	if type(message) ~= "string" or vim.trim(message) == "" then
		return false, "refusing to commit with an empty message"
	end
	local root, root_err = M.repo_root(opts and opts.cwd)
	if root_err ~= nil then
		return false, root_err
	end
	local argv = { "commit", "--signoff" }
	local key = M.signing_key()
	if key ~= nil then
		argv[#argv + 1] = "-S" .. key
	end
	argv[#argv + 1] = "-m"
	argv[#argv + 1] = vim.trim(message)
	local result, exec_err = run_git(argv, { cwd = root })
	if exec_err ~= nil then
		return false, exec_err
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		return false, "git commit failed: " .. vim.trim(result.stderr or "")
	end
	return true, nil
end

---Push the current branch, mirroring his gitpush alias
---(`git push -u origin <branch>`). Refuses outside a repo.
---@param opts? { cwd?: string }
---@return boolean ok
---@return string|nil err
function M.push(opts)
	local cwd = opts and opts.cwd
	local root, root_err = M.repo_root(cwd)
	if root_err ~= nil then
		return false, root_err
	end
	local branch, branch_err = M.current_branch(root)
	if branch_err ~= nil then
		return false, branch_err
	end
	local argv = { "push" }
	if M.config.push_set_upstream then
		argv[#argv + 1] = "-u"
	end
	argv[#argv + 1] = "origin"
	argv[#argv + 1] = branch
	local result, exec_err = run_git(argv, { cwd = root, timeout_ms = 120000 })
	if exec_err ~= nil then
		return false, exec_err
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		return false, "git push failed: " .. vim.trim(result.stderr or "")
	end
	return true, nil
end
---Pull, mirroring his gitpull dance: with no argument a plain `git pull`;
---with a branch name, check it out, pull, check back, then merge it into
---the original branch (`git pull . <branch>`). Refuses outside a repo.
---@param target? string Branch to pull in (default: plain pull).
---@param opts? { cwd?: string }
---@return boolean ok
---@return string|nil err
function M.pull(target, opts)
	local cwd = opts and opts.cwd
	local root, root_err = M.repo_root(cwd)
	if root_err ~= nil then
		return false, root_err
	end
	local run_opts = { cwd = root, timeout_ms = 120000 }
	if target == nil or vim.trim(target) == "" then
		local result, exec_err = run_git({ "pull" }, run_opts)
		if exec_err ~= nil then
			return false, exec_err
		end
		assert(result ~= nil, "safe_exec returned no error but no result")
		if result.code ~= 0 then
			return false, "git pull failed: " .. vim.trim(result.stderr or "")
		end
		return true, nil
	end
	local branch = vim.trim(target)
	local current, current_err = M.current_branch(root)
	if current_err ~= nil then
		return false, current_err
	end
	local steps = {
		{ "checkout", branch },
		{ "pull" },
		{ "checkout", current },
		{ "pull", ".", branch },
	}
	for _, step in ipairs(steps) do
		local result, exec_err = run_git(step, run_opts)
		if exec_err ~= nil then
			return false, ("git %s failed to spawn: %s"):format(table.concat(step, " "), exec_err)
		end
		assert(result ~= nil, "safe_exec returned no error but no result")
		if result.code ~= 0 then
			return false, ("git %s failed: %s"):format(table.concat(step, " "), vim.trim(result.stderr or ""))
		end
	end
	return true, nil
end

---Parse `git diff -U0` hunk headers into gutter signs. Pure: garbage in
---yields an empty list, never an error.
---@param diff_text string Output of `git diff -U0`.
---@return git.Sign[] signs
function M.parse_signs(diff_text)
	local signs = {}
	if type(diff_text) ~= "string" then
		return signs
	end
	local line_count = 0
	for _, line in ipairs(vim.split(diff_text, "\n", { plain = true })) do
		line_count = line_count + 1
		if line_count > DIFF_LINES_MAX or #signs >= SIGNS_PER_BUFFER_MAX then
			break
		end
		local old_count_s, new_start_s, new_count_s = line:match("^@@ %-%d+,?(%d*) %+(%d+),?(%d*) @@")
		if new_start_s ~= nil then
			local old_count = tonumber(old_count_s) or 1
			local new_start = tonumber(new_start_s) or 1
			local new_count = tonumber(new_count_s) or 1
			if new_count == 0 then
				-- Pure deletion: mark the anchor line the block was cut from.
				local anchor = new_start == 0 and 1 or new_start
				signs[#signs + 1] = { lnum = anchor, kind = "delete" }
			else
				local kind = old_count == 0 and "add" or "change"
				for lnum = new_start, new_start + new_count - 1 do
					if #signs >= SIGNS_PER_BUFFER_MAX then
						break
					end
					signs[#signs + 1] = { lnum = lnum, kind = kind }
				end
			end
		end
	end
	return signs
end

local git_ns = api.nvim_create_namespace("diver_git_signs")

---Refresh gutter signs for one buffer from `git diff -U0`. Silent on
---expected failures (untracked file, not a repo): no signs, no noise.
---@param bufnr integer Buffer handle.
local function refresh_signs(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return
	end
	api.nvim_buf_clear_namespace(bufnr, git_ns, 0, -1)
	if not M.config.gutter_sign_column then
		return
	end
	local path = api.nvim_buf_get_name(bufnr)
	if path == "" then
		return
	end
	local root = M.repo_root(vim.fs.dirname(path))
	if root == nil then
		return
	end
	local rel = vim.fs.relpath(root, path)
	if rel == nil then
		return
	end
	local result, exec_err = run_git({ "diff", "--no-ext-diff", "--no-color", "-U0", "--", rel }, { cwd = root })
	if exec_err ~= nil or result == nil or result.code ~= 0 then
		return
	end
	local hl = { add = "DiverGitSignAdd", change = "DiverGitSignChange", delete = "DiverGitSignDelete" }
	local text = { add = "+", change = "~", delete = "-" }
	local line_total = api.nvim_buf_line_count(bufnr)
	for _, sign in ipairs(M.parse_signs(result.stdout or "")) do
		if sign.lnum >= 1 and sign.lnum <= line_total then
			api.nvim_buf_set_extmark(bufnr, git_ns, sign.lnum - 1, 0, {
				sign_text = text[sign.kind],
				sign_hl_group = hl[sign.kind],
			})
		end
	end
end

---Open a centered, minimal float for command output. `q` closes it.
---@param lines string[] Body lines.
---@param title string Float title.
---@param width integer Desired width.
---@param height integer Desired height.
local function open_float(lines, title, width, height)
	local buf = api.nvim_create_buf(false, true)
	local shown = {}
	for index = 1, math.min(#lines, OUTPUT_LINES_MAX) do
		shown[#shown + 1] = lines[index]
	end
	api.nvim_buf_set_lines(buf, 0, -1, false, shown)
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "diver-git"
	local win_width = math.min(width, vim.o.columns - 4)
	local win_height = math.min(height, vim.o.lines - 4)
	api.nvim_open_win(buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = math.floor((vim.o.lines - win_height) / 2),
		col = math.floor((vim.o.columns - win_width) / 2),
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
	})
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Close git float" })
end

---Map a toolmgr binary report onto the git.Check status vocabulary.
---@param report utils.toolmgr.BinaryReport
---@return git.Check
local function to_check(report)
	local status = "unavailable"
	if report.present and report.meets_minimum then
		status = "ok"
	elseif report.present then
		status = "below minimum"
	end
	return { name = report.name, status = status, detail = report.detail }
end

---Per-tool validation. Never throws and never errors: a missing tool is
---'unavailable', a too-old one 'below minimum'.
---@return git.Check[] checks
function M.checks()
	local toolmgr = require("utils.toolmgr")
	local cfg = M.config
	local checks = {}
	checks[#checks + 1] = to_check(toolmgr.check_binary({ name = "git", min_version = cfg.git_version_min }))
	local root = M.repo_root(vim.fn.getcwd())
	checks[#checks + 1] = {
		name = "repo",
		status = root ~= nil and "ok" or "unavailable",
		detail = root ~= nil and ("work tree: " .. root) or "cwd is not inside a git work tree",
	}
	checks[#checks + 1] = to_check(toolmgr.check_binary({ name = "gpg" }))
	checks[#checks + 1] = to_check(toolmgr.check_binary({ name = "pass" }))
	checks[#checks + 1] = to_check(toolmgr.check_binary({ name = "git-lfs", min_version = cfg.lfs_version_min }))
	checks[#checks + 1] = to_check(toolmgr.check_binary({
		name = "git-xet",
		version_argv = { "git", "xet", "--version" },
		min_version = cfg.xet_version_min,
	}))
	return checks
end

---The three toolmgr update specs (git, git-lfs, git-xet). Pure data;
---current_version is nil when the tool is absent, which check_update
---treats as "not installed" without touching the network.
---@return utils.toolmgr.UpdateSpec[]
function M.update_specs()
	local toolmgr = require("utils.toolmgr")
	local cfg = M.config
	local function current(argv)
		return toolmgr.command_version(argv)
	end
	return {
		{
			tool_label = "git",
			repo = "git/git",
			package = "git",
			current_version = current({ "git", "--version" }),
			known_upstream_version = cfg.git_version_min,
			migrations = MIGRATIONS_GIT,
		},
		{
			tool_label = "git-lfs",
			repo = "git-lfs/git-lfs",
			package = "git-lfs",
			current_version = current({ "git-lfs", "--version" }),
			known_upstream_version = cfg.lfs_version_min,
			migrations = MIGRATIONS_LFS,
		},
		{
			tool_label = "git-xet",
			repo = "huggingface/xet-core",
			package = "git-xet",
			current_version = current({ "git", "xet", "--version" }),
			known_upstream_version = cfg.xet_version_min,
			migrations = MIGRATIONS_XET,
		},
	}
end

---:GitLog -- graph log in a float, mirroring his `gitlog` alias
---(`git log --graph --decorate`); --oneline keeps the float readable.
local function cmd_log()
	local root, root_err = M.repo_root()
	if root_err ~= nil then
		vim.notify("GitLog: " .. root_err, vim.log.levels.ERROR)
		return
	end
	local count = math.min(math.max(M.config.log_lines_max, 1), LOG_LINES_CAP)
	local result, exec_err = run_git(
		{ "log", "--graph", "--decorate", "--oneline", "--color=never", "--max-count", tostring(count) },
		{ cwd = root }
	)
	if exec_err ~= nil then
		notify_failed("GitLog", exec_err)
		return
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		notify_failed("GitLog", vim.trim(result.stderr or ""))
		return
	end
	local lines = vim.split(result.stdout or "", "\n", { plain = true })
	if #lines == 0 or (#lines == 1 and lines[1] == "") then
		vim.notify("GitLog: no commits yet", vim.log.levels.INFO)
		return
	end
	open_float(lines, " git log ", M.config.log_float_width, M.config.log_float_height)
end

---:Gcommit -- signoff commit; GPG-signed when a pass-sourced key exists.
---@param cmd_opts table nvim_create_user_command callback options.
local function cmd_commit(cmd_opts)
	local message = vim.trim(cmd_opts.args or "")
	local key = M.signing_key()
	local ok, err = M.commit(message, {})
	if not ok then
		vim.notify("Gcommit: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	if key == nil then
		vim.notify(
			"Gcommit: committed signoff-only (no signing key in pass git/signk or $GIT_SIGNINGKEY)",
			vim.log.levels.WARN
		)
	else
		vim.notify("Gcommit: committed with signoff + GPG signature", vim.log.levels.INFO)
	end
end

---:Ge -- edit the file, then stage it (his ge()).
---@param cmd_opts table nvim_create_user_command callback options.
local function cmd_ge(cmd_opts)
	local target = vim.trim(cmd_opts.args or "")
	if target == "" then
		target = api.nvim_buf_get_name(api.nvim_get_current_buf())
	end
	if target == "" then
		vim.notify("Ge: no file given and the buffer has no file", vim.log.levels.ERROR)
		return
	end
	vim.cmd.edit(vim.fn.fnameescape(target))
	local root, root_err = M.repo_root()
	if root_err ~= nil then
		vim.notify("Ge: edited but not staged (" .. root_err .. ")", vim.log.levels.WARN)
		return
	end
	local result, exec_err = run_git({ "add", "--", target }, { cwd = root })
	if exec_err ~= nil then
		notify_failed("Ge: git add", exec_err)
		return
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		notify_failed("Ge: git add", vim.trim(result.stderr or ""))
		return
	end
	vim.notify("Ge: staged " .. target, vim.log.levels.INFO)
end

---:Gpush -- branch-aware push (his gitpush).
local function cmd_push()
	local ok, err = M.push({})
	if not ok then
		vim.notify("Gpush: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	vim.notify("Gpush: pushed", vim.log.levels.INFO)
end

---:Gpull -- branch-aware pull (his gitpull dance with an argument,
---plain `git pull` without).
---@param cmd_opts table nvim_create_user_command callback options.
local function cmd_pull(cmd_opts)
	local target = vim.trim(cmd_opts.args or "")
	if target == "" then
		target = nil
	end
	local ok, err = M.pull(target, {})
	if not ok then
		vim.notify("Gpull: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	vim.notify("Gpull: pulled", vim.log.levels.INFO)
end

---:GitBlame -- blame for the cursor line in a float (kept simple: one
---line, one window, no virtual-text lifecycle to manage).
local function cmd_blame()
	local buf = api.nvim_get_current_buf()
	local path = api.nvim_buf_get_name(buf)
	if path == "" then
		vim.notify("GitBlame: buffer has no file", vim.log.levels.ERROR)
		return
	end
	local root, root_err = M.repo_root(vim.fs.dirname(path))
	if root_err ~= nil then
		vim.notify("GitBlame: " .. root_err, vim.log.levels.ERROR)
		return
	end
	local rel = vim.fs.relpath(root, path)
	if rel == nil then
		vim.notify("GitBlame: file is outside the work tree", vim.log.levels.ERROR)
		return
	end
	local lnum = api.nvim_win_get_cursor(0)[1]
	local result, exec_err = run_git({ "blame", "-L", lnum .. "," .. lnum, "--", rel }, { cwd = root })
	if exec_err ~= nil then
		notify_failed("GitBlame", exec_err)
		return
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		notify_failed("GitBlame", vim.trim(result.stderr or ""))
		return
	end
	open_float(
		vim.split(result.stdout or "", "\n", { plain = true }),
		" git blame ",
		M.config.blame_float_width,
		M.config.blame_float_height
	)
end

---:GitDocs -- open the verified upstream git reference.
local function cmd_docs()
	local url = M.config.docs_url
	local opened = vim.ui.open ~= nil and pcall(vim.ui.open, url)
	if not opened then
		vim.notify("git docs: " .. url, vim.log.levels.INFO)
	end
end

---:GitValidate -- one vim.notify per check; missing tools say
---"unavailable", never an error.
local function cmd_validate()
	for _, check in ipairs(M.checks()) do
		local level = check.status == "ok" and vim.log.levels.INFO or vim.log.levels.WARN
		vim.notify(("git %-8s %-13s %s"):format(check.name, check.status, check.detail), level)
	end
end

---:GitUpdateCheck -- toolmgr update dialog for git, git-lfs, git-xet.
local function cmd_update_check()
	local toolmgr = require("utils.toolmgr")
	for _, spec in ipairs(M.update_specs()) do
		toolmgr.check_update(spec)
	end
end

---Register commands and gutter-sign autocmds. Idempotent: commands are
---created once; the config is rebuilt on every call. Performs no
---subprocess I/O itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
	M.config = M.setup_config(config)
	api.nvim_set_hl(0, "DiverGitSignAdd", { link = "DiffAdd", default = true })
	api.nvim_set_hl(0, "DiverGitSignChange", { link = "DiffChange", default = true })
	api.nvim_set_hl(0, "DiverGitSignDelete", { link = "DiffDelete", default = true })
	if setup_done then
		return
	end
	setup_done = true
	api.nvim_create_user_command("GitLog", cmd_log, { desc = "Graph log in a float (mirrors gitlog alias)" })
	api.nvim_create_user_command(
		"Gcommit",
		cmd_commit,
		{ nargs = "+", desc = "Commit with --signoff; GPG-signs when a pass key exists" }
	)
	api.nvim_create_user_command(
		"Ge",
		cmd_ge,
		{ nargs = "?", complete = "file", desc = "Edit a file, then stage it (mirrors ge())" }
	)
	api.nvim_create_user_command("Gpush", cmd_push, { desc = "Push current branch to origin (mirrors gitpush)" })
	api.nvim_create_user_command(
		"Gpull",
		cmd_pull,
		{ nargs = "?", desc = "Pull (mirrors gitpull; branch arg does the checkout dance)" }
	)
	api.nvim_create_user_command("GitBlame", cmd_blame, { desc = "Blame for the cursor line in a float" })
	api.nvim_create_user_command("GitDocs", cmd_docs, { desc = "Open the upstream git reference" })
	api.nvim_create_user_command("GitValidate", cmd_validate, { desc = "Per-tool validation report" })
	api.nvim_create_user_command(
		"GitUpdateCheck",
		cmd_update_check,
		{ desc = "Update check for git, git-lfs, git-xet" }
	)
	api.nvim_create_user_command("GitXetInstall", function()
		xet.install()
	end, { desc = "Guided git-xet install + transfer-agent registration" })
	api.nvim_create_user_command("GitXetTrack", function()
		xet.track()
	end, { desc = "Track large-artifact patterns via git-xet" })
	api.nvim_create_user_command("GitXetStatus", function()
		local git = M
		local root, root_err = git.repo_root()
		if root_err ~= nil then
			vim.notify("GitXetStatus: " .. root_err, vim.log.levels.ERROR)
			return
		end
		open_float(xet.status_lines(root), " git-xet status ", 100, 24)
	end, { desc = "git-xet status for this repo" })
	local group = api.nvim_create_augroup("diver_git_signs", { clear = true })
	api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		group = group,
		callback = function(args)
			refresh_signs(args.buf)
		end,
		desc = "Refresh git gutter signs",
	})
end

-- =====================================================================
-- git-xet integration (folded from dev/git/xet.lua).
-- git-xet is a Git LFS custom transfer agent, NOT a filter driver.
-- =====================================================================

xet = {}

---Official install script, verified against huggingface/xet-core main.
local XET_INSTALL_SCRIPT_URL =
	"https://raw.githubusercontent.com/huggingface/xet-core/refs/heads/main/git_xet/install.sh"

local HF_HUB_HOST = "huggingface.co"
local TRACKED_LINES_MAX = 20 -- `git lfs track` lines shown in status.

---@class git.xet.Detection
---@field lfs utils.toolmgr.BinaryReport git-lfs presence/version report.
---@field xet utils.toolmgr.BinaryReport git-xet presence/version report.

---Detect git-lfs + git-xet presence and versions. Never throws.
---@return git.xet.Detection
function xet.detect()
	local toolmgr = require("utils.toolmgr")
	local git = require("dev.git")
	local cfg = git.config
	local lfs = toolmgr.check_binary({ name = "git-lfs", min_version = cfg.lfs_version_min })
	local xet_bin = toolmgr.check_binary({
		name = "git-xet",
		version_argv = { "git", "xet", "--version" },
		min_version = cfg.xet_version_min,
	})
	return { lfs = lfs, xet = xet_bin }
end

---Which transfer the server will actually negotiate for a remote URL.
---'xet' only for Xet-enabled remotes (HF Hub); everything else -- plain
---GitHub LFS included -- falls back to 'basic'. Pure: garbage in yields
---the safe 'basic' fallback, never an error.
---@param remote_url string|nil Remote URL, e.g. from remote.origin.url.
---@return 'xet'|'basic'
function xet.transfer_for_remote(remote_url)
	if type(remote_url) ~= "string" or remote_url == "" then
		return "basic"
	end
	local host = remote_url:match("^[^@]+@([^:]+):") or remote_url:match("^%w+://([^/]+)")
	if host ~= nil and host:lower():find(HF_HUB_HOST, 1, true) ~= nil then
		return "xet"
	end
	return "basic"
end

---origin remote URL for a repo root, or nil when unset/unreadable.
---@param root string Repo root.
---@return string|nil url
function xet.remote_url(root)
	local result, exec_err = rce.safe_exec({ "git", "config", "--get", "remote.origin.url" }, { cwd = root })
	if exec_err ~= nil or result == nil or result.code ~= 0 then
		return nil
	end
	local url = vim.trim(result.stdout or "")
	return url ~= "" and url or nil
end

---Whether `git xet install` has registered the custom transfer agent.
---@param root string Repo root.
---@return boolean
function xet.registered(root)
	local result, exec_err = rce.safe_exec({ "git", "config", "--get", "lfs.customtransfer.xet.path" }, { cwd = root })
	if exec_err ~= nil or result == nil or result.code ~= 0 then
		return false
	end
	return vim.trim(result.stdout or "") ~= ""
end

---Patterns currently tracked by git-lfs in this repo (first lines only).
---@param root string Repo root.
---@return string[] patterns
function xet.tracked_patterns(root)
	local patterns = {}
	local result, exec_err = rce.safe_exec({ "git", "lfs", "track" }, { cwd = root })
	if exec_err ~= nil or result == nil or result.code ~= 0 then
		return patterns
	end
	local count = 0
	for _, line in ipairs(vim.split(result.stdout or "", "\n", { plain = true })) do
		count = count + 1
		if count > TRACKED_LINES_MAX then
			break
		end
		if vim.trim(line) ~= "" then
			patterns[#patterns + 1] = line
		end
	end
	return patterns
end

---Status lines for :GitXetStatus. Says plainly where git-xet reports
---nothing (per-file chunk/dedup counters do not exist in its CLI).
---@param root string Repo root.
---@return string[] lines
function xet.status_lines(root)
	local git = require("dev.git")
	local det = xet.detect()
	local lines = {}
	local lfs_state = det.lfs.present and (det.lfs.version or "present") or "unavailable"
	lines[#lines + 1] = "git-lfs: " .. lfs_state .. " (required: git-xet is a transfer agent, not a filter)"
	local xet_state = det.xet.present and (det.xet.version or "present") or "unavailable"
	lines[#lines + 1] = "git-xet: " .. xet_state
	if not git.in_repo(root) then
		lines[#lines + 1] = "repo: not inside a git work tree"
		return lines
	end
	if xet.registered(root) then
		lines[#lines + 1] = 'transfer agent: registered ([lfs "customtransfer.xet"] path=git-xet args=transfer)'
	else
		lines[#lines + 1] = "transfer agent: NOT registered (run :GitXetInstall, then `git xet install`)"
	end
	local remote = xet.remote_url(root)
	lines[#lines + 1] = "origin: " .. (remote or "(no origin remote configured)")
	if xet.transfer_for_remote(remote) == "xet" then
		lines[#lines + 1] = "transfer: the server will negotiate 'xet' for this Xet-enabled remote"
	else
		lines[#lines + 1] =
			"transfer: the server negotiates; plain remotes fall back to 'basic' -- no Xet acceleration applies"
	end
	lines[#lines + 1] = "tracked patterns (git lfs track):"
	local tracked = xet.tracked_patterns(root)
	if #tracked == 0 then
		lines[#lines + 1] = "  (none)"
	else
		for _, pattern in ipairs(tracked) do
			lines[#lines + 1] = "  " .. pattern
		end
	end
	lines[#lines + 1] = "chunking: content-defined chunking + CAS dedup is configuration-level;"
	lines[#lines + 1] = "  git-xet exposes no per-file chunk/dedup counters, so none are reported."
	return lines
end

---Register the transfer agent at an explicit scope. Never auto-runs:
---called only from the explicit choice in xet.install.
---@param scope '--global'|'--local'
---@return boolean ok
---@return string|nil err
function xet.register_scope(scope)
	local result, exec_err = rce.safe_exec({ "git", "xet", "install", scope })
	if exec_err ~= nil then
		return false, exec_err
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		return false, "git xet install failed: " .. vim.trim(result.stderr or "")
	end
	return true, nil
end

---Guided install + registration. Explicit vim.ui.select choices only;
---nothing installs without the user picking it.
---@param select_impl? fun(items: string[], opts: table, on_choice: fun(idx: integer|nil)) Test seam.
function xet.install(select_impl)
	local toolmgr = require("utils.toolmgr")
	local pick = select_impl or vim.ui.select
	local items = {
		"Install the git-xet binary via system package manager",
		"Show the official install script command (you run it yourself)",
		"Binary already present: register the transfer agent now",
		"Cancel",
	}
	pick(items, { prompt = "git-xet install:" }, function(choice)
		if choice == 1 then
			toolmgr.install_package("git-xet", "git-xet")
		elseif choice == 2 then
			vim.notify(
				"run in a terminal:\n  curl --proto '=https' --tlsv1.2 -sSf " .. XET_INSTALL_SCRIPT_URL .. " | sh",
				vim.log.levels.INFO
			)
		elseif choice == 3 then
			xet.register(select_impl)
		end
	end)
end

---Registration scope picker, shared by xet.install and direct use.
---@param select_impl? fun(items: string[], opts: table, on_choice: fun(idx: integer|nil)) Test seam.
function xet.register(select_impl)
	local pick = select_impl or vim.ui.select
	local scopes = { "--global", "--local", "Cancel" }
	pick(scopes, { prompt = "git xet install scope:" }, function(choice)
		if choice == 1 or choice == 2 then
			local scope = scopes[choice]
			assert(scope == "--global" or scope == "--local", "scope must be --global or --local")
			local ok, err = xet.register_scope(scope)
			if ok then
				vim.notify("git-xet: transfer agent registered (" .. scope .. ")", vim.log.levels.INFO)
			else
				vim.notify("git-xet registration failed: " .. tostring(err), vim.log.levels.ERROR)
			end
		end
	end)
end

---Track one pattern via `git xet track` (thin wrapper over git lfs track).
---@param pattern string Non-empty track pattern, e.g. '*.safetensors'.
---@param opts? { cwd?: string }
---@return boolean ok
---@return string|nil err
function xet.track_pattern(pattern, opts)
	if type(pattern) ~= "string" or vim.trim(pattern) == "" then
		return false, "track pattern must be a non-empty string"
	end
	local git = require("dev.git")
	local root, root_err = git.repo_root(opts and opts.cwd)
	if root_err ~= nil then
		return false, root_err
	end
	local det = xet.detect()
	if not det.lfs.present then
		return false, "git-lfs is unavailable (git-xet requires it)"
	end
	if not det.xet.present then
		return false, "git-xet is unavailable (run :GitXetInstall)"
	end
	local result, exec_err = rce.safe_exec({ "git", "xet", "track", vim.trim(pattern) }, { cwd = root })
	if exec_err ~= nil then
		return false, exec_err
	end
	assert(result ~= nil, "safe_exec returned no error but no result")
	if result.code ~= 0 then
		return false, "git xet track failed: " .. vim.trim(result.stderr or "")
	end
	return true, nil
end

---Track patterns picker: all configured patterns at once, or one.
---@param select_impl? fun(items: string[], opts: table, on_choice: fun(idx: integer|nil)) Test seam.
function xet.track(select_impl)
	local git = require("dev.git")
	local pick = select_impl or vim.ui.select
	local patterns = git.config.xet_track_patterns
	local items = { "All configured patterns" }
	for _, pattern in ipairs(patterns) do
		items[#items + 1] = pattern
	end
	items[#items + 1] = "Cancel"
	pick(items, { prompt = "git-xet track:" }, function(choice)
		if choice == nil or choice == #items then
			return
		end
		local targets
		if choice == 1 then
			targets = patterns
		else
			targets = { items[choice] }
		end
		local tracked_count, failed = 0, 0
		for _, pattern in ipairs(targets) do
			local ok, err = xet.track_pattern(pattern, {})
			if ok then
				tracked_count = tracked_count + 1
			else
				failed = failed + 1
				vim.notify("track " .. pattern .. ": " .. tostring(err), vim.log.levels.WARN)
			end
		end
		vim.notify(
			("git-xet track: %d pattern(s) tracked, %d failed"):format(tracked_count, failed),
			vim.log.levels.INFO
		)
	end)
end

return M
