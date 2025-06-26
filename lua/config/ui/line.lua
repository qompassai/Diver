-- ~/.config/nvim/lua/config/ui/line.lua
--:TO DO
---@diagnostic disable: undefined-field, undefined-global
local M = {}

function M.line_ai()
  local status_ok, rose = pcall(require, "rose.config")
  if not status_ok then
    return ""
  end
  local status_info = rose.get_status_info()
  local status = ""
  if status_info.is_chat then
    status = status_info.prov.chat.name
  else
    status = status_info.prov.command.name
  end
  return string.format("%s(%s)", status, status_info.model)
end
function M.line_rose_status()
  return rose_status_ok and rose_lualine or nil
end
function M.line_lsp()
  local clients = vim.lsp.get_clients()
  if next(clients) == nil then
    return ""
  end
  local lsp_names = {}
  for _, client in pairs(clients) do
    table.insert(lsp_names, " " .. client.name)
  end
  return " " .. table.concat(lsp_names, ", ")
end
function M.line_datetime()
  local current_time = os.date("*t")
  return string.format(
    "%02d/%02d/%04d %02d:%02d:%02d",
    current_time.month,
    current_time.day,
    current_time.year,
    current_time.hour,
    current_time.min,
    current_time.sec
  )
end
function M.line_debounce(func, timeout)
  local debounce_timer = nil
  return function(...)
    local args = { ... }
    if debounce_timer then
      vim.fn.timer_stop(debounce_timer)
    end
    debounce_timer = vim.fn.timer_start(timeout, function()
      func(unpack(args))
    end)
  end
end
function M.line_diagnostics()
  return {
    "diagnostics",
    sources = { "nvim_diagnostic" },
    sections = { "error", "warn", "info", "hint" },
    diagnostics_color = {
      error = { fg = "#e06c75" },
      warn = { fg = "#e5c07b" },
      info = { fg = "#56b6c2" },
      hint = { fg = "#98c379" },
    },
    symbols = {
      error = " ",
      warn = " ",
      info = " ",
      hint = " ",
    },
    colored = true,
    update_in_insert = true,
    always_visible = true,
  }
end
function M.line_extensions(opts)
  opts = opts or {}
  return {
    "aerial",
    "ctrlspace",
    "fern",
    "fugitive",
    "fzf",
    "lazy",
    "man",
    "mason",
    "mundo",
    "neo-tree",
    "nerdtree",
    "nvim-dap-ui",
    "nvim-tree",
    "oil",
    "overseer",
    "quickfix",
    "symbols-outline",
    "toggleterm",
    "trouble",
  }
end

function M.line_file_info(opts)
  opts = opts or {}
  return {
    function()
      local filename = vim.fn.expand("%:t")
      local filetype = vim.bo.filetype
      local icon = require("nvim-web-devicons").get_icon(filename, filetype, { default = true })
      return string.format("%s %s", icon, filename)
    end,
    color = opts.color or {},
    cond = opts.cond,
  }
end
function M.line_file_size(opts)
  opts = opts or {}
  return {
    function()
      local file = vim.fn.expand("%:p")
      if file == "" then
        return ""
      end
      local size = vim.fn.getfsize(file)
      if size < 0 then
        return ""
      end
      local units = { "B", "KB", "MB", "GB", "TB" }
      local i = 1
      while size > 1024 and i < #units do
        size = size / 1024
        i = i + 1
      end
      return string.format("%.1f %s", size, units[i])
    end,
    icon = opts.icon or " ",
    cond = opts.cond,
    color = opts.color,
  }
end
function M.line_git_branch(opts)
  opts = opts or {}
  return {
    "branch",
    icon = opts.icon or "",
  }
end
function M.line_git_diff(opts)
  opts = opts or {}
  return {
    "diff",
    symbols = opts.symbols or { added = "  ", modified = "   ", removed = "   " },
    colored = opts.colored ~= false,
  }
end
function M.line_inactive_filename()
  local filename = vim.fn.expand("%:t")
  return { filename, color = { fg = "gray" } }
end

function M.line_inactive_location()
  return {
    "location",
    color = { fg = "darkgray" },
    fmt = function(str)
      return "󰍎 " .. str
    end,
  }
end

function M.line_os_icon()
  local uname = vim.uv.os_uname().sysname
  if uname:match("Linux") then
    local os_release = vim.fn.system("cat /etc/os-release")
    if os_release:match("Arch") then
      return ""
    elseif os_release:match("Ubuntu") then
      return " "
    else
      return " "
    end
  elseif uname:match("Darwin") then
    return "  "
  else
    return " "
  end
end

M.line_themes = {
  "tokyonight",
  "nightfox",
  "onedark",
  "gruvbox",
  "catppuccin",
  "everforest",
  "nord",
  "dracula",
  "material",
  "monokai",
  "palenight",
  "edge",
  "darkplus",
  "vscode",
  "ayu_dark",
  "carbonfox",
  "moonfly",
  "horizon",
  "gotham",
  "github_dark",
  "onedarkpro",
  "nightowl",
  "spacecamp",
  "nordfox",
  "halcyon",
  "synthwave84",
  "matrix",
  "vim-monochrome",
  "gruvbox-material-dark-hard",
  "sublimemonokai",
}

function M.line_settheme(theme_name)
  if not vim.tbl_contains(M.lualine_themes, theme_name) then
    vim.notify("Theme not found: " .. theme_name, vim.log.levels.ERROR)
    return
  end
  M.line_current_theme = theme_name
  require("lualine").setup({
    options = {
      theme = theme_name,
    },
  })
  vim.notify("Lualine theme set to: " .. theme_name, vim.log.levels.INFO)
end

