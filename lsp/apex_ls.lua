-- /qompassai/Diver/lsp/apex_ls.lua
-- Qompass AI Diver Apex LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.filetype.add({
    pattern = {
        ['.*/*.cls'] = 'apex',
    },
})
---@type vim.lsp.Config
return {
    apex_jar_path = vim.fn.stdpath('data') .. '/apex-ls/apex-jorje-lsp.jar',
    apex_enable_semantic_errors = false,
    apex_enable_completion_statistics = false,
    apex_jvm_max_heap = '2G',
    cmd = function(dispatchers, config)
        ---@diagnostic disable: undefined-field
        local java = vim.env.JAVA_HOME and (vim.env.JAVA_HOME .. '/bin/java') or 'java'
        local local_cmd = {
            java,
            '-cp',
            config.apex_jar_path,
            '-Ddebug.internal.errors=true',
            '-Ddebug.semantic.errors=' .. tostring(config.apex_enable_semantic_errors or false),
            '-Ddebug.completion.statistics=' .. tostring(config.apex_enable_completion_statistics or false),
            '-Dlwc.typegeneration.disabled=true',
        }
        if config.apex_jvm_max_heap then
            table.insert(local_cmd, '-Xmx' .. config.apex_jvm_max_heap)
        end
        ---@diagnostic enable: undefined-field
        table.insert(local_cmd, 'apex.jorje.lsp.ApexLanguageServerLauncher')
        return vim.lsp.rpc.start(local_cmd, dispatchers)
    end,
    filetypes = {
        'apex',
        'apexcode',
    },
    root_markers = {
        'sfdx-project.json',
    },
}
