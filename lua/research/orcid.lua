--- ORCID integration — your researcher identity, in Neovim.
---
--- Plain-language version: ORCID is like a DOI for people — a permanent ID
--- that identifies you as a researcher. This module talks to the ORCID public
--- API: view your profile, list your publications, search the registry, and
--- insert citations from your works into manuscripts. It runs when you invoke
--- its commands; it needs network access to pub.orcid.org.
---@module 'research.orcid'
-- #################################################################
-- /qompassai/lua/research/orcid.lua
-- Qompass AI ORCID
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################

local api = vim.api

local M = {}

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

---Base URL for the ORCID public API (v3.0). No authentication required
---for public record reads.
local API_BASE_URL = "https://pub.orcid.org/v3.0"

---Matt's ORCID iD. Used as the default for profile/works lookups.
local DEFAULT_ORCID_ID = "0000-0002-0302-4812"

---Maximum seconds to wait for a single API request.
local REQUEST_TIMEOUT_SEC = 30

---Maximum works to fetch in one listing.
local WORKS_LIMIT_MAX = 100

---Maximum search results to display.
local SEARCH_RESULTS_MAX = 20

---Maximum lines in a rendered display buffer.
local DISPLAY_LINES_MAX = 500

-- ---------------------------------------------------------------------------
-- LuaCATS types
-- ---------------------------------------------------------------------------

---@class OrcidWork
---@field title string Work title.
---@field journal string|nil Journal or venue name.
---@field year string|nil Publication year.
---@field doi string|nil DOI if available.
---@field put_code integer ORCID put-code for this work.

---@class OrcidProfile
---@field given_name string|nil
---@field family_name string|nil
---@field biography string|nil
---@field orcid string ORCID iD.

-- ---------------------------------------------------------------------------
-- Validation helpers
-- ---------------------------------------------------------------------------

---Check that an ORCID iD matches the expected format.
---@param orcid_id string Candidate ORCID iD.
---@return boolean True if the format is valid.
local function is_valid_orcid(orcid_id)
	if type(orcid_id) ~= "string" then
		return false
	end
	-- Format: 0000-0000-0000-0000 (last char may be X).
	return orcid_id:match("^%d%d%d%d%-%d%d%d%d%-%d%d%d%d%-%d%d%d[%dX]$") ~= nil
end

-- ---------------------------------------------------------------------------
-- HTTP helpers
-- ---------------------------------------------------------------------------

---Perform a GET request against the ORCID public API.
---@param path string API path (e.g. '/0000-0002-0302-4812/works').
---@return table|nil result Decoded JSON on success, nil on failure.
---@return string|nil err Error message on failure.
local function api_get(path)
	assert(type(path) == "string", "path must be a string")
	assert(path:sub(1, 1) == "/", "path must start with /")

	local url = API_BASE_URL .. path
	local cmd = {
		"curl",
		"--silent",
		"--show-error",
		"--fail",
		"--max-time",
		tostring(REQUEST_TIMEOUT_SEC),
		"--header",
		"Accept: application/json",
		url,
	}

	local result = vim.system(cmd, { text = true }):wait(REQUEST_TIMEOUT_SEC * 1000)
	if result.code ~= 0 then
		return nil, "ORCID request failed: " .. (result.stderr or "unknown error")
	end

	local ok, decoded = pcall(vim.json.decode, result.stdout)
	if not ok then
		return nil, "ORCID response was not valid JSON"
	end
	return decoded, nil
end

-- ---------------------------------------------------------------------------
-- Data extraction
-- ---------------------------------------------------------------------------

---Extract a display title from an ORCID work summary.
---@param work table Raw work summary from the API.
---@return string title
local function work_title(work)
	local title = work["title"] and work["title"]["title"]
	if title and title["value"] then
		return title["value"]
	end
	return "(untitled)"
end

---Extract the publication year from an ORCID work summary.
---@param work table Raw work summary from the API.
---@return string|nil year
local function work_year(work)
	local date = work["publication-date"]
	if date and date["year"] and date["year"]["value"] then
		return date["year"]["value"]
	end
	return nil