function M.line_preview_fzf()
  if not pcall(require, "fzf-lua") then
    vim.notify("fzf-lua is required for theme preview", vim.log.levels.ERROR)
    return
  end
  local current_theme = M.line_current_theme
  require("fzf-lua").fzf_exec(M.line_themes, {
    prompt = "Lualine Theme> ",
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          local theme_name = selected[1]
          M.set_theme(theme_name)
        end
      end,
      ["ctrl-x"] = function()
        M.set_theme(current_theme)
      end,
    },
    previewer = false,
  })
end
function M.line_wc()
  local wc = vim.fn.wordcount()
  return " " .. string.format("%d words, %d chars", wc.words, wc.chars)
end
function M.line_icon(opts)
  opts = opts or {}
  local type = opts.type or "filename"
  local ft = vim.bo.filetype
  local custom_icon = opts.icon
  local handlers = {}
  handlers.filetype = function()
    local icon = custom_icon or require("nvim-web-devicons").get_icon_by_filetype(ft, { default = true })
    return string.format("%s %s", icon, ft)
  end
  handlers.ft = function()
    return handlers.filetype()
  end
  handlers.filename = function()
    local fn = vim.fn.expand("%:t")
    local icon = custom_icon or require("nvim-web-devicons").get_icon(fn, ft, { default = true })
    return string.format("%s %s", icon, fn)
  end
  handlers.fn = function()
    return handlers.filename()
  end
  handlers.path = function()
    local path = opts.relative and vim.fn.expand("%:.") or vim.fn.expand("%:p")
    local fn = vim.fn.expand("%:t")
    local icon = custom_icon or require("nvim-web-devicons").get_icon(fn, ft, { default = true })
    return string.format("%s %s", icon, path)
  end
  local handler = handlers[type]
  if handler then
    return handler()
  else
    return ""
  end
end
function M.line_search_count(opts)
  opts = opts or {}
  return {
    "searchcount",
    maxcount = opts.maxcount or 999,
    timeout = opts.timeout or 500,
  }
end

function M.line_separators(opts)
  opts = opts or {}
  return {
    c_s = { left = "", right = "" },
    s_s = { left = "", right = "" },
  }
end
--local rose_component_ok, rose_lualine = pcall(require, "rose.extensions.lualine")
function M.line_setup(opts)
  M.line_current_theme = M.line_themes[1]
  local separators = M.line_separators()
  opts = opts or {}
  local config = {
    options = {
      icons_enabled = true,
      theme = M.line_current_theme,
      component_separators = separators.c_s,
      section_separators = separators.s_s,
      disabled_filetypes = {
        statusline = {},
        winbar = {},
      },
      always_divide_middle = true,
      globalstatus = false,
      refresh = {
        statusline = 1000,
        tabline = 1000,
        winbar = 1000,
      },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {
        {
          "branch",
          icon = "",
        },
        {
          "diff",
          symbols = { added = "  ", modified = "   ", removed = "   " },
          colored = true,
        },
        {
          function()
            local tag = vim.fn.system("git describe --tags --abbrev=0 2>/dev/null")
            tag = vim.trim(tag)

            if tag == "" then
              return ""
            else
              return "笠 " .. tag
            end
          end,
          cond = function()
            return vim.fn.isdirectory(".git") == 1
          end,
          color = { fg = "#b5bd68", gui = "bold" },
        },
        {
          "diagnostics",
          sources = { "nvim_diagnostic" },
          sections = { "error", "warn", "info", "hint" },
          diagnostics_color = {
            error = { fg = "#e06c75" },
            warn = { fg = "#e5c07b" },
            info = { fg = "#56b6c2" },
            hint = { fg = "#98c379" },
          },
          symbols = {
            error = " ",
            warn = " ",
            info = " ",
            hint = " ",
          },
          colored = true,
          update_in_insert = true,
          always_visible = true,
        },
      },
      lualine_c = {
        {
          function()
            local filetype = vim.bo.filetype
            local icon = require("nvim-web-devicons").get_icon_by_filetype(filetype, { default = true })
            return string.format("%s %s", icon, filetype)
          end,
          color = {},
        },
        {
          function()
            local clients = vim.lsp.get_clients()
            if next(clients) == nil then
              return ""
            end
            local lsp_names = {}
            for _, client in pairs(clients) do
              table.insert(lsp_names, " " .. client.name)
            end
            return table.concat(lsp_names, ", ")
          end,
          icon = " ",
        },
        {
          function()
            local wc = vim.fn.wordcount()
            return string.format("%d words, %d chars", wc.words, wc.chars)
          end,
          icon = " ",
        },
      },
      lualine_x = {
        {
          function()
            local file = vim.fn.expand("%:p")
            if file == "" then
              return ""
            end
            local size = vim.fn.getfsize(file)
            if size < 0 then
              return ""
            end
            local units = { "B", "KB", "MB", "GB", "TB" }
            local i = 1
            while size > 1024 and i < #units do
              size = size / 1024
              i = i + 1
            end
            return string.format("%.1f %s", size, units[i])
          end,
          icon = " ",
        },
        { "searchcount", maxcount = 999, timeout = 500 },
        { "selectioncount" },
      },
      lualine_y = { "progress" },
      lualine_z = { "location", os_data, datetime },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {
        "filename",
      },
      lualine_x = { M.line_inactive_location },
      lualine_y = {},
      lualine_z = {},
    },
    tabline = {},
    winbar = {},
    inactive_winbar = {},
    extensions = M.line_extensions and M.line_extensions() or {},
  }
  if opts then
    config = vim.tbl_deep_extend("force", config, opts)
  end
  require("lualine").setup(config)
end
function M.setup_line(opts)
  M.line_setup(opts)
end
return M
