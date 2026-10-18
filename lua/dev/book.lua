-- /qompassai/Diver/lua/dev/book.lua
-- :DiverBook -- build and open the config's mdBook documentation.
--
-- Plain words: the book under the diver repo's docs/book/ is
-- generated from the config's LuaCATS annotations by
-- docs/book/build-api.sh (emmylua_doc_cli + mdBook). This module is
-- the in-editor front end: `:DiverBook build` regenerates it,
-- `:DiverBook open` (the default) rebuilds first when the Lua
-- sources are newer than the last build, then opens the book.
--
-- The repo root resolves in order: setup opts, $DIVER_REPO, then
-- ~/.GH/Qompass/Diver. Builds run async through vim.system with a
-- watchdog; the editor never blocks on the generator.
---@module 'dev.book'

local M = {}

local api = vim.api

local BUILD_TIMEOUT_MS = 600000 ---@type integer Watchdog for one docs build
local DEFAULT_REPO = vim.fn.expand('~/.GH/Qompass/Diver') ---@type string
local FIND_TIMEOUT_MS = 5000 ---@type integer Bound for the staleness probe

local repo_override = nil ---@type string?
local setup_done = false

---Resolve and validate the diver repo root.
---@return string? root
---@return string? err
local function repo_root()
    local root = repo_override or vim.env.DIVER_REPO or DEFAULT_REPO
    if vim.fn.isdirectory(root .. '/docs/book') == 0 then
        return nil, 'no docs/book under repo root: ' .. root
    end
    return root, nil
end

---True when the rendered book is missing or older than the sources.
---@param root string
---@return boolean
local function book_is_stale(root)
    local book_dir = root .. '/docs/book'
    if vim.fn.filereadable(book_dir .. '/book/index.html') == 0 then
        return true
    end
    local stamp = book_dir .. '/.last-build'
    if vim.fn.filereadable(stamp) == 0 then
        return true
    end
    local obj = vim.system(
        { 'find', root .. '/lua', '-name', '*.lua', '-newer', stamp, '-print', '-quit' },
        { text = true }
    )
    local result = obj:wait(FIND_TIMEOUT_MS)
    if result.code ~= 0 then
        return true
    end
    return result.stdout ~= nil and vim.trim(result.stdout) ~= ''
end

---Run the build script async; on_done(ok) fires exactly once.
---@param root string
---@param on_done fun(ok: boolean)
local function run_build(root, on_done)
    local script = root .. '/docs/book/build-api.sh'
    local finished = false
    local function finish(ok, message, level)
        if finished then
            return
        end
        finished = true
        vim.notify('DiverBook: ' .. message, level)
        on_done(ok)
    end
    local handle = vim.system({ 'bash', script, root }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                finish(true, 'docs built', vim.log.levels.INFO)
            else
                local tail = vim.trim((obj.stderr or ''):sub(-400))
                finish(false, 'build failed: ' .. tail, vim.log.levels.ERROR)
            end
        end)
    end)
    vim.defer_fn(function()
        if not finished then
            handle:kill(9)
            finish(false, 'build timed out', vim.log.levels.ERROR)
        end
    end, BUILD_TIMEOUT_MS)
    vim.notify('DiverBook: building docs...', vim.log.levels.INFO)
end

---`:DiverBook build` -- regenerate the API reference and the book.
function M.build()
    local root, err = repo_root()
    if root == nil then
        vim.notify('DiverBook: ' .. err, vim.log.levels.ERROR)
        return
    end
    run_build(root, function() end)
end

---`:DiverBook open` -- build when stale, then open the book.
function M.open()
    local root, err = repo_root()
    if root == nil then
        vim.notify('DiverBook: ' .. err, vim.log.levels.ERROR)
        return
    end
    local html = root .. '/docs/book/book/index.html'
    if book_is_stale(root) then
        run_build(root, function(ok)
            if ok then
                vim.ui.open(html)
            end
        end)
    else
        vim.ui.open(html)
    end
end

---Register :DiverBook. Idempotent.
---@param opts? table { repo: string? }
function M.setup(opts)
    if setup_done then
        return
    end
    setup_done = true
    opts = opts or {}
    if opts.repo ~= nil then
        assert(type(opts.repo) == 'string', 'opts.repo must be a string')
        repo_override = opts.repo
    end
    api.nvim_create_user_command('DiverBook', function(cmd)
        local action = cmd.args
        if action == '' or action == 'open' then
            M.open()
        elseif action == 'build' then
            M.build()
        else
            vim.notify('DiverBook: usage :DiverBook [build|open]', vim.log.levels.WARN)
        end
    end, {
        nargs = '?',
        complete = function()
            return { 'build', 'open' }
        end,
        desc = 'Build or open the diver mdBook documentation',
    })
end

return M