end

---Extract the journal/venue from an ORCID work summary.
---@param work table Raw work summary from the API.
---@return string|nil journal
local function work_journal(work)
	if work["journal-title"] and work["journal-title"]["value"] then
		return work["journal-title"]["value"]
	end
	return nil
end

---Extract the DOI from an ORCID work's external IDs.
---@param work table Raw work summary from the API.
---@return string|nil doi
local function work_doi(work)
	local ext = work["external-ids"] and work["external-ids"]["external-id"]
	if type(ext) ~= "table" then
		return nil
	end
	for _, id_entry in ipairs(ext) do
		if id_entry["external-id-type"] == "doi" and id_entry["external-id-value"] then
			return id_entry["external-id-value"]
		end
	end
	return nil
end

---Convert a raw work summary into an OrcidWork.
---@param summary table Raw work summary.
---@param put_code integer ORCID put-code.
---@return OrcidWork
local function to_work(summary, put_code)
	return {
		title = work_title(summary),
		journal = work_journal(summary),
		year = work_year(summary),
		doi = work_doi(summary),
		put_code = put_code,
	}
end

-- ---------------------------------------------------------------------------
-- Public API: data fetching
-- ---------------------------------------------------------------------------

---Fetch the public profile for an ORCID iD.
---@param orcid_id string|nil ORCID iD (defaults to yours).
---@return OrcidProfile|nil profile
---@return string|nil err
function M.get_profile(orcid_id)
	orcid_id = orcid_id or DEFAULT_ORCID_ID
	if not is_valid_orcid(orcid_id) then
		return nil, "invalid ORCID iD format: " .. tostring(orcid_id)
	end

	local data, err = api_get("/" .. orcid_id .. "/personal-details")
	if not data then
		return nil, err
	end

	local name = data["name"] or {}
	local given = name["given-names"] and name["given-names"]["value"] or nil
	local family = name["family-name"] and name["family-name"]["value"] or nil
	local bio = data["biography"] and data["biography"]["content"] or nil

	return {
		given_name = given,
		family_name = family,
		biography = bio,
		orcid = orcid_id,
	}, nil
end

---Fetch the works list for an ORCID iD.
---@param orcid_id string|nil ORCID iD (defaults to yours).
---@param limit integer|nil Max works to return (default 100).
---@return OrcidWork[]|nil works
---@return string|nil err
function M.get_works(orcid_id, limit)
	orcid_id = orcid_id or DEFAULT_ORCID_ID
	limit = limit or WORKS_LIMIT_MAX

	if not is_valid_orcid(orcid_id) then
		return nil, "invalid ORCID iD format: " .. tostring(orcid_id)
	end
	assert(limit > 0 and limit <= WORKS_LIMIT_MAX, "limit out of bounds")

	local data, err = api_get("/" .. orcid_id .. "/works")
	if not data then
		return nil, err
	end

	local works = {}
	local groups = data["group"] or {}
	for _, group in ipairs(groups) do
		local summaries = group["work-summary"] or {}
		-- Take the most recent summary per group (highest put-code).
		local best = nil
		local best_code = -1
		for _, summary in ipairs(summaries) do
			local code = summary["put-code"] or 0
			if code > best_code then
				best = summary
				best_code = code
			end
		end
		if best then
			works[#works + 1] = to_work(best, best_code)
		end
		if #works >= limit then
			break
		end
	end

	-- Sort by year descending (undated last).
	table.sort(works, function(a, b)
		if a.year == nil then
			return false
		end
		if b.year == nil then
			return true
		end
		return a.year > b.year
	end)

	return works, nil
end

---Search the ORCID registry.
---@param query string Search query (e.g. 'family-name:Smith').
---@param rows integer|nil Max results (default 20).
---@return table|nil results Raw search results.
---@return string|nil err
function M.search(query, rows)
	if type(query) ~= "string" or query == "" then
		return nil, "search query must be a non-empty string"
	end
	rows = rows or SEARCH_RESULTS_MAX
	assert(rows > 0 and rows <= SEARCH_RESULTS_MAX, "rows out of bounds")

	-- URL-encode the query. Only unreserved chars pass through.
	local encoded = query:gsub("[^%w%-%._~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end)

	return api_get("/search/?q=" .. encoded .. "&rows=" .. tostring(rows))
end

-- ---------------------------------------------------------------------------
-- Display
-- ---------------------------------------------------------------------------

---Open a scratch buffer with the given lines.
---@param title string Buffer title.
---@param lines string[] Lines to display.
---@return integer bufnr
local function show_scratch(title, lines)
	assert(type(title) == "string", "title must be a string")
	assert(type(lines) == "table", "lines must be a table")
	assert(#lines <= DISPLAY_LINES_MAX, "too many display lines")

	local bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = bufnr })
	api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })

	-- Centered floating window.
	local width = 80
	local height = math.min(#lines + 2, 30)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	local win = api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
	})
	api.nvim_set_option_value("wrap", true, { win = win })

	-- q to close.
	api.nvim_buf_set_keymap(bufnr, "n", "q", "<cmd>close<cr>", {
		noremap = true,
		silent = true,
		desc = "Close ORCID window",
	})

	return bufnr
