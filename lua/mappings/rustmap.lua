-- /Diver/lua/mappings/rustmap.lua
local M = {}
function M.setup_rustmap()
    local group = vim.api.nvim_create_augroup("RustMappings", {clear = true})
    vim.api.nvim_create_autocmd("FileType", {
        pattern = {"rust", "toml"},
        group = group,
        once = true,
        callback = function(args)
            if not vim.api.nvim_buf_is_loaded(args.buf) then return end
            local bufnr = args.buf
            local filetype = vim.bo[bufnr].filetype
            if not vim.b[bufnr].rustmap_registered then
                if filetype == "toml" then
                    require("which-key").register({
                        ["<leader>r"] = {name = "+crates"}
                    }, {buffer = bufnr})
                elseif filetype == "rust" then
                    require("which-key").register({
                        ["<leader>r"] = {name = "+rust"},
                        ["<leader>t"] = {name = "+toggle"}
                    }, {buffer = bufnr})
                end
                vim.b[bufnr].rustmap_registered = true
            end
            local map = vim.keymap.set
            local opts = {noremap = true, silent = true, buffer = bufnr}
            if filetype == "toml" then
                local ok, crates = pcall(require, "crates")
                if ok then
                    map("n", "<leader>rod", crates.open_documentation,
                        vim.tbl_extend("force", opts,
                                       {desc = "[r]ust [o]pen [d]ocumentation"}))
                    map("n", "<leader>rcf", crates.show_features,
                        vim.tbl_extend("force", opts,
                                       {desc = "[r]ust [c]rate [f]eatures"}))
                    map("n", "<leader>rci", crates.open_crates_io,
                        vim.tbl_extend("force", opts,
                                       {desc = "[r]ust [c]rates [i]o"}))
                    map("n", "<leader>rch", crates.open_homepage,
                        vim.tbl_extend("force", opts,
                                       {desc = "[r]ust [c]rate [h]omepage"}))
                    map("n", "<leader>rcr", crates.reload, vim.tbl_extend(
                            "force", opts, {desc = "[r]ust [c]rate [r]eload"}))
                    map("n", "<leader>rct", crates.toggle, vim.tbl_extend(
                            "force", opts, {desc = "[r]ust [c]rate [t]oggle"}))
                    map("n", "<leader>rcu", crates.update_crate, vim.tbl_extend(
                            "force", opts, {desc = "[r]ust [c]rate [u]pdate"}))
                    map("n", "<leader>rcU", crates.update_all_crates,
                        vim.tbl_extend("force", opts,
                                       {desc = "[r]ust [c]rate update [U]all"}))
                    map("n", "<leader>rca", crates.upgrade_crate,
                        vim.tbl_extend("force", opts,
                                       {desc = "[r]ust [c]rate upgrade [a]ll"}))
                    map("n", "<leader>rcA", crates.upgrade_all_crates,
                        vim.tbl_extend("force", opts,
                                       {desc = "[r]ust [c]rate upgrade [A]ll"}))
                end
            elseif filetype == "rust" then
                map("n", "<space>ca", vim.lsp.buf.code_action,
                    vim.tbl_extend("force", opts, {desc = "Code actions"}))
                map("n", "gD", vim.lsp.buf.declaration,
                    vim.tbl_extend("force", opts, {desc = "Go to declaration"}))
                map("n", "gd", vim.lsp.buf.definition,
                    vim.tbl_extend("force", opts, {desc = "Go to definition"}))
                map("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend(
                        "force", opts, {desc = "Go to implementation"}))
                map("n", "gr", vim.lsp.buf.references,
                    vim.tbl_extend("force", opts, {desc = "Show references"}))
                map("n", "sh", vim.lsp.buf.hover,
                    vim.tbl_extend("force", opts, {desc = "Hover info"}))
                map("n", "<space>rn", vim.lsp.buf.rename,
                    vim.tbl_extend("force", opts, {desc = "Rename symbol"}))
                map("n", "<C-k>", vim.lsp.buf.signature_help,
                    vim.tbl_extend("force", opts, {desc = "Signature help"}))
                map("n", "<space>D", vim.lsp.buf.type_definition,
                    vim.tbl_extend("force", opts, {desc = "Type definition"}))
                map("n", "<leader>ret", "<cmd>RustExpandMacro<CR>",
                    vim.tbl_extend("force", opts, {desc = "Expand macro"}))
                map("n", "<leader>rp", "<cmd>RustParentModule<CR>",
                    vim.tbl_extend("force", opts, {desc = "Parent module"}))
                map("n", "<leader>rc", "<cmd>RustOpenCargo<CR>",
                    vim.tbl_extend("force", opts, {desc = "Open Cargo.toml"}))
                map("n", "<leader>rd", "<cmd>RustDebuggables<CR>",
                    vim.tbl_extend("force", opts, {desc = "Debuggables"}))
                map("n", "<leader>rr", "<cmd>RustRunnables<CR>",
                    vim.tbl_extend("force", opts, {desc = "Runnables"}))
                map("n", "<leader>tc", function() end, vim.tbl_extend("force",
                                                                      opts, {
                    desc = "Toggle comment continuation"
                }))
            end
        end
    })
end
return M
