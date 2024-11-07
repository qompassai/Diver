local M = {}

M.setup = function()
    local vim = vim
    local function get_os()
    if jit then
        return jit.os
    end
    local sysname = vim.loop.os_uname().sysname
    return sysname or "Unknown"
end
    local function has_compiler(compiler)
        local handle = io.popen(compiler .. " --version 2>&1")
        if handle then
            local result = handle:read("*a")
            handle:close()
            return result:match("clang") or result:match("gcc")
        end
        return false
    end
    local os_name = get_os()
    local compile_options = {}
    local function get_distro()
        local handle = io.popen("cat /etc/os-release")
        if handle then
            local content = handle:read("*a")
            handle:close()
            return content
        end
        return ""
    end

    if os_name == "Linux" then
        local distro = get_distro()
        if distro:match("Arch") then
            if has_compiler("clang++") then
                compile_options = {
                    cc = "clang",
                    cxx = "clang++",
                    cflags = {
                        "-I/usr/include/c++/14.2.1",
                        "-I/usr/include/c++/14.2.1/x86_64-pc-linux-gnu",
                        "-std=c++14",
                    },
                }
                require('nvim-treesitter.install').compilers = {
                    "clang++",
                    "g++",
                    "cc",
                    "gcc"
                }
            else
                compile_options = {
                    cc = "gcc",
                    cxx = "g++",
                    cflags = {
                        "-I/usr/include/c++/14.2.1",
                        "-I/usr/include/c++/14.2.1/x86_64-pc-linux-gnu",
                        "-std=c++14",
                    },
                }
                require('nvim-treesitter.install').compilers = {
                    "g++",
                    "gcc",
                    "cc"
                }
            end
        elseif distro:match("Ubuntu") or distro:match("Debian") then
            compile_options = {
                cc = has_compiler("clang++") and "clang" or "gcc",
                cxx = has_compiler("clang++") and "clang++" or "g++",
                cflags = {
                    "-I/usr/include/c++/11",
                    "-I/usr/include/x86_64-linux-gnu/c++/11",
                    "-std=c++14",
                },
            }
        else
            compile_options = {
                cc = has_compiler("clang++") and "clang" or "gcc",
                cxx = has_compiler("clang++") and "clang++" or "g++",
                cflags = {
                    "-std=c++14",
                },
            }
        end
    elseif os_name == "Darwin" then
        compile_options = {
            cc = "clang",
            cxx = "clang++",
            cflags = {
                "-I/usr/local/include",
                "-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include",
                "-std=c++14",
            },
        }
    elseif os_name == "Windows" then
        compile_options = {
            cc = "cl",
            cxx = "cl",
            cflags = {
                "/std:c++14",
            },
        }
    end
    require('nvim-treesitter.install').compilers = { "clang", "clang++", "gcc" }
    require('nvim-treesitter.install').prefer_git = true
    require('nvim-treesitter.install').compilation_dir = vim.fn.stdpath("data") .. "/treesitter"

    pcall(function() end)
    local lsp_signature = require("lsp_signature")
    local function on_attach(client, bufnr)
        if client.name == "lua_ls" then
            lsp_signature.on_attach({
                bind = false,
                floating_window = false,
                hint_enable = false,
                handler_opts = {
                    border = "rounded"
                },
            }, bufnr)
            client.server_capabilities.documentFormattingProvider = true
            require('lspconfig').lua_ls.setup({
                capabilities = require('cmp_nvim_lsp').default_capabilities(),
                settings = {
                    Lua = {
                        runtime = {
                            version = 'LuaJIT',
                            path = vim.split(package.path, ';'),
                        },
                        diagnostics = {
                            globals = { 'vim',
                                'jit' },
                        },
                        workspace = {
                            library = {
                                [vim.fn.expand('$VIMRUNTIME/lua')] = false,
                                [vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = false,
                                checkThirdParty = false,
                            },
                        },
                        telemetry = {
                            enable = false,
                        },
                    },
                },
            })
        end
    end

    local options = {
        ensure_installed = {
            "ansible",           -- Infrastructure as Code automation language
            "asciidoc",          -- Text document format
            "astro",             -- Web framework with islands architecture
            "awk",               -- Text processing scripting language
            "bash",              -- Shell scripting language
            "bibtex",            -- Bibliography management format
            "c",                 -- Systems programming language
            "capnp",             -- Cap'n Proto schema
            "cmake",             -- Build system configuration
            "csharp",            -- C# programming language
            "css",               -- Cascading Style Sheets
            "csv",               -- Comma-separated values data format
            "cuda",              -- NVIDIA CUDA
            "dart",              -- Google's UI programming language
            "devicetree",        -- Device Tree files
            "dhall",             -- Functional configuration language
            "diff",              -- File difference format
            "dockerfile",        -- Container definition format
            "dockerfile.docker", -- Enhanced Dockerfile
            "elixir",            -- Functional programming on BEAM VM
            "elvish",            -- Shell language
            "embedded_template", -- Template syntax (ERB, EJS)
            "erlang",            -- Concurrent programming language
            "fennel",            -- Lisp that compiles to Lua
            "fish",              -- User-friendly shell
            "flutter",           -- Flutter/Dart UI framework
            "fortran",           -- Scientific computing
            "gcc",               -- GNU Compiler Collection parser
            "gdscript",          -- Godot game engine
            "gitcommit",         -- Git commit message format
            "gitignore",         -- Git ignore rules
            "glimmer",           -- Ember.js templating
            "glsl",              -- OpenGL Shading Language
            "go",                -- Google's systems language
            "godot_resource",    -- Godot resource files
            "gradle",            -- Build automation tool
            "graphql",           -- API query language
            "handlebars",        -- Templating language
            "haskell",           -- Pure functional programming language
            "hcl",               -- HashiCorp Configuration Language
            "hcl2",              -- HashiCorp Config Language 2
            "helm",              -- Kubernetes package manager
            "hlsl",              -- DirectX Shading Language
            "html",              -- Web markup language
            "http",              -- HTTP request format
            "ini",               -- Configuration file format
            "java",              -- Object-oriented programming language
            "javascript",        -- Web programming language
            "jest",              -- JavaScript testing framework
            "jinja2",            -- Python template engine
            "jq",                -- JSON processing tool
            "jsdoc",             -- JavaScript documentation format
            "json",              -- Data interchange format
            "json5",             -- JSON with comments
            "jsonc",             -- JSON with comments (VSCode)
            "jsx",               -- React JavaScript XML
            "julia",             -- Scientific computing language
            "kdl",               -- Kid's Data Language
            "kotlin",            -- Modern JVM language
            "kubernetes",        -- Container orchestration configs
            "less",              -- CSS preprocessor
            "llvm",              -- LLVM IR
            "lua",               -- Lightweight scripting language
            "luadoc",            -- Lua documentation format
            "make",              -- Build automation tool
            "markdown",          -- Text-to-HTML markup
            "mathematica",       -- Technical computing
            "matlab",            -- Numerical computing language
            "mermaid",           -- Diagramming and charting
            "meson",             -- Build system
            "mysql",             -- MySQL database queries
            "ninja",             -- Build system
            "nix",               -- Package manager configuration
            "nu",                -- Nushell shell
            "ocaml",             -- Functional programming language
            "org",               -- Org mode markup
            "perl",              -- Text processing language
            "php",               -- Web development language
            "pickle",            -- Python serialization format
            "postgresql",        -- PostgreSQL database queries
            "prisma",            -- Database toolkit
            "promql",            -- Prometheus Query Language
            "properties",        -- Java properties format
            "proto",             -- Protocol buffers
            "pug",               -- Template engine for Node.js
            "python",            -- General-purpose programming language
            "pytest",            -- Python testing framework
            "query",             -- Tree-sitter query language
            "r",                 -- Statistical computing language
            "regex",             -- Regular expressions
            "requirements",      -- Python package requirements
            "ron",               -- Rusty Object Notation
            "rspec",             -- Ruby testing framework
            "rst",               -- reStructuredText markup
            "ruby",              -- Dynamic programming language
            "rust",              -- Systems programming language
            "scala",             -- JVM-based programming language
            "scss",              -- Sass CSS preprocessor
            "sed",               -- Stream editor
            "solidity",          -- Ethereum smart contracts
            "sql",               -- Database query language
            "stata",             -- Statistics and data
            "svelte",            -- Web framework
            "swift",             -- Apple's programming language
            "swift_proto",       -- Swift protocol buffers
            "teal",              -- Typed Lua for GUI
            "terraform",         -- Infrastructure as Code
            "tlaplus",           -- Formal specification
            "toml",              -- Configuration file format
            "tsx",               -- TypeScript JSX
            "twig",              -- Template engine
            "typescript",        -- Typed JavaScript
            "unreal",            -- Unreal Engine markup
            "verilog",           -- Hardware description
            "vim",               -- Text editor scripting
            "vimdoc",            -- Vim documentation format
            "vue",               -- Web framework
            "wasm",              -- WebAssembly text format
            "wgsl",              -- WebGPU Shading Language
            "xml",               -- Extensible markup language
            "yaml",              -- Data serialization format
            "yang",              -- Network configuration
            "zig",               -- Systems programming language
            "zsh",               -- Z shell scripting
        },

        sync_install = false,
        auto_install = false,
        parser_install_dir = vim.fn.stdpath("data") .. "/site/parser",
        compile_options = compile_options,

        highlight = {
            enable = true,
            use_languagetree = true,
            additional_vim_regex_highlighting = true,
        },
        indent = {
            enable = true,
            disable = {}
        },
        incremental_selection = {
            enable = false,
            keymaps = {
                init_selection = "<leader>si",
                node_incremental = "<leader>sn",
                node_decremental = "<leader>sd",
                scope_incremental = "<leader>ss",
            },
        },
        autotag = {
            enable = false,
        },

        textobjects = {
            select = {
                enable = true,
                lookahead = true,
                keymaps = {
                    ["af"] = "@function.outer",
                    ["if"] = "@function.inner",
                    ["ac"] = "@class.outer",
                    ["ic"] = "@class.inner",
                    ["aa"] = "@parameter.outer",
                    ["ia"] = "@parameter.inner",
                    ["ab"] = "@block.outer",
                    ["ib"] = "@block.inner",
                },
                selection_modes = {
                    ['@parameter.outer'] = 'v',
                    ['@function.outer'] = 'V',
                    ['@class.outer'] = '<c-v>',
                },
            },
            move = {
                enable = true,
                set_jumps = true,
                goto_next_start = {
                    ["]m"] = "@function.outer",
                    ["]]"] = "@class.outer",
                },
                goto_next_end = {
                    ["]M"] = "@function.outer",
                    ["]["] = "@class.outer",
                },
                goto_previous_start = {
                    ["[m"] = "@function.outer",
                    ["[["] = "@class.outer",
                },
                goto_previous_end = {
                    ["[M"] = "@function.outer",
                    ["[]"] = "@class.outer",
                },
            },
            swap = {
                enable = true,
                swap_next = {
                    ["<leader>a"] = "@parameter.inner",
                },
                swap_previous = {
                    ["<leader>A"] = "@parameter.inner",
                },
            },
        },

        context_commentstring = {
            enable = true,
            enable_autocmd = false,
        },

        playground = {
            enable = false,
            disable = {},
            updatetime = 25,
            persist_queries = false,
            keybindings = {
                toggle_query_editor = 'o',
                toggle_hl_groups = 'i',
                toggle_injected_languages = 't',
                toggle_anonymous_nodes = 'a',
                toggle_language_display = 'I',
                focus_language = 'f',
                unfocus_language = 'F',
                update = 'R',
                goto_node = '<cr>',
                show_help = '?',
            },
        },
        on_attach = on_attach,
        vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/site/parser")
    }

    return options
end

return M
