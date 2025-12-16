-- /qompassai/Diver/lsp/text_ls.lua
-- Qompass AI Text LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'textlsp',
  },
  filetypes = {
    'text',
    'tex',
    'org',
  },
  root_markers = {
    '.git',
  },
  settings = {
    textLSP = {
      analysers = {
        languagetool = {
          enabled = true,
          check_text = {
            on_open = true,
            on_save = true,
            on_change = false,
          },
        },
        ollama = {
          enabled = false,
          check_text = {
            on_open = false,
            on_save = false,
            on_change = false,
          },
          model = 'phi3:3.8b-instruct',
          -- model = "phi3:14b-instruct",
          max_token = 50,
        },
        gramformer = {
          enabled = true,
          gpu = true,
          check_text = {
            on_open = false,
            on_save = true,
            on_change = false,
          },
        },
        hf_checker = {
          enabled = false,
          gpu = false,
          quantize = 32,
          model = 'pszemraj/flan-t5-large-grammar-synthesis',
          min_length = 40,
          check_text = {
            on_open = false,
            on_save = true,
            on_change = false,
          },
        },
        hf_instruction_checker = {
          enabled = false,
          gpu = false,
          quantize = 32,
          model = 'grammarly/coedit-large',
          min_length = 40,
          check_text = {
            on_open = false,
            on_save = true,
            on_change = false,
          },
        },
        hf_completion = {
          enabled = false,
          gpu = false,
          quantize = 32,
          model = 'bert-base-multilingual-cased',
          topk = 5,
        },
        openai = {
          enabled = false,
          api_key = '<MY_API_KEY>',
          -- url = '<CUSTOM_URL>'
          check_text = {
            on_open = false,
            on_save = false,
            on_change = false,
          },
          model = 'gpt-3.5-turbo',
          max_token = 16,
        },
        grammarbot = {
          enabled = false,
          api_key = '<MY_API_KEY>',
          input_max_requests = 1,
          check_text = {
            on_open = false,
            on_save = false,
            on_change = false,
          },
        },
      },
      documents = {
        language = 'auto:en',
        min_length_language_detect = 20,
        org = {
          org_todo_keywords = {
            'TODO',
            'IN_PROGRESS',
            'DONE',
          },
        },
        txt = {
          parse = true,
        },
      },
    },
  },
}