-- /qompassai/Diver/lsp/roslyn_ls.lua
-- Qompass AI Roslyn LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local group = vim.api.nvim_create_augroup('lspconfig.roslyn_ls', {
    clear = true,
})
---@param client vim.lsp.Client
---@return nil|string
local function on_init_sln(client, target) ---@param target string
    vim.echo('Initializing: ' .. target, vim.log.levels.TRACE, {
        title = 'roslyn_ls',
    }) ---@diagnostic disable-next-line: param-type-mismatch
    client:notify('solution/open', {
        solution = vim.uri_from_fname(target), ---@type string
    })
end
---@param client vim.lsp.Client
---@return nil|string
local function on_init_project(client, project_files) ---@param project_files string[]
    vim.echo('Initializing: projects', vim.log.levels.TRACE, { title = 'roslyn_ls' }) ---@diagnostic disable-next-line: param-type-mismatch
    client:notify('project/open', {
        projects = vim.tbl_map(function(file)
            return vim.uri_from_fname(file)
        end, project_files),
    })
end
local function refresh_diagnostics(client) ---@param client vim.lsp.Client
    for buf, _ in pairs(vim.lsp.get_client_by_id(client.id).attached_buffers) do
        if vim.api.nvim_buf_is_loaded(buf) then
            client:request(vim.lsp.protocol.Methods.textDocument_diagnostic, {
                textDocument = vim.lsp.util.make_text_document_params(buf),
            }, nil, buf)
        end
    end
end
local function roslyn_handlers() ---@return table<string, fun(err?: lsp.ResponseError, result: any, ctx: lsp.HandlerContext, config?: table):any>
    return {
        ['workspace/projectInitializationComplete'] = function(_, _, ctx)
            vim.echo('Roslyn project initialization complete', vim.log.levels.INFO, { title = 'roslyn_ls' })
            local client = assert(vim.lsp.get_client_by_id(ctx.client_id)) ---@type vim.lsp.Client
            refresh_diagnostics(client)
            return vim.NIL
        end,
        ['workspace/_roslyn_projectNeedsRestore'] = function(_, result, ctx)
            local client = assert(vim.lsp.get_client_by_id(ctx.client_id)) ---@type vim.lsp.Client
            ---@diagnostic disable-next-line: param-type-mismatch
            client:request('workspace/_roslyn_restore', result, function(err, response)
                if err then
                    vim.echo(err.message, vim.log.levels.ERROR, {
                        title = 'roslyn_ls',
                    })
                end
                if response then
                    for _, v in ipairs(response) do
                        vim.echo(v.message, vim.log.levels.INFO, {
                            title = 'roslyn_ls',
                        })
                    end
                end
            end)
            return vim.NIL
        end,
        ['razor/provideDynamicFileInfo'] = function(_, _, _)
            vim.echo('Razor is not supported.\nPlease use https://github.com/tris203/rzls.nvim', vim.log.levels.WARN, {
                title = 'roslyn_ls',
            })
            return vim.NIL
        end,
    }
end
return ---@type vim.lsp.Config
{
    name = 'roslyn_ls',
    offset_encoding = 'utf-8',
    cmd = {
        'Microsoft.CodeAnalysis.LanguageServer',
        '--logLevel',
        'Information',
        '--extensionLogDirectory',
        '--stdio',
    },
    filetypes = {
        'cs',
    },
    handlers = roslyn_handlers(),
    capabilities = {
        textDocument = {
            diagnostic = {
                dynamicRegistration = true,
            },
        },
    },
    commands = { ---@param command lsp.Command
        ['roslyn.client.completionComplexEdit'] = function(command, ctx) ---@param ctx lsp.HandlerContext
            local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
            local args = command.arguments or {}
            local uri, edit = args[1], args[2]
            ---@diagnostic disable: undefined-field
            if uri and edit and edit.newText and edit.range then
                local workspace_edit = {
                    changes = {
                        [uri.uri] = {
                            {
                                range = edit.range,
                                newText = edit.newText,
                            },
                        },
                    },
                }
                vim.lsp.util.apply_workspace_edit(workspace_edit, client.offset_encoding)
            else
                vim.echo(
                    'roslyn_ls: completionComplexEdit args not understood: ' .. vim.inspect(args),
                    vim.log.levels.WARN
                )
            end
            ---@diagnostic enable: undefined-field
        end,
    },
    settings = { ---@type table<string, table>
        ['csharp|background_analysis'] = {
            dotnet_analyzer_diagnostics_scope = 'fullSolution',
            dotnet_compiler_diagnostics_scope = 'fullSolution',
        },
        ['csharp|inlay_hints'] = { ---@type boolean[]
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
            dotnet_enable_inlay_hints_for_indexer_parameters = true,
            dotnet_enable_inlay_hints_for_literal_parameters = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
            dotnet_enable_inlay_hints_for_other_parameters = true,
            dotnet_enable_inlay_hints_for_parameters = true,
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
        },
        ['csharp|symbol_search'] = { ---@type boolean[]
            dotnet_search_reference_assemblies = true,
        },
        ['csharp|completion'] = {
            dotnet_show_name_completion_suggestions = true,
            dotnet_show_completion_items_from_unimported_namespaces = true,
            dotnet_provide_regex_completions = true,
        },
        ['csharp|code_lens'] = {
            dotnet_enable_references_code_lens = true,
        },
    },
    ---@param bufnr integer
    root_dir = function(bufnr, cb) ---@param cb fun(root: string)
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if not bufname:match('^' .. vim.fs.joinpath('/tmp/MetadataAsSource/')) then
            local root_dir = vim.fs(bufnr, function(fname, _) ---@type string
                return fname:match('%.sln[x]?$') ~= nil
            end)
            if not root_dir then
                root_dir = vim.fs(bufnr, function(fname, _) ---@type string
                    return fname:match('%.csproj$') ~= nil
                end)
            end
            if root_dir then
                cb(root_dir)
            end
        end
    end,
    on_init = {
        function(client)
            for entry, type in vim.fs(client.config.root_dir, '.git') do
                if type == 'file' and (vim.endswith(entry, '.sln') or vim.endswith(entry, '.slnx')) then
                    on_init_sln(client, vim.fs.joinpath(client.config.root_dir, entry))
                    return
                end
            end
            for entry, type in vim.fs(client.config.root_dir, 'git') do
                if type == 'file' and vim.endswith(entry, '.csproj') then
                    on_init_project(client, { vim.fs.joinpath(client.config.root_dir, entry) })
                end
            end
        end,
    },
    ---@param client vim.lsp.Client
    on_attach = function(client, bufnr) ---@param bufnr integer
        if vim.api.nvim_get_autocmds({ buffer = bufnr, group = group })[1] then
            return
        end
        vim.api.nvim_create_autocmd({
            'BufWritePost',
            'InsertLeave',
        }, {
            group = group,
            buffer = bufnr,
            callback = function()
                refresh_diagnostics(client)
            end,
            desc = 'roslyn_ls: refresh diagnostics',
        })
    end,
}