end

---Format a work as a single display line.
---@param work OrcidWork
---@return string
local function format_work(work)
	local parts = {}
	if work.year then
		parts[#parts + 1] = "(" .. work.year .. ")"
	end
	parts[#parts + 1] = work.title
	if work.journal then
		parts[#parts + 1] = "_" .. work.journal .. "_"
	end
	if work.doi then
		parts[#parts + 1] = "doi:" .. work.doi
	end
	return table.concat(parts, " ")
end

---Display your ORCID profile in a floating window.
---@param orcid_id string|nil ORCID iD (defaults to yours).
function M.show_profile(orcid_id)
	local profile, err = M.get_profile(orcid_id)
	if not profile then
		vim.notify("ORCID: " .. (err or "unknown error"), vim.log.levels.ERROR)
		return
	end

	local lines = {
		"# ORCID Profile",
		"",
		"**ORCID:** " .. profile.orcid,
	}
	if profile.given_name or profile.family_name then
		local name = (profile.given_name or "") .. " " .. (profile.family_name or "")
		lines[#lines + 1] = "**Name:** " .. vim.trim(name)
	end
	if profile.biography and profile.biography ~= "" then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "## Biography"
		lines[#lines + 1] = ""
		lines[#lines + 1] = profile.biography
	end

	show_scratch("ORCID Profile", lines)
end

---Display your ORCID works in a floating window.
---@param orcid_id string|nil ORCID iD (defaults to yours).
function M.show_works(orcid_id)
	local works, err = M.get_works(orcid_id)
	if not works then
		vim.notify("ORCID: " .. (err or "unknown error"), vim.log.levels.ERROR)
		return
	end

	local lines = { "# ORCID Works (" .. #works .. ")", "" }
	for i, work in ipairs(works) do
		lines[#lines + 1] = i .. ". " .. format_work(work)
		lines[#lines + 1] = ""
		if #lines >= DISPLAY_LINES_MAX - 2 then
			lines[#lines + 1] = "... (truncated)"
			break
		end
	end

	show_scratch("ORCID Works", lines)
end

---Pick one of your works and insert a citation at the cursor.
---@param orcid_id string|nil ORCID iD (defaults to yours).
function M.insert_citation(orcid_id)
	local works, err = M.get_works(orcid_id)
	if not works then
		vim.notify("ORCID: " .. (err or "unknown error"), vim.log.levels.ERROR)
		return
	end
	if #works == 0 then
		vim.notify("ORCID: no works found", vim.log.levels.WARN)
		return
	end

	local items = {}
	for i, work in ipairs(works) do
		items[i] = string.format("%d. %s", i, format_work(work))
	end

	vim.ui.select(items, { prompt = "Insert citation:" }, function(choice, idx)
		if not choice or not idx then
			return
		end
		local work = works[idx]
		-- Insert as a markdown citation. DOI preferred, title fallback.
		local citation
		if work.doi then
			citation = "[@doi:" .. work.doi .. "]"
		else
			citation = '["' .. work.title .. '"]'
		end
		local row, col = unpack(api.nvim_win_get_cursor(0))
		local line = api.nvim_get_current_line()
		local new_line = line:sub(1, col) .. citation .. line:sub(col + 1)
		api.nvim_set_current_line(new_line)
		api.nvim_win_set_cursor(0, { row, col + #citation })
	end)
end

-- ---------------------------------------------------------------------------
-- OAuth (Public API client)
-- ---------------------------------------------------------------------------
-- The public API supports OAuth for two functions:
--   1. Sign in with ORCID (get a validated ORCID iD).
--   2. Collect validated ORCID iDs from users.
--
-- Register at https://orcid.org/developer-tools to get a client ID and
-- secret. For a Neovim (non-web) client, use the manual code flow:
--   :OrcidAuth      opens the browser; authorize and copy the code
--   :OrcidToken CODE exchanges the code for a token
--
-- Credentials are read from setup() opts first, then pass(1)
--   ('orcid/clientid', 'orcid/clientsec'), then environment:
--   ORCID_CLIENT_ID, ORCID_CLIENT_SECRET

---OAuth base URL (production or sandbox).
local OAUTH_BASE_URL = "https://orcid.org"

---Sandbox OAuth base URL.
local OAUTH_SANDBOX_URL = "https://sandbox.orcid.org"

---OAuth scope for authentication (returns validated ORCID iD).
local OAUTH_SCOPE_AUTHENTICATE = "/authenticate"

---Path for the cached token file (600 permissions).
local TOKEN_CACHE_PATH = vim.fn.expand("~/.cache/nvim/orcid_token.json")

---Module-level OAuth state. Nil when not configured/authenticated.
---@class OrcidOAuthState
---@field client_id string
---@field client_secret string
---@field redirect_uri string
---@field sandbox boolean
---@field access_token string|nil
---@field validated_orcid string|nil
---@field token_type string|nil

---@type OrcidOAuthState|nil
local oauth_state = nil

---Read a secret from pass(1).
---@param pass_path string Pass entry path (e.g. 'orcid/clientid').
---@return string|nil secret Trimmed secret, or nil if unavailable.
local function get_pass_secret(pass_path)
	assert(type(pass_path) == "string", "pass_path must be a string")
	local result = vim.system({ "pass", "show", pass_path }, { text = true }):wait(5000)
	if result.code ~= 0 then
		return nil
	end
	local secret = vim.trim(result.stdout)
	if secret == "" then
		return nil
	end
	return secret
end

---Load a cached token from disk.
---@return table|nil token
local function load_cached_token()
	local ok, content = pcall(vim.fn.readfile, TOKEN_CACHE_PATH)
	if not ok or #content == 0 then
		return nil
	end
	local decode_ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
	if not decode_ok then
		return nil
	end
	return data
end

---Save a token to disk with restricted permissions.
---@param data table Token data to cache.
local function save_cached_token(data)
	local dir = vim.fn.fnamemodify(TOKEN_CACHE_PATH, ":h")
	vim.fn.mkdir(dir, "p")
	local encoded = vim.json.encode(data)
	vim.fn.writefile({ encoded }, TOKEN_CACHE_PATH)
	-- Restrict to owner-only (600).
	vim.fn.setfperm(TOKEN_CACHE_PATH, "rw-------")
end

---Clear the cached token from disk and memory.
local function clear_cached_token()
	pcall(vim.fn.delete, TOKEN_CACHE_PATH)
	if oauth_state then
		oauth_state.access_token = nil
		oauth_state.validated_orcid = nil
		oauth_state.token_type = nil
	end
end

---Get the OAuth base URL for the current mode.
---@return string
local function oauth_base()
	if oauth_state and oauth_state.sandbox then
		return OAUTH_SANDBOX_URL
	end
	return OAUTH_BASE_URL
end

---URL-encode a string for query parameters.
---@param s string
---@return string
local function url_encode(s)
	assert(type(s) == "string", "s must be a string")
	return s:gsub("[^%w%-%._~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
end

---Build the ORCID OAuth authorization URL.
---@return string|nil url
---@return string|nil err
function M.get_auth_url()
	if not oauth_state then
		return nil, "ORCID OAuth not configured: call setup() with client_id"
	end
	local params = {
		"client_id=" .. url_encode(oauth_state.client_id),
		"response_type=code",
		"scope=" .. url_encode(OAUTH_SCOPE_AUTHENTICATE),
		"redirect_uri=" .. url_encode(oauth_state.redirect_uri),
	}
	return oauth_base() .. "/oauth/authorize?" .. table.concat(params, "&"), nil
end

---Open the browser to start ORCID OAuth sign-in.
---The user authorizes, then copies the code for :OrcidToken.
function M.start_auth()
	local url, err = M.get_auth_url()
	if not url then
		vim.notify("ORCID: " .. (err or "unknown error"), vim.log.levels.ERROR)
		return
	end
	-- Open in the default browser (detached).
	vim.system({ "xdg-open", url }, { detach = true })
	vim.notify("ORCID: browser opened. Authorize, then run :OrcidToken <code>", vim.log.levels.INFO)
end

---Exchange an authorization code for an access token.
---@param code string Authorization code from the OAuth redirect.
---@return table|nil token Token response (includes orcid, name).
---@return string|nil err
function M.exchange_code(code)
	if not oauth_state then
		return nil, "ORCID OAuth not configured: call setup() with client_id"
	end
	if type(code) ~= "string" or code == "" then
		return nil, "authorization code must be a non-empty string"
	end

	local url = oauth_base() .. "/oauth/token"
	local cmd = {
		"curl",
		"--silent",
		"--show-error",
		"--fail",
		"--max-time",
		tostring(REQUEST_TIMEOUT_SEC),
		"--header",
		"Accept: application/json",
		"--data-urlencode",
		"client_id=" .. oauth_state.client_id,
		"--data-urlencode",
		"client_secret=" .. oauth_state.client_secret,
		"--data-urlencode",
		"grant_type=authorization_code",
		"--data-urlencode",
		"code=" .. code,
		"--data-urlencode",
		"redirect_uri=" .. oauth_state.redirect_uri,
		url,
	}

	local result = vim.system(cmd, { text = true }):wait(REQUEST_TIMEOUT_SEC * 1000)
	if result.code ~= 0 then
		return nil, "ORCID token exchange failed: " .. (result.stderr or "unknown error")
	end

	local ok, data = pcall(vim.json.decode, result.stdout)
	if not ok then
		return nil, "ORCID token response was not valid JSON"
	end
	if data["error"] then
		return nil, "ORCID OAuth error: " .. tostring(data["error_description"] or data["error"])
	end

	-- Cache the validated ORCID iD and token.
	oauth_state.access_token = data["access_token"]
	oauth_state.validated_orcid = data["orcid"]
	oauth_state.token_type = data["token_type"]
	save_cached_token({
		access_token = data["access_token"],
		orcid = data["orcid"],
		name = data["name"],
		token_type = data["token_type"],
	})

	return data, nil
end

---Check if OAuth is configured and we have a validated token.
---@return boolean
function M.is_authenticated()
	return oauth_state ~= nil and oauth_state.validated_orcid ~= nil
end

---Get the validated ORCID iD from the OAuth flow (nil if not authenticated).
---@return string|nil
function M.get_validated_id()
	if oauth_state then
		return oauth_state.validated_orcid
	end
	return nil
end

---Clear the OAuth token (sign out).
function M.logout()
	clear_cached_token()
	vim.notify("ORCID: signed out", vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

---Configure the module and register user commands. Idempotent.
---@param opts table|nil Configuration.
---@field client_id string|nil ORCID Public API client ID.
---@field client_secret string|nil ORCID Public API client secret.
---@field redirect_uri string|nil OAuth redirect URI (must match registration).
---@field sandbox boolean|nil Use the sandbox API (default false).
function M.setup(opts)
	opts = opts or {}

	-- OAuth configuration: explicit opts win, then pass(1), then environment.
	local client_id = opts.client_id or get_pass_secret("orcid/clientid") or os.getenv("ORCID_CLIENT_ID")
	local client_secret = opts.client_secret or get_pass_secret("orcid/clientsec") or os.getenv("ORCID_CLIENT_SECRET")
	if client_id and client_secret then
		oauth_state = {
			client_id = client_id,
			client_secret = client_secret,
			redirect_uri = opts.redirect_uri or "https://orcid.org/signin",
			sandbox = opts.sandbox == true,
			access_token = nil,
			validated_orcid = nil,
			token_type = nil,
		}
		-- Restore cached token if present.
		local cached = load_cached_token()
		if cached and cached.orcid then
			oauth_state.access_token = cached.access_token
			oauth_state.validated_orcid = cached.orcid
			oauth_state.token_type = cached.token_type
		end
	end
	api.nvim_create_user_command("OrcidProfile", function(cmd_opts)
		local id = cmd_opts.args ~= "" and cmd_opts.args or nil
		M.show_profile(id)
	end, {
		nargs = "?",
		desc = "Show ORCID profile (default: yours)",
	})

	api.nvim_create_user_command("OrcidWorks", function(cmd_opts)
		local id = cmd_opts.args ~= "" and cmd_opts.args or nil
		M.show_works(id)
	end, {
		nargs = "?",
		desc = "List ORCID works (default: yours)",
	})

	api.nvim_create_user_command("OrcidCite", function(cmd_opts)
		local id = cmd_opts.args ~= "" and cmd_opts.args or nil
		M.insert_citation(id)
	end, {
		nargs = "?",
		desc = "Insert citation from your ORCID works",
	})

	-- OAuth: sign in with ORCID.
	api.nvim_create_user_command("OrcidAuth", function()
		M.start_auth()
	end, {
		nargs = 0,
		desc = "Start ORCID OAuth sign-in (opens browser)",
	})

	api.nvim_create_user_command("OrcidToken", function(cmd_opts)
		if cmd_opts.args == "" then
			vim.notify("OrcidToken: authorization code required", vim.log.levels.WARN)
			return
		end
		local data, err = M.exchange_code(cmd_opts.args)
		if not data then
			vim.notify("ORCID: " .. (err or "unknown error"), vim.log.levels.ERROR)
			return
		end
		vim.notify(
			string.format("ORCID: signed in as %s (%s)", data["name"] or "?", data["orcid"] or "?"),
			vim.log.levels.INFO
		)
	end, {
		nargs = 1,
		desc = "Complete ORCID OAuth with authorization code",
	})

	api.nvim_create_user_command("OrcidWhoami", function()
		local id = M.get_validated_id()
		if id then
			vim.notify("ORCID: authenticated as " .. id, vim.log.levels.INFO)
		else
			vim.notify("ORCID: not authenticated (run :OrcidAuth)", vim.log.levels.WARN)
		end
	end, {
		nargs = 0,
		desc = "Show validated ORCID iD",
	})

	api.nvim_create_user_command("OrcidLogout", function()
		M.logout()
	end, {
		nargs = 0,
		desc = "Clear ORCID OAuth token",
	})

	api.nvim_create_user_command("OrcidSearch", function(cmd_opts)
		if cmd_opts.args == "" then
			vim.notify("OrcidSearch: query required", vim.log.levels.WARN)
			return
		end
		local data, err = M.search(opts.args)
		if not data then
			vim.notify("ORCID: " .. (err or "unknown error"), vim.log.levels.ERROR)
			return
		end
		local results = (data["result"] or {})
		local lines = { "# ORCID Search (" .. #results .. " results)", "" }
		for i, r in ipairs(results) do
			local orcid = r["orcid-identifier"] or {}
			local path = orcid["path"] or "?"
			lines[#lines + 1] = string.format("%d. %s", i, path)
			if #lines >= DISPLAY_LINES_MAX - 2 then
				break
			end
		end
		show_scratch("ORCID Search", lines)
	end, {
		nargs = "+",
		desc = "Search the ORCID registry",
	})
end

return M
