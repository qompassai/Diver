-- /qompassai/Diver/lua/utils/lang/rust.lua
-- Qompass AI Rust Lang Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local U = {}
local M = {}
function M.rust_cmp()
    local caps = vim.lsp.protocol.make_client_capabilities()
    local ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
    if ok and type(cmp_lsp.default_capabilities) == 'function' then
        caps = cmp_lsp.default_capabilities(caps)
    end
    if vim.g.use_blink_cmp ~= false then
        local ok_blink, blink = pcall(require, 'blink.cmp')
        if ok_blink and type(blink.capabilities) == 'function' then
            caps = vim.tbl_deep_extend('force', caps, blink.capabilities())
        end
    end
    return caps
end

function M.rust_env()
    local sys = vim.uv.os_uname().sysname
    local sep = (sys == 'Windows_NT') and ';' or ':'
    local paths = {}
    local cargo_home = os.getenv('CARGO_HOME')
        or (sys == 'Windows_NT' and (os.getenv('USERPROFILE') .. [[\\.cargo]]) or vim.fn.expand('~/.cargo'))
    table.insert(paths, cargo_home .. '/bin')
    table.insert(paths, vim.fn.expand('~/.local/bin'))
    if sys == 'Windows_NT' then
        table.insert(paths, os.getenv('USERPROFILE') .. [[\\AppData\\Local\\bin]])
    end
    for _, p in ipairs(paths) do ---@type string
        p = vim.fn.expand(p)
        if vim.fn.isdirectory(p) == 1 and not vim.env.PATH:find(vim.pesc(p), 1, true) then
            vim.env.PATH = p .. sep .. vim.env.PATH ---@type string
        end
    end
end

M.rust_env()
M.rust_editions = {
    ['2021'] = '2021',
    ['2024'] = '2024',
}
M.rust_toolchains = {
    stable = 'stable',
    nightly = 'nightly',
    beta = 'beta',
}
M.rust_default_edition = '2024'
M.rust_default_toolchain = 'nightly'

function U.rust_edition(edition)
    if U.rust_editions[edition] then
        U.current_edition = edition
        vim.echo('Rust edition set to ' .. edition, vim.log.levels.INFO)
        vim.cmd('LspRestart')
    else
        vim.echo('Invalid Rust edition: ' .. tostring(edition), vim.log.levels.ERROR)
    end
end

function M.rust_set_toolchain(tc)
    if U.rust_toolchains[tc] then
        U.current_toolchain = tc
        vim.echo('Rust toolchain set to ' .. tc, vim.log.levels.INFO)
        vim.cmd('LspRestart')
    else
        vim.echo('Invalid Rust toolchain: ' .. tostring(tc), vim.log.levels.ERROR)
    end
end

function M.rust_auto_toolchain()
    local f = vim.fn.findfile('rust-toolchain.toml', '.;')
    if f ~= '' then
        for _, line in ipairs(vim.fn.readfile('f')) do
            local ed = line:match('edition%s*=%s*"(%d+)"')
            local tch = line:match('channel%s*=%s*"([%w%-]+)"')
            if ed then
                U.rust_edition(ed)
            end
            if tch then
                U.rust_set_toolchain(tch)
            end
        end
    end
end

function M.rust_analyzer()
    return {
        cargo = {
            allFeatures = true,
            loadOutDirsFromCheck = true,
            runBuildScripts = true,
        },
        checkOnSave = true,
        check = {
            command = 'clippy',
            extraArgs = {
                '--target-dir=target/analyzer',
            },
        },
        diagnostics = {
            enable = true,
            experimental = { enable = true },
            disabled = {
                'unresolved-proc-macro',
                'macro-error',
            },
        },
        procMacro = { enable = true, attributes = { enable = true } },
        files = {
            excludeDirs = {
                '.direnv',
                '.git',
                'target',
                'node_modules',
                'tests/generated',
                '.zig-cache',
            },
            watcher = 'client',
        },
        inlayHints = {
            typeHints = true,
            parameterHints = true,
            chainingHints = true,
            closingBraceHints = true,
        },
        rustc = {
            source = U.rust_default_toolchain, ---@type table[]
            edition = U.rust_default_edition, ---@type string[]
        },
    }
end

return M
