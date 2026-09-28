-- #################################################################
-- qompassai/Diver/lua/config/data/sql.lua
-- Qompass AI Diver Native SQL Language Toolkit
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Backend-agnostic SQL utilities for Neovim 0.13+.
--
-- The sibling backends (sqlite.lua, duckdb.lua, mysql.lua, psql.lua,
-- mariadb.lua, redis.lua) each know how to talk to one database.
-- This module knows how to talk about SQL itself: formatting, linting,
-- explaining query plans, and running SQL through whichever backend the
-- orchestrator (config.data/init.lua, :DB) has attached to the buffer.
--
-- Two access paths, mirroring the backends:
--   1. Human commands (:Sql*) for interactive use in a SQL buffer.
--   2. A buffer-independent Lua API (M.format_sync, M.lint_buffer, ...)
--      for AI agents or scripts, with no notify() side effects unless
--      asked — just results or an error.
--
-- Commands:
--   :SqlFormat            Format the buffer (or visual range) as SQL.
--   :SqlLint              Lint the buffer with every available SQL linter.
--   :SqlRun               Run the buffer (or visual range) via :DB.
--   :SqlExplain           Prepend EXPLAIN and run via :DB.
--   :SqlInfo              Show attached backend and formatter/linter status.
--
-- Agent API:
--   require('config.data.sql').format_sync(text, opts)
--   require('config.data.sql').lint_text(text, opts)
--   require('config.data.sql').detect_dialect(path_or_text)
--
-- Requiring this module performs no I/O and registers nothing.
-- M.setup() registers the :Sql* commands and is idempotent.

local api = vim.api
local fn = vim.fn

local M = {}

local SQL_BYTES_MAX = 1048576 -- 1 MiB cap on text handed to formatters.
local FORMAT_TIMEOUT_MS = 15000
local LINT_TIMEOUT_MS = 30000
local RESULT_LINE_COUNT_MAX = 5000

local defaults = {
	-- Formatter preference order. First available binary wins.
	formatters = { "sqlfluff", "pg_format", "sqlfmt" },
	-- Linter preference order. All available linters run, not just first.
	linters = { "sqlfluff", "sqruff", "sqlfluff_fix" },
	-- Default SQL dialect for formatters/linters that need one.
	dialect = "ansi",
	notify = true,
}

---@class SqlConfigOpts
---@field formatters? string[]
---@field linters? string[]
---@field dialect? string
---@field notify? boolean

---@type SqlConfigOpts
M.config = vim.deepcopy(defaults)

---@param message string
---@param level? integer
local function notify(message, level)
	if not M.config.notify then
		return
	end
	vim.notify(message, level or vim.log.levels.INFO)
end

---@param bin string Binary name.
---@return boolean
local function has_bin(bin)
	return fn.executable(bin) == 1
end

---Guess the SQL dialect from a file path or SQL text.
---Checks file extension first, then scans for dialect-specific keywords.
---@param path_or_text string File path or raw SQL.
---@return string dialect One of: postgres, mysql, sqlite, duckdb, ansi.
function M.detect_dialect(path_or_text)
	assert(type(path_or_text) == "string", "detect_dialect expects a string")
	local lower = path_or_text:lower()
	-- File extension hints.
	if lower:match("%.pgsql$") or lower:match("%.psql$") then
		return "postgres"
	end
	if lower:match("%.mysql$") then
		return "mysql"
	end
	if lower:match("%.sqlite.*$") or lower:match("%.duckdb$") or lower:match("%.ddb$") then
		return "sqlite"
	end
	-- Keyword hints (checked against the text body, not just the path).
	if lower:find("serial%s+primary%s+key") or lower:find("returning%s+") then
		return "postgres"
	end
	if lower:find("auto_increment") or lower:find("engine%s*=%s*innodb") then
		return "mysql"
	end
	if lower:find("pragma%s+") or lower:find("without%s+rowid") then
		return "sqlite"
	end
	if lower:find("copy%s+%w+%s+from%s+") and lower:find("parquet") then
		return "duckdb"
	end
	return M.config.dialect
end

