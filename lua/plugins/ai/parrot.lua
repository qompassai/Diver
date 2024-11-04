local mappings = require "mappings.aimap"
return {
    "frankroeder/parrot.nvim",
    lazy = false,
    dependencies = { "ibhagwan/fzf-lua", "nvim-lua/plenary.nvim", "rcarriga/nvim-notify", "nvim-treesitter/nvim-treesitter" },
    config = function()
        require("notify").setup {
            background_colour = "#000000",
            render = "compact",
            top_down = false,
        }
        local function get_pass_entry(entry_name)
            local handle = io.popen("pass show " .. entry_name)
            if handle then
                local result = handle:read "*a"
                handle:close()
                return vim.trim(result)
            end
            return nil
        end

        require("parrot").setup {
            providers = {
                -- Providers must be explicitly added to make them available.
                anthropic = {
                    api_key = get_pass_entry("anthropic/primo"),
                    topic_prompt = "You only respond with 3 to 4 words to summarize the past conversation.",
                    topic = {
                        model = "claude-3-haiku-20240307",
                        params = { max_tokens = 32 },
                    },
                    params = {
                        chat = { max_tokens = 4096 },
                        command = { max_tokens = 4096 },
                    },
                },
                -- gemini = {
                --   api_key = get_pass_entry("apis/gemini_api_key"),
                -- },
                groq = {
                    api_key = get_pass_entry "groq/primo",
                    params = {
                        max_tokens = 8192,
                        temperature = 0.85,
                        top_p = 1,
                    },
                },
                -- mistral = {
                --   api_key = get_pass_entry("apis/mistral_api_key"),
                -- },
                pplx = {
                    api_key = get_pass_entry "perplexity",
                    params = {
                        max_tokens = 3000,
                        temperature = 0.7,
                        top_p = 1,
                    },
                },
                ollama = {
                    model = "llama3.2:1b",
                    api_key = get_pass_entry "qompass/rose",
                    params = {
                        max_tokens = 4096,
                        temperature = 0.7,
                        top_p = 1,
                    },
                },
                openai = {
                    api_key = get_pass_entry "openai/primo",
                    params = {
                        max_tokens = 8192,
                        temperature = 0.7,
                        top_p = 1,
                    },
                },
                github = {
                    api_key = get_pass_entry "gh/token",
                    params = {
                        max_tokens = 3000,
                        temperature = 0.7,
                        top_p = 0.9,
                    },
                },
                nvidia = {
                    api_key = get_pass_entry "nvpk",
                    params = {
                        max_tokens = 2500,
                        temperature = 0.8,
                        top_p = 0.95,
                    },
                },
                -- xai = {
                --   api_key = get_pass_entry("apis/xai_api_key"),
                -- },
            },
            system_prompt = {
                chat = "You are a knowledgeable expert assistant. Engage in aiding a service disabled veteran by creating expert level answers to queries they provide you. Ensure you think through each step and provide an answer thorough enough to fully answer the query each time. Respond in a clear and concise manner to help the user understand complex topics.",

                command = "You are a knowledgeable expert assistant. Engage in aiding a service disabled veteran by creating expert level answers to queries they provide you. Focus on delivering precise, actionable insights based on the user's input to help them not just get the answer but understand why the answer is correct and if you are not sure then ensure that there is enough information to understand what level of confidence can be placed into what you provide in response to the user query.",
            },

            cmd_prefix = "Prt",

            curl_params = {},

            state_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parrot/persisted",
            chat_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parrot/chats",

            chat_file_pattern = { "*.chat", "*.md" },

            chat_user_prefix = "🗨:",
            llm_prefix = "🧭:",
            chat_confirm_delete = true,
            online_model_selection = true,

            chat_shortcut_respond = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g><C-g>" },
            chat_shortcut_delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>d" },
            chat_shortcut_stop = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>s" },
            chat_shortcut_new = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>c" },

            chat_free_cursor = false,
            chat_prompt_buf_type = false,
            toggle_target = "vsplit",
            user_input_ui = "native",

            style_popup_border = "single",
            style_popup_margin_bottom = 8,
            style_popup_margin_left = 1,
            style_popup_margin_right = 2,
            style_popup_margin_top = 2,
            style_popup_max_width = 160,

            command_prompt_prefix_template = "🤖 {{llm}} ~ ",
            command_auto_select_response = true,

            fzf_lua_opts = {
                ["--ansi"] = true,
                ["--sort"] = "",
                ["--info"] = "inline",
                ["--layout"] = "reverse",
                ["--preview-window"] = "nohidden:right:75%",
            },

            enable_spinner = true,
            spinner_type = "star",
        }
        local function parrot_status()
            local status_info = require("parrot.config").get_status_info()
            local status = ""
            if status_info.is_chat then
                status = status_info.prov.chat.name
            else
                status = status_info.prov.command.name
            end
            return string.format("%s(%s)", status, status_info.model)
        end
        local function disable_markdown_clients_if_parrot()
            local current_buf = vim.api.nvim_get_current_buf()
            if vim.bo.filetype == "markdown" then
                local clients = vim.lsp.get_clients()
                local is_parrot_buffer = false

                for _, client in ipairs(clients) do
                    if client.name == "parrot" then
                        is_parrot_buffer = true
                        break
                    end
                end
                if is_parrot_buffer then
                    for _, client in ipairs(clients) do
                        if client.name == "markdown_oxide" or client.name == "marksman" then
                            if vim.tbl_contains(client.attached_buffers, current_buf) then
                                client.stop()
                                print(string.format("Stopped %s for this buffer.", client.name))
                            end
                        end
                    end
                end
            end
        end

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = disable_markdown_clients_if_parrot,
        })
        mappings.setup_parrot_mappings()
        return {
            parrot_status = parrot_status,
        }
    end,
}
