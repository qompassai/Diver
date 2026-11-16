-- /qompassai/Diver/lua/games/wasm4/actions.lua
-- Qompass AI WASM-4 Actions
--- Action implementations for the verified WASM-4 CLI surface (w4
--- v2.7.1, `w4 <cmd> --help`, verified 2026-11-15):
--- * `w4 new <dir> --lang <lang>` scaffolds a cart project.
--- * `w4 bundle <cart> --html|--windows|--mac|--linux <out>` packages
---   a built cart; the HTML bundle is a single self-contained page
---   (the phone route).
--- * `w4 png2src <images...> --lang <lang>` prints sprite source on
---   stdout; this module lands it in a scratch buffer.
--- * `w4 run <cart>` serves the web runtime on port 4444 with a QR
---   code; `w4 run-native <cart>` opens the desktop runtime and needs
---   a display, so `run_mode = 'auto'` picks native only when DISPLAY
---   or WAYLAND_DISPLAY is set.
--- * `w4 watch` rebuilds on save and refreshes the web runtime.
---
--- Rust carts: `w4 new --rust` emits a `.cargo/config.toml` whose
--- rustflags predate current rust-lld, which refuses the console
--- API's undefined env-import symbols (blit, textUtf8, ...) at link
--- time. Scaffolding a Rust cart here applies the proven
--- `--allow-undefined` link fix (see util.ensure_rust_link_fix).
---
--- The games doctor in games/health.lua is a fixed probe list owned
--- outside this module; `health_check` below reports the same facts
--- (binary, version, wasm32 target) from inside the module.
---@module 'games.wasm4.actions'

local config = require('games.wasm4.config')
local shared_util = require('games.shared.util')
local util = require('games.wasm4.util')
local levels = vim.log.levels

local notify = vim.notify

local M = {}

---@type vim.SystemObj?
local current_job = nil
---@type integer?
local watch_bufnr = nil
local OUTPUT_LINE_MAX = 20000
local SIGTERM = 'sigterm'
local STDERR_PREVIEW_MAX = 500

---@param root string Project root directory.
---@param format string Bundle format from config.bundle_formats.
---@return string path Default bundle output path.
local function bundle_output_path(root, format)
    local base = vim.fn.fnamemodify(root, ':t')
    if format == 'html' then
        return root .. '/' .. base .. '.html'
    end
    return root .. '/' .. base .. '-' .. format
end

---@return string? root, string? kind Project enclosing the current
---buffer, or a prompted directory's project; nil when neither resolves.
local function current_project_or_prompt()
    local buffer_name = vim.api.nvim_buf_get_name(0)
    local start = vim.fn.getcwd()
    if buffer_name ~= '' then
        start = vim.fn.fnamemodify(buffer_name, ':h')
    end
    local root, kind = util.detect_project(start)
    if root ~= nil then
        return root, kind
    end
    local input = shared_util.trim(vim.fn.input('WASM-4 project dir: ', '', 'dir'))
    if input == '' then
        return nil, nil
    end
    return util.detect_project(vim.fs.normalize(vim.fn.expand(input)))
end

---@param lines string[] Buffer content.
---@param filetype string Filetype to set on the scratch buffer.
local function open_output_buffer(lines, filetype)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = filetype
    vim.api.nvim_set_current_buf(bufnr)
end

---@param argv string[] Command to run to completion.
---@param cwd string? Working directory for the command.
---@return boolean ok False when the command exits non-zero.
local function run_system(argv, cwd)
    local completed_obj = vim.system(argv, { cwd = cwd, text = true })
    ---@cast completed_obj vim.SystemObj
    local completed = completed_obj:wait()
    if completed.code ~= 0 then
        local stderr = shared_util.trim(completed.stderr or '')
        notify('WASM-4: command failed: ' .. stderr:sub(1, STDERR_PREVIEW_MAX), levels.ERROR)
        return false
    end
    return true
end

