local M = {}

M.setup = function()
	local capabilities = require("cmp_nvim_lsp").default_capabilities()
	local dap = require("dap")
	local dapui = require("dapui")

	--------------------------- | DAP UI | -----------------------------
	dapui.setup()
	dap.listeners.before.attach.dapui_config = function() dapui.open() end
	dap.listeners.before.launch.dapui_config = function() dapui.open() end
	dap.listeners.after.event_terminated.dapui_config = function() dapui.close() end
	dap.listeners.after.event_exited.dapui_config = function() dapui.close() end

	local sysname = (jit and jit.os) or "Linux"

	local mason_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/"
	local codelldb_path = mason_path .. "adapter/codelldb"
	local liblldb_path = mason_path .. "lldb/lib/liblldb.so"

	if sysname == "OSX" then
		liblldb_path = mason_path .. "lldb/lib/liblldb.dylib"
	elseif sysname == "Windows" then
		liblldb_path = mason_path .. "lldb/bin/liblldb.dll"
	end

	-- LSP on_attach
	local on_attach = function(_, bufnr)
		vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
	end

	-- Rustaceanvim --

	vim.g.rustaceanvim = {
		server = {
			on_attach = on_attach,
			capabilities = capabilities,
			default_settings = {
				["rust-analyzer"] = {
					assist = {
						expressionFillDefault = "default",
						importGranularity = "module",
						importPrefix = "self",
					},
					cargo = {
						allFeatures = true,
						loadOutDirsFromCheck = true,
						runBuildScripts = true,
						features = "all",
						target = "nil",
					},
					diagnostics = {
						enable = true,
						experimental = { enable = true },
						disabled = { "unresolved-proc-macro" },
					},
					files = {
						excludeDirs = {
							".direnv", ".git", "target", "node_modules",
						},
					},
					procMacro = {
						enable = true,
						attributes = {
							enable = true,
						},
					},
					checkOnSave = { command = "clippy" },
				},
			},
		},

		completion = {
			callable = {
				snippets = "fill_arguments",
			},
			postfix = {
				enable = true, -- allows `.dbg`, `.if`, `.match`, etc.
			},
		},
		-- Crates.nvim setup
		require("crates").setup {
			smart_insert = true,
			insert_closing_quote = true,
			autoload = true,
			autoupdate = true,
			autoupdate_throttle = 250,
			loading_indicator = true,
			search_indicator = true,
			date_format = "%Y-%m-%d",
			thousands_separator = ".",
			notification_title = "crates.nvim",
			curl_args = { "-sL", "--retry", "1" },
			max_parallel_requests = 80,
			expand_crate_moves_cursor = true,
			enable_update_available_warning = true,
			on_attach = function(_bufnr) end,
			text = {
				searching = "   Searching",
				loading = "   Loading",
				version = "   %s",
				prerelease = "   %s",
				yanked = "   %s",
				nomatch = "   No match",
				upgrade = "   %s",
				error = "   Error fetching crate",
			},
			highlight = {
				searching = "CratesNvimSearching",
				loading = "CratesNvimLoading",
				version = "CratesNvimVersion",
				prerelease = "CratesNvimPreRelease",
				yanked = "CratesNvimYanked",
				nomatch = "CratesNvimNoMatch",
				upgrade = "CratesNvimUpgrade",
				error = "CratesNvimError",
			},
			popup = {
				autofocus = false,
				hide_on_select = false,
				copy_register = '"',
				style = "minimal",
				border = "none",
				show_version_date = false,
				show_dependency_version = true,
				max_height = 30,
				min_width = 20,
				padding = 1,
				text = {
					title = " %s",
					pill_left = "",
					pill_right = "",
					description = "%s",
					created_label = " created        ",
					created = "%s",
					updated_label = " updated        ",
					updated = "%s",
					downloads_label = " downloads      ",
					downloads = "%s",
					homepage_label = " homepage       ",
					homepage = "%s",
					repository_label = " repository     ",
					repository = "%s",
					documentation_label = " documentation  ",
					documentation = "%s",
					crates_io_label = " crates.io      ",
					crates_io = "%s",
					lib_rs_label = " lib.rs         ",
					lib_rs = "%s",
					categories_label = " categories     ",
					keywords_label = " keywords       ",
					version = "  %s",
					prerelease = " %s",
					yanked = " %s",
					version_date = "  %s",
					feature = "  %s",
					enabled = " %s",
					transitive = " %s",
					normal_dependencies_title = " Dependencies",
					build_dependencies_title = " Build dependencies",
					dev_dependencies_title = " Dev dependencies",
					dependency = "  %s",
					optional = " %s",
					dependency_version = "  %s",
					loading = "  ",
				},
				highlight = {
					title = "CratesNvimPopupTitle",
					pill_text = "CratesNvimPopupPillText",
					pill_border = "CratesNvimPopupPillBorder",
					description = "CratesNvimPopupDescription",
					created_label = "CratesNvimPopupLabel",
					created = "CratesNvimPopupValue",
					updated_label = "CratesNvimPopupLabel",
					updated = "CratesNvimPopupValue",
					downloads_label = "CratesNvimPopupLabel",
					downloads = "CratesNvimPopupValue",
					homepage_label = "CratesNvimPopupLabel",
					homepage = "CratesNvimPopupUrl",
					repository_label = "CratesNvimPopupLabel",
					repository = "CratesNvimPopupUrl",
					documentation_label = "CratesNvimPopupLabel",
					documentation = "CratesNvimPopupUrl",
					crates_io_label = "CratesNvimPopupLabel",
					crates_io = "CratesNvimPopupUrl",
					lib_rs_label = "CratesNvimPopupLabel",
					lib_rs = "CratesNvimPopupUrl",
					categories_label = "CratesNvimPopupLabel",
					keywords_label = "CratesNvimPopupLabel",
					version = "CratesNvimPopupVersion",
					prerelease = "CratesNvimPopupPreRelease",
					yanked = "CratesNvimPopupYanked",
					version_date = "CratesNvimPopupVersionDate",
					feature = "CratesNvimPopupFeature",
					enabled = "CratesNvimPopupEnabled",
					transitive = "CratesNvimPopupTransitive",
					normal_dependencies_title = "CratesNvimPopupNormalDependenciesTitle",
					build_dependencies_title = "CratesNvimPopupBuildDependenciesTitle",
					dev_dependencies_title = "CratesNvimPopupDevDependenciesTitle",
					dependency = "CratesNvimPopupDependency",
					optional = "CratesNvimPopupOptional",
					dependency_version = "CratesNvimPopupDependencyVersion",
					loading = "CratesNvimPopupLoading",
				},
				keys = {
					hide = { "q", "<esc>" },
					open_url = { "<cr>" },
					select = { "<cr>" },
					select_alt = { "s" },
					toggle_feature = { "<cr>" },
					copy_value = { "yy" },
					goto_item = { "gd", "K", "<C-LeftMouse>" },
					jump_forward = { "<c-i>" },
					jump_back = { "<c-o>", "<C-RightMouse>" },
				},
			},
			completion = {
				insert_closing_quote = true,
				text = {
					prerelease = "  pre-release ",
					yanked = "  yanked ",
				},
				cmp = {
					enabled = false,
					use_custom_kind = true,
					kind_text = {
						version = "Version",
						feature = "Feature",
					},
					kind_highlight = {
						version = "CmpItemKindVersion",
						feature = "CmpItemKindFeature",
					},
				},
				coq = {
					enabled = false,
					name = "crates.nvim",
				},
				blink = {
					use_custom_kind = true,
					kind_text = {
						version = "Version",
						feature = "Feature",
					},
					kind_highlight = {
						version = "BlinkCmpKindVersion",
						feature = "BlinkCmpKindFeature",
					},
					kind_icon = {
						version = "🅥 ",
						feature = "🅕 ",
					},
				},
				crates = {
					enabled = true,
					min_chars = 3,
					max_results = 8,
				},
			},
			null_ls = {
				enabled = false,
				name = "crates.nvim",
			},
			neoconf = {
				enabled = false,
				namespace = "crates",
			},
			lsp = {
				enabled = false,
				name = "crates.nvim",
				on_attach = function(_client, _bufnr) end,


				actions = false,
				completion = false,
			},

		},

		dap = {
			adapter = function()
				return require("rustaceanvim.config").get_codelldb_adapter(codelldb_path, liblldb_path)
			end,
		},

		imports = {
			granularity = {
				group = "module",
			},
			prefix = "self",
		},

		inlayHints = {
			lifetimeElisionHints = {
				enable = "always",
				useParameterNames = true,
			},
			parameterHints = true,
			typeHints = true,
		},

		lens = {
			enable = true,
			enumVariantReferences = true,
			methodReferences = true,
			references = true,
		},

		rustc = {
			source = "discover",
		},

		rustfmt = {
			extraArgs = { "--config", "edition=2024" },
		},

		semanticTokensProvider = {
			full = true,
			legend = {
				tokenModifiers = {},
				tokenTypes = {},
			},
			range = true,
		},

		tools = {
			executor = "termopen",
			rustfmt = {
				overrideCommand = { "rustfmt", "+nightly", "--edition", "2024" },
			},
		},

		workspace = {
			symbol = {
				search = {
					kind = "all_symbols",
				},
			},
		},
	}

	-- Format on save
	vim.api.nvim_create_autocmd("BufWritePre", {
		pattern = "*.rs",
		callback = function()
			vim.lsp.buf.format({ async = false })
		end,
	})

	-- Cargo commands
	local cargo_cmds = {
		{ "CargoTest",         "test",                                  "Run cargo tests" },
		{ "CargoDoc",          "doc --open",                            "Generate and open documentation" },
		{ "CargoBuildAndroid", "build --target aarch64-linux-android",  "Build for Android" },
		{ "CargoBuildIos",     "build --target aarch64-apple-ios",      "Build for iOS" },
		{ "CargoBuildWasm",    "build --target wasm32-unknown-unknown", "Build for WASM" },
	}

	for _, cmd in ipairs(cargo_cmds) do
		vim.api.nvim_create_user_command(cmd[1], function()
			vim.cmd("!cargo " .. cmd[2])
		end, { desc = cmd[3] })
	end

	-- === Additional Cargo Tools ===

	-- cargo-expand: expand macros
	vim.api.nvim_create_user_command("CargoExpand", function()
		vim.cmd("!cargo expand")
	end, { desc = "Expand macros in Rust source" })

	-- cargo-nextest: run tests faster
	vim.api.nvim_create_user_command("CargoNextest", function()
		vim.cmd("!cargo nextest run")
	end, { desc = "Run tests with cargo-nextest" })

	-- cargo-zigbuild: cross compile via Zig
	vim.api.nvim_create_user_command("CargoZigBuild", function()
		vim.cmd("!cargo zigbuild --target aarch64-unknown-linux-gnu")
	end, { desc = "Zig cross compile for aarch64-linux-gnu" })

	-- cargo-audit: check for vulnerabilities
	vim.api.nvim_create_user_command("CargoAudit", function()
		vim.cmd("!cargo audit")
	end, { desc = "Audit Cargo.lock for vulnerabilities" })

	-- cargo-watch: watch files and run
	vim.api.nvim_create_user_command("CargoWatch", function()
		vim.cmd("!cargo watch -x run")
	end, { desc = "Watch and run app on file changes" })

	-- cargo-bloat: inspect binary size
	vim.api.nvim_create_user_command("CargoBloat", function()
		vim.cmd("!cargo bloat --crates")
	end, { desc = "Show crate-level binary bloat" })

	-- cargo-tarpaulin (already defined above): optionally open last report
	vim.api.nvim_create_user_command("CargoCoverageOpen", function()
		vim.cmd("!xdg-open tarpaulin-report.html")
	end, { desc = "Open last tarpaulin coverage report" })

	-- cargo flamegraph
	vim.api.nvim_create_user_command("CargoFlamegraph", function()
		vim.cmd("!cargo flamegraph")
	end, { desc = "Generate flamegraph for current project" })


	-- leptos build
	vim.api.nvim_create_user_command("LeptosBuild", function()
		vim.cmd("!cargo leptos build --release")
	end, { desc = "Build Leptos frontend" })

	--pingora
	vim.api.nvim_create_user_command("PingoraRun", function()
		vim.cmd("!sudo cargo run")
	end, { desc = "Run Pingora with elevated privileges" })

	-- trunk serve (for web UIs)
	vim.api.nvim_create_user_command("TrunkServe", function()
		vim.cmd("!trunk serve")
	end, { desc = "Serve via trunk (WASM/web)" })

	-- Leptos LSP
	local lspconfig = require("lspconfig")
	local configs = require("lspconfig.configs")

	if not configs.leptos_ls then
		configs.leptos_ls = {
			default_config = {
				cmd = { "leptosfmt", "lsp" },
				filetypes = { "rust" },
				root_dir = lspconfig.util.root_pattern("Cargo.toml", ".git"),
			},
		}
	end
	lspconfig.leptos_ls.setup({
		on_attach = on_attach,
		capabilities = capabilities,
	})
end

return M
