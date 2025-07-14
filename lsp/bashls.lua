-- /qompassai/Diver/lsp/bashls.lua
-- Qompass AI Bashls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['bashls'] = {
    cmd = { "bash-language-server", "start" },
    filetypes = { "sh", "bash" },
    handlers = {
        ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" }),
        ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
    },
    root_markers = { ".git", ".bashrc", ".bash_profile", ".profile" },
    settings = {
        bashIde = {
            globPattern = "**/*@(.sh|.inc|.bash|.command)",
            maxNumberOfProblems = 100,
            shellcheck = {
                enable = true,
                executablePath = "shellcheck",
                severity = {
                    error = "error",
                    warning = "warning",
                    info = "info",
                    style = "info",
                },
            },
            completion = {
                enabled = true,
                includeDirs = {},
            },
            diagnostics = {
                enabled = true,
            },
        },
    },
    capabilities = require("blink.cmp").get_lsp_capabilities(),
    on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        if client.server_capabilities.inlayHintProvider and type(vim.lsp.inlay_hint) == "function" then
            vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
            vim.lsp.inlay_hint(bufnr, true)
        end
        vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            callback = function() vim.lsp.buf.format({ async = false }) end,
        })
    end,
    flags = {
        debounce_text_changes = 150,
    },
    single_file_support = true,
}
