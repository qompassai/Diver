-- /qompassai/Diver/lsp/jdt_ls.lua
-- Qompass AI Eclipse JDT Java LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local function get_jdtls_cache_dir()
    return vim.fn.stdpath('cache') .. '/jdtls'
end
local function get_jdtls_workspace_dir()
    return get_jdtls_cache_dir() .. '/workspace'
end
local function get_jdtls_jvm_args()
    local env = os.getenv('JDTLS_JVM_ARGS')
    local args = {}
    for a in string.gmatch((env or ''), '%S+') do
        table.insert(args, ('--jvm-arg=' .. a))
    end
    return unpack(args)
end
---@type vim.lsp.Config
return {
    ---@param dispatchers? vim.lsp.rpc.Dispatchers
    ---@param config vim.lsp.ClientConfig
    cmd = function(dispatchers, config)
        local workspace_dir = get_jdtls_workspace_dir()
        local data_dir = workspace_dir
        if config.root_dir then
            data_dir = data_dir .. '/' .. vim.fn.fnamemodify(config.root_dir, ':p:h:t')
        end
        local config_cmd = {
            'jdtls',
            '-data',
            data_dir,
            get_jdtls_jvm_args(),
        }
        return vim.lsp.rpc.start(config_cmd, dispatchers, {
            cwd = config.cmd_cwd,
            env = config.cmd_env,
            detached = config.detached,
        })
    end,
    filetypes = {
        'java',
    },
    root_markers = {
        'build.gradle',
        'build.gradle.kts',
        'build.xml',
        'mvnw',
        'gradlew',
        'settings.gradle',
        'settings.gradle.kts',
        '.git',
        'pom.xml',
    },
    init_options = {},
}
