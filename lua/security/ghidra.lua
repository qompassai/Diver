--- Ghidra headless analysis -- the "x-ray machine" for mystery binaries.
---
--- Plain-language version: Ghidra is the NSA's reverse-engineering tool.
--- Point this module at a binary file and it runs Ghidra without its
--- graphical interface (analyzeHeadless), then reads back three exports:
--- the list of functions Ghidra found, the text strings embedded in the
--- binary, and the decompiled C code. Everything runs through
--- security.rce.safe_exec (argv form only, never a shell), every project
--- lives in this module's own scratch directory, and every list that comes
--- back is capped. When Ghidra is not installed the module says so in a
--- structured result -- it never crashes and never guesses.
---
--- Two modes exist and are not to be confused:
---   * THIS module: headless. No Ghidra window needs to be open.
---   * The 'ghidra' MCP server in ai.mcp.declared_servers: the
---     bethington/ghidra-mcp bridge (installed: /usr/bin/bridge-mcp-ghidra),
---     a stdio MCP server multiplexing to the GhidraMCP plugin inside a
---     RUNNING Ghidra GUI (plugin HTTP on 127.0.0.1:8089 by default,
---     GHIDRA_MCP_URL overrides). The bridge itself starts without the
---     GUI; the proxied analysis tools answer only while it is open.
---
--- Sources: Ghidra analyzeHeadless analyzer help (project location/name,
--- -import, -scriptPath, -postScript, -overwrite, -analysisTimeoutPerFile);
--- bethington/ghidra-mcp README and the installed bridge's own config
--- (bridge-mcp-ghidra on PATH, plugin HTTP default 127.0.0.1:8089).
---
--- Resources (curated from AllsafeCyberSecurity/awesome-ghidra, reviewed
--- 2026-10-08; that list carries no MCP bridges at all -- the installed
--- bridge of record is bethington/ghidra-mcp, with LaurieWired/GhidraMCP
--- as the smaller original alternative):
---   * ghidra-fidb-repo: extra Function ID datasets (.fidb/.fidbf). Drop
---     them in <ghidra home>/Ghidra/Features/FunctionID/data/ and headless
---     library naming improves with no code change; M.status() counts them.
---   * FindCrypt-Ghidra: companion extension for crypto-constant triage.
---     Extensions live in the Ghidra install, never in this config.
---   * Script collections (Allsafe ghidra_script, 0x6d696368, raptor):
---     vetting candidates for a future bundled script; none vendored --
---     third-party scripts join this config only after review.
---   * Learning: The Ghidra Book (Eagle & Nance); NSA's GhidraClass docs.
---@module 'security.ghidra'

local rce = require('security.rce')

local M = {}

local ANALYSIS_TIMEOUT_PER_FILE_S = 240 -- Ghidra-side per-file analysis cap.
local DECOMPILE_PREVIEW_BYTES_MAX = 64 * 1024 -- decompile text kept in the result.
local EXPORT_LINE_BYTES_MAX = 4096 -- one export line is never longer than this.
local FUNCTIONS_MAX = 5000 -- parsed function rows kept.
local LABEL_CHARS_MAX = 48 -- sanitized project-label length cap.
local STRINGS_MAX = 5000 -- parsed string rows kept.
local TIMEOUT_MS_DEFAULT = 300000 -- safe_exec's own hard maximum.
local TIMEOUT_MS_MIN = 1000

local BRIDGE_COMMAND_FALLBACK = '/usr/bin/bridge-mcp-ghidra'
local BRIDGE_COMMAND_NAME = 'bridge-mcp-ghidra'
local BRIDGE_SERVER_URL = 'http://127.0.0.1:8089/'
local EXPORT_SCRIPT_NAME = 'DiverExportAnalysis.java'
local SCRATCH_ROOT_DEFAULT = '~/.local/share/diver/ghidra'

---@class security.GhidraBridgeStatus
---@field command string Bridge executable (bethington/ghidra-mcp).
---@field note string What this status can and cannot see.
---@field plugin_present boolean True when the GhidraMCP plugin zip is installed.
---@field present boolean True when the bridge executable exists.
---@field server_url string Plugin HTTP endpoint the bridge proxies to.

---@class security.GhidraFunction
---@field address string Entry-point address as written by the export.
---@field name string Function name.
---@field signature string Full signature, whitespace-flattened.

---@class security.GhidraStatus
---@field analyze_headless string|nil Path to analyzeHeadless when found.
---@field available boolean True when analyzeHeadless was located.
---@field bridge security.GhidraBridgeStatus
---@field error string|nil Why Ghidra is unavailable, when it is.
---@field fidb_count integer Function ID datasets present in the install.
---@field ghidra_home string|nil Resolved installation root.
---@field scratch_root string This module's project scratch directory.
---@field version string|nil application.version from the install, when readable.

