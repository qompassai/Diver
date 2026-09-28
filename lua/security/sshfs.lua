--- Native SSHFS client — mount remote filesystems without plugins.
---
--- Plain-language version: SSHFS lets you mount a remote server's files as if
--- they were a local folder. This module lists your SSH hosts, mounts them
--- with the `sshfs` command, and unmounts them when done. It needs `sshfs`
--- installed. Replaces the `remote-sshfs.nvim` plugin.
---@module 'security.sshfs'
-- /qompassai/Diver/lua/dev/sshfs.lua
-- Qompass AI Diver Native SSHFS
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT

local fn = vim.fn
local api = vim.api

---Maximum lines to read from ssh config. Prevents runaway on huge files.
---@type integer
local SSH_CONFIG_LINES_MAX = 2000

---Maximum mount entries to parse from system mount table.
---@type integer
local MOUNT_ENTRIES_MAX = 500

---Timeout for sshfs mount operation in milliseconds.
---@type integer
local MOUNT_TIMEOUT_MS = 30000

---@class dev.sshfs.Config
---@field mount_base string Base directory for mount points.
---@field ssh_config string Path to SSH config file.
---@field remote_path string Default remote path to mount.

---@type dev.sshfs.Config
local config = {
	mount_base = fn.expand("~/mnt"),
	ssh_config = fn.expand("~/.ssh/config"),
	remote_path = "/",
}

---@class dev.sshfs.Host
---@field name string SSH host alias from config.
---@field mounted boolean Whether currently mounted.
---@field mount_point string Local mount point path.

---Validate that a host name is safe for shell argv use.
---Permitted: alphanumeric, dot, dash, underscore. Rejected: anything else.
---@param name string|nil Host name to validate.
---@return boolean valid True if safe.
local function is_valid_host(name)
	if type(name) ~= "string" then
		return false
	end
	if #name == 0 or #name > 64 then
		return false
	end
	return name:match("^[%w%.%-_]+$") ~= nil
end

---Read SSH host aliases from ssh config file.
---Parses `Host` lines, skipping wildcards and bounded by line limit.
---@return dev.sshfs.Host[] hosts List of known hosts (unmounted status).
---@return string|nil err Error message on failure, nil on success.
function M.list_hosts()
	local hosts = {}
	local seen = {}

	local file = io.open(config.ssh_config, "r")
	if not file then
		return hosts, "cannot read " .. config.ssh_config
	end

	local line_count = 0
	for line in file:lines() do
		line_count = line_count + 1
		if line_count > SSH_CONFIG_LINES_MAX then
			break
		end
		-- Match "Host alias" but not "Host *" wildcards or "Hostname".
		local name = line:match("^%s*[Hh][Oo][Ss][Tt]%s+([%w%.%-_]+)%s*$")
		if name and not seen[name] and is_valid_host(name) then
			seen[name] = true
			hosts[#hosts + 1] = {
				name = name,
				mounted = false,
				mount_point = config.mount_base .. "/" .. name,
			}
		end
	end
	file:close()

	table.sort(hosts, function(a, b)
		return a.name < b.name
	end)
	return hosts, nil
end

---Get currently mounted sshfs filesystems.
---Reads /proc/mounts (Linux) for fuse.sshfs entries, bounded.
---@return table<string, string> mounts Map of mount_point -> host name.
local function get_mounted()
	local mounts = {}
	local file = io.open("/proc/mounts", "r")
	if not file then
		return mounts
	end

	local count = 0
	for line in file:lines() do
		count = count + 1
		if count > MOUNT_ENTRIES_MAX then
			break
		end
		-- Format: "user@host:/path /mount/point fuse.sshfs ..."
		local source, target, fstype = line:match("^(%S+)%s+(%S+)%s+(%S+)")
		if fstype == "fuse.sshfs" and source and target then
			local host = source:match("^[^@]+@([^:]+):") or source:match("^([^:]+):")
			if host then
				mounts[target] = host
			end
		end
	end
	file:close()
	return mounts
end

---List all hosts with current mount status.
---@return dev.sshfs.Host[] hosts Hosts with mounted flags set.
function M.list_all()
	local hosts = M.list_hosts()
	local mounted = get_mounted()

	-- Build reverse map: host -> mount_point.
	local host_to_mount = {}
	for mount_point, host in pairs(mounted) do
		host_to_mount[host] = mount_point
	end

	for _, host in ipairs(hosts) do
		local mp = host_to_mount[host.name]
		if mp then
			host.mounted = true
			host.mount_point = mp
		end
	end
	return hosts
end

