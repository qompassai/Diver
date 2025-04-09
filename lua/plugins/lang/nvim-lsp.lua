return {
	"neovim/nvim-lspconfig",
	lazy = false,
	event = { "BufReadPre", "BufNewFile" },
	cmd = { "LspInfo", "LspInstall", "LspUninstall" },
	dependencies = {
		"williamboman/mason.nvim",
		"nvimtools/none-ls.nvim",
		"williamboman/mason-lspconfig.nvim",
		"hrsh7th/cmp-nvim-lsp",
		"mfussenegger/nvim-dap",
		"mfussenegger/nvim-dap-python",
		"leoluz/nvim-dap-go",
		"mrcjkb/rustaceanvim",
		"igorlfs/nvim-dap-view",
		{
			{
				"rcarriga/nvim-dap-ui",
				dependencies = {
					"mfussenegger/nvim-dap",
					"nvim-neotest/nvim-nio",
				},
				config = function()
					require("dapui").setup()
				end,
			}

		},
		config = function()
			-- Setup Mason and Devicons
			require("mason").setup()
			require("mason-lspconfig").setup({})
			require("nvim-web-devicons").setup({ default = true })

			-- Setup DAP and dap-view
			local dap = require("dap")
			local dv = require("dap-view")
			dv.setup({})

			-- Auto toggle dap-view
			for _, event in ipairs({ "attach", "launch" }) do
				dap.listeners.before[event]["dap-view-config"] = function() dv.open() end
			end
			for _, event in ipairs({ "event_terminated", "event_exited" }) do
				dap.listeners.before[event]["dap-view-config"] = function() dv.close() end
			end

			vim.keymap.set("n", "<leader>do", dv.toggle, { desc = "Debug: Toggle View" })
			vim.keymap.set("n", "<leader>dw", dv.add_expr, { desc = "Debug: Add Watch" })

			-- Setup DAP UI
			local dapui = require("dapui")
			dapui.setup()
			dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
			dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
			dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

			-- Go Debugging
			require("dap-go").setup({
				dap_configurations = {
					{
						type = "go",
						name = "Debug with CGO",
						request = "launch",
						program = "${file}",
						buildFlags = "-tags=cgo",
						env = { CGO_ENABLED = "1" },
					},
				},
			})

			-- Python Debugging
			require("dap-python").setup("python")

			-- C/C++/Rust Debugging
			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				executable = {
					command = vim.fn.exepath("codelldb"),
					args = { "--port", "${port}" },
				},
			}

			-- JavaScript/TypeScript Debugging
			dap.adapters.node2 = {
				type = "executable",
				command = "node",
				args = { vim.fn.stdpath("data") .. "/mason/packages/node-debug2-adapter/out/src/nodeDebug.js" },
			}

			dap.configurations.javascript = {
				{
					name = "Launch",
					type = "node2",
					request = "launch",
					program = "${file}",
					cwd = vim.fn.getcwd(),
					sourceMaps = true,
					protocol = "inspector",
				},
			}
			dap.configurations.typescript = dap.configurations.javascript

			-- Keybindings
			vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: Continue" })
			vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step Over" })
			vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step Into" })
			vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: Step Out" })
			vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
			vim.keymap.set("n", "<leader>dB", function()
				dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
			end, { desc = "Debug: Conditional Breakpoint" })
			vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: Run Last Configuration" })
			vim.keymap.set("n", "<leader>do", dapui.toggle, { desc = "Debug: Toggle UI" })

			vim.env.CGO_ENABLED = "1"

			-- LSP Config
			local lspconfig = require("lspconfig")
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- Hyprland
			lspconfig.hyprls.setup({
				on_attach = function(_, bufnr)
					local opts = { noremap = true, silent = true }
					vim.api.nvim_buf_set_keymap(bufnr, "n", "gd",
						"<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
					vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>",
						opts)
					vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn",
						"<Cmd>lua vim.lsp.buf.rename()<CR>", opts)
					vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ca",
						"<Cmd>lua vim.lsp.buf.code_action()<CR>", opts)
				end,
				capabilities = capabilities,
			})

			-- Go

			lspconfig.gopls.setup({
				settings = {
					gopls = {
						buildFlags = { "-tags=cgo" },
						env = { CGO_ENABLED = "1" },
					},
				},
			})

			-- Lua
			lspconfig.lua_ls.setup({
				settings = {
					Lua = {
						diagnostics = {
							globals = { 'vim' },
						},
						workspace = {
							checkThirdParty = false,
							library = vim.api.nvim_get_runtime_file("", true),
						},
						format = {
							enable = true,
						},
					},
				},
				capabilities = capabilities,
			})

			-- Global LSP Defaults
			local attach_lsp = false
			lspconfig.util.default_config = vim.tbl_deep_extend("force", lspconfig.util.default_config, {
				flags = { debounce_text_changes = 250 },
				capabilities = capabilities,
				on_attach = function(client, bufnr)
					if not attach_lsp then return end
					local buf_name = vim.api.nvim_buf_get_name(bufnr)
					if not buf_name:match("2024%-%d+%.%d+%-%d+%.%d+%.md$") and client.supports_method("textDocument/formatting") then
						vim.api.nvim_create_autocmd("BufWritePre", {
							group = vim.api.nvim_create_augroup("LspFormatting",
								{ clear = true }),
							buffer = bufnr,
							callback = function() vim.lsp.buf.format({ async = false }) end,
						})
					end
				end,
			})

			-- Diagnostic UI
			vim.diagnostic.config({
				virtual_text = true,
				signs = true,
				underline = true,
				update_in_insert = true,
				severity_sort = true,
			})

			-- Helper for Mason LSP Paths
			local function get_lsp_cmd(package_name, executable_name)
				if vim.fn.executable(executable_name) == 1 then
					return executable_name
				end
				local mason_path = vim.fn.stdpath("data") ..
				    "/mason/packages/" .. package_name .. "/bin/" .. executable_name
				if vim.fn.filereadable(mason_path) == 1 then
					return mason_path
				end
				return nil
			end

			-- C/C++/LLVM --

			lspconfig.clangd.setup {
				capabilities = capabilities,
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--completion-style=detailed",
					"--function-arg-placeholders",
					"--fallback-style=llvm",
				},
				on_attach = function(_, bufnr)
					vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>sh",
						"<cmd>ClangdSwitchSourceHeader<cr>",
						{ noremap = true, silent = true })
					vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>si", "<cmd>ClangdSymbolInfo<cr>",
						{ noremap = true, silent = true })
				end,
				init_options = {
					usePlaceholders = true,
					completeUnimported = true,
					clangdFileStatus = true,
				},
			}
			-- Docker Compose LSP Configuration
			lspconfig.docker_compose_language_service.setup {
				capabilities = capabilities,
				cmd = { "docker-compose-langserver", "--stdio" },
				filetypes = { "yaml.docker-compose" },
				root_dir = lspconfig.util.root_pattern(
					"docker-compose.yml",
					"docker-compose.yaml",
					"compose.yml",
					"compose.yaml"
				),
				on_attach = function(client, bufnr)
					local opts = { noremap = true, silent = true, buffer = bufnr }
					vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
					vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
					vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)

					if client.server_capabilities.documentFormattingProvider then
						vim.api.nvim_create_autocmd("BufWritePre", {
							buffer = bufnr,
							callback = function()
								vim.lsp.buf.format({ bufnr = bufnr })
							end
						})
					end
				end,
				settings = {
					docker = {
						compose = {
							completion = {
								showAllSnippets = true,
							},
							formatting = {
								enabled = true,
							},
							diagnostics = {
								enabled = true,
								deprecatedKeys = "error",
								unusedKeys = "warning",
							},
							validation = {
								enabled = true,
							},
							hover = {
								enabled = true,
							},
							images = {
								hubLinks = true,
							}
						}
					}
				}
			}

			-- Docker/Dockerfile LSP Configuration
			lspconfig.dockerls.setup {
				capabilities = capabilities,
				on_attach = function(client, bufnr)
					local opts = { noremap = true, silent = true, buffer = bufnr }
					vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
					vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
					vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)

					if client.server_capabilities.documentFormattingProvider then
						vim.api.nvim_create_autocmd("BufWritePre", {
							buffer = bufnr,
							callback = function()
								vim.lsp.buf.format({ bufnr = bufnr })
							end
						})
					end
				end,
				filetypes = { "dockerfile", "Dockerfile", "Containerfile" },
				root_dir = lspconfig.util.root_pattern("Dockerfile", "Containerfile", ".dockerignore", "docker-compose.yml", "docker-compose.yaml"),
			}

			vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
				pattern = {
					"docker-compose*.yml",
					"docker-compose*.yaml",
					"compose*.yml",
					"compose*.yaml"
				},
				callback = function()
					vim.bo.filetype = "yaml.docker-compose"
				end
			})

			vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
				pattern = { "Containerfile", "*Containerfile*" },
				callback = function()
					vim.bo.filetype = "dockerfile"
				end
			})

			vim.api.nvim_create_user_command("DockerComposeValidate", function()
				vim.lsp.buf.command({
					command = "docker-compose.validate",
					arguments = { vim.fn.expand("%:p") }
				})
			end, { desc = "Validate Docker Compose file" })

			local null_ls_ok, null_ls = pcall(require, "null-ls")
			if null_ls_ok then
				null_ls.register(null_ls.builtins.diagnostics.hadolint.with({
					filetypes = { "dockerfile", "Dockerfile", "Containerfile", "yaml.docker-compose" },
				}))
			end

			-- Deno --
			lspconfig.denols.setup {
				capabilities = capabilities,
				cmd = { get_lsp_cmd("deno", "deno") },
				root_dir = lspconfig.util.root_pattern("deno.json", "deno.jsonc"),
				init_options = {
					enable = true,
					lint = true,
					unstable = true,
				},
				settings = {
					deno = {
						enable = true,
						lint = true,
						unstable = true,
					},
				},
				filetypes = {
					"typescript",
					"typescriptreact",
					"typescript.tsx",
					"javascript",
					"javascriptreact",
					"javascript.jsx",
				},
			}

			--Diagnosticls
			local enable_diagnosticls = false

			if enable_diagnosticls then
				require("lspconfig").diagnosticls.setup {
					autostart = false,
					filetypes = { "lua", "javascript", "typescript", "python" },
					init_options = {
						filetypes = {
							lua = "lua-format",
						},
						formatters = {
							["lua-format"] = {
								command = "lua-format",
								args = {
									"--indent-width=4",
									"--column-limit=130",
								},
							},
						},
						formatFiletypes = {
							lua = "lua-format",
						},
					},
				}
			end

			-- Go --

			-- Gopls
			lspconfig.gopls.setup {
				capabilities = capabilities,
				cmd = { get_lsp_cmd("gopls", "gopls") },
				settings = {
					gopls = {
						analyses = {
							unusedparams = true,
							shadow = true,
							fieldalignment = true,
							nilness = true,
						},
						staticcheck = true,
						gofumpt = true,
						usePlaceholders = true,
						completeUnimported = true,
						experimentalWorkspaceModule = true,
					},
				},
				on_attach = function(_, bufnr)
					-- Format on save
					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format({ bufnr = bufnr })
						end
					})
					-- Add keybindings here
				end,
				flags = {
					debounce_text_changes = 150,
				},
				init_options = {
					buildFlags = { "-tags=cgo" },
				},
			}

			-- HyprLS --

			lspconfig.hyprls.setup({
				on_attach = function(_, bufnr)
					local opts = { noremap = true, silent = true }
					vim.api.nvim_buf_set_keymap(bufnr, "n", "gd",
						"<Cmd>lua vim.lsp.buf.definition()<CR>",
						opts)
					vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>",
						opts)
					vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn",
						"<Cmd>lua vim.lsp.buf.rename()<CR>",
						opts)
					vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ca",
						"<Cmd>lua vim.lsp.buf.code_action()<CR>", opts)

					vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ds",
						"<cmd>lua vim.lsp.buf.document_symbol()<CR>", opts)

					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format({ bufnr = bufnr })
						end
					})
				end,
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
			})

			-- Java
			lspconfig.jdtls.setup {
				capabilities = capabilities,
				cmd = { get_lsp_cmd("jdtls", "jdtls") },
			}
			-- JSON --

			lspconfig.jsonls.setup {
				capabilities = capabilities,
				cmd = { get_lsp_cmd("vscode-json-languageserver", "vscode-json-languageserver") },
				commands = {
					Format = {
						function()
							vim.lsp.buf.range_formatting({}, { 0, 0 }, { vim.fn.line "$", 0 })
						end,
					},
				},
			}
			-- Lua --

			require("lspconfig").lua_ls.setup {
				cmd = { get_lsp_cmd("lua-language-server", "lua-language-server"), "-E" },
				capabilities = capabilities,
				settings = {
					Lua = {
						runtime = {
							version = (vim.fn.executable "luajit" == 1) and "LuaJIT" or "Lua 5.1",
							path = vim.split(package.path, ";"),
						},
						diagnostics = {
							globals = {
								"vim",
								"use",
								"require",
								"pcall",
								"pairs",
								"ipairs",
								"error",
								"assert",
								"print",
								"table",
								"string",
								"math",
								"os",
								"on_attach",
								"io",
								"debug",
								"package",
								"coroutine",
								"bit32",
								"utf8",
							},
							disable = { "missing-parameter", "lowercase-global", "mixed-type" },
						},
						severity = {
							["missing-parameter"] = "Warning",
						},
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
							maxPreload = 10000,
							preloadFileSize = 150,
							checkThirdParty = false,
						},
						telemetry = {
							enable = false,
						},
					},
				},
			}

			-- Metals (Scala)
			local metals = require("metals")

			local metals_config = metals.bare_config()
			metals_config.settings = {
				showImplicitArguments = true,
				superMethodLensesEnabled = true,
				showInferredType = true,
			}
			metals_config.capabilities = capabilities
			metals_config.on_attach = function(_, bufnr)
				local opts = { noremap = true, silent = true }
				vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>",
					opts)
				vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
				vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<Cmd>lua vim.lsp.buf.rename()<CR>",
					opts)
				vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ca",
					"<Cmd>lua vim.lsp.buf.code_action()<CR>", opts)
				vim.api.nvim_create_autocmd("BufWritePre", {
					buffer = bufnr,
					callback = function() vim.lsp.buf.format({ bufnr = bufnr }) end
				})
			end

			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "scala", "sbt", "java" },
				callback = function() metals.initialize_or_attach(metals_config) end,
			})
			-- Markdown --

			-- Marksman
			lspconfig.marksman.setup {
				capabilities = capabilities,
				cmd = { get_lsp_cmd("marksman", "marksman") },
				filetypes = { "markdown", "markdown.mdx" },
				root_dir = lspconfig.util.root_pattern(".git", ".marksman.toml"),
				settings = {
					marksman = {
						lint = {
							ignore = {
								"no-consecutive-blank-lines",
							},
						},
					},
				},
			}
			-- MATLAB
			lspconfig.matlab_ls.setup { capabilities = capabilities }
			--Python --

			--(Azure-CLI, Jupyter Lab/Hub, Pyenv, Python, PyPy)
			lspconfig.pyright.setup { capabilities = capabilities }
			lspconfig.pylsp.setup { capabilities = capabilities }
			-- R
			lspconfig.r_language_server.setup { capabilities = capabilities }
			-- Ruby
			lspconfig.solargraph.setup { capabilities = capabilities }
			-- TypeScript configuration combining ts_ls and tsserver features
			lspconfig.tsserver.setup {
				capabilities = capabilities,
				filetypes = {
					"typescript",
					"typescriptreact",
					"typescript.tsx",
					"javascript",
					"javascriptreact",
					"javascript.jsx",
				},
				root_dir = lspconfig.util.root_pattern("tsconfig.json", "jsconfig.json", ".git"),
				on_attach = function(client, bufnr)
					client.server_capabilities.documentFormattingProvider = false

					-- Add keybindings if needed
					-- vim.api.nvim_buf_set_keymap(bufnr, ...)

					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						callback = function()
							vim.cmd "Prettier"
						end,
					})
				end,
				settings = {
					typescript = {
						inlayHints = {
							includeInlayParameterNameHints = "all",
							includeInlayParameterNameHintsWhenArgumentMatchesName = false,
							includeInlayFunctionParameterTypeHints = true,
							includeInlayVariableTypeHints = true,
							includeInlayPropertyDeclarationTypeHints = true,
							includeInlayFunctionLikeReturnTypeHints = true,
						},
					},
					javascript = {
						inlayHints = {
							includeInlayParameterNameHints = "all",
							includeInlayParameterNameHintsWhenArgumentMatchesName = false,
							includeInlayFunctionParameterTypeHints = true,
							includeInlayVariableTypeHints = true,
							includeInlayPropertyDeclarationTypeHints = true,
							includeInlayFunctionLikeReturnTypeHints = true,
						},
					},
				}
			}

			-- Tailwind --
			lspconfig.tailwindcss.setup {
				capabilities = capabilities,
				filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact", "html", "css", "rust" },
				root_dir = lspconfig.util.root_pattern("tailwind.config.js", "tailwind.config.ts", "input.css", "Cargo.toml"),
				settings = {
					tailwindCSS = {
						experimental = {
							classRegex = {
								-- For Leptos view! macro class patterns
								'class="([^"]*)"',
								'class=\\{\\s*"([^"]*)"\\s*\\}',
								-- Add this pattern for quoted class strings in Rust
								'"([^"]*)"', -- This will capture classes in strings
							}
						},
						includeLanguages = {
							rust = "html", -- Treat Rust as HTML for class completion
						},
					}
				}
			}

			-- ESLint --
			lspconfig.eslint.setup {
				capabilities = capabilities,
				on_attach = function(_, bufnr)
					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						command = "EslintFixAll",
					})
				end,
				settings = {
					packageManager = "npm",
				},
				root_dir = lspconfig.util.root_pattern(".eslintrc", ".eslintrc.js", ".eslintrc.json", "eslint.config.mjs"),
			}

			-- JSON
			lspconfig.jsonls.setup {
				capabilities = capabilities,
				settings = {
					json = {
						schemas = {
							{
								fileMatch = { "package.json" },
								url = "https://json.schemastore.org/package.json"
							},
							{
								fileMatch = { "tsconfig.json", "tsconfig.*.json" },
								url = "https://json.schemastore.org/tsconfig.json"
							},
							{
								fileMatch = { ".eslintrc.json" },
								url = "https://json.schemastore.org/eslintrc.json"
							}
						}
					}
				}
			}

			-- Add to your Mason ensure_installed list
			require("mason-lspconfig").setup {
				ensure_installed = {
					"tsserver",
					"eslint",
					"tailwindcss",
					"jsonls",
				}
			}

			require("conform").setup({
				formatters_by_ft = {
					javascript = { "prettierd" },
					typescript = { "prettierd" },
					javascriptreact = { "prettierd" },
					typescriptreact = { "prettierd" },
					css = { "prettierd" },
					html = { "prettierd" },
					json = { "prettierd" },
					yaml = { "prettierd" },
					markdown = { "prettierd" },
				},
				format_on_save = {
					timeout_ms = 500,
					lsp_fallback = true,
				},
			})

			require("lint").linters_by_ft = {
				javascript = { "eslint_d" },
				typescript = { "eslint_d" },
				javascriptreact = { "eslint_d" },
				typescriptreact = { "eslint_d" },
			}

			vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
				callback = function()
					require("lint").try_lint()
				end,
			})
			-- TOML --
			-- Taplo
			lspconfig.taplo.setup {
				capabilities = capabilities,
				cmd = { "taplo", "lsp", "stdio" },
				filetypes = { "toml" },
				on_attach = function(toml_client, toml_bufnr)
					if toml_client.supports_method "textDocument/formatting" then
						vim.api.nvim_create_autocmd("BufWritePre", {
							group = vim.api.nvim_create_augroup("LspFormatting",
								{ clear = true }),
							buffer = toml_bufnr,
							callback = function()
								vim.lsp.buf.format { async = true }
							end,
						})
					end
				end,
			}

			-- YAML --
			-- Yamlls
			lspconfig.yamlls.setup {
				capabilities = capabilities,
				cmd = { "yaml-language-server", "--stdio" },
				settings = {
					yaml = {
						schemas = {
							["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
							["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "docker-compose*.yml",
						},
					},
				},
				on_attach = function(yaml_client, yaml_bufnr)
					if yaml_client.supports_method "textDocument/formatting" then
						vim.api.nvim_create_autocmd("BufWritePre", {
							group = vim.api.nvim_create_augroup("YamllsFormatting",
								{ clear = true }),
							buffer = yaml_bufnr,
							callback = function()
								vim.lsp.buf.format { async = true }
							end,
						})
					end
				end,
			}
			-- Zig -

			-- ZLS (Zig Language Server)
			lspconfig.zls.setup {
				capabilities = capabilities,
				cmd = { "/usr/bin/zls" }, -- Explicit path to your ZLS executable
				filetypes = { "zig", "zir" },
				root_dir = lspconfig.util.root_pattern("zls.json", "build.zig", ".git"),
				single_file_support = true,
				settings = {
					zls = {
						-- Enable semantic highlighting
						semantic_tokens = "full",
						enable_inlay_hints = true,
						inlay_hints_show_builtin = true,
						inlay_hints_exclude_single_argument = true,
						inlay_hints_hide_redundant_param_names = false,
						inlay_hints_hide_redundant_param_names_last_token = false,
						-- Formatting
						enable_autofix = true, -- Apply small automatic fixes (e.g. unused variables removal)
						-- Path to Zig executable for advanced features
						zig_exe_path = "/usr/bin/zig",
						zig_lib_path = "/usr/lib/zig",
						-- Enable build-on-save diagnostics
						enable_build_on_save = true,
						-- Use build_runner from build.zig
						build_runner_path = "${zig_exe_path}",
						-- Include/warn/error filters
						warn_style = true,
						warn_undocumented = true,
						-- Experimental features
						operator_completions = true,
						use_comptime_interpreter = true,
						dangerous_comptime_experiments_do_not_enable = false, -- Set to true only if you're feeling brave
						-- Documentation options
						highlight_global_var_declarations = true,
						dangerous_comptime_interpreter_behavior_override = "default",
						record_session = false,
					}
				},
				on_attach = function(_, bufnr)
					-- Enable formatting on save
					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format({ bufnr = bufnr })
						end,
					})

					-- Add useful LSP keymappings for Zig
					local opts = { noremap = true, silent = true, buffer = bufnr }
					vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
					vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
					vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
					vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
					vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
					vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, opts)
					vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
				end,
			}

			-- Configure DAP for Zig
			-- Make sure to install nvim-dap first with your package manager

			-- Configure the CodeLLDB adapter (recommended for Zig)
			dap.adapters.codelldb = {
				type = 'server',
				port = '${port}',
				executable = {
					command = 'codelldb', -- Make sure this is in your PATH or provide full path
					args = { '--port', '${port}' },
				}
			}

			-- Alternative: LLDB adapter configuration
			dap.adapters.lldb = {
				type = 'executable',
				command = '/usr/bin/lldb', -- Adjust path as needed
				name = 'lldb'
			}

			-- Configure Zig debugging
			dap.configurations.zig = {
				{
					name = 'Launch',
					type = 'codelldb', -- Use 'lldb' as alternative
					request = 'launch',
					program = '${workspaceFolder}/zig-out/bin/${workspaceFolderBasename}',
					cwd = '${workspaceFolder}',
					stopOnEntry = false,
					args = {},
					runInTerminal = false,
					-- For console programs that require input:
					-- terminal = 'integrated',
				},
				{
					-- Additional configuration for debugging tests
					name = 'Debug Zig Tests',
					type = 'codelldb',
					request = 'launch',
					program = '${workspaceFolder}/zig-out/bin/test',
					cwd = '${workspaceFolder}',
					stopOnEntry = false,
					args = {},
				}
			}

			-- Add debugging keymaps
			vim.keymap.set('n', '<F5>', function() require('dap').continue() end,
				{ desc = 'Debug: Continue' })
			vim.keymap.set('n', '<F10>', function() require('dap').step_over() end,
				{ desc = 'Debug: Step Over' })
			vim.keymap.set('n', '<F11>', function() require('dap').step_into() end,
				{ desc = 'Debug: Step Into' })
			vim.keymap.set('n', '<F12>', function() require('dap').step_out() end,
				{ desc = 'Debug: Step Out' })
			vim.keymap.set('n', '<leader>b', function() require('dap').toggle_breakpoint() end,
				{ desc = 'Debug: Toggle Breakpoint' })
			vim.keymap.set('n', '<leader>dr', function() require('dap').repl.open() end,
				{ desc = 'Debug: Open REPL' })

			-- Optional: Add nvim-dap-ui configuration if installed
			-- require("dapui").setup()
			-- vim.keymap.set('n', '<leader>du', function() require('dapui').toggle() end, { desc = 'Debug: Toggle UI' })
		end,
	}
}
