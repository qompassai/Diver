-- ~/.config/nvim/lua/cicd/json.lua
------------------------------------
local M = {}
function M.setup_json_completion(opts)
  local sources = opts.sources or {}
  table.insert(sources, {
    name = "blink",
    group_index = 1,
    priority = 100,
    option = {
      additional_trigger_characters = { ":", "," },
    },
    entry_filter = function(entry, ctx)
      local ft = ctx.filetype
      return ft == "json" or ft == "jsonc" or ft == "json5" or ft == "jsonl"
    end
  })

  opts.sources = sources
  return opts
end
function M.setup_json_conform(opts)
  opts.formatters_by_ft = vim.tbl_deep_extend("force",
    opts.formatters_by_ft or {},
    {
      json = { "prettierd", "jq" },
      jsonc = { "prettierd" },
      json5 = { "prettierd" },
      jsonl = { "jq" },
    }
  )
  opts.formatters = vim.tbl_deep_extend("force",
    opts.formatters or {},
    {
      prettier = {
        prepend_args = { "--parser", "json" },
      },
      jq = {
        args = { "--indent", "2" },
      }
    }
  )
  return opts
end
function M.setup_json_lsp(opts)
  if not opts.servers then opts.servers = {} end
  opts.servers.jsonls = {
    filetypes = { "json", "jsonc", "json5", "jsonl" },
    settings = {
      json = {
        schemas = require("schemastore").json.schemas({
          select = {
            "package.json",
            "tsconfig.json",
            "jsconfig.json",
            ".eslintrc",
            "composer.json",
            "babelrc.json",
            "lerna.json",
            "GitHub Action",
            "AWS CloudFormation",
            "docker-compose.yml",
          },
        }),
        validate = { enable = true },
        format = { enable = true },
      },
    },
    commands = {
      Format = {
        function()
          vim.lsp.buf.range_formatting({}, { 0, 0 }, { vim.fn.line("$"), 0 })
        end,
      },
    },
  }
  return opts
end
function M.setup_json_linter(opts)
  local null_ls = require("null-ls")
  opts.sources = vim.list_extend(opts.sources or {}, {
    require("none-ls-jsonlint.diagnostics.jsonlint"),
    null_ls.builtins.diagnostics.cfn_lint,
  })
  opts.root_dir = M.detect_json_root_dir
  return opts
end
function M.detect_json_root_dir(fname)
  local util = require("lspconfig.util")
  local root = util.root_pattern(
    "package.json",
    "tsconfig.json",
    ".eslintrc.json",
    ".prettierrc.json"
  )(fname) or
  util.root_pattern(".git")(fname)
  return root or vim.fn.getcwd()
end
function M.setup_json_formatter(opts)
  local null_ls = require("null-ls")
  opts.sources = vim.list_extend(opts.sources or {}, {
    null_ls.builtins.formatting.prettier.with({
      filetypes = { "json", "jsonc", "json5" },
    }),
    require("none-ls.formatting.jq"),
  })
  return opts
end
function M.setup_json_filetype_detection()
  vim.filetype.add({
    extension = {
      json = "json",
      jsonc = "jsonc",
      json5 = "json5",
      jsonl = "jsonl",
    },
    pattern = {
      ["%.json5$"] = "json5",
      ["%.jsonl$"] = "jsonl",
      ["%.jsonc$"] = "jsonc",
      ["tsconfig.*%.json"] = "jsonc",
      [".*rc%.json"] = "jsonc",
    },
    filename = {
      [".eslintrc.json"] = "jsonc",
      [".babelrc"] = "jsonc",
      [".prettierrc"] = "jsonc",
      ["tsconfig.json"] = "jsonc",
      ["package.json"] = "json",
    },
  })
end
function M.setup_json_keymaps(opts)
  opts.defaults = vim.tbl_deep_extend("force",
    opts.defaults or {},
    {
      ["<leader>cj"] = { name = "+json" },
      ["<leader>cjf"] = { "<cmd>lua require('conform').format()<cr>", "Format JSON" },
      ["<leader>cjv"] = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Validate JSON" },
      ["<leader>cjs"] = { "<cmd>lua require('telescope').extensions.schemastore.list()<cr>", "Schema Store" },
      ["<leader>cjp"] = { "<cmd>lua require('conform').format({formatters = {'prettier'}})<cr>", "Format with Prettier" },
      ["<leader>cjj"] = { "<cmd>lua require('conform').format({formatters = {'jq'}})<cr>", "Format with jq" },
    }
  )
  return opts
end
return M