---Format SQL text with the first available formatter.
---@param text string Raw SQL.
---@param opts? { dialect?: string, formatter?: string }
---@return string|nil formatted Nil on failure.
---@return string|nil err Error message on failure.
function M.format_sync(text, opts)
	if type(text) ~= "string" or text == "" then
		return nil, "format_sync expects non-empty SQL text"
	end
	if #text > SQL_BYTES_MAX then
		return nil, "SQL text exceeds size limit"
	end
	opts = opts or {}
	local dialect = opts.dialect or M.detect_dialect(text)

	-- Build the candidate list: explicit choice first, then preferences.
	local candidates = {}
	if opts.formatter then
		candidates[#candidates + 1] = opts.formatter
	end
	for _, f in ipairs(M.config.formatters) do
		if f ~= opts.formatter then
			candidates[#candidates + 1] = f
		end
	end

	for _, formatter in ipairs(candidates) do
		if has_bin(formatter) then
			local cmd
			if formatter == "sqlfluff" then
				cmd = { "sqlfluff", "format", "--dialect", dialect, "-" }
			elseif formatter == "pg_format" then
				cmd = { "pg_format", "-" }
			elseif formatter == "sqlfmt" then
				cmd = { "sqlfmt", "-" }
			else
				cmd = { formatter, "-" }
			end
			local result = vim.system(cmd, { stdin = text, text = true }):wait(FORMAT_TIMEOUT_MS)
			if result.code == 0 and result.stdout and result.stdout ~= "" then
				return result.stdout, nil
			end
		end
	end
	return nil, "no SQL formatter available (tried: " .. table.concat(candidates, ", ") .. ")"
end

---Format the current buffer (or visual range) in place.
---@param line1? integer Start line (default: 1).
---@param line2? integer End line (default: last).
function M.format_buffer(line1, line2)
	local bufnr = api.nvim_get_current_buf()
	line1 = line1 or 1
	line2 = line2 or api.nvim_buf_line_count(bufnr)
	local lines = api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
	local text = table.concat(lines, "\n")
	local formatted, err = M.format_sync(text)
	if not formatted then
		notify("SqlFormat: " .. (err or "unknown error"), vim.log.levels.WARN)
		return
	end
	local new_lines = vim.split(vim.trim(formatted), "\n")
	api.nvim_buf_set_lines(bufnr, line1 - 1, line2, false, new_lines)
	notify("SqlFormat: formatted " .. #new_lines .. " lines")
end

---@class SqlLintIssue
---@field linter string Which linter reported this.
---@field lnum integer 1-based line number.
---@field col integer 1-based column number.
---@field text string Issue description.
---@field type string 'E' or 'W'.

---Lint SQL text with all available linters.
---@param text string Raw SQL.
---@param opts? { dialect?: string }
---@return SqlLintIssue[] issues
function M.lint_text(text, opts)
	assert(type(text) == "string", "lint_text expects a string")
	opts = opts or {}
	local dialect = opts.dialect or M.detect_dialect(text)
	---@type SqlLintIssue[]
	local issues = {}

	-- Write to a temp file; most SQL linters want a path.
	local tmp = fn.tempname() .. ".sql"
	local fh = io.open(tmp, "w")
	if not fh then
		return issues
	end
	fh:write(text:sub(1, SQL_BYTES_MAX))
	fh:close()

	for _, linter in ipairs(M.config.linters) do
		if has_bin(linter) then
			local cmd
			if linter == "sqlfluff" then
				cmd = { "sqlfluff", "lint", "--dialect", dialect, "--format", "human", tmp }
			elseif linter == "sqruff" then
				cmd = { "sqruff", "lint", tmp }
			end
			if cmd then
				local result = vim.system(cmd, { text = true }):wait(LINT_TIMEOUT_MS)
				local output = (result.stdout or "") .. (result.stderr or "")
				for _, line in ipairs(vim.split(output, "\n")) do
					-- sqlfluff human format: "L:   3 | P:   5 | L044 | ..."
					local lnum, col, code, msg = line:match("L:%s*(%d+)%s*|%s*P:%s*(%d+)%s*|%s*(%w+)%s*|%s*(.+)")
					if lnum and msg then
						issues[#issues + 1] = {
							linter = linter,
							lnum = tonumber(lnum) or 1,
							col = tonumber(col) or 1,
							text = (code or "") .. " " .. vim.trim(msg),
							type = "W",
						}
					end
				end
			end
		end
	end
	os.remove(tmp)

	if #issues > RESULT_LINE_COUNT_MAX then
		local trimmed = {}
		for i = 1, RESULT_LINE_COUNT_MAX do
			trimmed[i] = issues[i]
		end
		issues = trimmed
	end
	return issues
end

---Lint the current buffer and populate the quickfix list.
function M.lint_buffer()
	local bufnr = api.nvim_get_current_buf()
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local issues = M.lint_text(table.concat(lines, "\n"))
	if #issues == 0 then
		notify("SqlLint: clean")
		return
	end
	local qf = {}
	local fname = api.nvim_buf_get_name(bufnr)
	for _, issue in ipairs(issues) do
		qf[#qf + 1] = {
			filename = fname,
			lnum = issue.lnum,
			col = issue.col,
			text = "[" .. issue.linter .. "] " .. issue.text,
			type = issue.type,
		}
	end
	fn.setqflist(qf, "r", { title = "SqlLint" })
	vim.cmd("copen")
	notify(("SqlLint: %d issue(s)"):format(#issues), vim.log.levels.WARN)
end

---Run SQL through the orchestrator (:DB) for the current buffer.
---Delegates to config.data's dispatch; this module never talks to a
---database directly.
---@param line1? integer Start line.
---@param line2? integer End line.
function M.run(line1, line2)
	local bufnr = api.nvim_get_current_buf()
	line1 = line1 or 1
	line2 = line2 or api.nvim_buf_line_count(bufnr)
	-- Use :DB with the visual range; the orchestrator picks the backend.
	vim.cmd(("%d,%dDB"):format(line1, line2))
end

---Prepend EXPLAIN and run through :DB.
---@param line1? integer Start line.
---@param line2? integer End line.
function M.explain(line1, line2)
	local bufnr = api.nvim_get_current_buf()
	line1 = line1 or 1
	line2 = line2 or api.nvim_buf_line_count(bufnr)
	local lines = api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
	local sql = vim.trim(table.concat(lines, "\n"))
	-- Strip any existing EXPLAIN to avoid doubling.
	sql = sql:gsub("^[Ee][Xx][Pp][Ll][Aa][Ii][Nn]%s+", "")
	local tmp = fn.tempname() .. "_explain.sql"
	local fh = io.open(tmp, "w")
	if not fh then
		notify("SqlExplain: cannot write temp file", vim.log.levels.ERROR)
		return
	end
	fh:write("EXPLAIN\n" .. sql)
	fh:close()
	-- Open in a scratch buffer and run via :DB.
	vim.cmd("split " .. fn.fnameescape(tmp))
	vim.cmd("DB")
	-- Clean up the temp file after the split closes.
	api.nvim_create_autocmd("BufWipeout", {
		buffer = api.nvim_get_current_buf(),
		once = true,
		callback = function()
			os.remove(tmp)
		end,
	})
end

---Show attached backend, dialect, and tool availability.
function M.info()
	local lines = { "SQL toolkit status:", "" }
	lines[#lines + 1] = "  dialect default: " .. M.config.dialect
	lines[#lines + 1] = ""
	lines[#lines + 1] = "  formatters:"
	for _, f in ipairs(M.config.formatters) do
		lines[#lines + 1] = ("    %s %s"):format(has_bin(f) and "✓" or "✗", f)
	end
	lines[#lines + 1] = "  linters:"
	for _, l in ipairs(M.config.linters) do
		lines[#lines + 1] = ("    %s %s"):format(has_bin(l) and "✓" or "✗", l)
	end
	lines[#lines + 1] = ""
	-- Ask the orchestrator which backend owns this buffer.
	local ok, data = pcall(require, "config.data")
	if ok and data and type(data.info) == "function" then
		lines[#lines + 1] = "  backend: (see :DBInfo)"
	else
		lines[#lines + 1] = "  backend: orchestrator not loaded"
	end
	-- Show in a float.
	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	width = math.min(width + 4, vim.o.columns - 4)
	api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = math.min(#lines + 2, vim.o.lines - 4),
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - #lines) / 2),
		style = "minimal",
		border = "rounded",
		title = " SqlInfo ",
		title_pos = "center",
	})
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
end

local setup_done = false

---Register the :Sql* commands. Idempotent.
---@param opts? SqlConfigOpts
function M.setup(opts)
	if opts ~= nil then
		assert(type(opts) == "table", "setup expects a table")
		M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
	end
	if setup_done then
		return M
	end
	setup_done = true

	api.nvim_create_user_command("SqlFormat", function(cmd_opts)
		M.format_buffer(cmd_opts.line1, cmd_opts.line2)
	end, { range = true, desc = "Format SQL buffer or range" })

	api.nvim_create_user_command("SqlLint", function()
		M.lint_buffer()
	end, { desc = "Lint SQL buffer" })

	api.nvim_create_user_command("SqlRun", function(cmd_opts)
		M.run(cmd_opts.line1, cmd_opts.line2)
	end, { range = true, desc = "Run SQL via :DB" })

	api.nvim_create_user_command("SqlExplain", function(cmd_opts)
		M.explain(cmd_opts.line1, cmd_opts.line2)
	end, { range = true, desc = "EXPLAIN the SQL range via :DB" })

	api.nvim_create_user_command("SqlInfo", function()
		M.info()
	end, { desc = "SQL toolkit status" })

	return M
end

return M
