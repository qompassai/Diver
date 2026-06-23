-- /qompassai/Diver/lsp/apex_ls.lua
-- Qompass AI Diver Apex LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@source https://developer.salesforce.com/docs/platform/sfvscode-extensions/guide/apex-language-server.html
local function apex_cmd(dispatchers, config)
    local apex_settings = config.settings and config.settings.apex or {}
    local jvm = apex_settings.jvm or {}
    local java = config.apex_java_home and (config.apex_java_home .. '/bin/java')
        or (vim.env.JAVA_HOME and (vim.env.JAVA_HOME .. '/bin/java') or 'java')
    local cmd = {
        java,
        '-cp',
        config.apex_jar_path,
        string.format('-Ddebug.internal.errors=%s', tostring(jvm.debugInternalErrors ~= false)),
        string.format('-Ddebug.semantic.errors=%s', tostring(jvm.debugSemanticErrors or false)),
        string.format('-Ddebug.completion.statistics=%s', tostring(jvm.completionStatistics or false)),
        string.format('-Dlwc.typegeneration.disabled=%s', tostring(jvm.disableLwcTypeGeneration ~= false)),
    }
    if jvm.maxHeap or config.apex_jvm_max_heap then
        table.insert(cmd, '-Xmx' .. (jvm.maxHeap or config.apex_jvm_max_heap))
    end
    table.insert(cmd, 'apex.jorje.lsp.ApexLanguageServerLauncher')
    return vim.lsp.rpc.start(cmd, dispatchers)
end
local function setup_apex_format_on_save()
    local group = vim.api.nvim_create_augroup('apex-external-format', {
        clear = true,
    })
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        pattern = {
            '*.cls',
            '*.trigger',
            '*.apex',
        },
        callback = function(args)
            local buf = args.buf
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end
            if vim.bo[buf].buftype ~= '' then
                return
            end
            if vim.bo[buf].filetype ~= 'apex' then
                return
            end
            local file = vim.api.nvim_buf_get_name(buf)
            if file == '' then
                return
            end
            if vim.fn.executable('apexfmt') ~= 1 then
                return
            end
            local stderr = {}
            vim.fn.jobstart({
                'apexfmt',
                file,
            }, {
                stdout_buffered = true,
                stderr_buffered = true,
                on_stderr = function(_, data)
                    if data then
                        for _, line in ipairs(data) do
                            if line and line ~= '' then
                                table.insert(stderr, line)
                            end
                        end
                    end
                end,
                on_exit = function(_, code)
                    vim.schedule(function()
                        if not vim.api.nvim_buf_is_valid(buf) then
                            return
                        end
                        if code == 0 then
                            if vim.api.nvim_buf_is_loaded(buf) then
                                vim.cmd('checktime ' .. vim.fn.fnameescape(file))
                            end
                        elseif #stderr > 0 then
                            vim.notify(table.concat(stderr, '\n'), vim.log.levels.WARN, {
                                title = 'apexfmt',
                            })
                        else
                            vim.notify('apexfmt failed for ' .. file, vim.log.levels.WARN, {
                                title = 'apexfmt',
                            })
                        end
                    end)
                end,
            })
        end,
    })
end

setup_apex_format_on_save()
return ---@type vim.lsp.Config
{
    apex_jar_path = vim.fn.stdpath('data') .. '/apex-ls/apex-jorje-lsp.jar',
    apex_enable_completion_statistics = false,
    apex_enable_semantic_errors = false,
    apex_java_home = nil,
    apex_jvm_max_heap = '2G',
    cmd = apex_cmd,
    filetypes = {
        'apex',
        'apexcode',
    },
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        '.git',
        'sfdx-project.json',
        'force-app',
        'manifest',
    },
    settings = {
        apex = {
            enable_completion_statistics = false,
            enable_semantic_errors = false,
            jvm = {
                completionStatistics = false,
                debugInternalErrors = true,
                debugSemanticErrors = false,
                maxHeap = '2G',
                disableLwcTypeGeneration = true,
            },
        },
    },
    single_file_support = false,
}