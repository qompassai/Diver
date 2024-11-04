local M = {}

function M.defaults()
    local lspconfig = require "lspconfig"
    local cmp_nvim_lsp = require('cmp_nvim_lsp')
    local on_attach = M.on_attach
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)

    local luasnip = require("luasnip")

    local cmp = require("cmp")
    cmp.setup({
        snippet = {
            expand = function(args)
                luasnip.lsp_expand(args.body)
            end,
        },
        mapping = cmp.mapping.preset.insert({
            ['<C-b>'] = cmp.mapping.scroll_docs(-4),
            ['<C-f>'] = cmp.mapping.scroll_docs(4),
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<C-e>'] = cmp.mapping.abort(),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
            { name = 'nvim_lsp' },
            { name = 'luasnip' },
        }, {
            { name = 'buffer' },
        })
    })

    local servers = {
        "solargraph",
        "ts_ls",
        "gopls",
        "jdtls",
        "clangd",
        "dockerls",
        "graphql",
        "html",
        "sqlls",
        "lua_ls",
        "jsonls",
        "yamlls",
        "matlab_ls",
        "r_language_server",
        "zls",
    }

    for _, lsp in ipairs(servers) do
        if lspconfig[lsp] then
            lspconfig[lsp].setup {
                on_attach = M.on_attach,
                capabilities = capabilities,
            }
        else
            vim.notify("LSP: Server configuration for " .. lsp .. " not found!", vim.log.levels.WARN)
        end
    end
    lspconfig.lua_ls.setup {
        capabilities = capabilities,
        on_init = function(client)
            if client.workspace_folders then
                local path = client.workspace_folders[1].name
                if vim.loop.fs_stat(path .. '/.luarc.json') or vim.loop.fs_stat(path .. '/.luarc.jsonc') then
                    return
                end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
                runtime = {
                    version = 'LuaJIT',
                },
                workspace = {
                    checkThirdParty = true,
                    library = {
                        vim.env.VIMRUNTIME,
                    }
                }
            })
            client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
            return true
        end,
        settings = {
            Lua = {
                diagnostics = {
                    globals = { "vim" }
                },
                workspace = {
                    library = vim.api.nvim_get_runtime_file("", true),
                    maxPreload = 1000,
                    preloadFileSize = 200
                },
                telemetry = {
                    enable = false,
                },
            }
        }
    }
    lspconfig.zls.setup {
        on_attach = on_attach,
        capabilities = capabilities,
        filetypes = { "zig" },
        root_dir = lspconfig.util.root_pattern("zls.json", ".git"),
    }
end

function M.capabilities()
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    local cmp_nvim_lsp = require "cmp_nvim_lsp"
    if cmp_nvim_lsp then
        capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
    end
    return capabilities
end


return M