---@class security.GhidraString
---@field address string Address of the defined string data.
---@field value string String value, control characters escaped by the export.

---@class security.GhidraResult
---@field binary string Absolute path of the analyzed binary.
---@field decompile_bytes integer Size of decompile.c on disk.
---@field decompile_path string Path of the decompile export.
---@field decompile_preview string First bytes of decompile.c, bounded.
---@field duration_ms integer Wall time of the safe_exec run.
---@field export_dir string Directory holding the three export files.
---@field function_count integer Function rows parsed (after the cap).
---@field functions security.GhidraFunction[]
---@field functions_truncated boolean True when FUNCTIONS_MAX cut the list.
---@field project_dir string Ghidra project directory for this binary.
---@field string_count integer String rows parsed (after the cap).
---@field strings security.GhidraString[]
---@field strings_truncated boolean True when STRINGS_MAX cut the list.

---@class security.GhidraSetupOptions
---@field bridge_command? string Override the bridge executable path (tests).
---@field ghidra_home? string Override the installation root (tests).
---@field scratch_root? string Override the scratch root (tests).

---@type security.GhidraSetupOptions
local configured = {}

local setup_done = false

---@param path string
---@return string path Path with a leading '~' expanded to $HOME.
local function expand_home(path)
    if path:sub(1, 1) == '~' then
        return (vim.env.HOME or '') .. path:sub(2)
    end
    return path
end

---@return string root Absolute scratch root (configured or default).
local function scratch_root()
    return expand_home(configured.scratch_root or SCRATCH_ROOT_DEFAULT)
end

---@return string path Directory holding the bundled export script.
local function export_script_dir()
    local source = debug.getinfo(1, 'S').source
    assert(source:sub(1, 1) == '@', 'ghidra.lua must be loaded from a file')
    local module_dir = vim.fn.fnamemodify(source:sub(2), ':p:h')
    return module_dir .. '/ghidra'
end

---@param home string
---@return string path
local function analyze_headless_in(home)
    return home .. '/support/analyzeHeadless'
end

---@param path string
---@return boolean found True when the path is an executable file.
local function is_executable(path)
    return vim.fn.executable(path) == 1
end

