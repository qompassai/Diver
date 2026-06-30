-- /qompassai/Diver/lsp/powershell_es.lua
-- Qompass AI PowerShell LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
local uv = vim.uv or vim.uv
local function fs_stat(path)
    return path and uv.fs_stat(path) or nil
end
local function is_dir(path)
    local stat = fs_stat(path)
    return stat and stat.type == 'directory'
end
local function is_file(path)
    local stat = fs_stat(path)
    return stat and stat.type == 'file'
end
local function exepath(cmd)
    local p = vim.fn.exepath(cmd)
    return (p and p ~= '') and p or nil
end
local function first_existing(paths, predicate)
    for _, path in ipairs(paths) do
        if predicate(path) then
            return path
        end
    end
    return nil
end
local function find_pwsh()
    local candidates = {
        exepath('pwsh'),
        exepath('powershell'),
        '/data/data/com.termux/files/usr/bin/pwsh',
        '/data/data/com.termux/files/usr/bin/powershell',
        '/usr/bin/pwsh',
        '/usr/local/bin/pwsh',
        '/run/current-system/sw/bin/pwsh',
        '/nix/var/nix/profiles/default/bin/pwsh',
    }
    local pwsh = first_existing(candidates, is_file)
    if pwsh then
        return pwsh
    end
    vim.notify('pwsh not found on PATH; install PowerShell 7+ or add pwsh to PATH', vim.log.levels.ERROR)
    return 'pwsh'
end
local function candidate_bundle_roots()
    local data = vim.fn.stdpath('data')
    local home = vim.env.HOME or ''
    local xdg_data = vim.env.XDG_DATA_HOME or (home ~= '' and (home .. '/.local/share') or nil)
    local termux_prefix = vim.env.PREFIX or '/data/data/com.termux/files/usr'
    return {
        '/opt/powershell-editor-services',
        data .. '/mason/packages/powershell-editor-services',
        data .. '/lazy/powershell-editor-services',
        xdg_data and (xdg_data .. '/powershell-editor-services') or nil,
        '/usr/share/powershell-editor-services',
        '/usr/local/share/powershell-editor-services',
        termux_prefix .. '/opt/powershell-editor-services',
        termux_prefix .. '/share/powershell-editor-services',
        '/data/data/com.termux/files/usr/opt/powershell-editor-services',
        '/data/data/com.termux/files/usr/share/powershell-editor-services',
        '/nix/store',
    }
end
local function find_pses_bundle()
    local roots = candidate_bundle_roots()
    for _, root in ipairs(roots) do
        if root and root ~= '/nix/store' then
            local start_script = root .. '/PowerShellEditorServices/Start-EditorServices.ps1'
            if is_dir(root) and is_file(start_script) then
                return root, start_script
            end
        end
    end
    if is_dir('/nix/store') then
        local matches = vim.fn.glob('/nix/store/*powershell-editor-services*', false, true)
        for _, root in ipairs(matches) do
            local start_script = root .. '/PowerShellEditorServices/Start-EditorServices.ps1'
            if is_dir(root) and is_file(start_script) then
                return root, start_script
            end
        end
    end
    local fallback = '/opt/powershell-editor-services'
    vim.notify('PowerShell Editor Services not found in any known location', vim.log.levels.ERROR)
    return fallback, fallback .. '/PowerShellEditorServices/Start-EditorServices.ps1'
end
local function config_dir()
    return vim.env.XDG_CONFIG_HOME or ((vim.env.HOME or '') .. '/.config')
end
local pwsh = find_pwsh()
local bundle_path, start_script = find_pses_bundle()
local session_path = vim.fs.joinpath(vim.fn.stdpath('cache'), 'pses_session.json')
local script_analyzer_settings = vim.fs.joinpath(config_dir(), 'powershell', 'ScriptAnalyzerSettings.psd1')
return ---@type vim.lsp.Config
{
    cmd = {
        pwsh,
        '-NoLogo',
        '-NoProfile',
        '-Command',
        string.format(
            [[& '%s' -BundledModulesPath '%s' -LogLevel Normal -HostName 'Neovim' -HostProfileId 'Neovim' -HostVersion '0.12.0' -SessionDetailsPath '%s' -Stdio]],
            start_script,
            bundle_path,
            session_path
        ),
    },
    filetypes = {
        'ps1',
        'psm1',
        'psd1',
    },
    root_markers = {
        'PSScriptAnalyzerSettings.psd1',
        '.editorconfig',
        '.git',
    },
    on_attach = function(client, bufnr)
        require('config.core.lsp').on_attach(client, bufnr)

        if client.server_capabilities and client.server_capabilities.documentFormattingProvider then
            local group = vim.api.nvim_create_augroup('PowerShell', { clear = false })
            vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
            vim.api.nvim_create_autocmd('BufWritePre', {
                group = group,
                buffer = bufnr,
                callback = function()
                    vim.lsp.buf.format({
                        bufnr = bufnr,
                        async = false,
                        filter = function(c)
                            return c.name == client.name
                        end,
                    })
                end,
            })
        end
    end,
    settings = {
        powershell = {
            codeFormatting = {
                AutoCorrectAliases = true,
                ExpandShortcut = true,
                Preset = 'Allman',
                TrimWhitespaceAroundPipe = true,
                UseCorrectCasing = true,
                WhitespaceAfterSeparator = true,
            },
            diagnostics = {
                enable = true,
                severity = {
                    MissingImport = 'Warning',
                    UnusedVariable = 'Hint',
                },
            },
            scriptAnalysis = {
                enable = true,
                settingsPath = script_analyzer_settings,
            },
            telemetry = {
                enable = false,
            },
        },
    },
}
