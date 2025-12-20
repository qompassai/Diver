-- /qompassai/Diver/lsp/ts_ls.lua
-- Qompass AI Typescript LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'typescript-language-server',
    },
    filetypes = { ---@type string[]
        'javascript',
        'javascript.jsx',
        'javascriptreact',
        'typescript',
        'typescript.tsx',
        'typescriptreact',
    },
    init_options = {
        hostInfo = 'neovim',
    },
    preferences = {
        allowTextChangesInNewFiles = true,
        disableSuggestions = false,
        includeAutomaticOptionalChainCompletions = true,
        includeCompletionsForModuleExports = true,
        includeCompletionsForImportStatements = true,
        includeCompletionsWithClassMemberSnippets = true,
        includeCompletionsWithInsertText = true,
        includeCompletionsWithSnippetText = true,
        includeInlayParameterNameHints = 'all',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayEnumMemberValueHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        quotePreference = 'single',
    },
    tsserver = {
        log = 'verbose',
    },
    root_markers = {
        '.git',
        'jsconfig.json',
        'package.json',
        'tsconfig.json',
    },
    handlers = {
        ---@param result { textDocument: lsp.TextDocumentIdentifier, position: lsp.Position }
        ---@return nil|string[]
        ['_typescript.rename'] = function(_, result, ctx) ---@param ctx lsp.HandlerContext
            local Client = assert(vim.lsp.get_client_by_id(ctx.client_id)) ---@type vim.lsp.Client
            vim.lsp.util.show_document({
                uri = result.textDocument.uri,
                range = {
                    start = result.position,
                    ['end'] = result.position,
                },
            }, Client.offset_encoding)
            vim.lsp.buf.rename()
            return vim.NIL
        end,
    },
    commands = {
        ---@param command lsp.Command
        ---@return nil
        ['editor.action.showReferences'] = function(command, ctx) ---@param ctx { client_id: integer, bufnr: integer }
            local Client = assert(vim.lsp.get_client_by_id(ctx.client_id)) ---@type vim.lsp.Client
            local file_uri, position, references = unpack(command.arguments)
            local quickfix_items = vim.lsp.util.locations_to_items(references --[[@as any]], Client.offset_encoding) ---@type string[]
            vim.fn.setqflist({}, ' ', {
                title = command.title,
                items = quickfix_items,
                context = {
                    command = command,
                    bufnr = ctx.bufnr,
                },
            })
            vim.lsp.util.show_document({
                uri = file_uri --[[@as string]],
                range = {
                    start = position --[[@as lsp.Position]],
                    ['end'] = position --[[@as lsp.Position]],
                },
            }, Client.offset_encoding)
            ---@diagnostic enable: assign-type-mismatch
            vim.cmd('botright copen')
        end,
    },
    on_attach = function(Client, bufnr)
        vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptSourceAction', function()
            local source_actions = vim.tbl_filter(function(action) ---@type string[]
                return vim.startswith(action, 'source.')
            end, Client.server_capabilities.codeActionProvider.codeActionKinds)
            vim.lsp.buf.code_action({
                context = {
                    only = source_actions,
                    diagnostics = {},
                },
            })
        end, {})
        vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptGoToSourceDefinition', function()
            local win = vim.api.nvim_get_current_win()
            local params = vim.lsp.util.make_position_params(win, Client.offset_encoding) ---@type lsp.TextDocumentPositionParams
            Client:exec_cmd({
                command = '_typescript.goToSourceDefinition',
                title = 'Go to source definition',
                arguments = { params.textDocument.uri, params.position },
            }, { bufnr = bufnr }, function(err, result)
                if err then
                    vim.echo('Go to source definition failed: ' .. err.message, vim.log.levels.ERROR)
                    return
                end
                if not result or vim.tbl_isempty(result) then
                    vim.echo('No source definition found', vim.log.levels.INFO)
                    return
                end
                vim.lsp.util.show_document(result[1], Client.offset_encoding, { focus = true })
            end)
        end, { desc = 'Go to source definition' })
    end,
}