---Resolve the Ghidra installation root. Order: setup() override, the
---GHIDRA_INSTALL_DIR environment variable, analyzeHeadless on PATH, then
---the two conventional install roots. A candidate counts only when its
---support/analyzeHeadless is executable.
---@return string|nil home
local function resolve_ghidra_home()
    local candidates = {}
    if configured.ghidra_home ~= nil then
        candidates[#candidates + 1] = expand_home(configured.ghidra_home)
    end
    local env_home = vim.env.GHIDRA_INSTALL_DIR
    if env_home ~= nil and env_home ~= '' then
        candidates[#candidates + 1] = env_home
    end
    local on_path = vim.fn.exepath('analyzeHeadless')
    if on_path ~= '' then
        -- <home>/support/analyzeHeadless -> <home> is two directories up.
        candidates[#candidates + 1] = vim.fn.fnamemodify(on_path, ':h:h')
    end
    candidates[#candidates + 1] = '/opt/ghidra'
    candidates[#candidates + 1] = '/usr/share/ghidra'
    for _, home in ipairs(candidates) do
        if is_executable(analyze_headless_in(home)) then
            return home
        end
    end
    return nil
end

---@param home string
---@return string|nil version application.version from the install metadata.
local function read_version(home)
    local props_path = home .. '/Ghidra/application.properties'
    local lines = vim.fn.readfile(props_path, '', 64)
    for _, line in ipairs(lines) do
        local version = line:match('^application%.version=(.+)$')
        if version ~= nil then
            return vim.trim(version)
        end
    end
    return nil
end

---@return string command Bridge executable: setup() override, PATH, or the
---canonical fallback (reported even when absent, so the path is visible).
local function resolve_bridge_command()
    if configured.bridge_command ~= nil then
        return expand_home(configured.bridge_command)
    end
    local on_path = vim.fn.exepath(BRIDGE_COMMAND_NAME)
    if on_path ~= '' then
        return on_path
    end
    return BRIDGE_COMMAND_FALLBACK
end

---@param home string|nil
---@return boolean present True when a GhidraMCP plugin zip is installed.
local function plugin_present(home)
    if home == nil then
        return false
    end
    return #vim.fn.glob(home .. '/Extensions/Ghidra/GhidraMCP-*.zip', false, true) > 0
end

---Probe Ghidra and the MCP bridge. Never fails: absence is reported in the
---returned table, because "not installed yet" is a normal state.
---@return security.GhidraStatus status
function M.status()
    local home = resolve_ghidra_home()
    local bridge_command = resolve_bridge_command()
    ---@type security.GhidraStatus
    local status = {
        analyze_headless = nil,
        available = home ~= nil,
        bridge = {
            command = bridge_command,
            note = 'Bridge and plugin presence only: whether the plugin is '
                .. 'enabled inside a running Ghidra GUI is not visible from Neovim.',
            plugin_present = plugin_present(home),
            present = is_executable(bridge_command),
            server_url = BRIDGE_SERVER_URL,
        },
        error = nil,
        fidb_count = 0,
        ghidra_home = home,
        scratch_root = scratch_root(),
        version = nil,
    }
    if home == nil then
        status.error = 'Ghidra not found (looked in GHIDRA_INSTALL_DIR, PATH, '
            .. '/opt/ghidra, /usr/share/ghidra). Install Ghidra '
            .. '(paru -S ghidra) to enable headless analysis.'
        return status
    end
    status.analyze_headless = analyze_headless_in(home)
    status.version = read_version(home)
    status.fidb_count = #vim.fn.glob(home .. '/Ghidra/Features/FunctionID/data/*.fidb*', false, true)
    return status
end

---Turn arbitrary label text into a project-safe name: only [A-Za-z0-9._-]
---survive, everything else becomes '_', leading dots are stripped, and the
---result is length-capped. Traversal input such as '../../etc' therefore
---cannot escape the scratch root -- it becomes literal name characters.
---@param label string
---@return string sanitized Never empty.
local function sanitize_label(label)
    local cleaned = label:gsub('[^A-Za-z0-9._-]', '_')
    cleaned = cleaned:gsub('^%.+', '')
    cleaned = cleaned:sub(1, LABEL_CHARS_MAX)
    if cleaned == '' then
        cleaned = 'binary'
    end
    return cleaned
end

---Deterministic project name for a binary: sanitized basename (extension
---dropped) plus a short hash of the full path, so two different files with
---the same basename never share a project.
---@param binary_path string Absolute path of the binary.
---@return string project_name
function M.project_name_for(binary_path)
    assert(type(binary_path) == 'string', 'project_name_for expects a string path')
    local basename = vim.fn.fnamemodify(binary_path, ':t')
    local stem = basename:gsub('%.[^.]*$', '')
    local digest = vim.fn.sha256(binary_path):sub(1, 8)
    return sanitize_label(stem) .. '-' .. digest
end

---@param binary_path string Absolute path of the binary.
---@return string dir Project directory analyzeHeadless will use/create.
function M.scratch_dir_for(binary_path)
    return scratch_root() .. '/' .. M.project_name_for(binary_path)
end

---@param binary_path any
---@return string|nil abs_path Normalized absolute path when valid.
---@return string|nil err
local function validate_binary(binary_path)
    if type(binary_path) ~= 'string' or binary_path == '' then
        return nil, 'binary path must be a non-empty string'
    end
    if binary_path:find('[%c]') ~= nil then
        return nil, 'binary path must not contain control characters'
    end
    local abs_path = vim.fn.fnamemodify(expand_home(binary_path), ':p')
    if vim.fn.isdirectory(abs_path) == 1 then
        return nil, 'binary path is a directory: ' .. abs_path
    end
    if vim.fn.filereadable(abs_path) ~= 1 then
        return nil, 'binary path is not a readable file: ' .. abs_path
    end
    return abs_path, nil
end

---@param timeout_ms any
---@return integer|nil timeout_ms
---@return string|nil err
local function validate_timeout(timeout_ms)
    if timeout_ms == nil then
        return TIMEOUT_MS_DEFAULT, nil
    end
    if type(timeout_ms) ~= 'number' or timeout_ms < TIMEOUT_MS_MIN or timeout_ms > TIMEOUT_MS_DEFAULT then
        return nil, ('timeout_ms must be a number in [%d, %d]'):format(TIMEOUT_MS_MIN, TIMEOUT_MS_DEFAULT)
    end
    return math.floor(timeout_ms), nil
end

---Build the analyzeHeadless argv. The binary path travels as ONE argv
---element (safe_exec never invokes a shell), so metacharacters in a file
---name are inert data, not syntax.
---@param home string
---@param binary_path string Absolute, validated.
---@param export_dir string
---@return string[] argv
local function build_argv(home, binary_path, export_dir)
    return {
        analyze_headless_in(home),
        scratch_root(),
        M.project_name_for(binary_path),
        '-import',
        binary_path,
        '-scriptPath',
        export_script_dir(),
        '-postScript',
        EXPORT_SCRIPT_NAME,
        export_dir,
        '-overwrite',
        '-analysisTimeoutPerFile',
        tostring(ANALYSIS_TIMEOUT_PER_FILE_S),
    }
end

---Parse a two/three-column TSV export with hard caps on rows and line size.
---@param path string
---@param columns integer Expected tab-separated column count.
---@param rows_max integer
---@return table[] rows Each row is a list of column strings.
---@return boolean truncated True when the cap cut rows.
---@return integer total_rows Rows present in the file (counted past the cap).
local function parse_tsv(path, columns, rows_max)
    local rows = {}
    local total_rows = 0
    local file = io.open(path, 'r')
    if file == nil then
        return rows, false, 0
    end
    for line in file:lines() do
        if #line <= EXPORT_LINE_BYTES_MAX then
            local fields = vim.split(line, '\t', { plain = true })
            if #fields == columns then
                total_rows = total_rows + 1
                if #rows < rows_max then
                    rows[#rows + 1] = fields
                end
            end
        end
    end
    file:close()
    return rows, total_rows > rows_max, total_rows
end

---@param export_dir string
---@return security.GhidraFunction[] functions
---@return boolean truncated
local function read_functions(export_dir)
    local rows, truncated = parse_tsv(export_dir .. '/functions.tsv', 3, FUNCTIONS_MAX)
    local functions = {}
    for _, fields in ipairs(rows) do
        functions[#functions + 1] = { address = fields[1], name = fields[2], signature = fields[3] }
    end
    return functions, truncated
end

---@param export_dir string
---@return security.GhidraString[] strings
---@return boolean truncated
local function read_strings(export_dir)
    local rows, truncated = parse_tsv(export_dir .. '/strings.tsv', 2, STRINGS_MAX)
    local strings = {}
    for _, fields in ipairs(rows) do
        strings[#strings + 1] = { address = fields[1], value = fields[2] }
    end
    return strings, truncated
end

---@param export_dir string
---@return string path
---@return integer bytes
---@return string preview Bounded head of the decompile export.
local function read_decompile(export_dir)
    local path = export_dir .. '/decompile.c'
    local bytes = vim.fn.getfsize(path)
    if bytes < 0 then
        return path, 0, ''
    end
    local file = io.open(path, 'rb')
    if file == nil then
        return path, bytes, ''
    end
    local preview = file:read(DECOMPILE_PREVIEW_BYTES_MAX) or ''
    file:close()
    return path, bytes, preview
end

---Analyze one binary with headless Ghidra. Synchronous: the caller blocks
---for at most opts.timeout_ms (default and maximum 300000, safe_exec's own
---ceiling). The project lives in this module's scratch root and is reused
---on repeat runs; exports are rewritten each run.
---@param binary_path string Path of the binary to analyze.
---@param opts? { timeout_ms?: integer }
---@return security.GhidraResult|nil result
---@return string|nil err Human-readable reason on expected failure.
function M.analyze(binary_path, opts)
    opts = opts or {}
    local abs_path, path_err = validate_binary(binary_path)
    if path_err ~= nil then
        return nil, path_err
    end
    assert(abs_path ~= nil, 'validate_binary returned no error but no path')
    local timeout_ms, timeout_err = validate_timeout(opts.timeout_ms)
    if timeout_err ~= nil then
        return nil, timeout_err
    end
    assert(timeout_ms ~= nil, 'validate_timeout returned no error but no value')

    local home = resolve_ghidra_home()
    if home == nil then
        return nil, M.status().error
    end
    if vim.fn.isdirectory(export_script_dir()) ~= 1 then
        return nil, 'bundled export script missing: ' .. export_script_dir() .. '/' .. EXPORT_SCRIPT_NAME
    end

    local project_name = M.project_name_for(abs_path)
    local export_dir = scratch_root() .. '/' .. project_name .. '-exports'
    if vim.fn.mkdir(export_dir, 'p') == -1 then
        return nil, 'could not create export directory: ' .. export_dir
    end

    local argv = build_argv(home, abs_path, export_dir)
    local started_ms = vim.uv.now()
    local completed, exec_err = rce.safe_exec(argv, { timeout_ms = timeout_ms })
    local duration_ms = vim.uv.now() - started_ms
    if exec_err ~= nil then
        return nil, 'analyzeHeadless failed to run: ' .. exec_err
    end
    assert(completed ~= nil, 'safe_exec returned no error but no result')
    if completed.code ~= 0 then
        local stderr_tail = (completed.stderr or ''):sub(-1024)
        return nil, ('analyzeHeadless exited with code %d: %s'):format(completed.code, stderr_tail)
    end

    local functions, functions_truncated = read_functions(export_dir)
    local strings, strings_truncated = read_strings(export_dir)
    local decompile_path, decompile_bytes, preview = read_decompile(export_dir)
    ---@type security.GhidraResult
    local result = {
        binary = abs_path,
        decompile_bytes = decompile_bytes,
        decompile_path = decompile_path,
        decompile_preview = preview,
        duration_ms = duration_ms,
        export_dir = export_dir,
        function_count = #functions,
        functions = functions,
        functions_truncated = functions_truncated,
        project_dir = scratch_root() .. '/' .. project_name .. '.proj',
        string_count = #strings,
        strings = strings,
        strings_truncated = strings_truncated,
    }
    return result, nil
end

---@param result security.GhidraResult
---@return string[] lines Human-readable summary plus the function listing.
local function result_lines(result)
    local lines = {
        ('GhidraAnalyze: %s'):format(result.binary),
        ('  project:  %s'):format(result.project_dir),
        ('  exports:  %s'):format(result.export_dir),
        ('  time:     %d ms'):format(result.duration_ms),
        ('  functions: %d%s'):format(
            result.function_count,
            result.functions_truncated and ' (truncated at ' .. FUNCTIONS_MAX .. ')' or ''
        ),
        ('  strings:   %d%s'):format(
            result.string_count,
            result.strings_truncated and ' (truncated at ' .. STRINGS_MAX .. ')' or ''
        ),
        ('  decompile: %s (%d bytes)'):format(result.decompile_path, result.decompile_bytes),
        '',
        'Functions:',
    }
    for _, fn in ipairs(result.functions) do
        lines[#lines + 1] = ('  %s  %s'):format(fn.address, fn.signature)
    end
    return lines
end

---Register :GhidraStatus and :GhidraAnalyze. Idempotent.
---@param opts? security.GhidraSetupOptions Resolution overrides (used by tests).
---@return table M
function M.setup(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'security.ghidra.setup expects an options table')
    if opts.ghidra_home ~= nil then
        configured.ghidra_home = opts.ghidra_home
    end
    if opts.bridge_command ~= nil then
        configured.bridge_command = opts.bridge_command
    end
    if opts.scratch_root ~= nil then
        configured.scratch_root = opts.scratch_root
    end
    if setup_done then
        return M
    end
    setup_done = true

    vim.api.nvim_create_user_command('GhidraStatus', function()
        local status = M.status()
        local lines = {
            ('Ghidra headless: %s'):format(status.available and 'available' or 'unavailable'),
        }
        if status.available then
            lines[#lines + 1] = ('  analyzeHeadless: %s'):format(status.analyze_headless)
            lines[#lines + 1] = ('  version: %s'):format(status.version or 'unknown')
            lines[#lines + 1] = ('  function-id datasets: %d'):format(status.fidb_count)
        else
            lines[#lines + 1] = '  ' .. tostring(status.error)
        end
        lines[#lines + 1] = ('  scratch root: %s'):format(status.scratch_root)
        lines[#lines + 1] = ('  MCP bridge: %s (%s)'):format(
            status.bridge.command,
            status.bridge.present and 'present' or 'not installed'
        )
        lines[#lines + 1] = ('  MCP plugin zip: %s'):format(status.bridge.plugin_present and 'installed' or 'absent')
        lines[#lines + 1] = '  ' .. status.bridge.note
        vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    end, { desc = 'Report Ghidra headless + MCP bridge availability (security.ghidra)' })

    vim.api.nvim_create_user_command('GhidraAnalyze', function(command)
        local path = vim.trim(command.args)
        if path == '' then
            vim.notify('GhidraAnalyze: usage :GhidraAnalyze <binary path>', vim.log.levels.WARN)
            return
        end
        local result, analyze_err = M.analyze(path)
        if analyze_err ~= nil then
            vim.notify('GhidraAnalyze: ' .. analyze_err, vim.log.levels.ERROR)
            return
        end
        assert(result ~= nil, 'analyze returned no error but no result')
        local lines = result_lines(result)
        local buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
        vim.api.nvim_buf_set_name(buffer, 'ghidra://results/' .. M.project_name_for(result.binary))
        vim.bo[buffer].modifiable = false
        vim.api.nvim_set_current_buf(buffer)
    end, {
        complete = 'file',
        desc = 'Analyze a binary with headless Ghidra (security.ghidra)',
        nargs = '+',
    })
    return M
end

return M
