-- pymap.lua
local M = {}
function M.setup_pymap()
    local map = vim.keymap.set
    local opts = {noremap = true, silent = true}
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
            local bufnr = ev.buf
            local bufopts = {noremap = true, silent = true, buffer = bufnr}
            -- Nerd Translate Legend:

            -- 'Black': A Python code formatter that automatically formats Python code to conform to the PEP 8 style guide.
            --   Example: Like an auto-formatter that ensures consistent code style.
            -- 'Code Action': Suggestions provided by LSP to refactor, add missing imports, or fix code issues.
            --   Example: Like spellcheck for code; it suggests fixes when you have mistakes.
            -- 'Conda': A package and environment management system for Python that allows creating isolated environments.
            --   Example: Like having separate rooms for different projects, each with their own set of tools.
            -- 'DAP': Debug Adapter Protocol, a standardized way to debug programs across different editors and languages.
            --   Example: Similar to having a universal remote control that works with any TV.
            -- 'Definition': The place where a function, class, or variable is defined with its implementation.
            --   Example: The blueprint that shows exactly how something is built and works.
            -- 'Implementation': The actual code where a function or method is defined. It differs from a declaration as it contains logic.
            --   Example: If you declare a function in a header, its implementation contains the actual steps it performs.
            -- 'isort': A Python utility that sorts imports alphabetically and automatically separates them into sections.
            --   Example: Like organizing books on a shelf by category and then alphabetically.
            -- 'Jupyter': An interactive computing environment that enables users to create notebook documents with live code.
            --   Example: Like a digital lab notebook where you can write notes and run experiments.
            -- 'Lint': The process of analyzing code for potential errors, bugs, stylistic errors, and suspicious constructs.
            --   Example: Like having a proofreader check your writing for grammar and style issues.
            -- 'LSP': Language Server Protocol, a tool that provides intelligent code features like autocompletion, go-to-definition, and diagnostics.
            --   Example: Helps your editor understand code better, like suggesting how to finish typing a function name.
            -- 'Poetry': A tool for dependency management and packaging in Python that makes project management easier.
            --   Example: Like a recipe book that manages all ingredients and cooking steps for you.
            -- 'Pytest': A testing framework for Python that makes it easy to write simple and scalable test cases.
            --   Example: Like a quality control system that checks if your product works as expected.

            -- 'References': Shows all occurrences of a symbol across the codebase, helping understand where and how it's used.
            --   Example: Like finding every mention of a character's name in a book to track their appearances.
            ----------------------------------------------------------------------------------------------------------------
            -- Python Debugging Keymaps
            map("n", "<leader>dpm",
                function() require("dap-python").test_method() end,
                vim.tbl_extend("force", bufopts,
                               {desc = "[d]ebug [p]ython [m]ethod"}))

            map("n", "<leader>dpc",
                function() require("dap-python").test_class() end,
                vim.tbl_extend("force", opts,
                               {desc = "[d]ebug [p]ython [c]lass"}))

            map("n", "<leader>dps",
                function() require("dap-python").debug_selection() end,
                vim.tbl_extend("force", opts,
                               {desc = "[d]ebug [p]ython [s]election"}))

            map("n", "<leader>pd", vim.lsp.buf.definition, vim.tbl_extend(
                    "force", opts, {desc = "🐍 [p]ython go to [d]efinition"}))
            map("n", "<leader>pr", vim.lsp.buf.references, vim.tbl_extend(
                    "force", opts, {desc = "🐍 [p]ython find [r]eferences"}))
            map("n", "<leader>pgi", vim.lsp.buf.implementation, vim.tbl_extend(
                    "force", opts, {desc = "🐍 [p]ython [g]o to [i]mplementation"}))
            map("n", "<leader>pl", function() vim.cmd("PythonLint") end,
                vim.tbl_extend("force", opts, {desc = "[p]ython [l]int"}))

            -- Python Testing Keymaps
            map("n", "<leader>ptF", function() vim.cmd("PyTestFile") end,
                vim.tbl_extend("force", opts, {desc = "🐍 [p]ython [t]est [F]ile"}))
            map("n", "<leader>ptf", function() vim.cmd("PyTestFunc") end,
                vim.tbl_extend("force", opts, {desc = "🐍 [p]ython [t]est [f]unction"}))

            -- Python Project Management Keymaps
            map("n", "<leader>ppi", function()
                vim.cmd("PoetryInstall")
            end, vim.tbl_extend("force", opts, {desc = "🐍 [p]ython [p]oetry [i]nstall"}))
            map("n", "<leader>pu", function() vim.cmd("PoetryUpdate") end,
                vim.tbl_extend("force", opts, {desc = "🐍 [p]ython [p]oetry Update"}))

            -- Jupyter (Iron.nvim, Jupynium, Molten.nvim, Otter.nvim) Keymaps

            -- Attach to a running Jupyter kernel.
            map("n", "<leader>ja", "<cmd>JupyniumAttachToRunningNotebook<CR>",
                vim.tbl_extend("force", bufopts, {
                desc = "[j]upyter [a]ttach to running jupyter notebook"
            }))

            map("n", "<leader>jc", "<cmd>IronReplClear<CR>", vim.tbl_extend(
                    "force", bufopts, {desc = "[j]upyter [c]lear REPL output"}))
            -- In normal mode, press 'Space' + 'j' + 'c' to clear the current REPL output.

            map("n", "<leader>jel",
                function() vim.cmd("MoltenEvaluateLine") end, vim.tbl_extend(
                    "force", opts, {desc = "[j]upter [e]valuate [l]ine"}))

            map("v", "<leader>jev",
                function() vim.cmd("MoltenEvaluateVisual") end,
                vim.tbl_extend("force", opts, {
                desc = "[j]upyter [e]valuate [v]isual selection"
            }))
            -- Evaluate the selected visual code with Molten.

            -- Interrupt the current Jupyter kernel.
            map("n", "<leader>ji", "<cmd>JupyniumKernelInterrupt<CR>",
                vim.tbl_extend("force", bufopts,
                               {desc = "[j]upyter [i]nterrupt kernel"}))

            -- Toggle Jupyter Lab terminal using toggleterm
            map("n", "<leader>jl", function()
                require("toggleterm.terminal").Terminal:new({
                    cmd = "jupyter lab",
                    direction = "float"
                }):toggle()
            end, vim.tbl_extend("force", bufopts,
                                {desc = "start [j]upyter [l]ab terminal"}))
            -- In normal mode, press 'Space' + 'j' + 'l' to start Jupyter lab via Toggleterm plugin.

            map("n", "<leader>jrc",
                function() vim.cmd("MoltenReevaluateCell") end, vim.tbl_extend(
                    "force", opts, {desc = "[j]upyter [r]evaluate [c]ell"}))
            -- Reevaluate the current cell with Molten.

            -- Iron.nvim --
            map("n", "<leader>jri", "<cmd>IronRepl<CR>", vim.tbl_extend("force",
                                                                        bufopts,
                                                                        {
                desc = "[j]upyter [r]epl [i]python"
            }))
            -- In normal mode, press 'Space' + 'j' + 'r' 'i' + Open an IPython REPL.

            map({"n", "v"}, "<leader>jrs", "<cmd>IronReplSend<CR>",
                vim.tbl_extend("force", bufopts,
                               {desc = "[j]upyter [r]epl code"}))
            -- In normal mode, press 'Space' + 'j' + 'r' + 's' to send code to REPL.

            -- Molten.nvim mappings
            map("n", "<leader>jse", ":MoltenInit<CR>", vim.tbl_extend("force",
                                                                      bufopts, {
                desc = "[j]upyter [s]tart [e]nvironment"
            }))
            -- Initialize Molten environment.

            map("n", "<leader>jsk", "<cmd>JupyniumStartAndAttach<CR>",
                vim.tbl_extend("force", bufopts,
                               {desc = "[j]upyter [s]tart [k]ernel"}))
            -- Start a Jupyter kernel and attach to it.

            -- Otter.nvim output panel
            map("n", "<leader>top", "<cmd>OtterToggleOutputPanel<CR>",
                vim.tbl_extend("force", bufopts,
                               {desc = "🦦 [j]upter [o]utput toggle panel"}))
            -- Toggle the Otter output panel.

            -- Vim-Slime mappings
            -- Mark the terminal for Slime.
            map("n", "<leader>jtm", ":lua vim.fn['slime#mark_terminal']()<CR>",
                vim.tbl_extend("force", bufopts,
                               {desc = "[j]upyter [t]erminal [m]ark"}))

            -- Set the terminal for Slime.
            map("n", "<leader>jts", ":lua vim.fn['slime#set_terminal']()<CR>",
                vim.tbl_extend("force", bufopts,
                               {desc = "[j]upyter [t]erminal [s]et"}))

            -- UV.nvim Keymaps

            map("n", "<leader>ur", "<cmd>UVRunFile<CR>",
                vim.tbl_extend("force", opts, {desc = "UV Run File"}))
            map("v", "<leader>us", "<cmd>UVRunSelection<CR>",
                vim.tbl_extend("force", opts, {desc = "UV Run Selection"}))
            map("n", "<leader>uf", "<cmd>UVRunFunction<CR>",
                vim.tbl_extend("force", opts, {desc = "UV Run Function"}))
            map("n", "<leader>ue", "<cmd>UVEnvironment<CR>",
                vim.tbl_extend("force", opts, {desc = "UV Environment"}))
            map("n", "<leader>ui", "<cmd>UVInit<CR>",
                vim.tbl_extend("force", opts, {desc = "UV Initialize"}))
            map("n", "<leader>ua", "<cmd>UVAdd<CR>",
                vim.tbl_extend("force", opts, {desc = "UV Add Package"}))
            map("n", "<leader>ud", "<cmd>UVRemove<CR>",
                vim.tbl_extend("force", opts, {desc = "UV Remove Package"}))
            map("n", "<leader>uc", "<cmd>UVSync<CR>",
                vim.tbl_extend("force", opts, {desc = "UV Sync Packages"}))
        end
    })
end
return M