---Stop the running cart, if any. Idempotent: safe to call with no job.
local function stop_current()
    local job = current_job
    current_job = nil
    if job ~= nil then
        pcall(job.kill, job, SIGTERM)
    end
end

---@return table[]
local function build_actions()
    return {
        { id = 'build', label = 'Build cart', group = 'Build', run = M.build_cart },
        { id = 'bundle', label = 'Bundle cart (html/native)', group = 'Build', run = M.bundle_cart },
    }
end

---@return table[]
local function media_actions()
    return {
        {
            id = 'png2_src',
            label = 'Convert sprite PNG to source',
            group = 'Media',
            run = function()
                M.png2src()
            end,
        },
    }
end

---@return table[]
local function project_actions()
    return {
        { id = 'new', label = 'New cart (w4 new scaffold)', group = 'Project', run = M.new_cart },
        {
            id = 'describe_environment',
            label = 'Describe environment',
            group = 'Project',
            run = M.describe_environment,
        },
        { id = 'health_check', label = 'Health check', group = 'Project', run = M.health_check },
    }
end

---@return table[]
local function run_actions()
    return {
        { id = 'run', label = 'Run cart', group = 'Run', run = M.run_cart },
        { id = 'stop', label = 'Stop running cart', group = 'Run', run = M.stop_cart },
        { id = 'watch', label = 'Watch (rebuild + web runtime)', group = 'Run', run = M.watch_cart },
    }
end

---Build the cart project at `root` (detected from the current buffer
---when nil) with the kind's verified build command.
---@param root string?
---@return boolean ok False when no project resolves or the build fails.
function M.build_cart(root)
    local kind
    if root == nil then
        root, kind = current_project_or_prompt()
        if root == nil then
            return false
        end
    else
        local found_root, found_kind = util.detect_project(root)
        if found_root == nil then
            notify('WASM-4: no cart project found at ' .. root, levels.WARN)
            return false
        end
        root, kind = found_root, found_kind
    end
    local kind_spec = config.project_kinds[kind]
    if kind_spec == nil then
        notify('WASM-4: unknown project kind: ' .. tostring(kind), levels.ERROR)
        return false
    end
    notify('WASM-4: building ' .. tostring(kind) .. ' cart in ' .. root .. ' ...', levels.INFO)
    if not run_system(kind_spec.build_argv, root) then
        return false
    end
    local cart = util.project_cart_path(root, kind)
    if cart == nil or vim.fn.filereadable(cart) == 0 then
        notify('WASM-4: build finished but no cart at ' .. tostring(cart), levels.WARN)
        return false
    end
    notify('WASM-4: built ' .. cart, levels.INFO)
    return true
end

---Bundle the current project's built cart for distribution. The HTML
---bundle is one self-contained page (the phone route); the native
---bundles are single executables per platform.
function M.bundle_cart()
    local bin = util.require_binary()
    if bin == nil then
        return
    end
    local root, kind = current_project_or_prompt()
    if root == nil then
        return
    end
    local cart = util.project_cart_path(root, kind)
    if cart == nil or vim.fn.filereadable(cart) == 0 then
        notify('WASM-4: no built cart found; run :Wasm4Build first.', levels.WARN)
        return
    end
    vim.ui.select(config.bundle_formats, {
        prompt = 'WASM-4 bundle format:',
    }, function(format)
        if format == nil then
            return
        end
        local out = shared_util.trim(vim.fn.input('WASM-4 bundle output: ', bundle_output_path(root, format), 'file'))
        if out == '' then
            return
        end
        out = vim.fs.normalize(vim.fn.expand(out))
        local title = vim.fn.fnamemodify(root, ':t')
        if run_system({ bin, 'bundle', cart, '--' .. format, out, '--title', title }) then
            notify('WASM-4: bundled ' .. format .. ' -> ' .. out, levels.INFO)
        end
    end)
end

