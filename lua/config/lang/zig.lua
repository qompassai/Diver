-- ~/.config/nvim/lua/config/zig.lua
-- ~/.config/nvim/lua/config/zig.lua
local M = {}
function M.setup_zig()
  local function find_executable(names)
    return vim.iter(names)
      :map(function(name)
        return vim.fs.find(name, {
          path = table.concat({
            vim.env.HOME .. "/.local/bin",
            vim.fn.stdpath("data") .. "/mason/bin",
            vim.env.PATH,
          }, ":")
        })[1]
      end)
      :next()
  end
  local zls_path = find_executable({ "zls" }) or "zls"
  local zig_path = find_executable({ "zig" }) or "zig"
  return {
    cmd = { zls_path },
    settings = {
      zls = {
        enable_ast_check_diagnostics = true,
        enable_build_on_save = true,
        zig_exe_path = zig_path,
        enable_inlay_hints = true,
        inlay_hints = {
          parameter_names = true,
          variable_names = false,
          builtin = true,
          type_names = true,
        }
      }
    }
  }
end
function M.zig_tools()
  return {
    build_dir = "zig-out",
    on_attach = function(client, bufnr)
      vim.keymap.set("n", "<leader>zih", function()
        vim.lsp.inlay_hint.enable(bufnr, not vim.lsp.inlay_hint.is_enabled(bufnr))
      end, { buffer = bufnr, desc = "Toggle inlay hints" })
    end
  }
end
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = { "*.zig", "*.zon" },
      callback = function(ctx)
        local output = vim.fn.systemlist(zlint_path .. " --format github " .. vim.fn.shellescape(ctx.file))
        local diagnostics = {}
        for _, line in ipairs(output) do
          local line_num, col_num, code, msg = line:match(":(%d+):(%d+): (%S+): (.*)")
          if line_num then
            table.insert(diagnostics, {
              lnum = tonumber(line_num) - 1,
              col = tonumber(col_num) - 1,
              message = string.format("[%s] %s", code, msg),
              severity = vim.diagnostic.severity.WARN,
              source = "zlint",
            })
          end
        end
        vim.diagnostic.set(0, diagnostics)
      end
    })
  return M
