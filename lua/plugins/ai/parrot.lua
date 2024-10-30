return {
  "frankroeder/parrot.nvim",
  lazy = false,
  dependencies = { "ibhagwan/fzf-lua", "nvim-lua/plenary.nvim", "rcarriga/nvim-notify" },
  config = function()
    local function get_pass_entry(entry_name)
      local handle = io.popen("pass show" .. entry_name)
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
        -- anthropic = {
        --   api_key = get_pass_entry("apis/anthropic_api_key"),
        -- },
        -- gemini = {
        --   api_key = get_pass_entry("apis/gemini_api_key"),
        -- },
        groq = {
          api_key = get_pass_entry "groq/primo",
        },
        -- mistral = {
        --   api_key = get_pass_entry("apis/mistral_api_key"),
        -- },
        pplx = {
          api_key = get_pass_entry "perplexity",
        },
        ollama = {},
        openai = {
          api_key = get_pass_entry "openai/primo",
        },
        github = {
          api_key = get_pass_entry "gh/token",
        },
        nvidia = {
          api_key = get_pass_entry "ngcapi",
        },
        -- xai = {
        --   api_key = get_pass_entry("apis/xai_api_key"),
        -- },
      },
    }
  end,
}