function M.describe_environment()
    local root, kind = util.detect_project(vim.fn.getcwd())
    notify(
        table.concat({
            'WASM-4 binary: ' .. (util.find_binary() or 'not found'),
            'WASM-4 version: ' .. (util.version() or 'unknown'),
            'Projects dir: ' .. config.current.projects_dir,
            'Default language: ' .. config.current.default_language,
            'Run mode: ' .. config.current.run_mode,
            'Project at cwd: ' .. (root ~= nil and (root .. ' (' .. tostring(kind) .. ')') or 'none detected'),
        }, '\n'),
        levels.INFO
    )
end

---@return table[] Action descriptors for the menu/command surface.
function M.get_actions()
    local result = {}
    vim.list_extend(result, run_actions())
    vim.list_extend(result, build_actions())
    vim.list_extend(result, media_actions())
    vim.list_extend(result, project_actions())
    return result
end

---Module-local health check: the games doctor's probe list in
---games/health.lua is fixed and owned outside this module, so the
---wasm4 facts (binary, version, Rust wasm32 target) are reported here.
function M.health_check()
    local bin = util.find_binary()
    notify(
        table.concat({
            'WASM-4 binary: ' .. (bin or 'not found (set NVIM_WASM4_BIN or add w4 to $PATH)'),
            'WASM-4 version: ' .. (util.version() or 'unknown'),
            'Rust wasm32 target: ' .. (util.wasm32_target_installed() and 'installed' or 'not installed'),
        }, '\n'),
        bin ~= nil and levels.INFO or levels.ERROR
    )
end

---Prompt for a name, parent directory, and language, then scaffold.
function M.new_cart()
    local name = shared_util.trim(vim.fn.input('WASM-4 new cart name: ', 'game'))
    if name == '' then
        return
    end
    local parent = shared_util.trim(vim.fn.input('WASM-4 parent dir: ', config.current.projects_dir .. '/', 'dir'))
    if parent == '' then
        return
    end
    vim.ui.select(config.languages, {
        prompt = 'WASM-4 language (default ' .. config.current.default_language .. '):',
    }, function(language)
        if language == nil then
            return
        end
        local dir = vim.fs.normalize(vim.fn.expand(parent) .. '/' .. name)
        M.scaffold_cart(dir, language)
    end)
end

