-- /qompassai/Diver/lua/security/container.lua
-- Qompass AI Diver Docker/Container Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local header = require("research.docs")
local group = api.nvim_create_augroup("Docker", {
	clear = true,
})
local function buf_is_empty()
	return api.nvim_buf_get_lines(0, 0, 1, false)[1] == ""
end
api.nvim_create_autocmd("BufNewFile", {
	group = group,
	pattern = {
		"Dockerfile",
		"Dockerfile.*",
		"Containerfile",
		"Containerfile.*",
		"compose.yml",
		"compose.yaml",
		"docker-compose.yml",
		"docker-compose.yaml",
	},
	callback = function()
		if not buf_is_empty() then
			return
		end
		local filepath = fn.expand("%:p")
		local hdr = header.make_header(filepath, "#")
		api.nvim_buf_set_lines(0, 0, 0, false, hdr)
		vim.cmd("normal! G")
	end,
})

--- Dockerfile security audit patterns.
--- Each entry: { pattern, severity, message }.
local DOCKERFILE_CHECKS = {
	{ "^%s*USER%s+root", "HIGH", "Container runs as root; add a non-root USER" },
	{ "^%s*USER%s*$", "MEDIUM", "Empty USER directive; specify a non-root user" },
	{ "ENV%s+.*[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]", "CRITICAL", "Possible hardcoded password in ENV" },
	{ "ENV%s+.*[Ss][Ee][Cc][Rr][Ee][Tt]", "CRITICAL", "Possible hardcoded secret in ENV" },
	{ "ENV%s+.*[Tt][Oo][Kk][Ee][Nn]", "CRITICAL", "Possible hardcoded token in ENV" },
	{ "ENV%s+.*[Aa][Pp][Ii][_-]?[Kk][Ee][Yy]", "CRITICAL", "Possible hardcoded API key in ENV" },
	{ "FROM%s+.*:latest", "MEDIUM", "Pinned image tag preferred over :latest" },
	{ "^%s*ADD%s+http", "MEDIUM", "ADD with remote URL; prefer COPY + curl with checksum verify" },
	{ "^%s*EXPOSE%s+.*22%s", "MEDIUM", "SSH port exposed; ensure this is intentional" },
	{
		"apt%-get%s+install.*%-%-no%-install%-recommends",
		"LOW",
		"Consider --no-install-recommends to reduce attack surface",
		invert = true,
	},
	{ "apk%s+add%s+.*%-%-no%-cache", "LOW", "Consider --no-cache to avoid stale package index", invert = true },
}

--- Audit a Dockerfile buffer for security issues.
---@param bufnr integer|nil Buffer number (default: current).
---@return table findings List of { line, severity, message }.
function M.audit_dockerfile(bufnr)
	assert(bufnr == nil or type(bufnr) == "number", "bufnr must be a number")
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local findings = {}
	local has_user = false

	for i, line in ipairs(lines) do
		for _, check in ipairs(DOCKERFILE_CHECKS) do
			local pattern, severity, msg = check[1], check[2], check[3]
			local matched = line:match(pattern) ~= nil
			-- Inverted checks: warn when the good practice is ABSENT.
			if check.invert then
				if line:match("apt%-get%s+install") or line:match("apk%s+add") then
					if not matched then
						findings[#findings + 1] = { line = i, severity = severity, message = msg }
					end
				end
			elseif matched then
				findings[#findings + 1] = { line = i, severity = severity, message = msg }
			end
		end
		if line:match("^%s*USER%s+") and not line:match("^%s*USER%s+root") then
			has_user = true
		end
	end

	if not has_user then
		findings[#findings + 1] = {
			line = 1,
			severity = "HIGH",
			message = "No non-root USER directive; container will run as root",
		}
	end

	return findings
end

--- Display Dockerfile audit results in a float.
---@param bufnr integer|nil Buffer number (default: current).
function M.show_audit(bufnr)
	local findings = M.audit_dockerfile(bufnr)
	if #findings == 0 then
		vim.notify("Dockerfile audit: no issues found", vim.log.levels.INFO)
		return
	end
	local lines = { "Dockerfile Security Audit", "" }
	for _, f in ipairs(findings) do
		lines[#lines + 1] = string.format("[%s] line %d: %s", f.severity, f.line, f.message)
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = math.min(width + 4, 100),
		height = math.min(#lines + 2, 30),
		col = math.floor((vim.o.columns - math.min(width + 4, 100)) / 2),
		row = math.floor((vim.o.lines - math.min(#lines + 2, 30)) / 2),
		style = "minimal",
		border = "rounded",
		title = " Dockerfile Audit ",
	})
end

--- Scan a container image with trivy (if available).
---@param image string Image name:tag.
function M.scan_image(image)
	assert(type(image) == "string" and image ~= "", "image must be a non-empty string")
	if vim.fn.executable("trivy") == 0 then
		vim.notify("trivy not found; install it to scan images", vim.log.levels.WARN)
		return
	end
	-- Sanitize: image names allow alphanumeric, ., _, -, /, :.
	if not image:match("^[%w%.%_%-/%:]+$") then
		vim.notify("Invalid image name", vim.log.levels.ERROR)
		return
	end
	vim.notify("Scanning " .. image .. " with trivy...", vim.log.levels.INFO)
	vim.system(
		{ "trivy", "image", "--severity", "HIGH,CRITICAL", "--format", "table", image },
		{ text = true },
		function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					vim.notify("trivy scan failed", vim.log.levels.ERROR)
					return
				end
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result.stdout, "\n"))
				vim.api.nvim_buf_set_option(buf, "modifiable", false)
				vim.api.nvim_open_win(buf, true, {
					relative = "editor",
					width = math.floor(vim.o.columns * 0.9),
					height = math.floor(vim.o.lines * 0.8),
					col = math.floor(vim.o.columns * 0.05),
					row = math.floor(vim.o.lines * 0.1),
					style = "minimal",
					border = "rounded",
					title = " trivy: " .. image .. " ",
				})
			end)
		end
	)
end

-- Register user commands on setup.
vim.api.nvim_create_user_command("DockerAudit", function()
	M.show_audit()
end, { desc = "Audit current Dockerfile for security issues" })

vim.api.nvim_create_user_command("DockerScan", function(opts)
	M.scan_image(opts.args)
end, { nargs = 1, desc = "Scan container image with trivy" })

return M
