-- /qompassai/Diver/lsp/lsp-ai.lua
-- Qompass AI Qompass LSP-AI Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- References: https://github.com/SilasMarvin/lsp-ai/wiki/Configuration
-- cargo install lsp-ai -F llama_cpp -F cuda
vim.lsp.config['ai_ls'] = {
  cmd = {
    'lsp-ai',
  },
  filetypes = {},
  init_options = {
    memory = {
      file_store = {},
    },
    models = {
      model1 = {
        type = 'anthropic',
        chat_endpoint = "https://api.anthropic.com/v1/messages",
        model = 'claude-3-haiku-20240307',
        auth_token_env_var_name = 'ANTHROPIC_API_KEY',
      },
    },
    completion = {
      model = 'model1',
      parameters = {
        max_context = 2048,
        max_tokens = 128,
        system = [[
Instructions:
- You are an AI programming assistant.
- Given a piece of code with the cursor location marked by "<CURSOR>", replace "<CURSOR>" with the correct code or comment.
- First, think step-by-step.
- Describe your plan for what to build in pseudocode, written out in great detail.
- Then output the code replacing the "<CURSOR>"
- Ensure that your completion fits within the language context of the provided code snippet (e.g., Python, JavaScript, Rust).

Rules:
- Only respond with code or comments.
- Only replace "<CURSOR>"; do not include any previously written code.
- Never include "<CURSOR>" in your response
- If the cursor is within a comment, complete the comment meaningfully.
- Handle ambiguous cases by providing the most contextually appropriate completion.
- Be consistent with your responses.
]],
        messages = {
          {
            role = 'user',
            content = 'def greet(name):\n    print(f"Hello, {<CURSOR>}")',
          },
          {
            role = 'assistant',
            content = 'name',
          },
          {
            role = "user",
            content = "function sum(a, b) {\n    return a + <CURSOR>;\n}",
          },
          {
            role = "assistant",
            content = "b",
          },
          {
            role = "user",
            content = "fn multiply(a: i32, b: i32) -> i32 {\n    a * <CURSOR>\n}",
          },
          {
            role = "assistant",
            content = "b",
          },
          {
            role = "user",
            content = "# <CURSOR>\ndef add(a, b):\n    return a + b",
          },
          {
            role = "assistant",
            content = "Adds two numbers",
          },
          {
            role = "user",
            content = "# This function checks if a number is even\n<CURSOR>",
          },
          {
            role = "assistant",
            content = "def is_even(n):\n    return n % 2 == 0",
          },
          {
            role = "user",
            content = "{CODE}",
          },
        },
      },
    },
  },
}