---Convert sprite PNGs to source with `w4 png2src` and land the output
---in a scratch buffer. Language follows config.default_language.
---@param files string[]? PNG paths; current buffer or a prompt when empty.
function M.png2src(files)
    local bin = util.require_binary()
    if bin == nil then
        return
    end
    local targets = files
    if targets == nil or #targets == 0 then
        local current = vim.api.nvim_buf_get_name(0)
        if current:sub(-4) == '.png' then
            targets = { current }
        else
            local input = shared_util.trim(vim.fn.input('WASM-4 sprite PNG: ', '', 'file'))
            if input == '' then
                return
            end
            targets = { vim.fn.expand(input) }
        end
    end
    local language = config.current.default_language
    local argv = { bin, 'png2src', '--lang', language }
    for _, file in ipairs(targets) do
        argv[#argv + 1] = file
    end
    local completed_obj = vim.system(argv, { text = true })
    ---@cast completed_obj vim.SystemObj
    local completed = completed_obj:wait()
    if completed.code ~= 0 then
        local stderr = shared_util.trim(completed.stderr or '')
        notify('WASM-4: png2src failed: ' .. stderr:sub(1, STDERR_PREVIEW_MAX), levels.ERROR)
        return
    end
    local lines = vim.split(completed.stdout or '', '\n', { plain = true })
    if #lines > OUTPUT_LINE_MAX then
        local line_count = #lines
        lines = vim.list_slice(lines, 1, OUTPUT_LINE_MAX)
        lines[#lines + 1] = '-- truncated: ' .. line_count .. ' lines total'
    end
    open_output_buffer(lines, config.png2src_filetypes[language] or config.output_filetype)
end

---@param action table Action descriptor from get_actions().
function M.run_action(action)
    action.run()
end

---@param id string Action id from get_actions().
function M.run_action_by_id(id)
    local map = shared_util.build_action_map(M.get_actions())
    local action = map[id]
    if action == nil then
        notify('Unknown WASM-4 action: ' .. id, levels.ERROR)
        return
    end
    M.run_action(action)
end

---Run a built cart, stopping the previous run first. Native runtime
---when run_mode says so (auto: only with a display); otherwise the
---web runtime, which serves the cart on port 4444 with a QR code.
---@param cart string? Cart path; the current project's cart when nil.
---@return boolean ok False when no cart or no binary is available.
function M.run_cart(cart)
    if cart == nil then
        local root, kind = current_project_or_prompt()
        if root == nil then
            return false
        end
        cart = util.project_cart_path(root, kind)
    end
    if cart == nil or cart == '' or vim.fn.filereadable(cart) == 0 then
        notify('WASM-4: no built cart to run; run :Wasm4Build first.', levels.WARN)
        return false
    end
    local bin = util.find_binary()
    if bin == nil then
        notify('WASM-4: no w4 binary found (install w4 or set NVIM_WASM4_BIN)', levels.WARN)
        return false
    end
    stop_current()
    local mode = config.current.run_mode
    if mode == 'auto' then
        if vim.env.DISPLAY ~= nil or vim.env.WAYLAND_DISPLAY ~= nil then
            mode = 'native'
        else
            mode = 'web'
        end
    end
    local argv = { bin, 'run', cart }
    if mode == 'native' then
        argv = { bin, 'run-native', cart }
    end
    local spawned = vim.system(argv)
    ---@cast spawned vim.SystemObj
    current_job = spawned
    notify('WASM-4: running ' .. vim.fs.basename(cart) .. ' (' .. mode .. ' runtime).', levels.INFO)
    return true
end

---Scaffold a cart project with `w4 new`; Rust carts also get the
---proven `--allow-undefined` link fix in `.cargo/config.toml`.
---@param dir string Directory to create the project in.
---@param language string One of config.languages.
---@return boolean ok False when the scaffold or the link fix fails.
function M.scaffold_cart(dir, language)
    local bin = util.require_binary()
    if bin == nil then
        return false
    end
    if vim.fn.isdirectory(dir) == 1 and util.detect_project(dir) ~= nil then
        notify('WASM-4: a cart project already exists at ' .. dir, levels.WARN)
        return false
    end
    vim.fn.mkdir(vim.fn.fnamemodify(dir, ':h'), 'p')
    if not run_system({ bin, 'new', '--lang', language, dir }) then
        return false
    end
    if language == 'rust' then
        local changed, fix_error = util.ensure_rust_link_fix(dir)
        if changed == nil then
            notify('WASM-4: cart scaffolded but the Rust link fix failed: ' .. tostring(fix_error), levels.WARN)
            return false
        end
    end
    notify('WASM-4: cart scaffolded at ' .. dir .. ' (' .. language .. ').', levels.INFO)
    return true
end

function M.show_menu()
    require('games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
        group_order = config.group_order,
        prompt = 'Select WASM-4 action:',
    })
end

---Stop the running cart, if any.
function M.stop_cart()
    stop_current()
end

---Open `w4 watch` for the current project in a terminal split: the
---CLI rebuilds on save and refreshes the web runtime (port 4444).
function M.watch_cart()
    local root = current_project_or_prompt()
    if root == nil then
        return
    end
    local bin = util.require_binary()
    if bin == nil then
        return
    end
    if watch_bufnr ~= nil and vim.api.nvim_buf_is_valid(watch_bufnr) then
        local wins = vim.fn.win_findbuf(watch_bufnr)
        if #wins > 0 then
            vim.api.nvim_set_current_win(wins[1])
        else
            vim.cmd('botright split')
            vim.api.nvim_win_set_buf(0, watch_bufnr)
        end
        return
    end
    vim.cmd('botright split')
    vim.fn.termopen({ bin, 'watch' }, { cwd = root })
    watch_bufnr = vim.api.nvim_get_current_buf()
    notify('WASM-4: watching ' .. root .. ' (web runtime on port 4444).', levels.INFO)
end

return M
