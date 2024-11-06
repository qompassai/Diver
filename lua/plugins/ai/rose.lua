local mappings = require "mappings.aimap"

local function get_pass_entry(entry_name)
    local handle = io.popen("pass show " .. entry_name)
    if handle then
        local result = handle:read("*a")
        handle:close()
        return vim.trim(result)
    end
    return nil
end

local function rose_status()
    local status_info = require("rose.config").get_status_info()
    local status = ""
    if status_info.is_chat then
        status = status_info.prov.chat.name
    else
        status = status_info.prov.command.name
    end
    return string.format("%s(%s)", status, status_info.model)
end

local function disable_markdown_clients_if_rose()
    local current_buf = vim.api.nvim_get_current_buf()
    if vim.bo.filetype == "markdown" then
        local clients = vim.lsp.get_clients()
        local is_rose_buffer = false

        for _, client in ipairs(clients) do
            if client.name == "rose" then
                is_rose_buffer = true
                break
            end
        end
        if is_rose_buffer then
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

return {
    "qompassai/rose.nvim",
    lazy = false,
    dependencies = { "ibhagwan/fzf-lua", "nvim-lua/plenary.nvim", "rcarriga/nvim-notify", "nvim-treesitter/nvim-treesitter" },
    config = function(_, opts)
        require("notify").setup {
            background_colour = "#000000",
            render = "compact",
            top_down = false,
        }

        require("rose").setup(opts)
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = disable_markdown_clients_if_rose,
        })

        -- Set up mappings for Rose.nvim
        mappings.setup_rose_mappings()
    end,
    opts = {
        chat_mode = true,
        providers = {
            -- Providers must be explicitly added to make them available.
           -- anthropic = {
           --     api_key = get_pass_entry("anthropic/primo"),
           -- },
            -- gemini = {
            --   api_key = get_pass_entry("apis/gemini_api_key"),
            -- },
           -- groq = {
           --     api_key = get_pass_entry "groq/primo",
           --     params = {
           --         chat = {
           --             max_tokens = 2048
           --         },
           --         command = {
           --             max_tokens = 2048
           --         },
           --         temperature = 0.7,
           --         top_p = 0.9,
           --     }
           -- },
            -- mistral = {
            --   api_key = get_pass_entry("apis/mistral_api_key"),
            -- },
            -- pplx = {
            --    api_key = get_pass_entry "pass/word",
            --    params = {
            --        chat = {
            --            max_tokens = 2048
            --        },
            --        command = {
            --            max_tokens = 2048
            --        },
            --        temperature = 0.7,
            --        top_p = 0.9,
            --        return_citations = true,
            --    },
           -- },
            ollama = {
                model = "llama3.2:1b",
                params = {
                    chat = {
                        max_tokens = 2048
                    },
                    command = {
                        max_tokens = 2048
                    },
                    temperature = 0.7,
                    top_p = 0.9,
                }
            },
            -- openai = {
            --    api_key = get_pass_entry "pass/word",
            --    params = {
            --        chat = {
            --            max_tokens = 2048 -- A good balance between response length and context
            --        },
            --        command = {
            --            max_tokens = 2048
            --        },
            --        temperature = 0.7,
            --        top_p = 0.9,
            --    }
            --},
            -- github = {
            --    api_key = get_pass_entry "pass/word",
            --    params = {
            --        chat = {
            --            max_tokens = 2048
            --        },
            --        command = {
            --            max_tokens = 2048
            --        },
            --        temperature = 0.7,
            --        top_p = 0.9,
            --    }
            --},
            --nvidia = {
            --    api_key = get_pass_entry "pass/word",
            --    params = {
            --        chat = {
            --           max_tokens = 2048
            --        },
            --        command = {
            --            max_tokens = 2048
            --        },
            --        temperature = 0.7,
            --        top_p = 0.9,
            --    }
            --},
            -- xai = {
            --   api_key = get_pass_entry("pass/word"),
            -- },
        },
        cmd_prefix = "Rose",
        chat_conceal_model_params = false,
        user_input_ui = "buffer",
        toggle_target = "vsplit", --vpslit, hsplit, tabnew
        chat_split_direction = "right",
        chat_split_size = 40,
        online_model_selection = true,
        command_auto_select_response = true,
        hooks = {
            Complete = function(prt, params)
                local template = [[
        I have the following code from {{filename}}:

        ```{{filetype}}
        {{selection}}
        ```

        Please finish the code above carefully and logically.
        Respond just with the snippet of code that should be inserted."
        ]]
                local model_obj = prt.get_model "command"
                prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
            end,
            CompleteFullContext = function(prt, params)
                local template = [[
        I have the following code from {{filename}}:

        ```{{filetype}}
        {filecontent}}
        ```

        Please look at the following section specifically:
        ```{{filetype}}
        {{selection}}
        ```

        Please finish the code above carefully and logically.
        Respond just with the snippet of code that should be inserted.
        ]]
                local model_obj = prt.get_model "command"
                prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
            end,
            CompleteMultiContext = function(prt, params)
                local template = [[
        I have the following code from {{filename}} and other realted files:

        ```{{filetype}}
        {{multifilecontent}}
        ```

        Please look at the following section specifically:
        ```{{filetype}}
        {{selection}}
        ```

        Please finish the code above carefully and logically.
        Respond just with the snippet of code that should be inserted.
        ]]
                local model_obj = prt.get_model "command"
                prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
            end,
            Explain = function(prt, params)
                local template = [[
        Your task is to take the code snippet from {{filename}} and explain it with gradually increasing complexity.
        Break down the code's functionality, purpose, and key components.
        The goal is to help the reader understand what the code does and how it works.

        ```{{filetype}}
        {{selection}}
        ```

        Use the markdown format with codeblocks and inline code.
        Explanation of the code above:
        ]]
                local model = prt.get_model "command"
                prt.logger.info("Explaining selection with model: " .. model.name)
                prt.Prompt(params, prt.ui.Target.new, model, nil, template)
            end,
            FixBugs = function(prt, params)
                local template = [[
        You are an expert in {{filetype}}.
        Fix bugs in the below code from {{filename}} carefully and logically:
        Your task is to analyze the provided {{filetype}} code snippet, identify
        any bugs or errors present, and provide a corrected version of the code
        that resolves these issues. Explain the problems you found in the
        original code and how your fixes address them. The corrected code should
        be functional, efficient, and adhere to best practices in
        {{filetype}} programming.

        ```{{filetype}}
        {{selection}}
        ```

        Fixed code:
        ]]
                local model_obj = prt.get_model "command"
                prt.logger.info("Fixing bugs in selection with model: " .. model_obj.name)
                prt.Prompt(params, prt.ui.Target.new, model_obj, nil, template)
            end,
            Optimize = function(prt, params)
                local template = [[
        You are an expert in {{filetype}}.
        Your task is to analyze the provided {{filetype}} code snippet and
        suggest improvements to optimize its performance. Identify areas
        where the code can be made more efficient, faster, or less
        resource-intensive. Provide specific suggestions for optimization,
        along with explanations of how these changes can enhance the code's
        performance. The optimized code should maintain the same functionality
        as the original code while demonstrating improved efficiency.

        ```{{filetype}}
        {{selection}}
        ```

        Optimized code:
        ]]
                local model_obj = prt.get_model "command"
                prt.logger.info("Optimizing selection with model: " .. model_obj.name)
                prt.Prompt(params, prt.ui.Target.new, model_obj, nil, template)
            end,
            UnitTests = function(prt, params)
                local template = [[
        I have the following code from {{filename}}:

        ```{{filetype}}
        {{selection}}
        ```

        Please respond by writing table driven unit tests for the code above.
        ]]
                local model_obj = prt.get_model "command"
                prt.logger.info("Creating unit tests for selection with model: " .. model_obj.name)
                prt.Prompt(params, prt.ui.Target.enew, model_obj, nil, template)
            end,
            Debug = function(prt, params)
                local template = [[
        I want you to act as {{filetype}} expert.
        Review the following code, carefully examine it, and report potential
        bugs and edge cases alongside solutions to resolve them.
        Keep your explanation short and to the point:

        ```{{filetype}}
        {{selection}}
        ```
        ]]
                local model_obj = prt.get_model "command"
                prt.logger.info("Debugging selection with model: " .. model_obj.name)
                prt.Prompt(params, prt.ui.Target.enew, model_obj, nil, template)
            end,
            CommitMsg = function(prt, params)
                local futils = require "parrot.file_utils"
                if futils.find_git_root() == "" then
                    prt.logger.warning "Not in a git repository"
                    return
                else
                    local template = [[
          I want you to act as a commit message generator. I will provide you
          with information about the task and the prefix for the task code, and
          I would like you to generate an appropriate commit message using the
          conventional commit format. Do not write any explanations or other
          words, just reply with the commit message.
          Start with a short headline as summary but then list the individual
          changes in more detail.

          Here are the changes that should be considered by this message:
          ]] .. vim.fn.system "git diff --no-color --no-ext-diff --staged"
                    local model_obj = prt.get_model "command"
                    prt.Prompt(params, prt.ui.Target.append, model_obj, nil, template)
                end
            end,
            SpellCheck = function(prt, params)
                local chat_prompt = [[
        Your task is to take the text provided and rewrite it into a clear,
        grammatically correct version while preserving the original meaning
        as closely as possible. Correct any spelling mistakes, punctuation
        errors, verb tense issues, word choice problems, and other
        grammatical mistakes.
        ]]
                prt.ChatNew(params, chat_prompt)
            end,
            CodeConsultant = function(prt, params)
                local chat_prompt = [[
          Your task is to analyze the provided {{filetype}} code and suggest
          improvements to optimize its performance. Identify areas where the
          code can be made more efficient, faster, or less resource-intensive.
          Provide specific suggestions for optimization, along with explanations
          of how these changes can enhance the code's performance. The optimized
          code should maintain the same functionality as the original code while
          demonstrating improved efficiency.

          Here is the code
          ```{{filetype}}
          {{filecontent}}
          ```
        ]]
                prt.ChatNew(params, chat_prompt)
            end,
            ProofReader = function(prt, params)
                local chat_prompt = [[
        I want you to act as a proofreader. I will provide you with texts and
        I would like you to review them for any spelling, grammar, or
        punctuation errors. Once you have finished reviewing the text,
        provide me with any necessary corrections or suggestions to improve the
        text. Highlight the corrected fragments (if any) using markdown backticks.

        When you have done that subsequently provide me with a slightly better
        version of the text, but keep close to the original text.

        Finally provide me with an ideal version of the text.

        Whenever I provide you with text, you reply in this format directly:

        ## Corrected text:

        {corrected text, or say "NO_CORRECTIONS_NEEDED" instead if there are no corrections made}

        ## Slightly better text

        {slightly better text}

        ## Ideal text

        {ideal text}
        ]]
                prt.ChatNew(params, chat_prompt)
            end,
        },
        style_popup_border = "single",
        style_popup_margin_bottom = 1,
        style_popup_margin_left = 1,
        style_popup_margin_right = 1,
        style_popup_margin_top = 1,
        style_popup_max_width = 100,
        style_popup_width = 0.5,
        style_popup_height = 0.6,


        fzf_lua_opts = {
            ["--ansi"] = true,
            ["--sort"] = "",
            ["--info"] = "inline",
            ["--layout"] = "reverse",
            ["--preview-window"] = "nohidden:right:75%",
        },

        enable_spinner = true,
        spinner_type = "star",
    },
    rose_status = rose_status,
}
