-- /qompassai/Diver/lua/utils/git.lua
-- Qompass AI Diver Hardened Git Queries
---@module 'utils.git'
local M = {}

-- Repo-config hardening (CVE-2026-129128 shape): command-line -c values
-- override the opened repo's own config, so a hostile repo cannot turn
-- diff.external, core.fsmonitor, core.pager or core.hooksPath into code
-- execution from an editor query. Editor git calls run in whatever repo
-- the user has open, i.e. precisely the uninspected-repo case.
local CONFIG_OVERRIDES = {
    '-c',
    'core.fsmonitor=false',
    '-c',
    'core.pager=cat',
    '-c',
    'diff.external=',
    '-c',
    'core.hooksPath=/dev/null',
}

local DIFF_FAMILY = {
    diff = true,
    log = true,
    show = true,
}

--- Environment for the child process: the editor's environment minus
--- the variables that would relocate or reconfigure git, with the
--- pager pinned so no pager can fire. Passed with clear_env so the
--- table is the whole environment, not a merge over the parent's.
---@return table<string, string>
local function git_env()
    local env = {}
    for key, value in pairs(vim.fn.environ()) do
        env[key] = value
    end
    env.GIT_CONFIG = nil
    env.GIT_CONFIG_COUNT = nil
    env.GIT_DIR = nil
    env.GIT_EXTERNAL_DIFF = nil
    env.GIT_WORK_TREE = nil
    env.GIT_PAGER = 'cat'
    env.PAGER = 'cat'
    return env
end

--- Run git with the hardening prefix and return its stdout lines.
--- Returns an empty table when git fails or is absent.
---@param args string[] git arguments, subcommand first
---@param cwd string|nil working directory (default: editor cwd)
---@return string[]
function M.lines(args, cwd)
    local argv = { 'git', '--no-pager', '-C', cwd or vim.fn.getcwd() }
    vim.list_extend(argv, CONFIG_OVERRIDES)
    if DIFF_FAMILY[args[1]] then
        argv[#argv + 1] = args[1]
        argv[#argv + 1] = '--no-ext-diff'
        for index = 2, #args do
            argv[#argv + 1] = args[index]
        end
    else
        vim.list_extend(argv, args)
    end
    local result = vim.system(argv, { clear_env = true, env = git_env(), text = true }):wait()
    if result.code ~= 0 or result.stdout == nil or result.stdout == '' then
        return {}
    end
    return vim.split(result.stdout, '\n', { plain = true, trimempty = true })
end

return M
