-- /qompassai/lsp/symfony_ls.lua
-- Qompass AI Symfony Ls
---@source https://github.com/symfony/language-tools
---@type vim.lsp.Config
return {
    cmd = { 'symfony-lsp' },
    filetypes = {
        'php',
        'twig',
        'yaml',
        'json',
        'xml',
        'javascript',
        'typescript',
        'env',
    },
    root_markers = {
        'composer.json',
        '.git',
    },
    workspace_required = true,
    capabilities = {
        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true,
            },
        },
    },
    init_options = {
        phpCommand = {
            'php',
        },
        containerProjectRoot = '',
        consolePath = 'bin/console',
        environment = 'dev',
        debug = true,
        runtimeIndexing = true,
        projectRoots = {},
        trace = 'off',
    },
    settings = {
        symfonyLsp = {
            phpCommand = { 'php' },
            containerProjectRoot = '',
            consolePath = 'bin/console',
            environment = 'dev',
            debug = true,
            runtimeIndexing = true,
            projectRoots = {},
            translationDiagnostics = false,
        },
    },
    commands = {
        ['editor.action.showReferences'] = function(command, ctx)
            local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
            local arguments = command.arguments or {}
            local uri = arguments[1]
            local position = arguments[2]
            local references = arguments[3]
            if type(uri) ~= 'string' or type(position) ~= 'table' or type(references) ~= 'table' then
                vim.notify('Symfony Language Tools returned an invalid reference command.', vim.log.levels.ERROR)
                return
            end
            -- LuaLS cannot narrow lsp.LSPAny through type(); the check above
            -- establishes table-ness, so this cast only recovers the LSP
            -- object shape. Fields stay lsp.LSPAny until validated below.
            ---@cast position lsp.LSPObject
            local line, character = position.line, position.character
            if
                type(line) ~= 'number'
                or type(character) ~= 'number'
                or line % 1 ~= 0
                or character % 1 ~= 0
                or line < 0
                or character < 0
            then
                vim.notify('Symfony Language Tools returned an invalid position.', vim.log.levels.ERROR)
                return
            end
            -- The guard established non-negative integrals; math.tointeger does not
            -- exist on LuaJIT, so the guard above is the validation and this cast
            -- only recovers the integer type lsp.Position needs.
            local line_int = line --[[@as integer]]
            local character_int = character --[[@as integer]]
            ---@type lsp.Position
            local pos = { line = line_int, character = character_int }

            local items = vim.lsp.util.locations_to_items(references, client.offset_encoding)
            vim.fn.setqflist({}, ' ', {
                title = command.title,
                items = items,
                context = {
                    command = command,
                    bufnr = ctx.bufnr,
                },
            })
            vim.lsp.util.show_document({
                uri = uri,
                range = {
                    start = pos,
                    ['end'] = pos,
                },
            }, client.offset_encoding)
            vim.cmd('botright copen')
        end,
    },
}
