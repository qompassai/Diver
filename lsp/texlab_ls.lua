-- /qompassai/Diver/lsp/texlab.lua
-- Qompass AI Texlab LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['texlab_ls'] = {
  cmd = {
    'texlab',
  },
  filetypes = {
    'tex',
    'plaintex',
    "bib",
  },
  root_markers = {
    '.git',
    '.latexmkrc',
    "latexmkrc",
    ".texlabroot",
    "texlabroot",
    "Tectonic.toml",
  },
  settings = {
    texlab = {
      rootDirectory = nil,
      build = {
        executable = 'latexmk',
        args = {
          '-pdf',
          "-interaction=nonstopmode",
          "-synctex=1",
          "%f",
        },
        onSave = false,
        forwardSearchAfter = false,
      },
      forwardSearch = {
        executable = nil,
        args = {},
      },
      chktex = {
        onOpenAndSave = true,
        onEdit = false,
      },
      diagnosticsDelay = 300,
      latexFormatter = "latexindent",
      latexindent = {
        ["local"] = nil,
        modifyLineBreaks = false,
      },
      bibtexFormatter = "texlab",
      formatterLineLength = 80,
    },
  },
  on_attach = function(client, bufnr)
    local function buf_build()
      local win = vim.api.nvim_get_current_win()
      local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
      client:request("textDocument/build", params, function(err, result)
        if err then
          error(tostring(err))
        end
        local status = {
          [0] = "Success",
          [1] = "Error",
          [2] = "Failure",
          [3] = "Cancelled",
        }
        vim.notify("Build " .. status[result.status], vim.log.levels.INFO)
      end, bufnr)
    end
    local function buf_search()
      local win = vim.api.nvim_get_current_win()
      local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
      client:request("textDocument/forwardSearch", params, function(err, result)
        if err then
          error(tostring(err))
        end
        local status = {
          [0] = "Success",
          [1] = "Error",
          [2] = "Failure",
          [3] = "Unconfigured",
        }
        vim.notify("Search " .. status[result.status], vim.log.levels.INFO)
      end, bufnr)
    end
    local function buf_cancel_build()
      return client:exec_cmd({
        title = 'cancel',
        command = "texlab.cancelBuild",
      }, {
        bufnr = bufnr,
      })
    end
    local function dependency_graph()
      client:exec_cmd({
        title = 'showDependency',
        command = "texlab.showDependencyGraph",
      }, {
        bufnr = 0,
      }, function(err, result)
        if err then
          return vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
        end
        vim.notify("The dependency graph has been generated:\n" .. result, vim.log.levels.INFO)
      end)
    end
    local function command_factory(kind)
      local cmd_tbl = {
        Auxiliary = "texlab.cleanAuxiliary",
        Artifacts = "texlab.cleanArtifacts",
      }
      return function()
        return client:exec_cmd({
          title = ("clean_%s"):format(kind),
          command = cmd_tbl[kind],
          arguments = { { uri = vim.uri_from_bufnr(bufnr) } },
        }, {
          bufnr = bufnr,
        }, function(err, _)
          if err then
            vim.notify(("Failed to clean %s files: %s"):format(kind, err.message), vim.log.levels.ERROR)
          else
            vim.notify(("Command %s executed successfully"):format(kind), vim.log.levels.INFO)
          end
        end)
      end
    end
    local function buf_find_envs()
      local win = vim.api.nvim_get_current_win()
      client:exec_cmd({
        command = "texlab.findEnvironments",
        arguments = { vim.lsp.util.make_position_params(win, client.offset_encoding) },
      }, {
        bufnr = bufnr,
      }, function(err, result)
        if err then
          return vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
        end
        local env_names = {}
        local max_length = 1
        for _, env in ipairs(result) do
          table.insert(env_names, env.name.text)
          max_length = math.max(max_length, string.len(env.name.text))
        end
        for i, name in ipairs(env_names) do
          env_names[i] = string.rep(" ", i - 1) .. name
        end
        vim.lsp.util.open_floating_preview(env_names, "", {
          height = #env_names,
          width = math.max((max_length + #env_names - 1), string.len("Environments")),
          focusable = false,
          focus = false,
          title = "Environments",
        })
      end)
    end
    local function buf_change_env()
      vim.ui.input({
        prompt = "New environment name: ",
      }, function(input)
        if not input or input == "" then
          return vim.notify("No environment name provided", vim.log.levels.WARN)
        end
        local pos = vim.api.nvim_win_get_cursor(0)
        return client:exec_cmd({
          title = "change_environment",
          command = "texlab.changeEnvironment",
          arguments = {
            {
              textDocument = {
                uri = vim.uri_from_bufnr(bufnr),
              },
              position = {
                line = pos[1] - 1,
                character = pos[2],
              },
              newName = tostring(input),
            },
          },
        }, {
          bufnr = bufnr,
        })
      end)
    end
    local cmds = {
      {
        name = "TexlabBuild",
        fn = buf_build,
        desc = "Build the current buffer",
      },
      {
        name = "TexlabForward",
        fn = buf_search,
        desc = "Forward search from current position",
      },
      {
        name = "TexlabCancelBuild",
        fn = buf_cancel_build,
        desc = "Cancel the current build",
      },
      {
        name = "TexlabDependencyGraph",
        fn = dependency_graph,
        desc = "Show the dependency graph",
      },
      {
        name = "TexlabCleanArtifacts",
        fn = command_factory("Artifacts"),
        desc = "Clean the artifacts",
      },
      {
        name = "TexlabCleanAuxiliary",
        fn = command_factory("Auxiliary"),
        desc = "Clean the auxiliary files",
      },
      {
        name = "TexlabFindEnvironments",
        fn = buf_find_envs,
        desc = "Find environments at current position",
      },
      {
        name = "TexlabChangeEnvironment",
        fn = buf_change_env,
        desc = "Change environment at current position",
      },
    }
    for _, cmd in ipairs(cmds) do
      vim.api.nvim_buf_create_user_command(bufnr, "Lsp" .. cmd.name, function()
        cmd.fn()
      end, {
        desc = cmd.desc,
      })
    end
  end,
}
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.tex", "*.bib" },
  callback = function(args)
    vim.lsp.buf.format({
      bufnr = args.buf,
      filter = function(client)
        return client.name == "texlab"
      end,
    })
  end,
})