---Mount a remote host via sshfs. Async, non-blocking.
---Creates mount point directory if missing.
---@param host_name string SSH host alias.
---@param opts? { remote_path?: string } Optional remote path override.
---@param on_done? fun(ok: boolean, err?: string) Completion callback.
---@return boolean started True if mount was initiated.
function M.connect(host_name, opts, on_done)
	assert(type(host_name) == "string", "host_name must be a string")
	if not is_valid_host(host_name) then
		if on_done then
			on_done(false, "invalid host name: " .. tostring(host_name))
		end
		return false
	end

	opts = opts or {}
	local remote_path = opts.remote_path or config.remote_path
	local mount_point = config.mount_base .. "/" .. host_name

	-- Create mount point. pcall: failure means we cannot proceed.
	local ok, mkdir_err = pcall(fn.mkdir, mount_point, "p")
	if not ok then
		if on_done then
			on_done(false, "cannot create " .. mount_point)
		end
		return false
	end
	_ = mkdir_err

	-- Argv form: no shell interpolation of host_name.
	local cmd = {
		"sshfs",
		host_name .. ":" .. remote_path,
		mount_point,
		"-o",
		"reconnect,ServerAliveInterval=15,ServerAliveCountMax=3",
	}

	vim.system(cmd, { timeout = MOUNT_TIMEOUT_MS }, function(result)
		vim.schedule(function()
			if result.code == 0 then
				vim.notify("Mounted " .. host_name .. " at " .. mount_point, vim.log.levels.INFO)
				if on_done then
					on_done(true)
				end
			else
				local err = (result.stderr or "unknown error"):sub(1, 200)
				vim.notify("SSHFS mount failed: " .. err, vim.log.levels.ERROR)
				if on_done then
					on_done(false, err)
				end
			end
		end)
	end)
	return true
end

---Unmount a previously mounted host. Async, non-blocking.
---@param host_name string SSH host alias.
---@param on_done? fun(ok: boolean, err?: string) Completion callback.
---@return boolean started True if unmount was initiated.
function M.disconnect(host_name, on_done)
	assert(type(host_name) == "string", "host_name must be a string")
	if not is_valid_host(host_name) then
		if on_done then
			on_done(false, "invalid host name")
		end
		return false
	end

	local mount_point = config.mount_base .. "/" .. host_name

	-- Try fusermount (FUSE) first, fall back to umount.
	-- Argv form throughout.
	local function try_unmount(cmd, next_fn)
		vim.system(cmd, { timeout = 10000 }, function(result)
			vim.schedule(function()
				if result.code == 0 then
					vim.notify("Unmounted " .. host_name, vim.log.levels.INFO)
					if on_done then
						on_done(true)
					end
				elseif next_fn then
					next_fn()
				else
					local err = (result.stderr or "unmount failed"):sub(1, 200)
					vim.notify("SSHFS unmount failed: " .. err, vim.log.levels.ERROR)
					if on_done then
						on_done(false, err)
					end
				end
			end)
		end)
	end

	try_unmount({ "fusermount", "-u", mount_point }, function()
		try_unmount({ "umount", mount_point }, nil)
	end)
	return true
end

