return {
  {
    "huggingface/llm.nvim",
    lazy = true,
    opts = {
      api_token = function()
        return vim.fn.system("pass show hf"):gsub("\n", "")
      end,
      model = "qompass/r3",
      backend = "huggingface",
      url = "https://localhost:3000",
      tokens_to_clear = { "<|endoftext|>" },
      request_body = {
        parameters = {
          max_new_tokens = 60, -- Maximum number of tokens to generate (0 to infinity, based on model limits)
          temperature = 0.85, -- Controls randomness in generation (0.0-1.0; lower values are deterministic)
          top_p = 0.95, -- Top-p sampling (0.0-1.0); higher values include more tokens in consideration
          frequency_penalty = 0.5, -- Penalizes repeated tokens (range: -2.0 to 2.0)
          presence_penalty = 0.6, -- Penalizes new occurrences of tokens (range: -2.0 to 2.0)
        },
      },
      fim = { -- FIM (Fill-in-the-middle) configuration
        enabled = true,
        prefix = "<fim_prefix>",
        middle = "<fim_middle>",
        suffix = "<fim_suffix>",
      },
      debounce_ms = 150, -- Delay in milliseconds between input events before sending a request (range: 0+)
      accept_keymap = "<Tab>",
      dismiss_keymap = "<S-Tab>",
      tls_skip_verify_insecure = false,
      lsp = {
        bin_path = nil,
        host = nil,
        port = nil,
        cmd_env = nil,
        version = "0.5.3",
      },
      tokenizer = "qompass/r3",
      context_window = 1024,
      enable_suggestions_on_startup = false,
      enable_suggestions_on_files = "*",
      disable_url_path_completion = false,
    },
    config = function(_, opts)
      require("llm").setup(opts)
    end,
  },
}
