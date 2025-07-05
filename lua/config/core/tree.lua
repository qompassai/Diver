-- /qompassai/Diver/lua/config/core/tree.lua
-- Qompass AI Diver TreeSitter Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
------------------------------------------------------
local M = {}

function M.treesitter(opts)
  local ts_ok, configs = pcall(require, 'nvim-treesitter.configs')
  if not ts_ok then return end
  require("nvim-treesitter.install").prefer_git = true
local langs = { "ui.html", "lang.go", "lang.rust", 'lang.zig' }
local merged_lang_opts = {}

for _, lang_mod in ipairs(langs) do
  local ok, mod = pcall(require, "config." .. lang_mod)
  if ok and type(mod[lang_mod:match("[^.]+$") .. "_treesitter"]) == "function" then
    local ts_cfg = mod[lang_mod:match("[^.]+$") .. "_treesitter"]()
    if ts_cfg then
      merged_lang_opts = vim.tbl_deep_extend("force", merged_lang_opts, ts_cfg)
    end
  end
end
  local parser_path = vim.fn.stdpath("data") .. "/parsers"
  vim.opt.runtimepath:prepend(parser_path)
  local exclude = { "ipkg" }
  local ensure = require("nvim-treesitter.parsers").available_parsers()
  for _, lang in ipairs(exclude) do
    ensure = vim.tbl_filter(function(p) return p ~= lang end, ensure)
  end
  local default_opts = {
    ensure_installed = ensure,
    sync_install = true,
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = true,
      disable = function(_, buf)
        local max_filesize = 100 * 1024
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
        return ok and stats and stats.size > max_filesize
      end,
    },
    indent = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn",
        node_incremental = "grn",
        scope_incremental = "grc",
        node_decremental = "grm",
      },
    },
  }
  local merged = vim.tbl_deep_extend("force", default_opts, opts or {})
  configs.setup(merged)
  vim.api.nvim_create_autocmd("FileType", {
    desc = "Use Tree-sitter for code folding",
    callback = function()
      vim.wo.foldmethod = "expr"
      vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    end,
  })
end