---Open interactive picker for SSHFS connections.
---Shows mount status; Enter toggles mount/unmount.
---Uses fzf-lua if available, falls back to vim.ui.select.
function M.pick()
	local hosts = M.list_all()
	if #hosts == 0 then
		vim.notify("No SSH hosts found in " .. config.ssh_config, vim.log.levels.WARN)
		return
	end

	---Format: "● hostname (/mount/point)" or "○ hostname".
	---@param h dev.sshfs.Host
	---@return string
	local function format_host(h)
		if h.mounted then
			return "● " .. h.name .. " (" .. h.mount_point .. ")"
		end
		return "○ " .. h.name
	end

	local items = {}
	local by_label = {}
	for _, h in ipairs(hosts) do
		local label = format_host(h)
		items[#items + 1] = label
		by_label[label] = h
	end

	---@param label string|nil
	local function on_select(label)
		if not label then
			return
		end
		local h = by_label[label]
		if not h then
			return
		end
		if h.mounted then
			M.disconnect(h.name)
		else
			M.connect(h.name)
		end
	end

	local has_fzf, fzf = pcall(require, "fzf-lua")
	if has_fzf and fzf.fzf_exec then
		fzf.fzf_exec(items, {
			prompt = "SSHFS > ",
			actions = {
				["default"] = function(selected)
					if selected[1] then
						on_select(selected[1])
					end
				end,
			},
		})
	else
		vim.ui.select(items, { prompt = "SSHFS:" }, on_select)
	end
end

---Edit a single remote file via netrw scp:// (no mount needed).
---Native replacement for distant.nvim's quick remote file access.
---@param host_name string|nil SSH host alias (prompts if nil).
---@param remote_path string|nil Remote file path (prompts if nil).
function M.edit_remote(host_name, remote_path)
	if not host_name or host_name == "" then
		local hosts = M.list_hosts()
		if #hosts == 0 then
			vim.notify("No SSH hosts found", vim.log.levels.WARN)
			return
		end
		local names = {}
		for _, h in ipairs(hosts) do
			names[#names + 1] = h.name
		end
		vim.ui.select(names, { prompt = "Host:" }, function(choice)
			if choice then
				M.edit_remote(choice, remote_path)
			end
		end)
		return
	end

	assert(is_valid_host(host_name), "invalid host name")

	if not remote_path or remote_path == "" then
		vim.ui.input({ prompt = "Remote path: ", default = "~/" }, function(input)
			if input and input ~= "" then
				M.edit_remote(host_name, input)
			end
		end)
		return
	end

	-- netrw handles scp:// natively. No plugin needed.
	local url = "scp://" .. host_name .. "/" .. remote_path:gsub("^/+", "")
	vim.cmd("edit " .. vim.fn.fnameescape(url))
end

---Open a remote Neovim session via SSH in a terminal.
---Native replacement for remote-nvim.nvim.
---@param host_name string|nil SSH host alias (prompts if nil).
function M.ssh_nvim(host_name)
	if not host_name or host_name == "" then
		local hosts = M.list_hosts()
		if #hosts == 0 then
			vim.notify("No SSH hosts found", vim.log.levels.WARN)
			return
		end
		local names = {}
		for _, h in ipairs(hosts) do
			names[#names + 1] = h.name
		end
		vim.ui.select(names, { prompt = "SSH to:" }, function(choice)
			if choice then
				M.ssh_nvim(choice)
			end
		end)
		return
	end

	assert(is_valid_host(host_name), "invalid host name")
	-- Open terminal with ssh + nvim. Argv form via termopen.
	vim.cmd("terminal ssh " .. vim.fn.shellescape(host_name) .. " -t nvim")
	vim.cmd("startinsert")
end

---Configure the module. Idempotent; safe to call multiple times.
---@param opts? dev.sshfs.Config Partial config overrides.
function M.setup(opts)
	opts = opts or {}
	assert(type(opts) == "table", "opts must be a table")

	if opts.mount_base ~= nil then
		assert(type(opts.mount_base) == "string", "mount_base must be a string")
		config.mount_base = fn.expand(opts.mount_base)
	end
	if opts.ssh_config ~= nil then
		assert(type(opts.ssh_config) == "string", "ssh_config must be a string")
		config.ssh_config = fn.expand(opts.ssh_config)
	end
	if opts.remote_path ~= nil then
		assert(type(opts.remote_path) == "string", "remote_path must be a string")
		config.remote_path = opts.remote_path
	end

	-- Ensure mount base exists.
	pcall(fn.mkdir, config.mount_base, "p")

	-- Preserve the original keymap.
	vim.keymap.set("n", "<leader>ss", function()
		M.pick()
	end, { desc = "[SSHFS] Toggle remote host mount" })

	-- Quick single-file remote edit via netrw (replaces distant.nvim).
	api.nvim_create_user_command("SshEdit", function(cmd_opts)
		local args = vim.split(cmd_opts.args, "%s+", { trimempty = true })
		M.edit_remote(args[1], args[2])
	end, {
		nargs = "*",
		desc = "Edit remote file via scp:// (no mount)",
	})

	-- Remote Neovim session via SSH (replaces remote-nvim.nvim).
	api.nvim_create_user_command("SshNvim", function(cmd_opts)
		local args = vim.split(cmd_opts.args, "%s+", { trimempty = true })
		M.ssh_nvim(args[1])
	end, {
		nargs = "?",
		desc = "Open remote Neovim via SSH",
	})
end

--- SSH config security audit.
--- Checks ~/.ssh/config for dangerous settings.
---@return table findings List of { severity, setting, message }.
function M.audit_ssh_config()
	local findings = {}
	local config_path = vim.fn.expand("~/.ssh/config")

	-- Check file permissions (should be 600).
	local stat = vim.uv.fs_stat(config_path)
	if stat then
		local mode = stat.mode % 512 -- last 9 bits
		if mode ~= 384 then -- 0600
			findings[#findings + 1] = {
				severity = "HIGH",
				setting = "permissions",
				message = string.format("~/.ssh/config has mode %o; should be 600", mode),
			}
		end
	end

	local f = io.open(config_path, "r")
	if not f then
		findings[#findings + 1] = {
			severity = "INFO",
			setting = "config",
			message = "No ~/.ssh/config found",
		}
		return findings
	end

	local content = f:read("*all")
	f:close()

	local checks = {
		{
			pattern = "StrictHostKeyChecking%s+[Nn][Oo]",
			severity = "CRITICAL",
			setting = "StrictHostKeyChecking",
			message = "Host key checking disabled; vulnerable to MITM attacks",
		},
		{
			pattern = "ForwardAgent%s+[Yy][Ee][Ss]",
			severity = "HIGH",
			setting = "ForwardAgent",
			message = "Agent forwarding enabled; keys can be hijacked on compromised hosts",
		},
		{
			pattern = "PasswordAuthentication%s+[Yy][Ee][Ss]",
			severity = "MEDIUM",
			setting = "PasswordAuthentication",
			message = "Password auth allowed; prefer key-only authentication",
		},
		{
			pattern = "PermitLocalCommand%s+[Yy][Ee][Ss]",
			severity = "MEDIUM",
			setting = "PermitLocalCommand",
			message = "Local commands on connect; ensure ProxyCommand/LocalCommand are trusted",
		},
	}

	for _, check in ipairs(checks) do
		if content:match(check.pattern) then
			findings[#findings + 1] = {
				severity = check.severity,
				setting = check.setting,
				message = check.message,
			}
		end
	end

	-- Check for weak algorithms.
	local weak = {
		{ "diffie%-hellman%-group1%-sha1", "Weak DH group1; vulnerable to Logjam" },
		{ "ssh%-rsa%s", "SHA1-based ssh-rsa; prefer rsa-sha2-256/512" },
		{ "3des", "3DES cipher; deprecated and slow" },
		{ "arcfour", "RC4 cipher; broken" },
		{ "hmac%-md5", "MD5 HMAC; use SHA2 variants" },
		{ "hmac%-sha1%-96", "Truncated HMAC; use full-length" },
	}
	for _, w in ipairs(weak) do
		if content:lower():match(w[1]) then
			findings[#findings + 1] = {
				severity = "HIGH",
				setting = "algorithms",
				message = w[2],
			}
		end
	end

	return findings
end

--- Verify mount point security before mounting.
---@param mount_point string Local mount path.
---@return boolean ok
---@return string msg
function M.check_mount_security(mount_point)
	assert(type(mount_point) == "string", "mount_point must be a string")
	local stat = vim.uv.fs_stat(mount_point)
	if not stat then
		return true, "Mount point does not exist yet (will be created)"
	end
	if stat.type ~= "directory" then
		return false, "Mount point is not a directory"
	end
	local mode = stat.mode % 512
	-- Check world-writable (o+w = 2).
	if mode % 8 >= 2 then
		return false, "Mount point is world-writable; fix with chmod o-w"
	end
	-- Check ownership (should be current user).
	local uid = vim.uv.getuid()
	if stat.uid ~= uid then
		return false, "Mount point not owned by current user"
	end
	return true, "Mount point secure"
end

--- Verify remote host key before connecting.
---@param host string Hostname.
---@return boolean ok
---@return string msg
function M.verify_host_key(host)
	assert(type(host) == "string" and host ~= "", "host must be a non-empty string")
	-- Sanitize hostname.
	if not host:match("^[%w%.%-]+$") then
		return false, "Invalid hostname"
	end
	local result = vim.system({ "ssh-keygen", "-F", host }, { text = true }):wait(5000)
	if result.code == 0 and result.stdout ~= "" then
		return true, "Host key found in known_hosts"
	end
	return false, "No host key for " .. host .. " in known_hosts; verify out-of-band before connecting"
end

--- Display SSH audit results.
function M.show_ssh_audit()
	local findings = M.audit_ssh_config()
	if #findings == 0 then
		vim.notify("SSH audit: no issues found", vim.log.levels.INFO)
		return
	end
	local lines = { "SSH Security Audit", "" }
	for _, f in ipairs(findings) do
		lines[#lines + 1] = string.format("[%s] %s: %s", f.severity, f.setting, f.message)
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
		height = math.min(#lines + 2, 25),
		col = math.floor((vim.o.columns - math.min(width + 4, 100)) / 2),
		row = math.floor((vim.o.lines - math.min(#lines + 2, 25)) / 2),
		style = "minimal",
		border = "rounded",
		title = " SSH Audit ",
	})
end

vim.api.nvim_create_user_command("SshAudit", function()
	M.show_ssh_audit()
end, { desc = "Audit SSH config for security issues" })

vim.api.nvim_create_user_command("SshVerifyHost", function(cmd_opts)
	local ok, msg = M.verify_host_key(cmd_opts.args)
	vim.notify(msg, ok and vim.log.levels.INFO or vim.log.levels.WARN)
end, { nargs = 1, desc = "Verify host key in known_hosts" })

return M
