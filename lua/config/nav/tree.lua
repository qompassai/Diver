--~/.config/nvim/lua/config/nav/tree.lua
-----------------------------------------
local M = {}

---@param opts NeoTreeOptions|nil

function M.get_config(opts)
  opts = opts or {}
  return {
    close_if_last_window = opts.close_if_last_window ~= false,
    popup_border_style = opts.popup_border_style or "rounded",
    enable_git_status = opts.enable_git_status ~= false,
    enable_diagnostics = opts.enable_diagnostics ~= false,
    sort_case_insensitive = opts.sort_case_insensitive ~= false,
    sources = opts.sources or {
      "filesystem",
      "buffers",
      "git_status",
    },
    source_selector = opts.source_selector or {
      winbar = true,
      content_layout = "center",
      sources = {
        { source = "filesystem", display_name = " Files " },
        { source = "buffers", display_name = " Buffers " },
        { source = "git_status", display_name = " Git " },
      },
    },
    default_component_configs = opts.default_component_configs or {
      indent = {
        indent_size = 2,
        padding = 1,
        with_markers = true,
        indent_marker = "│",
        last_indent_marker = "└",
        highlight = "NeoTreeIndentMarker",
      },
      icon = {
        folder_closed = "",
        folder_open = "",
        folder_empty = "",
        default = "*",
        highlight = "NeoTreeFileIcon",
      },
      name = {
        trailing_slash = false,
        use_git_status_colors = true,
        highlight = "NeoTreeFileName",
      },
      git_status = {
        symbols = {
          added = "",
          modified = "",
          deleted = "✖",
          renamed = "",
          untracked = "",
          ignored = "",
          unstaged = "",
          staged = "",
          conflict = "",
        },
      },
    },
    window = {
      position = "left",
      width = 30,
      mapping_options = {
        noremap = true,
        nowait = true,
      },
      mappings = {
        ["<space>"] = "toggle_node",
        ["<2-LeftMouse>"] = "open",
        ["<cr>"] = "open",
        ["S"] = "open_split",
        ["s"] = "open_vsplit",
        ["t"] = "open_tabnew",
        ["C"] = "close_node",
        ["a"] = "add",
        ["d"] = "delete",
        ["r"] = "rename",
        ["y"] = "copy_to_clipboard",
        ["x"] = "cut_to_clipboard",
        ["p"] = "paste_from_clipboard",
        ["c"] = "copy",
        ["m"] = "move",
        ["q"] = "close_window",
        ["R"] = "refresh",
        ["?"] = "show_help",
      },
    },

    filesystem = opts.filesystem or {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_hidden = false,
        hide_by_name = {
          ".DS_Store",
          "thumbs.db",
        },
        never_show = {
          ".DS_Store",
          "thumbs.db",
        },
      },
      follow_current_file = {
        enabled = true,
      },
      use_libuv_file_watcher = true,
      window = {
        mappings = {
          ["H"] = "toggle_hidden",
          ["/"] = "fuzzy_finder",
          ["f"] = "filter_on_submit",
          ["<C-c>"] = "clear_filter",
        },
      },
    },

    buffers = opts.buffers or {
      follow_current_file = {
        enabled = true,
      },
      group_empty_dirs = true,
      show_unloaded = true,
    },

    git_status = opts.git_status or {
      window = {
        mappings = {
          ["A"] = "git_add_all",
          ["u"] = "git_unstage_file",
          ["a"] = "git_add_file",
          ["r"] = "git_revert_file",
          ["c"] = "git_commit",
          ["p"] = "git_push",
          ["g"] = "git_commit_and_push",
        },
      },
    },
  }
end

---@param opts NeoTreeOptions|nil
function M.setup(opts)
  return M.get_config(opts)
end

return M