function M.neotree(opts)
  opts = opts or {}
  return {
    close_if_last_window = opts.close_if_last_window ~= false,
    popup_border_style = opts.popup_border_style or "rounded",
    enable_git_status = opts.enable_git_status ~= false,
    enable_diagnostics = opts.enable_diagnostics ~= false,
    enable_modified_markers = opts.enable_modified_markers ~= false,
    enable_opened_markers = opts.enable_opened_markers ~= false,
    enable_refresh_on_write = opts.enable_refresh_on_write ~= false,
    enable_cursor_hijack = opts.enable_cursor_hijack ~= true,
    auto_clean_after_session_restore = opts.auto_clean_after_session_restore ~= false,
    add_blank_line_at_top = opts.add_blank_line_at_top == true,
    default_source = opts.default_source or "filesystem",
    git_status_async = opts.git_status_async ~= false,
    git_status_async_options = opts.git_status_async_options or {
      batch_size = 1000,
      batch_delay = 10,
      max_lines = 10000,
    },
    hide_root_node = opts.hide_root_node == true,
    retain_hidden_root_indent = opts.retain_hidden_root_indent == true,
    log_level = opts.log_level or "info",
    log_to_file = opts.log_to_file or false,
    open_files_in_last_window = opts.open_files_in_last_window ~= false,
    open_files_do_not_replace_types = opts.open_files_do_not_replace_types or {
      "terminal", "Trouble", "qf", "edgy"
    },
    open_files_using_relative_paths = opts.open_files_using_relative_paths == true,
    resize_timer_interval = opts.resize_timer_interval or 500,
    sort_case_insensitive = opts.sort_case_insensitive ~= false,
    sort_function = opts.sort_function or nil,
    use_popups_for_input = opts.use_popups_for_input ~= false,
    use_default_mappings = opts.use_default_mappings ~= false,
    source_selector = opts.source_selector or {
      winbar = true,
      content_layout = "center",
      sources = {
        "filesystem",
        "buffers",
        "git_status",
        "document_symbols",
      },
    },
    default_component_configs = opts.default_component_configs or {
      indent = {
        indent_size = 2,
        padding = 1,
        with_markers = true,
        indent_marker = "â",
        last_indent_marker = "â",
        highlight = "NeoTreeIndentMarker",
        with_expanders = nil,
        expander_collapsed = "ï ",
        expander_expanded = "ï¼",
        expander_highlight = "NeoTreeExpander",
      },
      icon = {
        folder_closed = "î¿",
        folder_open = "î¾",
        folder_empty = "ó°",
        folder_empty_open = "ó°·",
        default = "*",
        highlight = "NeoTreeFileIcon",
      },
      name = {
        trailing_slash = true,
        highlight_opened_files = true,
        use_git_status_colors = true,
        highlight = 'NeoTreeFileName'
      },
      git_status = {
        symbols = {
          added     = "â",
          deleted   = "â",
          modified  = "ï",
          renamed   = "ó°",
          untracked = "ï¨",
          ignored   = "ï´",
          unstaged  = "ó°±",
          staged    = "ï",
          conflict  = "î§",
        },
        align = "right",
      },
      file_size = {
        enabled = true,
        width = 12,
        required_width = 64,
      },
      type = {
        enabled = true,
        width = 10,
        required_width = 110,
      },
      last_modified = {
        enabled = true,
        width = 20,
        required_width = 88,
        format = "%Y-%m-%d %I:%M %p",
        --format = require("neo-tree.utils").relative_date, -- enable relative timestamps
      },
      created = {
        enabled = true,
        width = 20,
        required_width = 120,
        format = "%Y-%m-%d %I:%M %p",
        --format = require("neo-tree.utils").relative_date, -- enable relative timestamps
      },
      symlink_target = {
        enabled = true,
        text_format = " â %s",
      },
    },
    renderers = {
      directory = {
        { "indent" },
        { "icon" },
        { "current_filter" },
        {
          "container",
          content = {
            { "name",          zindex = 10 },
            {
              "symlink_target",
              zindex = 10,
              highlight = "NeoTreeSymbolicLinkTarget",
            },
            { "clipboard",     zindex = 10 },
            { "diagnostics",   errors_only = true, zindex = 20,     align = "right",          hide_when_expanded = true },
            { "git_status",    zindex = 10,        align = "right", hide_when_expanded = true },
            { "file_size",     zindex = 10,        align = "right" },
            { "type",          zindex = 10,        align = "right" },
            { "last_modified", zindex = 10,        align = "right" },
            { "created",       zindex = 10,        align = "right" },
          },
        },
      },
      file = {
        { "indent" },
        { "icon" },
        {
          "container",
          content = {
            {
              "name",
              zindex = 10
            },
            {
              "symlink_target",
              zindex = 10,
              highlight = "NeoTreeSymbolicLinkTarget",
            },
            { "clipboard",     zindex = 10 },
            { "bufnr",         zindex = 10 },
            { "modified",      zindex = 20, align = "right" },
            { "diagnostics",   zindex = 20, align = "right" },
            { "git_status",    zindex = 10, align = "right" },
            { "file_size",     zindex = 10, align = "right" },
            { "type",          zindex = 10, align = "right" },
            { "last_modified", zindex = 10, align = "right" },
            { "created",       zindex = 10, align = "right" },
          },
        },
      },
      message = {
        { "indent", with_markers = true },
        { "name",   highlight = "NeoTreeMessage" },
      },
      terminal = {
        { "indent" },
        { "icon" },
        { "name" },
        { "bufnr" }
      }
    },
    nesting_rules = {},
    commands = {},
    window = {
      position = "left",
      width = 40,
      height = 15,
      auto_expand_width = true,
      popup = {
        size = {
          height = "80%",
          width = "50%",
        },
        position = "50%",
        title = function(state)
          return "Neo-tree " .. state.name:gsub("^%l", string.upper)
        end,
      },
      insert_as = "child",
      mapping_options = {
        noremap = true,
        nowait = true,
      },
      mappings = {
        ["<space>"] = {
          "toggle_node",
          nowait = false,
        },
        ["<2-LeftMouse>"] = "open",
        ["<cr>"] = "open",
        -- ["<cr>"] = { "open", config = { expand_nested_files = true } }, -- expand nested file takes precedence
        ["<esc>"] = "cancel", -- close preview or floating neo-tree window
        ["P"] = {
          "toggle_preview",
          config = {
            use_float = true,
            use_image_nvim = false,
            title = "Neo-tree Preview",
          }
        },
        ["<C-f>"] = { "scroll_preview", config = { direction = -10 } },
        ["<C-b>"] = { "scroll_preview", config = { direction = 10 } },
        ["l"] = "focus_preview",
        ["S"] = "open_split",
        -- ["S"] = "split_with_window_picker",
        ["s"] = "open_vsplit",
        -- ["sr"] = "open_rightbelow_vs",
        -- ["sl"] = "open_leftabove_vs",
        -- ["s"] = "vsplit_with_window_picker",
        ["t"] = "open_tabnew",
        -- ["<cr>"] = "open_drop",
        -- ["t"] = "open_tab_drop",
        ["w"] = "open_with_window_picker",
        ["C"] = "close_node",
        --["C"] = "close_all_subnodes",
        ["z"] = "close_all_nodes",
        --["Z"] = "expand_all_nodes",
        --["Z"] = "expand_all_subnodes",
        ["R"] = "refresh",
        ["a"] = {
          "add",
          config = {
            show_path = "absolute", -- "none", "relative", "absolute"
          }
        },
        filesystem = opts.filesystem or {
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_hidden = false,
            hide_by_name = { '.DS_Store', 'thumbs.db' },
            never_show = { '.DS_Store', 'thumbs.db' }
          },
          follow_current_file = { enabled = true },
          use_libuv_file_watcher = true,
          mappings = {
            ["H"] = "toggle_hidden",
            ["/"] = "fuzzy_finder",
            --["/"] = {"fuzzy_finder", config = { keep_filter_on_submit = true }},
            --["/"] = "filter_as_you_type", -- this was the default until v1.28
            ["D"] = "fuzzy_finder_directory",
            -- ["D"] = "fuzzy_sorter_directory",
            ["#"] = "fuzzy_sorter", -- fuzzy sorting using the fzy algorithm
            ["f"] = "filter_on_submit",
            ["<C-x>"] = "clear_filter",
            ["<bs>"] = "navigate_up",
            ["."] = "set_root",
            ["[g"] = "prev_git_modified",
            ["]g"] = "next_git_modified",
            ["i"] = "show_file_details",
            ["b"] = "rename_basename",
            ["o"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "o" } },
            ["oc"] = { "order_by_created", nowait = false },
            ["od"] = { "order_by_diagnostics", nowait = false },
            ["og"] = { "order_by_git_status", nowait = false },
            ["om"] = { "order_by_modified", nowait = false },
            ["on"] = { "order_by_name", nowait = false },
            ["os"] = { "order_by_size", nowait = false },
            ["ot"] = { "order_by_type", nowait = false },
          },
          fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
            ["<down>"] = "move_cursor_down",
            ["<C-n>"] = "move_cursor_down",
            ["<up>"] = "move_cursor_up",
            ["<C-p>"] = "move_cursor_up",
            ["<Esc>"] = "close",
            ["<S-CR>"] = "close_keep_filter",
            ["<C-CR>"] = "close_clear_filter",
            ["<C-w>"] = { "<C-S-w>", raw = true },
            {
              n = {
                ["j"] = "move_cursor_down",
                ["k"] = "move_cursor_up",
                ["<S-CR>"] = "close_keep_filter",
                ["<C-CR>"] = "close_clear_filter",
                ["<esc>"] = "close",
              }
            }
            -- ["<esc>"] = "noop", -- if you want to use normal mode
            -- ["key"] = function(state, scroll_padding) ... end,
          },
        },
        buffers = opts.buffers or {
          follow_current_file = { enabled = true },
          group_empty_dirs = true,
          show_unloaded = true
        },
        git_status = {
          window = {
            mappings = {
              ["A"] = "git_add_all",
              ["gu"] = "git_unstage_file",
              ["gU"] = "git_undo_last_commit",
              ["ga"] = "git_add_file",
              ["gr"] = "git_revert_file",
              ["gc"] = "git_commit",
              ["gp"] = "git_push",
              ["gg"] = "git_commit_and_push",
              ["i"] = "show_file_details", -- see `:h neo-tree-file-actions` for options to customize the window.
              ["b"] = "rename_basename",
              ["o"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "o" } },
              ["oc"] = { "order_by_created", nowait = false },
              ["od"] = { "order_by_diagnostics", nowait = false },
              ["om"] = { "order_by_modified", nowait = false },
              ["on"] = { "order_by_name", nowait = false },
              ["os"] = { "order_by_size", nowait = false },
              ["ot"] = { "order_by_type", nowait = false },
            },
          },
        },
        document_symbols = {
          follow_cursor = false,
          client_filters = "first",
          renderers = {
            root = {
              { "indent" },
              { "icon",  default = "C" },
              { "name",  zindex = 10 },
            },
            symbol = {
              { "indent",    with_expanders = true },
              { "kind_icon", default = "?" },
              {
                "container",
                content = {
                  { "name",      zindex = 10 },
                  { "kind_name", zindex = 20, align = "right" },
                }
              }
            },
          },
          window = {
            mappings = {
              ["<cr>"] = "jump_to_symbol",
              ["o"] = "jump_to_symbol",
              ["A"] = "noop", -- also accepts the config.show_path and config.insert_as options.
              ["d"] = "noop",
              ["y"] = "noop",
              ["x"] = "noop",
              ["p"] = "noop",
              ["c"] = "noop",
              ["m"] = "noop",
              ["a"] = "noop",
              ["/"] = "filter",
              ["f"] = "filter_on_submit",
            },
          },
          custom_kinds = {
            -- define custom kinds here (also remember to add icon and hl group to kinds)
            -- ccls
            -- [252] = 'TypeAlias',
            -- [253] = 'Parameter',
            -- [254] = 'StaticMethod',
            -- [255] = 'Macro',
          },
          kinds = {
            Unknown = { icon = "?", hl = "" },
            Root = { icon = "îª", hl = "NeoTreeRootName" },
            File = { icon = "ó°", hl = "Tag" },
            Module = { icon = "î¤", hl = "Exception" },
            Namespace = { icon = "ó°", hl = "Include" },
            Package = { icon = "ó°", hl = "Label" },
            Class = { icon = "ó°", hl = "Include" },
            Method = { icon = "î", hl = "Function" },
            Property = { icon = "ó°§", hl = "@property" },
            Field = { icon = "ï­", hl = "@field" },
            Constructor = { icon = "ï ¥", hl = "@constructor" },
            Enum = { icon = "ó°»", hl = "@number" },
            Interface = { icon = "ï", hl = "Type" },
            Function = { icon = "ó°", hl = "Function" },
            Variable = { icon = "î", hl = "@variable" },
            Constant = { icon = "î±", hl = "Constant" },
            String = { icon = "ó°¬", hl = "String" },
            Number = { icon = "ó° ", hl = "Number" },
            Boolean = { icon = "î©", hl = "Boolean" },
            Array = { icon = "ó°ª", hl = "Type" },
            Object = { icon = "ó°©", hl = "Type" },
            Key = { icon = "ó°", hl = "" },
            Null = { icon = "ï", hl = "Constant" },
            EnumMember = { icon = "ï", hl = "Number" },
            Struct = { icon = "ó°", hl = "Type" },
            Event = { icon = "ï£", hl = "Constant" },
            Operator = { icon = "ó°", hl = "Operator" },
            TypeParameter = { icon = "ó°", hl = "Type" },
            -- ccls
            -- TypeAlias = { icon = 'î ', hl = 'Type' },
            -- Parameter = { icon = 'î³ ', hl = '@parameter' },
            -- StaticMethod = { icon = 'ó°  ', hl = 'Function' },
            -- Macro = { icon = 'ï¶ ', hl = 'Macro' },
          }
        },
        example = {
          renderers = {
            custom = {
              { "indent" },
              { "icon",  default = "C" },
              { "custom" },
              { "name" }
            }
          },
          window = {
            mappings = {
              ["<cr>"] = "toggle_node",
              ["<C-e>"] = "example_command",
              ["d"] = "show_debug_info",
            },
          },
        },
      }
    }
  }
end

function M.tree_cfg(opts)
  opts = opts or {}
  M.treesitter(opts)
  return {
    treesitter = vim.tbl_deep_extend("force", M.options.treesitter or {}, opts),
    neotree = vim.tbl_deep_extend("force", M.options.neotree or {}, opts),
  }
end

return M
