vim.o.splitright = true -- Ensure vertical splits are to the right

return {
  {
    "qompassai/rose.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "rcarriga/nvim-notify",
      "folke/noice.nvim",
      "folke/edgy.nvim",
    },
    lazy = false,
    opts = function()
      -- Helper function to retrieve API keys from `pass`
      local function get_api_key_from_pass(path)
        local handle = io.popen("pass show " .. path .. " 2>/dev/null")
        if handle then
          local key = handle:read("*a")
          handle:close()
          if key and key ~= "" then
            return key:gsub("%s+$", "") -- Trim trailing whitespace
          end
        end
        vim.notify("Failed to retrieve API key from pass: " .. path, vim.log.levels.ERROR)
        return nil
      end

      return {
        providers = {
          groq = { api_key = get_api_key_from_pass("api/groq"),
  temperature = 1.0 },
          mistral = { api_key = get_api_key_from_pass("api/mistral") },
          pplx = { api_key = get_api_key_from_pass("api/perplexity") },
          qompass = {}, -- No API key required
          openai = { api_key = get_api_key_from_pass("api/openai") },
          github = { api_key = get_api_key_from_pass("api/gh") },
          nvidia = { api_key = get_api_key_from_pass("api/nvidia") },
          xai = { api_key = get_api_key_from_pass("api/xai") },
        },
        state_dir = vim.fn.stdpath("data") .. "/rose/persisted",
        chat_dir = vim.fn.stdpath("data") .. "/rose/chats",
        chat_user_prefix = "🗨:",
        llm_prefix = "🌹:",
        chat_confirm_delete = true,
        online_model_selection = true,
        chat_free_cursor = false,
        chat_prompt_buf_type = false,
        toggle_target = "vsplit",
        user_input_ui = "native",
        style_popup_border = "double",
        style_popup_margin_bottom = 8,
        style_popup_margin_left = 3,
        style_popup_margin_right = 2,
        style_popup_margin_top = 2,
        style_popup_max_width = 160,
        command_prompt_prefix_template = "🌹 {{llm}} ~ ",
        command_auto_select_response = true,
        enable_spinner = true,
        spinner_type = "dots",
        fzf_lua_opts = {
          ["--ansi"] = true,
          ["--sort"] = "",
          ["--info"] = "inline",
          ["--layout"] = "reverse",
          ["--preview-window"] = "nohidden:right:50%",
        },
      }
    end,
    keys = {
      {
        "<leader>ar",
        function()
          require("rose").chat_respond()
        end,
        desc = "🧭 Respond to Chat",
        mode = { "n", "v" },
      },
      {
        "<leader>ad",
        function()
          require("rose").chat_delete()
        end,
        desc = "🧭 Delete Chat",
        mode = { "n", "v" },
      },
      {
        "<leader>as",
        function()
          require("rose").stop()
        end,
        desc = "🧭 Stop Generation",
        mode = { "n", "v" },
      },
      {
        "<leader>ap",
        function()
          vim.cmd("RoseProvider")
        end,
        desc = "🧭 Rose Provider",
        mode = { "n", "v" },
      },
      {
        "<leader>am",
        function()
          vim.cmd("RoseModel")
        end,
        desc = "🧭 Rose Model",
        mode = { "n", "v" },
      },
      {
        "<leader>ac",
        function()
          vim.cmd("vertical resize 30 | RoseChatNew") -- Resize and open chat
        end,
        desc = "🧭 New Chat",
        mode = { "n", "v" },
      },
      {
        "<leader>aq",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("rose").ask(input)
          end
        end,
        desc = "🧭 Quick Chat",
        mode = { "n", "v" },
      },
    },
    config = function(_, opts)
      local rose = require("rose")
      rose.setup(opts)

      -- Ensure all rose-chat splits have the desired width
      vim.api.nvim_create_autocmd("WinNew", {
        pattern = "rose-chat",
        callback = function()
          vim.cmd("vertical resize 30")
        end,
      })

      -- Disable numbers in rose-chat buffers
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "rose-chat",
        callback = function()
          vim.opt_local.relativenumber = false
          vim.opt_local.number = false
        end,
      })
    end,
  },
}
