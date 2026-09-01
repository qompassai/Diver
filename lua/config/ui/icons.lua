-- /qompassai/Diver/lua/config/ui/icons.lua
-- Qompass AI Diver Icons Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
---@param config table|nil Module config table. See |Icons.config|.
---@usage >lua
---   require('.icons').setup() -- use default config
---   -- OR
---   require('icons').setup({}) -- replace {} with your config table
--- <
M.setup = function(config)
  if vim.fn.has('nvim-0.10') == 0 then
    vim.notify(
      '(icons) Neovim<0.10 is soft deprecated (module works but is not supported).'
        .. ' Please update your Neovim version.'
    )
    _G.Icons = M
    config = M.setup_config(config)
    M.apply_config(config)
    M.create_autocommands()
    M.create_default_hl()
  end
end
M.config = {
  style = 'glyph',
  default = {},
  directory = {},
  extension = {},
  file = {},
  filetype = {},
  lsp = {},
  os = {},
  use_file_extension = function()
    return true
  end,
}
M.devicons = {
  override = {
    bash = {
      icon = ' ',
      color = '#4EAA25',
      cterm_color = '35',
      name = 'Bash',
    },
    css = {
      icon = ' ',
      color = '#563d7c',
      cterm_color = '60',
      name = 'CSS',
    },
    docker = {
      icon = ' ',
      color = '#2496ed',
      cterm_color = '33',
      name = 'Docker',
    },
    go = {
      icon = ' ',
      color = '#00ADD8',
      cterm_color = '38',
      name = 'Go',
    },
    haskell = {
      icon = ' ',
      color = '#5e5086',
      cterm_color = '98',
      name = 'Haskell',
    },
    html = {
      icon = ' ',
      color = '#e44d26',
      cterm_color = '202',
      name = 'HTML',
    },
    javascript = {
      icon = ' ',
      color = '#f7df1e',
      cterm_color = '220',
      name = 'JavaScript',
    },
    json = {
      icon = 'ﬥ',
      color = '#cbcb41',
      cterm_color = '185',
      name = 'Json',
    },
    jsonc = {
      icon = 'ﬥ',
      color = '#cbcb41',
      cterm_color = '185',
      name = 'JSONConfig',
    },
    jupyter = {
      icon = ' ',
      color = '#f28e1c',
      cterm_color = '214',
      name = 'Jupyter',
    },
    lua = {
      icon = ' ',
      color = '#56b6c2',
      cterm_color = '74',
      name = 'Lua',
    },
    markdown = {
      icon = ' ',
      color = '#519aba',
      cterm_color = '67',
      name = 'Markdown',
    },
    python = {
      icon = ' ',
      color = '#3572A5',
      cterm_color = '67',
      name = 'Python',
    },
    rust = {
      icon = ' ',
      color = '#dea584',
      cterm_color = '173',
      name = 'Rust',
    },
    sqls = {
      icon = ' ',
      color = '#dad8d8',
      cterm_color = '250',
      name = 'SQL',
    },
    stylua = {
      icon = ' ',
      color = '#56b6c2',
      cterm_color = '74',
      name = 'Stylua',
    },
    svelte = {
      icon = ' ',
      color = '#ff3e00',
      cterm_color = '202',
      name = 'Svelte',
    },
    tailwindcss = {
      icon = '󰞁 ',
      color = '#38bdf8',
      cterm_color = '39',
      name = 'TailwindCSS',
    },
    terraform = {
      icon = ' ',
      color = '#5c4ee5',
      cterm_color = '99',
      name = 'Terraform',
    },
    tex = {
      icon = ' ',
      color = '#3d6117',
      cterm_color = '64',
      name = 'TeX',
    },
    thrift = {
      icon = ' ',
      color = '#D12127',
      cterm_color = '167',
      name = 'Thrift',
    },
    tfsec = {
      icon = ' ',
      color = '#f30067',
      cterm_color = '197',
      name = 'TFSec',
    },
    typescript = {
      icon = ' ',
      color = '#3178c6',
      cterm_color = '68',
      name = 'TypeScript',
    },
    vim = {
      icon = ' ',
      color = '#019833',
      cterm_color = '28',
      name = 'VimLanguageServer',
    },
    vimls = {
      icon = ' ',
      color = '#019833',
      cterm_color = '28',
      name = 'VimLanguageServer',
    },
    yaml = {
      icon = ' ',
      color = '#6e9fda',
      cterm_color = '39',
      name = 'Yaml',
    },
    zsh = {
      icon = ' ',
      color = '#428850',
      cterm_color = '65',
      name = 'Zsh',
    },
  },
  default = true,
  color_icons = true,
}
M.nonicons = {
  default = false,
  icons = {
    ai = '󰞉 ',
    cloud = ' ',
    data = ' ',
    docker = ' ',
    dotnet = ' ',
    edu = ' ',
    file = ' ',
    folder = ' ',
    git_branch = ' ',
    go = ' ',
    js = ' ',
    json = 'ﬥ',
    haskell = ' ',
    java = ' ',
    lua = ' ',
    markdown = ' ',
    nimble = ' ',
    perl = ' ',
    php = ' ',
    python = ' ',
    ruby = ' ',
    rust = ' ',
    scala = ' ',
    sh = ' ',
    swift = ' ',
    toml = ' ',
    yaml = ' ',
    zig = '  ',
  },
}
function M.icons_devicons()
  require('nvim-web-devicons').setup(M.devicons)
  vim.cmd([[
    augroup DevIconsRefresh
      autocmd!
      autocmd BufEnter * lua require('nvim-web-devicons').refresh()
    augroup END
  ]])
end

function M.icons_nonicons()
  require('nvim-nonicons').setup(M.nonicons)
end

M.icons_highlights = function()
  local highlights = {
    MathBlock = {
      bg = '#1e1e2e',
      fg = '#89b4fa',
    },
    CodeBlock = {
      bg = '#1e1e2e',
      fg = '#a6e3a1',
    },
    MarkdownBold = {
      bold = true,
      fg = '#f5c2e7',
    },
    MarkdownItalic = {
      italic = false,
      fg = '#89dceb',
    },
    MarkdownHeading = {
      bold = true,
      fg = '#f38ba8',
    },
  }
  for name, attrs in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, attrs)
  end
end
M.default_icons = {
  default = {
    glyph = '󰟢',
    hl = 'IconsGrey',
  },
  directory = {
    glyph = '󰉋',
    hl = 'IconsAzure',
  },
  extension = {
    glyph = '󰈔',
    hl = 'IconsGrey',
  },
  file = {
    glyph = '󰈔',
    hl = 'IconsGrey',
  },
  filetype = {
    glyph = '󰈔',
    hl = 'IconsGrey',
  },
  lsp = {
    glyph = '󰞋',
    hl = 'IconsRed',
  },
  os = {
    glyph = '󰟀',
    hl = 'IconsPurple',
  },
}
M.directory_icons = {
  ['.cache'] = {
    glyph = '󰪺',
    hl = 'IconsCyan',
  },
  ['.config'] = {
    glyph = '󱁿',
    hl = 'IconsCyan',
  },
  ['.git'] = {
    glyph = '',
    hl = 'IconsOrange',
  },
  ['.github'] = {
    glyph = '',
    hl = 'IconsAzure',
  },
  ['.local'] = {
    glyph = '󰉌',
    hl = 'IconsCyan',
  },
  ['.vim'] = {
    glyph = '󰉋',
    hl = 'IconsGreen',
  },
  AppData = {
    glyph = '󰉌',
    hl = 'IconsOrange',
  },
  Applications = {
    glyph = '󱧺',
    hl = 'IconsOrange',
  },
  Desktop = {
    glyph = '󰚝',
    hl = 'IconsOrange',
  },
  Documents = {
    glyph = '󱧶',
    hl = 'IconsOrange',
  },
  Downloads = {
    glyph = '󰉍',
    hl = 'IconsOrange',
  },
  Favorites = {
    glyph = '󱃪',
    hl = 'IconsOrange',
  },
  Library = {
    glyph = '󰲂',
    hl = 'IconsOrange',
  },
  Music = {
    glyph = '󱍙',
    hl = 'IconsOrange',
  },
  Network = {
    glyph = '󰡰',
    hl = 'IconsOrange',
  },
  Pictures = {
    glyph = '󰉏',
    hl = 'IconsOrange',
  },
  ProgramData = {
    glyph = '󰉌',
    hl = 'IconsOrange',
  },
  Public = {
    glyph = '󱧰',
    hl = 'IconsOrange',
  },
  System = {
    glyph = '󱧼',
    hl = 'IconsOrange',
  },
  Templates = {
    glyph = '󱋣',
    hl = 'IconsOrange',
  },
  Trash = {
    glyph = '󱧴',
    hl = 'IconsOrange',
  },
  Users = {
    glyph = '󰉌',
    hl = 'IconsOrange',
  },
  Videos = {
    glyph = '󱞊',
    hl = 'IconsOrange',
  },
  Volumes = {
    glyph = '󰉓',
    hl = 'IconsOrange',
  },
  autoload = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  bin = {
    glyph = '󱧺',
    hl = 'IconsYellow',
  },
  build = {
    glyph = '󱧼',
    hl = 'IconsGrey',
  },
  boot = {
    glyph = '󰴋',
    hl = 'IconsYellow',
  },
  colors = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  compiler = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  dev = {
    glyph = '󱧼',
    hl = 'IconsYellow',
  },
  doc = {
    glyph = '󱂷',
    hl = 'IconsPurple',
  },
  docs = {
    glyph = '󱂷',
    hl = 'IconsPurple',
  },
  etc = {
    glyph = '󱁿',
    hl = 'IconsYellow',
  },
  ftdetect = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  ftplugin = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  home = {
    glyph = '󱂵',
    hl = 'IconsYellow',
  },
  indent = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  keymap = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  lang = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  lib = {
    glyph = '󰲂',
    hl = 'IconsYellow',
  },
  lsp = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  lua = {
    glyph = '󰉋',
    hl = 'IconsBlue',
  },
  media = {
    glyph = '󱧺',
    hl = 'IconsYellow',
  },
  mnt = {
    glyph = '󰉓',
    hl = 'IconsYellow',
  },
  ['mini.nvim'] = {
    glyph = '󰚝',
    hl = 'IconsRed',
  },
  node_modules = {
    glyph = '',
    hl = 'IconsGreen',
  },
  nvim = {
    glyph = '󰉋',
    hl = 'IconsGreen',
  },
  opt = {
    glyph = '󰉗',
    hl = 'IconsYellow',
  },
  pack = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  parser = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  plugin = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  proc = {
    glyph = '󰢬',
    hl = 'IconsYellow',
  },
  queries = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  rplugin = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  root = {
    glyph = '󰷌',
    hl = 'IconsYellow',
  },
  sbin = {
    glyph = '󱧺',
    hl = 'IconsYellow',
  },
  spell = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  src = {
    glyph = '󰴉',
    hl = 'IconsPurple',
  },
  srv = {
    glyph = '󱋣',
    hl = 'IconsYellow',
  },
  snippets = {
    glyph = '󱁽',
    hl = 'IconsYellow',
  },
  syntax = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  tmp = {
    glyph = '󰪺',
    hl = 'IconsYellow',
  },
  test = {
    glyph = '󱞊',
    hl = 'IconsBlue',
  },
  tests = {
    glyph = '󱞊',
    hl = 'IconsBlue',
  },
  tutor = {
    glyph = '󱁽',
    hl = 'IconsGreen',
  },
  usr = {
    glyph = '󰉌',
    hl = 'IconsYellow',
  },
  var = {
    glyph = '󱋣',
    hl = 'IconsYellow',
  },
}
M.extension_icons = {
  h = {
    glyph = '󰫵',
    hl = 'IconsPurple',
  },
  ipynb = {
    glyph = '󰠮',
    hl = 'IconsOrange',
  },
  exs = {
    glyph = '',
    hl = 'IconsPurple',
  },
  purs = 'purescript',
  tf = 'terraform',
  ['3gp'] = {
    glyph = '󰈫',
    hl = 'IconsYellow',
  },
  avi = {
    glyph = '󰈫',
    hl = 'IconsGrey',
  },
  cast = {
    glyph = '󰈫',
    hl = 'IconsRed',
  },
  m4v = {
    glyph = '󰈫',
    hl = 'IconsOrange',
  },
  mkv = {
    glyph = '󰈫',
    hl = 'IconsGreen',
  },
  mov = {
    glyph = '󰈫',
    hl = 'IconsCyan',
  },
  mp4 = {
    glyph = '󰈫',
    hl = 'IconsAzure',
  },
  mpeg = {
    glyph = '󰈫',
    hl = 'IconsPurple',
  },
  mpg = {
    glyph = '󰈫',
    hl = 'IconsPurple',
  },
  webm = {
    glyph = '󰈫',
    hl = 'IconsGrey',
  },
  wmv = {
    glyph = '󰈫',
    hl = 'IconsBlue',
  },
  aac = {
    glyph = '󰈣',
    hl = 'IconsYellow',
  },
  aif = {
    glyph = '󰈣',
    hl = 'IconsCyan',
  },
  flac = {
    glyph = '󰈣',
    hl = 'IconsOrange',
  },
  m4a = {
    glyph = '󰈣',
    hl = 'IconsPurple',
  },
  mp3 = {
    glyph = '󰈣',
    hl = 'IconsAzure',
  },
  ogg = {
    glyph = '󰈣',
    hl = 'IconsGrey',
  },
  snd = {
    glyph = '󰈣',
    hl = 'IconsRed',
  },
  wav = {
    glyph = '󰈣',
    hl = 'IconsGreen',
  },
  wma = {
    glyph = '󰈣',
    hl = 'IconsBlue',
  },
  bmp = {
    glyph = '󰈟',
    hl = 'IconsGreen',
  },
  eps = {
    glyph = '',
    hl = 'IconsRed',
  },
  gif = {
    glyph = '󰵸',
    hl = 'IconsAzure',
  },
  jpeg = {
    glyph = '󰈥',
    hl = 'IconsOrange',
  },
  jpg = {
    glyph = '󰈥',
    hl = 'IconsOrange',
  },
  png = {
    glyph = '󰸭',
    hl = 'IconsPurple',
  },
  tif = {
    glyph = '󰈟',
    hl = 'IconsYellow',
  },
  tiff = {
    glyph = '󰈟',
    hl = 'IconsYellow',
  },
  webp = {
    glyph = '󰈟',
    hl = 'IconsBlue',
  },
  ['7z'] = {
    glyph = '󰗄',
    hl = 'IconsBlue',
  },
  bz = {
    glyph = '󰗄',
    hl = 'IconsOrange',
  },
  bz2 = {
    glyph = '󰗄',
    hl = 'IconsOrange',
  },
  bz3 = {
    glyph = '󰗄',
    hl = 'IconsOrange',
  },
  gz = {
    glyph = '󰗄',
    hl = 'IconsGrey',
  },
  rar = {
    glyph = '󰗄',
    hl = 'IconsGreen',
  },
  rpm = {
    glyph = '󰗄',
    hl = 'IconsRed',
  },
  sit = {
    glyph = '󰗄',
    hl = 'IconsRed',
  },
  tar = {
    glyph = '󰗄',
    hl = 'IconsCyan',
  },
  tgz = {
    glyph = '󰗄',
    hl = 'IconsGrey',
  },
  txz = {
    glyph = '󰗄',
    hl = 'IconsPurple',
  },
  xz = {
    glyph = '󰗄',
    hl = 'IconsGreen',
  },
  z = {
    glyph = '󰗄',
    hl = 'IconsGrey',
  },
  zip = {
    glyph = '󰗄',
    hl = 'IconsAzure',
  },
  zst = {
    glyph = '󰗄',
    hl = 'IconsYellow',
  },
  doc = {
    glyph = '󱎒',
    hl = 'IconsAzure',
  },
  docm = {
    glyph = '󱎒',
    hl = 'IconsAzure',
  },
  docx = {
    glyph = '󱎒',
    hl = 'IconsAzure',
  },
  dot = {
    glyph = '󱎒',
    hl = 'IconsAzure',
  },
  dotx = {
    glyph = '󱎒',
    hl = 'IconsAzure',
  },
  exe = {
    glyph = '󰖳',
    hl = 'IconsRed',
  },
  pps = {
    glyph = '󱎐',
    hl = 'IconsRed',
  },
  ppsm = {
    glyph = '󱎐',
    hl = 'IconsRed',
  },
  ppsx = {
    glyph = '󱎐',
    hl = 'IconsRed',
  },
  ppt = {
    glyph = '󱎐',
    hl = 'IconsRed',
  },
  pptm = {
    glyph = '󱎐',
    hl = 'IconsRed',
  },
  pptx = {
    glyph = '󱎐',
    hl = 'IconsRed',
  },
  xls = {
    glyph = '󱎏',
    hl = 'IconsGreen',
  },
  xlsm = {
    glyph = '󱎏',
    hl = 'IconsGreen',
  },
  xlsx = {
    glyph = '󱎏',
    hl = 'IconsGreen',
  },
  xlt = {
    glyph = '󱎏',
    hl = 'IconsGreen',
  },
  xltm = {
    glyph = '󱎏',
    hl = 'IconsGreen',
  },
  xltx = {
    glyph = '󱎏',
    hl = 'IconsGreen',
  },

  ['code-snippets'] = 'json',
}
M.file_icons = {
  ['.DS_Store'] = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  ['.bash_profile'] = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  ['.bashrc'] = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  ['.git'] = {
    glyph = '󰊢',
    hl = 'IconsOrange',
  },
  ['.gitlab-ci.yml'] = {
    glyph = '󰮠',
    hl = 'IconsOrange',
  },
  ['.gitkeep'] = {
    glyph = '󰊢',
    hl = 'IconsRed',
  },
  ['.mailmap'] = {
    glyph = '󰊢',
    hl = 'IconsCyan',
  },
  ['.nvmrc'] = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  ['.xinitrc'] = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  ['.zshrc'] = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  CHANGELOG = {
    glyph = '󰉻',
    hl = 'IconsBlue',
  },
  ['CHANGELOG.md'] = {
    glyph = '󰉻',
    hl = 'IconsBlue',
  },
  CODE_OF_CONDUCT = {
    glyph = '󱃱',
    hl = 'IconsRed',
  },
  ['CODE_OF_CONDUCT.md'] = {
    glyph = '󱃱',
    hl = 'IconsRed',
  },
  CODEOWNERS = {
    glyph = '󰜻',
    hl = 'IconsPurple',
  },
  CONTRIBUTING = {
    glyph = '󰺾',
    hl = 'IconsAzure',
  },
  ['CONTRIBUTING.md'] = {
    glyph = '󰺾',
    hl = 'IconsAzure',
  },
  ['FUNDING.yml'] = {
    glyph = '󰇁',
    hl = 'IconsGreen',
  },
  LICENSE = {
    glyph = '',
    hl = 'IconsCyan',
  },
  ['LICENSE.md'] = {
    glyph = '',
    hl = 'IconsCyan',
  },
  ['LICENSE.txt'] = {
    glyph = '',
    hl = 'IconsCyan',
  },
  NEWS = {
    glyph = '󰎕',
    hl = 'IconsBlue',
  },
  ['NEWS.md'] = {
    glyph = '󰎕',
    hl = 'IconsBlue',
  },
  PKGBUILD = {
    glyph = '󱁤',
    hl = 'IconsPurple',
  },
  README = {
    glyph = '',
    hl = 'IconsYellow',
  },
  ['README.md'] = {
    glyph = '',
    hl = 'IconsYellow',
  },
  ['README.txt'] = {
    glyph = '',
    hl = 'IconsYellow',
  },
  TODO = {
    glyph = '󰝖',
    hl = 'IconsPurple',
  },
  ['TODO.md'] = {
    glyph = '󰝖',
    hl = 'IconsPurple',
  },
  ['init.lua'] = {
    glyph = '',
    hl = 'IconsGreen',
  },
  ['build.xml'] = 'ant',
  ['GNUmakefile.am'] = 'automake',
  ['Makefile.am'] = 'automake',
  ['makefile.am'] = 'automake',
  ['CMakeLists.txt'] = 'cmake',
  ['CMakeCache.txt'] = 'cmakecache',
  ['auto.master'] = 'conf',
  ['.oelint.cfg'] = 'dosini',
  ['.wakatime.cfg'] = 'dosini',
  ['pudb.cfg'] = 'dosini',
  ['setup.cfg'] = 'dosini',
  ['lltxxxxx.txt'] = 'gedcom',
  ['go.sum'] = 'gosum',
  ['go.work.sum'] = 'gosum',
  ['.indent.pro'] = 'indent',
  ['indent.pro'] = 'indent',
  ['ipf.rules'] = 'ipfilter',
  ['config.ld'] = 'lua',
  ['lynx.cfg'] = 'lynx',
  ['cm3.cfg'] = 'm3quake',
  ['maxima-init.mac'] = 'maxima',
  ['meson_options.txt'] = 'meson',
  ['.gitolite.rc'] = 'perl',
  ['example.gitolite.rc'] = 'perl',
  ['gitolite.rc'] = 'perl',
  ['main.cf.proto'] = 'pfmain',
  ['constraints.txt'] = 'requirements',
  ['requirements.txt'] = 'requirements',
  ['robots.txt'] = 'robots',
  ['tclsh.rc'] = 'tcl',
  ['.containerignore'] = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  ['.dockerignore'] = {
    glyph = '󰡨',
    hl = 'IconsOrange',
  },
  ['.fdignore'] = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  ['.ignore'] = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  ['.npmignore'] = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  ['.prettierignore'] = {
    glyph = '',
    hl = 'IconsOrange',
  },
  ['.rgignore'] = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  ['.vscodeignore'] = {
    glyph = '',
    hl = 'IconsAzure',
  },
}
M.filetype_icons = {
  ['8th'] = {
    glyph = '󰭁',
    hl = 'IconsYellow',
  },
  a2ps = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  a65 = {
    glyph = '',
    hl = 'IconsRed',
  },
  aap = {
    glyph = '󰫮',
    hl = 'IconsOrange',
  },
  abap = {
    glyph = '󰫮',
    hl = 'IconsGreen',
  },
  abaqus = {
    glyph = '󰫮',
    hl = 'IconsGreen',
  },
  abc = {
    glyph = '󰝚',
    hl = 'IconsAzure',
  },
  abel = {
    glyph = '󰫮',
    hl = 'IconsAzure',
  },
  abnf = {
    glyph = '󰫮',
    hl = 'IconsYellow',
  },
  acedb = {
    glyph = '󰆼',
    hl = 'IconsGrey',
  },
  ada = {
    glyph = '󱁷',
    hl = 'IconsAzure',
  },
  aflex = {
    glyph = '󰫮',
    hl = 'IconsCyan',
  },
  ahdl = {
    glyph = '󰫮',
    hl = 'IconsRed',
  },
  aidl = {
    glyph = '󰫮',
    hl = 'IconsYellow',
  },
  alsaconf = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  amiga = {
    glyph = '󰫮',
    hl = 'IconsCyan',
  },
  aml = {
    glyph = '󰫮',
    hl = 'IconsPurple',
  },
  ampl = {
    glyph = '󰫮',
    hl = 'IconsOrange',
  },
  ant = {
    glyph = '󰫮',
    hl = 'IconsRed',
  },
  antlr = {
    glyph = '󰫮',
    hl = 'IconsCyan',
  },
  antlr4 = {
    glyph = '󰫮',
    hl = 'IconsYellow',
  },
  apache = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  apachestyle = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  apkbuild = {
    glyph = '󱁤',
    hl = 'IconsBlue',
  },
  applescript = {
    glyph = '󰀵',
    hl = 'IconsYellow',
  },
  aptconf = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  arch = {
    glyph = '󰣇',
    hl = 'IconsBlue',
  },
  arduino = {
    glyph = '',
    hl = 'IconsAzure',
  },
  art = {
    glyph = '󰫮',
    hl = 'IconsPurple',
  },
  asciidoc = {
    glyph = '󰪶',
    hl = 'IconsYellow',
  },
  asm = {
    glyph = '',
    hl = 'IconsPurple',
  },
  asm68k = {
    glyph = '',
    hl = 'IconsRed',
  },
  asmh8300 = {
    glyph = '',
    hl = 'IconsOrange',
  },
  asn = {
    glyph = '󰫮',
    hl = 'IconsBlue',
  },
  aspperl = {
    glyph = '',
    hl = 'IconsBlue',
  },
  aspvbs = {
    glyph = '󰫮',
    hl = 'IconsGreen',
  },
  asterisk = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  asteriskvm = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  astro = {
    glyph = '',
    hl = 'IconsOrange',
  },
  asy = {
    glyph = '󰫮',
    hl = 'IconsAzure',
  },
  atlas = {
    glyph = '󰫮',
    hl = 'IconsAzure',
  },
  authzed = {
    glyph = '󰫮',
    hl = 'IconsYellow',
  },
  autodoc = {
    glyph = '󰪶',
    hl = 'IconsGreen',
  },
  autohotkey = {
    glyph = '󰫮',
    hl = 'IconsYellow',
  },
  autoit = {
    glyph = '󰫮',
    hl = 'IconsCyan',
  },
  automake = {
    glyph = '󱁤',
    hl = 'IconsPurple',
  },
  autopkgtest = {
    glyph = '󰣚',
    hl = 'IconsRed',
  },
  ave = {
    glyph = '󰫮',
    hl = 'IconsGrey',
  },
  avra = {
    glyph = '',
    hl = 'IconsPurple',
  },
  awk = {
    glyph = '',
    hl = 'IconsGrey',
  },
  ayacc = {
    glyph = '󰫮',
    hl = 'IconsCyan',
  },
  b = {
    glyph = '󰫯',
    hl = 'IconsYellow',
  },
  baan = {
    glyph = '󰫯',
    hl = 'IconsOrange',
  },
  bash = {
    glyph = '',
    hl = 'IconsGreen',
  },
  basic = {
    glyph = '󰫯',
    hl = 'IconsPurple',
  },
  bass = {
    glyph = '󰋄',
    hl = 'IconsBlue',
  },
  bat = {
    glyph = '󰭟',
    hl = 'IconsGrey',
  },
  bc = {
    glyph = '󰫯',
    hl = 'IconsCyan',
  },
  bdf = {
    glyph = '󰛖',
    hl = 'IconsRed',
  },
  beancount = {
    glyph = '󰫯',
    hl = 'IconsAzure',
  },
  bib = {
    glyph = '󱉟',
    hl = 'IconsYellow',
  },
  bicep = {
    glyph = '',
    hl = 'IconsCyan',
  },
  ['bicep-params'] = {
    glyph = '',
    hl = 'IconsPurple',
  },
  bindzone = {
    glyph = '󰫯',
    hl = 'IconsCyan',
  },
  bitbake = {
    glyph = '󰃫',
    hl = 'IconsOrange',
  },
  blade = {
    glyph = '󰫐',
    hl = 'IconsRed',
  },
  blank = {
    glyph = '󰫯',
    hl = 'IconsPurple',
  },
  blueprint = {
    glyph = '󰠡',
    hl = 'IconsBlue',
  },
  bp = {
    glyph = '󰫯',
    hl = 'IconsYellow',
  },
  bpftrace = {
    glyph = '󰾡',
    hl = 'IconsYellow',
  },
  brighterscript = {
    glyph = '󰫯',
    hl = 'IconsAzure',
  },
  brightscript = {
    glyph = '󰫯',
    hl = 'IconsPurple',
  },
  bsdl = {
    glyph = '󰫯',
    hl = 'IconsPurple',
  },
  bst = {
    glyph = '󰫯',
    hl = 'IconsCyan',
  },
  btm = {
    glyph = '󰫯',
    hl = 'IconsGreen',
  },
  bzl = {
    glyph = '',
    hl = 'IconsGreen',
  },
  bzr = {
    glyph = '󰜘',
    hl = 'IconsRed',
  },
  c = {
    glyph = '󰙱',
    hl = 'IconsBlue',
  },
  c3 = {
    glyph = '󰙱',
    hl = 'IconsPurple',
  },
  cabal = {
    glyph = '󰲒',
    hl = 'IconsBlue',
  },
  cabalconfig = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  cabalproject = {
    glyph = '󰫰',
    hl = 'IconsBlue',
  },
  cairo = {
    glyph = '󰫰',
    hl = 'IconsOrange',
  },
  calendar = {
    glyph = '󰃵',
    hl = 'IconsRed',
  },
  cangjie = {
    glyph = '󰫰',
    hl = 'IconsBlue',
  },
  capnp = {
    glyph = '󰫰',
    hl = 'IconsBlue',
  },
  catalog = {
    glyph = '󰕲',
    hl = 'IconsGrey',
  },
  cdc = {
    glyph = '󰻫',
    hl = 'IconsRed',
  },
  cdl = {
    glyph = '󰫰',
    hl = 'IconsOrange',
  },
  cdrdaoconf = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  cdrtoc = {
    glyph = '󰠶',
    hl = 'IconsRed',
  },
  cedar = {
    glyph = '󰐅',
    hl = 'IconsGreen',
  },
  cf = {
    glyph = '󰫰',
    hl = 'IconsRed',
  },
  cfengine = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  cfg = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  cgdbrc = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  ch = {
    glyph = '󰫰',
    hl = 'IconsCyan',
  },
  chaiscript = {
    glyph = '󰶞',
    hl = 'IconsOrange',
  },
  change = {
    glyph = '󰹳',
    hl = 'IconsYellow',
  },
  changelog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  chaskell = {
    glyph = '󰲒',
    hl = 'IconsGreen',
  },
  chatito = {
    glyph = '󰫰',
    hl = 'IconsCyan',
  },
  checkhealth = {
    glyph = '󰓙',
    hl = 'IconsBlue',
  },
  cheetah = {
    glyph = '󰫰',
    hl = 'IconsGrey',
  },
  chicken = {
    glyph = '󰫰',
    hl = 'IconsRed',
  },
  chill = {
    glyph = '󰫰',
    hl = 'IconsBlue',
  },
  chordpro = {
    glyph = '󰫰',
    hl = 'IconsGreen',
  },
  chuck = {
    glyph = '󰫰',
    hl = 'IconsBlue',
  },
  cl = {
    glyph = '󰫰',
    hl = 'IconsCyan',
  },
  clean = {
    glyph = '󰫰',
    hl = 'IconsBlue',
  },
  clipper = {
    glyph = '󰫰',
    hl = 'IconsPurple',
  },
  clojure = {
    glyph = '',
    hl = 'IconsGreen',
  },
  cmake = {
    glyph = '󱁤',
    hl = 'IconsOrange',
  },
  cmakecache = {
    glyph = '󱁤',
    hl = 'IconsRed',
  },
  cmod = {
    glyph = '󰫰',
    hl = 'IconsCyan',
  },
  cmusrc = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  cobol = {
    glyph = '󱌼',
    hl = 'IconsBlue',
  },
  coco = {
    glyph = '󰫰',
    hl = 'IconsRed',
  },
  codeowners = {
    glyph = '󰈮',
    hl = 'IconsBlue',
  },
  conaryrecipe = {
    glyph = '󰫰',
    hl = 'IconsGrey',
  },
  conf = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  config = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  confini = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  context = {
    glyph = '',
    hl = 'IconsGreen',
  },
  cook = {
    glyph = '󰆘',
    hl = 'IconsBlue',
  },
  coq = {
    glyph = '󱍓',
    hl = 'IconsAzure',
  },
  corn = {
    glyph = '󰞸',
    hl = 'IconsYellow',
  },
  cpon = {
    glyph = '󰫰',
    hl = 'IconsCyan',
  },
  cpp = {
    glyph = '󰙲',
    hl = 'IconsAzure',
  },
  cqlang = {
    glyph = '󰫰',
    hl = 'IconsYellow',
  },
  crm = {
    glyph = '󰫰',
    hl = 'IconsGreen',
  },
  crontab = {
    glyph = '󰔠',
    hl = 'IconsAzure',
  },
  crystal = {
    glyph = '',
    hl = 'IconsGrey',
  },
  cs = {
    glyph = '󰌛',
    hl = 'IconsGreen',
  },
  csc = {
    glyph = '󰫰',
    hl = 'IconsBlue',
  },
  csdl = {
    glyph = '󰫰',
    hl = 'IconsCyan',
  },
  csh = {
    glyph = '',
    hl = 'IconsGrey',
  },
  csp = {
    glyph = '󰫰',
    hl = 'IconsAzure',
  },
  css = {
    glyph = '󰌜',
    hl = 'IconsAzure',
  },
  csv = {
    glyph = '',
    hl = 'IconsGreen',
  },
  csv_pipe = {
    glyph = '',
    hl = 'IconsAzure',
  },
  csv_semicolon = {
    glyph = '',
    hl = 'IconsRed',
  },
  csv_whitespace = {
    glyph = '',
    hl = 'IconsPurple',
  },
  cterm = {
    glyph = '󰫰',
    hl = 'IconsCyan',
  },
  ctrlh = {
    glyph = '󰫰',
    hl = 'IconsOrange',
  },
  cucumber = {
    glyph = '󰫰',
    hl = 'IconsPurple',
  },
  cuda = {
    glyph = '',
    hl = 'IconsGreen',
  },
  cue = {
    glyph = '󰝚',
    hl = 'IconsYellow',
  },
  cupl = {
    glyph = '󰫰',
    hl = 'IconsOrange',
  },
  cuplsim = {
    glyph = '󰫰',
    hl = 'IconsPurple',
  },
  cvs = {
    glyph = '󰜘',
    hl = 'IconsGreen',
  },
  cvsrc = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  cweb = {
    glyph = '󰫰',
    hl = 'IconsCyan',
  },
  cynlib = {
    glyph = '󰙲',
    hl = 'IconsPurple',
  },
  cynpp = {
    glyph = '󰙲',
    hl = 'IconsYellow',
  },
  cypher = {
    glyph = '󰫰',
    hl = 'IconsOrange',
  },
  d = {
    glyph = '',
    hl = 'IconsGreen',
  },
  dafny = {
    glyph = '󰫱',
    hl = 'IconsYellow',
  },
  dart = {
    glyph = '',
    hl = 'IconsBlue',
  },
  datascript = {
    glyph = '󰫱',
    hl = 'IconsGreen',
  },
  dax = {
    glyph = '󰫱',
    hl = 'IconsBlue',
  },
  dcd = {
    glyph = '󰫱',
    hl = 'IconsCyan',
  },
  dcl = {
    glyph = '󰫱',
    hl = 'IconsAzure',
  },
  deb822sources = {
    glyph = '󰫱',
    hl = 'IconsCyan',
  },
  debchangelog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  debcontrol = {
    glyph = '󰣚',
    hl = 'IconsOrange',
  },
  debcopyright = {
    glyph = '󰣚',
    hl = 'IconsRed',
  },
  debsources = {
    glyph = '󰫱',
    hl = 'IconsYellow',
  },
  def = {
    glyph = '󰫱',
    hl = 'IconsGrey',
  },
  denyhosts = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  dep3patch = {
    glyph = '󰫱',
    hl = 'IconsCyan',
  },
  desc = {
    glyph = '󰫱',
    hl = 'IconsCyan',
  },
  desktop = {
    glyph = '󰍹',
    hl = 'IconsPurple',
  },
  dhall = {
    glyph = '󰏪',
    hl = 'IconsOrange',
  },
  dictconf = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  dictdconf = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  diff = {
    glyph = '󰦓',
    hl = 'IconsRed',
  },
  dircolors = {
    glyph = '󰫱',
    hl = 'IconsRed',
  },
  dirpager = {
    glyph = '󰙅',
    hl = 'IconsYellow',
  },
  diva = {
    glyph = '󰫱',
    hl = 'IconsRed',
  },
  django = {
    glyph = '',
    hl = 'IconsGreen',
  },
  djot = {
    glyph = '󰫱',
    hl = 'IconsYellow',
  },
  dns = {
    glyph = '󰫱',
    hl = 'IconsOrange',
  },
  dnsmasq = {
    glyph = '󰫱',
    hl = 'IconsGrey',
  },
  docbk = {
    glyph = '󰫱',
    hl = 'IconsYellow',
  },
  docbksgml = {
    glyph = '󰫱',
    hl = 'IconsGrey',
  },
  docbkxml = {
    glyph = '󰫱',
    hl = 'IconsGrey',
  },
  dockerfile = {
    glyph = '󰡨',
    hl = 'IconsBlue',
  },
  dosbatch = {
    glyph = '󰯂',
    hl = 'IconsGreen',
  },
  dosini = {
    glyph = '󰯂',
    hl = 'IconsAzure',
  },
  dot = {
    glyph = '󱁉',
    hl = 'IconsAzure',
  },
  doxygen = {
    glyph = '󰋘',
    hl = 'IconsBlue',
  },
  dracula = {
    glyph = '󰭟',
    hl = 'IconsGrey',
  },
  dsl = {
    glyph = '󰫱',
    hl = 'IconsAzure',
  },
  dtd = {
    glyph = '󰫱',
    hl = 'IconsCyan',
  },
  dtml = {
    glyph = '󰫱',
    hl = 'IconsRed',
  },
  dtrace = {
    glyph = '󰫱',
    hl = 'IconsRed',
  },
  dts = {
    glyph = '󰫱',
    hl = 'IconsRed',
  },
  dune = {
    glyph = '',
    hl = 'IconsGreen',
  },
  dylan = {
    glyph = '󰫱',
    hl = 'IconsRed',
  },
  dylanintr = {
    glyph = '󰫱',
    hl = 'IconsGrey',
  },
  dylanlid = {
    glyph = '󰫱',
    hl = 'IconsOrange',
  },
  earthfile = {
    glyph = '󰫲',
    hl = 'IconsAzure',
  },
  ecd = {
    glyph = '󰫲',
    hl = 'IconsPurple',
  },
  edif = {
    glyph = '󰫲',
    hl = 'IconsCyan',
  },
  editorconfig = {
    glyph = '',
    hl = 'IconsGrey',
  },
  eelixir = {
    glyph = '',
    hl = 'IconsYellow',
  },
  eiffel = {
    glyph = '󱕫',
    hl = 'IconsYellow',
  },
  elf = {
    glyph = '󰫲',
    hl = 'IconsGreen',
  },
  elinks = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  elixir = {
    glyph = '',
    hl = 'IconsPurple',
  },
  elm = {
    glyph = '',
    hl = 'IconsAzure',
  },
  elmfilt = {
    glyph = '󰫲',
    hl = 'IconsBlue',
  },
  elsa = {
    glyph = '󰘧',
    hl = 'IconsGreen',
  },
  elvish = {
    glyph = '',
    hl = 'IconsGreen',
  },
  epuppet = {
    glyph = '',
    hl = 'IconsYellow',
  },
  erlang = {
    glyph = '',
    hl = 'IconsRed',
  },
  eruby = {
    glyph = '󰴭',
    hl = 'IconsOrange',
  },
  esdl = {
    glyph = '󰆼',
    hl = 'IconsCyan',
  },
  esmtprc = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  esqlc = {
    glyph = '󰆼',
    hl = 'IconsGrey',
  },
  esterel = {
    glyph = '󰫲',
    hl = 'IconsAzure',
  },
  eterm = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  euphoria3 = {
    glyph = '󰫲',
    hl = 'IconsRed',
  },
  euphoria4 = {
    glyph = '󰫲',
    hl = 'IconsYellow',
  },
  eviews = {
    glyph = '󰫲',
    hl = 'IconsCyan',
  },
  execline = {
    glyph = '󰫲',
    hl = 'IconsAzure',
  },
  exim = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  expect = {
    glyph = '󰫲',
    hl = 'IconsGrey',
  },
  exports = {
    glyph = '󰈇',
    hl = 'IconsPurple',
  },
  factor = {
    glyph = '󰫳',
    hl = 'IconsAzure',
  },
  falcon = {
    glyph = '󱗆',
    hl = 'IconsOrange',
  },
  fan = {
    glyph = '󰫳',
    hl = 'IconsAzure',
  },
  fasm = {
    glyph = '',
    hl = 'IconsPurple',
  },
  faust = {
    glyph = '󰫳',
    hl = 'IconsYellow',
  },
  fdcc = {
    glyph = '󰫳',
    hl = 'IconsBlue',
  },
  fennel = {
    glyph = '',
    hl = 'IconsYellow',
  },
  fetchmail = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  fgl = {
    glyph = '󰫳',
    hl = 'IconsCyan',
  },
  firrtl = {
    glyph = '󰫳',
    hl = 'IconsGreen',
  },
  fish = {
    glyph = '',
    hl = 'IconsGrey',
  },
  flexwiki = {
    glyph = '󰖬',
    hl = 'IconsPurple',
  },
  flix = {
    glyph = '󰫳',
    hl = 'IconsGreen',
  },
  fluent = {
    glyph = '󰫳',
    hl = 'IconsAzure',
  },
  foam = {
    glyph = '󰫳',
    hl = 'IconsBlue',
  },
  focexec = {
    glyph = '󰫳',
    hl = 'IconsPurple',
  },
  form = {
    glyph = '󰫳',
    hl = 'IconsCyan',
  },
  forth = {
    glyph = '󰬽',
    hl = 'IconsRed',
  },
  fortran = {
    glyph = '󱈚',
    hl = 'IconsPurple',
  },
  foxpro = {
    glyph = '󰫳',
    hl = 'IconsGreen',
  },
  fpcmake = {
    glyph = '󱁤',
    hl = 'IconsRed',
  },
  framescript = {
    glyph = '󰫳',
    hl = 'IconsCyan',
  },
  freebasic = {
    glyph = '󰫳',
    hl = 'IconsOrange',
  },
  fsh = {
    glyph = '󰫳',
    hl = 'IconsOrange',
  },
  fsharp = {
    glyph = '',
    hl = 'IconsBlue',
  },
  fstab = {
    glyph = '󰋊',
    hl = 'IconsGrey',
  },
  func = {
    glyph = '󰫳',
    hl = 'IconsCyan',
  },
  fusion = {
    glyph = '󰫳',
    hl = 'IconsYellow',
  },
  fvwm = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  fvwm2m4 = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  gdb = {
    glyph = '󰈺',
    hl = 'IconsGrey',
  },
  gdmo = {
    glyph = '󰫴',
    hl = 'IconsBlue',
  },
  gdresource = {
    glyph = '',
    hl = 'IconsGreen',
  },
  gdscript = {
    glyph = '',
    hl = 'IconsYellow',
  },
  gdshader = {
    glyph = '',
    hl = 'IconsPurple',
  },
  gedcom = {
    glyph = '󰫴',
    hl = 'IconsRed',
  },
  gel = {
    glyph = '󰫴',
    hl = 'IconsCyan',
  },
  gemtext = {
    glyph = '󰪁',
    hl = 'IconsAzure',
  },
  gift = {
    glyph = '󰹄',
    hl = 'IconsRed',
  },
  git = {
    glyph = '󰊢',
    hl = 'IconsOrange',
  },
  gitattributes = {
    glyph = '󰊢',
    hl = 'IconsYellow',
  },
  gitcommit = {
    glyph = '󰊢',
    hl = 'IconsGreen',
  },
  gitconfig = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  gitignore = {
    glyph = '󰊢',
    hl = 'IconsPurple',
  },
  gitolite = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  gitrebase = {
    glyph = '󰊢',
    hl = 'IconsAzure',
  },
  gitsendemail = {
    glyph = '󰊢',
    hl = 'IconsBlue',
  },
  gkrellmrc = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  gleam = {
    glyph = '󰦥',
    hl = 'IconsPurple',
  },
  glsl = {
    glyph = '󰫴',
    hl = 'IconsCyan',
  },
  gn = {
    glyph = '󰫴',
    hl = 'IconsGrey',
  },
  gnash = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  gnuplot = {
    glyph = '󰺒',
    hl = 'IconsPurple',
  },
  go = {
    glyph = '󰟓',
    hl = 'IconsAzure',
  },
  goaccess = {
    glyph = '󰫴',
    hl = 'IconsPurple',
  },
  godoc = {
    glyph = '󰟓',
    hl = 'IconsOrange',
  },
  gomod = {
    glyph = '󰟓',
    hl = 'IconsAzure',
  },
  gosum = {
    glyph = '󰟓',
    hl = 'IconsCyan',
  },
  gowork = {
    glyph = '󰟓',
    hl = 'IconsPurple',
  },
  gp = {
    glyph = '󰫴',
    hl = 'IconsCyan',
  },
  gpg = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  gprof = {
    glyph = '󰫴',
    hl = 'IconsAzure',
  },
  grads = {
    glyph = '󰫴',
    hl = 'IconsPurple',
  },
  graphql = {
    glyph = '󰡷',
    hl = 'IconsRed',
  },
  gretl = {
    glyph = '󰫴',
    hl = 'IconsCyan',
  },
  groff = {
    glyph = '󰫴',
    hl = 'IconsYellow',
  },
  groovy = {
    glyph = '',
    hl = 'IconsAzure',
  },
  group = {
    glyph = '󰫴',
    hl = 'IconsCyan',
  },
  grub = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  gsp = {
    glyph = '󰫴',
    hl = 'IconsYellow',
  },
  gtkrc = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  gvpr = {
    glyph = '󰫴',
    hl = 'IconsBlue',
  },
  gyp = {
    glyph = '󰫴',
    hl = 'IconsPurple',
  },
  hack = {
    glyph = '󰫵',
    hl = 'IconsPurple',
  },
  haml = {
    glyph = '󰅴',
    hl = 'IconsGrey',
  },
  hamster = {
    glyph = '󰫵',
    hl = 'IconsCyan',
  },
  handlebars = {
    glyph = '󰌞',
    hl = 'IconsGreen',
  },
  hare = {
    glyph = '󰫵',
    hl = 'IconsRed',
  },
  haredoc = {
    glyph = '󰪶',
    hl = 'IconsGrey',
  },
  haskell = {
    glyph = '󰲒',
    hl = 'IconsPurple',
  },
  haskellpersistent = {
    glyph = '󰲒',
    hl = 'IconsAzure',
  },
  haste = {
    glyph = '󰫵',
    hl = 'IconsYellow',
  },
  hastepreproc = {
    glyph = '󰫵',
    hl = 'IconsCyan',
  },
  haxe = {
    glyph = '󰫵',
    hl = 'IconsGrey',
  },
  hb = {
    glyph = '󰫵',
    hl = 'IconsGreen',
  },
  hcl = {
    glyph = '󰫵',
    hl = 'IconsAzure',
  },
  heex = {
    glyph = '',
    hl = 'IconsRed',
  },
  helm = {
    glyph = '󰠳',
    hl = 'IconsBlue',
  },
  help = {
    glyph = '󰋖',
    hl = 'IconsPurple',
  },
  hercules = {
    glyph = '󰫵',
    hl = 'IconsRed',
  },
  hex = {
    glyph = '󰋘',
    hl = 'IconsYellow',
  },
  hgcommit = {
    glyph = '󰜘',
    hl = 'IconsGrey',
  },
  hjson = {
    glyph = '󰘦',
    hl = 'IconsGreen',
  },
  hlsplaylist = {
    glyph = '󰲸',
    hl = 'IconsOrange',
  },
  hog = {
    glyph = '󰫵',
    hl = 'IconsOrange',
  },
  hollywood = {
    glyph = '󰓎',
    hl = 'IconsYellow',
  },
  hoon = {
    glyph = '󰫵',
    hl = 'IconsCyan',
  },
  hostconf = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  hostsaccess = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  html = {
    glyph = '󰌝',
    hl = 'IconsOrange',
  },
  htmlangular = {
    glyph = '󰚲',
    hl = 'IconsRed',
  },
  htmlcheetah = {
    glyph = '󰌝',
    hl = 'IconsYellow',
  },
  htmldjango = {
    glyph = '󰌝',
    hl = 'IconsGreen',
  },
  htmlm4 = {
    glyph = '󰌝',
    hl = 'IconsRed',
  },
  htmlos = {
    glyph = '󰌝',
    hl = 'IconsAzure',
  },
  httest = {
    glyph = '󰫵',
    hl = 'IconsGrey',
  },
  http = {
    glyph = '󰌷',
    hl = 'IconsOrange',
  },
  hurl = {
    glyph = '󰫵',
    hl = 'IconsGreen',
  },
  hy = {
    glyph = '󰫵',
    hl = 'IconsGrey',
  },
  hylo = {
    glyph = '󰫵',
    hl = 'IconsYellow',
  },
  hyprlang = {
    glyph = '',
    hl = 'IconsCyan',
  },
  i3config = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  ia64 = {
    glyph = '',
    hl = 'IconsPurple',
  },
  ibasic = {
    glyph = '󰫶',
    hl = 'IconsOrange',
  },
  icemenu = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  icon = {
    glyph = '󰫶',
    hl = 'IconsGreen',
  },
  idl = {
    glyph = '󰫶',
    hl = 'IconsRed',
  },
  idlang = {
    glyph = '󱗿',
    hl = 'IconsAzure',
  },
  idris2 = {
    glyph = '󰫶',
    hl = 'IconsGrey',
  },
  indent = {
    glyph = '󰉶',
    hl = 'IconsGreen',
  },
  info = {
    glyph = '󰫶',
    hl = 'IconsAzure',
  },
  inform = {
    glyph = '󰫶',
    hl = 'IconsOrange',
  },
  initex = {
    glyph = '',
    hl = 'IconsGreen',
  },
  initng = {
    glyph = '󰫶',
    hl = 'IconsAzure',
  },
  inittab = {
    glyph = '󰫶',
    hl = 'IconsBlue',
  },
  inko = {
    glyph = '󱗆',
    hl = 'IconsGreen',
  },
  ipfilter = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  ipkg = {
    glyph = '󰫶',
    hl = 'IconsGrey',
  },
  ishd = {
    glyph = '󰫶',
    hl = 'IconsYellow',
  },
  iss = {
    glyph = '󰏗',
    hl = 'IconsBlue',
  },
  ist = {
    glyph = '󰫶',
    hl = 'IconsCyan',
  },
  j = {
    glyph = '󰫷',
    hl = 'IconsAzure',
  },
  jal = {
    glyph = '󰫷',
    hl = 'IconsCyan',
  },
  jam = {
    glyph = '󰫷',
    hl = 'IconsCyan',
  },
  janet = {
    glyph = '󰫷',
    hl = 'IconsOrange',
  },
  jargon = {
    glyph = '󰫷',
    hl = 'IconsCyan',
  },
  java = {
    glyph = '󰬷',
    hl = 'IconsOrange',
  },
  javacc = {
    glyph = '󰬷',
    hl = 'IconsRed',
  },
  javascript = {
    glyph = '󰌞',
    hl = 'IconsYellow',
  },
  ['javascript.glimmer'] = {
    glyph = '󰌞',
    hl = 'IconsRed',
  },
  javascriptreact = {
    glyph = '',
    hl = 'IconsAzure',
  },
  jess = {
    glyph = '󰫷',
    hl = 'IconsPurple',
  },
  jgraph = {
    glyph = '󰫷',
    hl = 'IconsGrey',
  },
  jinja = {
    glyph = '',
    hl = 'IconsRed',
  },
  jjdescription = {
    glyph = '󱨎',
    hl = 'IconsYellow',
  },
  jovial = {
    glyph = '󰫷',
    hl = 'IconsGrey',
  },
  jproperties = {
    glyph = '󰬷',
    hl = 'IconsGreen',
  },
  jq = {
    glyph = '󰘦',
    hl = 'IconsBlue',
  },
  json = {
    glyph = '󰘦',
    hl = 'IconsYellow',
  },
  json5 = {
    glyph = '󰘦',
    hl = 'IconsOrange',
  },
  jsonc = {
    glyph = '󰘦',
    hl = 'IconsYellow',
  },
  jsonl = {
    glyph = '󰘦',
    hl = 'IconsYellow',
  },
  jsonnet = {
    glyph = '󰫷',
    hl = 'IconsYellow',
  },
  jsp = {
    glyph = '󰫷',
    hl = 'IconsAzure',
  },
  julia = {
    glyph = '',
    hl = 'IconsPurple',
  },
  just = {
    glyph = '󰖷',
    hl = 'IconsOrange',
  },
  karel = {
    glyph = '󰚩',
    hl = 'IconsGrey',
  },
  kconfig = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  kdl = {
    glyph = '󰫸',
    hl = 'IconsGrey',
  },
  kerml = {
    glyph = '󰫸',
    hl = 'IconsGreen',
  },
  kitty = {
    glyph = '󰄛',
    hl = 'IconsGrey',
  },
  kivy = {
    glyph = '󰫸',
    hl = 'IconsBlue',
  },
  kix = {
    glyph = '󰫸',
    hl = 'IconsRed',
  },
  koka = {
    glyph = '󰫸',
    hl = 'IconsGreen',
  },
  kos = {
    glyph = '󰫸',
    hl = 'IconsPurple',
  },
  kotlin = {
    glyph = '󱈙',
    hl = 'IconsBlue',
  },
  krl = {
    glyph = '󰚩',
    hl = 'IconsGrey',
  },
  kscript = {
    glyph = '󰫸',
    hl = 'IconsGrey',
  },
  kwt = {
    glyph = '󰫸',
    hl = 'IconsOrange',
  },
  lace = {
    glyph = '󰫹',
    hl = 'IconsCyan',
  },
  lalrpop = {
    glyph = '󱘗',
    hl = 'IconsGreen',
  },
  larch = {
    glyph = '󱎦',
    hl = 'IconsOrange',
  },
  latte = {
    glyph = '󰅶',
    hl = 'IconsOrange',
  },
  lc = {
    glyph = '󰫹',
    hl = 'IconsRed',
  },
  ld = {
    glyph = '󰫹',
    hl = 'IconsPurple',
  },
  ldapconf = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  ldif = {
    glyph = '󰫹',
    hl = 'IconsPurple',
  },
  lean = {
    glyph = '󱎦',
    hl = 'IconsPurple',
  },
  ledger = {
    glyph = '󱪹',
    hl = 'IconsBlue',
  },
  leex = {
    glyph = '󰫹',
    hl = 'IconsYellow',
  },
  leo = {
    glyph = '󰪂',
    hl = 'IconsYellow',
  },
  less = {
    glyph = '󰌜',
    hl = 'IconsPurple',
  },
  lex = {
    glyph = '󰫹',
    hl = 'IconsOrange',
  },
  lf = {
    glyph = '󰫹',
    hl = 'IconsPurple',
  },
  lftp = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  lhaskell = {
    glyph = '',
    hl = 'IconsPurple',
  },
  libao = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  lidris2 = {
    glyph = '󰫹',
    hl = 'IconsPurple',
  },
  lifelines = {
    glyph = '󰫹',
    hl = 'IconsCyan',
  },
  lilo = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  lilypond = {
    glyph = '󱎦',
    hl = 'IconsOrange',
  },
  limits = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  liquid = {
    glyph = '',
    hl = 'IconsGreen',
  },
  liquidsoap = {
    glyph = '󰐹',
    hl = 'IconsPurple',
  },
  lisp = {
    glyph = '',
    hl = 'IconsGrey',
  },
  lite = {
    glyph = '󰫹',
    hl = 'IconsCyan',
  },
  litestep = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  livebook = {
    glyph = '󰂾',
    hl = 'IconsGreen',
  },
  llvm = {
    glyph = '',
    hl = 'IconsCyan',
  },
  lnk = {
    glyph = '󰫹',
    hl = 'IconsPurple',
  },
  lnkmap = {
    glyph = '󰫹',
    hl = 'IconsCyan',
  },
  logcheck = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  loginaccess = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  logindefs = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  logtalk = {
    glyph = '󰫹',
    hl = 'IconsOrange',
  },
  lotos = {
    glyph = '󰴈',
    hl = 'IconsGrey',
  },
  lout = {
    glyph = '󰫹',
    hl = 'IconsCyan',
  },
  lpc = {
    glyph = '󰫹',
    hl = 'IconsGrey',
  },
  lprolog = {
    glyph = '󰘧',
    hl = 'IconsOrange',
  },
  lscript = {
    glyph = '󰫹',
    hl = 'IconsCyan',
  },
  lsl = {
    glyph = '󰫹',
    hl = 'IconsYellow',
  },
  lsp_markdown = {
    glyph = '󰍔',
    hl = 'IconsGrey',
  },
  lss = {
    glyph = '󰫹',
    hl = 'IconsAzure',
  },
  lua = {
    glyph = '󰢱',
    hl = 'IconsAzure',
  },
  luau = {
    glyph = '󰢱',
    hl = 'IconsGreen',
  },
  lynx = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  lyrics = {
    glyph = '󰫹',
    hl = 'IconsOrange',
  },
  m17ndb = {
    glyph = '󰫺',
    hl = 'IconsAzure',
  },
  m3build = {
    glyph = '󰫺',
    hl = 'IconsGrey',
  },
  m3quake = {
    glyph = '󰫺',
    hl = 'IconsGreen',
  },
  m4 = {
    glyph = '󰫺',
    hl = 'IconsYellow',
  },
  mail = {
    glyph = '󰇮',
    hl = 'IconsRed',
  },
  mailaliases = {
    glyph = '󰇮',
    hl = 'IconsOrange',
  },
  mailcap = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  make = {
    glyph = '󱁤',
    hl = 'IconsGrey',
  },
  mallard = {
    glyph = '󰫺',
    hl = 'IconsGrey',
  },
  man = {
    glyph = '󰗚',
    hl = 'IconsYellow',
  },
  manconf = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  manual = {
    glyph = '󰗚',
    hl = 'IconsYellow',
  },
  map = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  maple = {
    glyph = '󰲓',
    hl = 'IconsRed',
  },
  markdown = {
    glyph = '󰍔',
    hl = 'IconsGrey',
  },
  masm = {
    glyph = '',
    hl = 'IconsPurple',
  },
  master = {
    glyph = '󰫺',
    hl = 'IconsOrange',
  },
  matlab = {
    glyph = '󰿈',
    hl = 'IconsOrange',
  },
  maxima = {
    glyph = '󰫺',
    hl = 'IconsGrey',
  },
  mbsyncrc = {
    glyph = '󰫺',
    hl = 'IconsPurple',
  },
  mediawiki = {
    glyph = '󰖬',
    hl = 'IconsBlue',
  },
  mel = {
    glyph = '󰫺',
    hl = 'IconsAzure',
  },
  mermaid = {
    glyph = '󰫺',
    hl = 'IconsCyan',
  },
  meson = {
    glyph = '󰫺',
    hl = 'IconsBlue',
  },
  messages = {
    glyph = '󰍡',
    hl = 'IconsBlue',
  },
  mf = {
    glyph = '󰫺',
    hl = 'IconsCyan',
  },
  mgl = {
    glyph = '󰫺',
    hl = 'IconsCyan',
  },
  mgp = {
    glyph = '󰫺',
    hl = 'IconsAzure',
  },
  mib = {
    glyph = '󰫺',
    hl = 'IconsCyan',
  },
  mix = {
    glyph = '󰫺',
    hl = 'IconsRed',
  },
  mlir = {
    glyph = '󰫺',
    hl = 'IconsGreen',
  },
  mma = {
    glyph = '󰘨',
    hl = 'IconsAzure',
  },
  mmix = {
    glyph = '󰫺',
    hl = 'IconsRed',
  },
  mmp = {
    glyph = '󰫺',
    hl = 'IconsGrey',
  },
  modconf = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  model = {
    glyph = '󰫺',
    hl = 'IconsGreen',
  },
  modsim3 = {
    glyph = '󰫺',
    hl = 'IconsCyan',
  },
  modula2 = {
    glyph = '󰫺',
    hl = 'IconsOrange',
  },
  modula3 = {
    glyph = '󰫺',
    hl = 'IconsRed',
  },
  mojo = {
    glyph = '󰈸',
    hl = 'IconsRed',
  },
  monk = {
    glyph = '󰫺',
    hl = 'IconsCyan',
  },
  moo = {
    glyph = '󰫺',
    hl = 'IconsYellow',
  },
  moonscript = {
    glyph = '󰽥',
    hl = 'IconsGrey',
  },
  move = {
    glyph = '󰆾',
    hl = 'IconsBlue',
  },
  mp = {
    glyph = '󰫺',
    hl = 'IconsAzure',
  },
  mplayerconf = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  mrxvtrc = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  msidl = {
    glyph = '󰫺',
    hl = 'IconsPurple',
  },
  msmessages = {
    glyph = '󰍡',
    hl = 'IconsAzure',
  },
  msmtp = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  msql = {
    glyph = '󰆼',
    hl = 'IconsGrey',
  },
  mss = {
    glyph = '󰫺',
    hl = 'IconsGrey',
  },
  mupad = {
    glyph = '󰫺',
    hl = 'IconsCyan',
  },
  murphi = {
    glyph = '󰫺',
    hl = 'IconsAzure',
  },
  mush = {
    glyph = '󰫺',
    hl = 'IconsPurple',
  },
  mustache = {
    glyph = '󱗞',
    hl = 'IconsAzure',
  },
  muttrc = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  mysql = {
    glyph = '󰆼',
    hl = 'IconsOrange',
  },
  n1ql = {
    glyph = '󰫻',
    hl = 'IconsYellow',
  },
  named = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  nanorc = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  nasm = {
    glyph = '',
    hl = 'IconsPurple',
  },
  nastran = {
    glyph = '󰫻',
    hl = 'IconsRed',
  },
  natural = {
    glyph = '󰫻',
    hl = 'IconsBlue',
  },
  ncf = {
    glyph = '󰫻',
    hl = 'IconsYellow',
  },
  neomuttlog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  neomuttrc = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  netlinx = {
    glyph = '󰫻',
    hl = 'IconsBlue',
  },
  netrc = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  netrw = {
    glyph = '󰙅',
    hl = 'IconsBlue',
  },
  nginx = {
    glyph = '󰰓',
    hl = 'IconsGreen',
  },
  nickel = {
    glyph = '󰫻',
    hl = 'IconsRed',
  },
  nim = {
    glyph = '',
    hl = 'IconsYellow',
  },
  ninja = {
    glyph = '󰝴',
    hl = 'IconsGrey',
  },
  nix = {
    glyph = '󱄅',
    hl = 'IconsAzure',
  },
  norg = {
    glyph = '',
    hl = 'IconsBlue',
  },
  nq = {
    glyph = '󱁉',
    hl = 'IconsGrey',
  },
  nqc = {
    glyph = '󱊈',
    hl = 'IconsYellow',
  },
  nroff = {
    glyph = '󰫻',
    hl = 'IconsCyan',
  },
  nsis = {
    glyph = '󰫻',
    hl = 'IconsAzure',
  },
  ntriples = {
    glyph = '󱁉',
    hl = 'IconsGreen',
  },
  nu = {
    glyph = '',
    hl = 'IconsPurple',
  },
  numbat = {
    glyph = '󰫻',
    hl = 'IconsAzure',
  },
  obj = {
    glyph = '󰆧',
    hl = 'IconsGrey',
  },
  objc = {
    glyph = '󰀵',
    hl = 'IconsOrange',
  },
  objcpp = {
    glyph = '󰀵',
    hl = 'IconsOrange',
  },
  objdump = {
    glyph = '󰫼',
    hl = 'IconsCyan',
  },
  obse = {
    glyph = '󰫼',
    hl = 'IconsBlue',
  },
  ocaml = {
    glyph = '',
    hl = 'IconsOrange',
  },
  occam = {
    glyph = '󱦗',
    hl = 'IconsGrey',
  },
  octave = {
    glyph = '󱥸',
    hl = 'IconsBlue',
  },
  odin = {
    glyph = '󰮔',
    hl = 'IconsBlue',
  },
  omnimark = {
    glyph = '󰫼',
    hl = 'IconsPurple',
  },
  ondir = {
    glyph = '󰫼',
    hl = 'IconsCyan',
  },
  opam = {
    glyph = '󰫼',
    hl = 'IconsBlue',
  },
  opencl = {
    glyph = '',
    hl = 'IconsGreen',
  },
  openroad = {
    glyph = '󰫼',
    hl = 'IconsOrange',
  },
  openscad = {
    glyph = '',
    hl = 'IconsYellow',
  },
  openvpn = {
    glyph = '󰖂',
    hl = 'IconsPurple',
  },
  opl = {
    glyph = '󰫼',
    hl = 'IconsPurple',
  },
  ora = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  org = {
    glyph = '',
    hl = 'IconsCyan',
  },
  pacmanlog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  pamconf = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  pamenv = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  pandoc = {
    glyph = '󰍔',
    hl = 'IconsYellow',
  },
  papp = {
    glyph = '',
    hl = 'IconsAzure',
  },
  pascal = {
    glyph = '󱤊',
    hl = 'IconsRed',
  },
  passwd = {
    glyph = '󰟵',
    hl = 'IconsGrey',
  },
  pbtxt = {
    glyph = '󰈚',
    hl = 'IconsRed',
  },
  pcap = {
    glyph = '󰐪',
    hl = 'IconsRed',
  },
  pccts = {
    glyph = '󰫽',
    hl = 'IconsRed',
  },
  pcmk = {
    glyph = '󰫽',
    hl = 'IconsRed',
  },
  pdf = {
    glyph = '󰈦',
    hl = 'IconsRed',
  },
  pem = {
    glyph = '󰌇',
    hl = 'IconsYellow',
  },
  perl = {
    glyph = '',
    hl = 'IconsAzure',
  },
  pf = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  pfmain = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  php = {
    glyph = '󰌟',
    hl = 'IconsPurple',
  },
  phtml = {
    glyph = '󰌟',
    hl = 'IconsOrange',
  },
  pic = {
    glyph = '',
    hl = 'IconsPurple',
  },
  pike = {
    glyph = '󰈺',
    hl = 'IconsGrey',
  },
  pilrc = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  pine = {
    glyph = '󰇮',
    hl = 'IconsRed',
  },
  pinfo = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  pkl = {
    glyph = '󰫽',
    hl = 'IconsBlue',
  },
  plaintex = {
    glyph = '',
    hl = 'IconsGreen',
  },
  pli = {
    glyph = '󰫽',
    hl = 'IconsRed',
  },
  plm = {
    glyph = '󰫽',
    hl = 'IconsBlue',
  },
  plp = {
    glyph = '',
    hl = 'IconsBlue',
  },
  plsql = {
    glyph = '󰆼',
    hl = 'IconsOrange',
  },
  po = {
    glyph = '󰗊',
    hl = 'IconsAzure',
  },
  pod = {
    glyph = '',
    hl = 'IconsPurple',
  },
  poefilter = {
    glyph = '󰫽',
    hl = 'IconsAzure',
  },
  poke = {
    glyph = '󰫽',
    hl = 'IconsPurple',
  },
  pony = {
    glyph = '󱖿',
    hl = 'IconsGrey',
  },
  postscr = {
    glyph = '',
    hl = 'IconsYellow',
  },
  pov = {
    glyph = '󰫽',
    hl = 'IconsPurple',
  },
  povini = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  ppd = {
    glyph = '',
    hl = 'IconsPurple',
  },
  ppwiz = {
    glyph = '󰫽',
    hl = 'IconsGrey',
  },
  pq = {
    glyph = '󰫽',
    hl = 'IconsAzure',
  },
  prescribe = {
    glyph = '󰜆',
    hl = 'IconsYellow',
  },
  prisma = {
    glyph = '',
    hl = 'IconsBlue',
  },
  privoxy = {
    glyph = '󰫽',
    hl = 'IconsOrange',
  },
  proc = {
    glyph = '󰆼',
    hl = 'IconsRed',
  },
  procmail = {
    glyph = '󰇮',
    hl = 'IconsBlue',
  },
  progress = {
    glyph = '󰫽',
    hl = 'IconsGreen',
  },
  prolog = {
    glyph = '',
    hl = 'IconsYellow',
  },
  promela = {
    glyph = '󰫽',
    hl = 'IconsRed',
  },
  proto = {
    glyph = '',
    hl = 'IconsRed',
  },
  protocols = {
    glyph = '󰖟',
    hl = 'IconsOrange',
  },
  prql = {
    glyph = '󱘻',
    hl = 'IconsYellow',
  },
  ps1 = {
    glyph = '󰨊',
    hl = 'IconsBlue',
  },
  ps1xml = {
    glyph = '󰨊',
    hl = 'IconsAzure',
  },
  psf = {
    glyph = '󰫽',
    hl = 'IconsPurple',
  },
  psl = {
    glyph = '󰫽',
    hl = 'IconsAzure',
  },
  ptcap = {
    glyph = '󰐪',
    hl = 'IconsRed',
  },
  ptx = {
    glyph = '󰫽',
    hl = 'IconsGreen',
  },
  pug = {
    glyph = '',
    hl = 'IconsPurple',
  },
  puppet = {
    glyph = '',
    hl = 'IconsOrange',
  },
  purescript = {
    glyph = '',
    hl = 'IconsGrey',
  },
  purifylog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  pymanifest = {
    glyph = '󰌠',
    hl = 'IconsAzure',
  },
  pyret = {
    glyph = '󰫽',
    hl = 'IconsBlue',
  },
  pyrex = {
    glyph = '󰫽',
    hl = 'IconsYellow',
  },
  python = {
    glyph = '󰌠',
    hl = 'IconsYellow',
  },
  python2 = {
    glyph = '󰌠',
    hl = 'IconsGrey',
  },
  qb64 = {
    glyph = '󰫾',
    hl = 'IconsCyan',
  },
  qf = {
    glyph = '󰝖',
    hl = 'IconsAzure',
  },
  ql = {
    glyph = '󰆼',
    hl = 'IconsGrey',
  },
  qml = {
    glyph = '󰫾',
    hl = 'IconsAzure',
  },
  qmldir = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  quake = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  quarto = {
    glyph = '󰐗',
    hl = 'IconsAzure',
  },
  query = {
    glyph = '󰐅',
    hl = 'IconsGreen',
  },
  quickbms = {
    glyph = '󰫾',
    hl = 'IconsGrey',
  },
  r = {
    glyph = '󰟔',
    hl = 'IconsBlue',
  },
  racc = {
    glyph = '󰫿',
    hl = 'IconsYellow',
  },
  racket = {
    glyph = '󰘧',
    hl = 'IconsRed',
  },
  radiance = {
    glyph = '󰫿',
    hl = 'IconsGrey',
  },
  raku = {
    glyph = '󱖉',
    hl = 'IconsYellow',
  },
  raml = {
    glyph = '󰫿',
    hl = 'IconsCyan',
  },
  rapid = {
    glyph = '󰫿',
    hl = 'IconsCyan',
  },
  rasi = {
    glyph = '󰫿',
    hl = 'IconsOrange',
  },
  ratpoison = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  rbs = {
    glyph = '󰁯',
    hl = 'IconsBlue',
  },
  rc = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  rcs = {
    glyph = '󰫿',
    hl = 'IconsYellow',
  },
  rcslog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  readline = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  rebol = {
    glyph = '󰫿',
    hl = 'IconsBlue',
  },
  redif = {
    glyph = '󰫿',
    hl = 'IconsOrange',
  },
  registry = {
    glyph = '󰪶',
    hl = 'IconsRed',
  },
  rego = {
    glyph = '󰫿',
    hl = 'IconsPurple',
  },
  remind = {
    glyph = '󰢌',
    hl = 'IconsPurple',
  },
  requirements = {
    glyph = '󱘎',
    hl = 'IconsPurple',
  },
  rescript = {
    glyph = '󰫿',
    hl = 'IconsAzure',
  },
  resolv = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  reva = {
    glyph = '󰫿',
    hl = 'IconsGrey',
  },
  rexx = {
    glyph = '󰫿',
    hl = 'IconsGreen',
  },
  rfc_csv = {
    glyph = '',
    hl = 'IconsOrange',
  },
  rfc_semicolon = {
    glyph = '',
    hl = 'IconsRed',
  },
  rhelp = {
    glyph = '󰟔',
    hl = 'IconsAzure',
  },
  rib = {
    glyph = '󰫿',
    hl = 'IconsGreen',
  },
  rmarkdown = {
    glyph = '󰍔',
    hl = 'IconsAzure',
  },
  rmd = {
    glyph = '󰍔',
    hl = 'IconsAzure',
  },
  rnc = {
    glyph = '󰫿',
    hl = 'IconsGreen',
  },
  rng = {
    glyph = '󰫿',
    hl = 'IconsCyan',
  },
  rnoweb = {
    glyph = '󰟔',
    hl = 'IconsGreen',
  },
  robot = {
    glyph = '󰚩',
    hl = 'IconsYellow',
  },
  robots = {
    glyph = '󰚩',
    hl = 'IconsGrey',
  },
  roc = {
    glyph = '󱗆',
    hl = 'IconsPurple',
  },
  ron = {
    glyph = '󱘗',
    hl = 'IconsCyan',
  },
  routeros = {
    glyph = '󱂇',
    hl = 'IconsGrey',
  },
  rpcgen = {
    glyph = '󰫿',
    hl = 'IconsCyan',
  },
  rpgle = {
    glyph = '󰫿',
    hl = 'IconsGreen',
  },
  rpl = {
    glyph = '󰫿',
    hl = 'IconsCyan',
  },
  rrst = {
    glyph = '󰫿',
    hl = 'IconsGreen',
  },
  rst = {
    glyph = '󰊄',
    hl = 'IconsYellow',
  },
  rtf = {
    glyph = '󰚞',
    hl = 'IconsAzure',
  },
  ruby = {
    glyph = '󰴭',
    hl = 'IconsRed',
  },
  rust = {
    glyph = '󱘗',
    hl = 'IconsOrange',
  },
  sage = {
    glyph = '󰘨',
    hl = 'IconsPurple',
  },
  salt = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  samba = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  sas = {
    glyph = '󰱐',
    hl = 'IconsAzure',
  },
  sass = {
    glyph = '󰟬',
    hl = 'IconsRed',
  },
  sather = {
    glyph = '󰬀',
    hl = 'IconsAzure',
  },
  sbt = {
    glyph = '',
    hl = 'IconsOrange',
  },
  scala = {
    glyph = '',
    hl = 'IconsRed',
  },
  scdoc = {
    glyph = '󰪶',
    hl = 'IconsAzure',
  },
  scheme = {
    glyph = '󰘧',
    hl = 'IconsGrey',
  },
  scilab = {
    glyph = '󰂓',
    hl = 'IconsYellow',
  },
  screen = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  scss = {
    glyph = '󰟬',
    hl = 'IconsRed',
  },
  sd = {
    glyph = '󰬀',
    hl = 'IconsGrey',
  },
  sdc = {
    glyph = '󰬀',
    hl = 'IconsGreen',
  },
  sdl = {
    glyph = '󰬀',
    hl = 'IconsRed',
  },
  sed = {
    glyph = '󰟥',
    hl = 'IconsRed',
  },
  sendpr = {
    glyph = '󰆨',
    hl = 'IconsBlue',
  },
  sensors = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  services = {
    glyph = '󰖟',
    hl = 'IconsGreen',
  },
  setserial = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  sexplib = {
    glyph = '',
    hl = 'IconsYellow',
  },
  sgml = {
    glyph = '󰬀',
    hl = 'IconsRed',
  },
  sgmldecl = {
    glyph = '󰬀',
    hl = 'IconsYellow',
  },
  sgmllnx = {
    glyph = '󰬀',
    hl = 'IconsGrey',
  },
  sh = {
    glyph = '',
    hl = 'IconsGrey',
  },
  shada = {
    glyph = '󰆼',
    hl = 'IconsGrey',
  },
  shaderslang = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  sicad = {
    glyph = '󰬀',
    hl = 'IconsPurple',
  },
  sieve = {
    glyph = '󰈲',
    hl = 'IconsOrange',
  },
  sil = {
    glyph = '󰛥',
    hl = 'IconsOrange',
  },
  sile = {
    glyph = '󰬀',
    hl = 'IconsGreen',
  },
  simula = {
    glyph = '󰬀',
    hl = 'IconsPurple',
  },
  sinda = {
    glyph = '󰬀',
    hl = 'IconsYellow',
  },
  sindacmp = {
    glyph = '󱒒',
    hl = 'IconsRed',
  },
  sindaout = {
    glyph = '󰬀',
    hl = 'IconsBlue',
  },
  sisu = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  skhd = {
    glyph = '󰬀',
    hl = 'IconsAzure',
  },
  skill = {
    glyph = '󰬀',
    hl = 'IconsGrey',
  },
  sl = {
    glyph = '󰟽',
    hl = 'IconsRed',
  },
  slang = {
    glyph = '󰬀',
    hl = 'IconsYellow',
  },
  slice = {
    glyph = '󰧻',
    hl = 'IconsGrey',
  },
  slint = {
    glyph = '󰬀',
    hl = 'IconsAzure',
  },
  slpconf = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  slpreg = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  slpspi = {
    glyph = '󰬀',
    hl = 'IconsPurple',
  },
  slrnrc = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  slrnsc = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  sm = {
    glyph = '󱃜',
    hl = 'IconsBlue',
  },
  smali = {
    glyph = '',
    hl = 'IconsGrey',
  },
  smarty = {
    glyph = '',
    hl = 'IconsYellow',
  },
  smcl = {
    glyph = '󰄨',
    hl = 'IconsRed',
  },
  smil = {
    glyph = '󰬀',
    hl = 'IconsOrange',
  },
  smith = {
    glyph = '󰬀',
    hl = 'IconsRed',
  },
  smithy = {
    glyph = '󰬀',
    hl = 'IconsGrey',
  },
  sml = {
    glyph = '󰘧',
    hl = 'IconsOrange',
  },
  snakemake = {
    glyph = '󱔎',
    hl = 'IconsGreen',
  },
  snnsnet = {
    glyph = '󰖟',
    hl = 'IconsGreen',
  },
  snnspat = {
    glyph = '󰬀',
    hl = 'IconsGreen',
  },
  snnsres = {
    glyph = '󰬀',
    hl = 'IconsBlue',
  },
  snobol4 = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  solidity = {
    glyph = '',
    hl = 'IconsAzure',
  },
  solution = {
    glyph = '󰘐',
    hl = 'IconsBlue',
  },
  soy = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  spajson = {
    glyph = '󰘦',
    hl = 'IconsPurple',
  },
  sparql = {
    glyph = '󰬀',
    hl = 'IconsRed',
  },
  spec = {
    glyph = '',
    hl = 'IconsBlue',
  },
  specman = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  spice = {
    glyph = '󰬀',
    hl = 'IconsOrange',
  },
  splint = {
    glyph = '󰙱',
    hl = 'IconsGreen',
  },
  spup = {
    glyph = '󰬀',
    hl = 'IconsOrange',
  },
  spyce = {
    glyph = '󰬀',
    hl = 'IconsRed',
  },
  sql = {
    glyph = '󰆼',
    hl = 'IconsGrey',
  },
  sqlanywhere = {
    glyph = '󰆼',
    hl = 'IconsAzure',
  },
  sqlforms = {
    glyph = '󰆼',
    hl = 'IconsOrange',
  },
  sqlhana = {
    glyph = '󰆼',
    hl = 'IconsPurple',
  },
  sqlinformix = {
    glyph = '󰆼',
    hl = 'IconsBlue',
  },
  sqlj = {
    glyph = '󰆼',
    hl = 'IconsGrey',
  },
  sqloracle = {
    glyph = '󰆼',
    hl = 'IconsOrange',
  },
  sqr = {
    glyph = '󰬀',
    hl = 'IconsGrey',
  },
  squid = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  squirrel = {
    glyph = '',
    hl = 'IconsGrey',
  },
  srec = {
    glyph = '󰍛',
    hl = 'IconsAzure',
  },
  srt = {
    glyph = '󰨖',
    hl = 'IconsYellow',
  },
  ssa = {
    glyph = '󰨖',
    hl = 'IconsOrange',
  },
  sshconfig = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  sshdconfig = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  st = {
    glyph = '󰄚',
    hl = 'IconsOrange',
  },
  starlark = {
    glyph = '',
    hl = 'IconsRed',
  },
  stata = {
    glyph = '󰝫',
    hl = 'IconsRed',
  },
  stp = {
    glyph = '󰬀',
    hl = 'IconsYellow',
  },
  strace = {
    glyph = '󰬀',
    hl = 'IconsPurple',
  },
  structurizr = {
    glyph = '󰬀',
    hl = 'IconsBlue',
  },
  stylus = {
    glyph = '󰴒',
    hl = 'IconsGrey',
  },
  sudoers = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  supercollider = {
    glyph = '󰆦',
    hl = 'IconsGrey',
  },
  superhtml = {
    glyph = '󰌝',
    hl = 'IconsPurple',
  },
  surface = {
    glyph = '󰬀',
    hl = 'IconsRed',
  },
  svelte = {
    glyph = '',
    hl = 'IconsOrange',
  },
  svg = {
    glyph = '󰜡',
    hl = 'IconsYellow',
  },
  svn = {
    glyph = '󰜘',
    hl = 'IconsOrange',
  },
  sway = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  swayconfig = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  swift = {
    glyph = '󰛥',
    hl = 'IconsOrange',
  },
  swiftgyb = {
    glyph = '󰛥',
    hl = 'IconsYellow',
  },
  swig = {
    glyph = '󰬀',
    hl = 'IconsGreen',
  },
  sysctl = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  sysml = {
    glyph = '󰬀',
    hl = 'IconsCyan',
  },
  systemd = {
    glyph = '',
    hl = 'IconsGrey',
  },
  systemverilog = {
    glyph = '󰍛',
    hl = 'IconsGreen',
  },
  tablegen = {
    glyph = '󰬁',
    hl = 'IconsGrey',
  },
  tads = {
    glyph = '󱩼',
    hl = 'IconsAzure',
  },
  tags = {
    glyph = '󰓻',
    hl = 'IconsGreen',
  },
  tak = {
    glyph = '󰔏',
    hl = 'IconsRed',
  },
  takcmp = {
    glyph = '󰔏',
    hl = 'IconsGreen',
  },
  takout = {
    glyph = '󰔏',
    hl = 'IconsBlue',
  },
  tal = {
    glyph = '󰬁',
    hl = 'IconsBlue',
  },
  tap = {
    glyph = '󰬁',
    hl = 'IconsAzure',
  },
  tar = {
    glyph = '󰬁',
    hl = 'IconsCyan',
  },
  taskdata = {
    glyph = '󱒋',
    hl = 'IconsPurple',
  },
  taskedit = {
    glyph = '󰬁',
    hl = 'IconsAzure',
  },
  tasm = {
    glyph = '',
    hl = 'IconsPurple',
  },
  tcl = {
    glyph = '󰛓',
    hl = 'IconsRed',
  },
  tcsh = {
    glyph = '',
    hl = 'IconsAzure',
  },
  teal = {
    glyph = '󰢱',
    hl = 'IconsCyan',
  },
  templ = {
    glyph = '󰬁',
    hl = 'IconsAzure',
  },
  template = {
    glyph = '󰬁',
    hl = 'IconsGreen',
  },
  tera = {
    glyph = '󰬁',
    hl = 'IconsAzure',
  },
  teraterm = {
    glyph = '󰅭',
    hl = 'IconsGreen',
  },
  terminfo = {
    glyph = '',
    hl = 'IconsGrey',
  },
  terraform = {
    glyph = '󱁢',
    hl = 'IconsBlue',
  },
  ['terraform-vars'] = {
    glyph = '󱁢',
    hl = 'IconsAzure',
  },
  tex = {
    glyph = '',
    hl = 'IconsGreen',
  },
  texinfo = {
    glyph = '',
    hl = 'IconsAzure',
  },
  texmf = {
    glyph = '󰒓',
    hl = 'IconsPurple',
  },
  text = {
    glyph = '󰦪',
    hl = 'IconsYellow',
  },
  tf = {
    glyph = '󰬁',
    hl = 'IconsRed',
  },
  thrift = {
    glyph = '󰬁',
    hl = 'IconsPurple',
  },
  tiasm = {
    glyph = '',
    hl = 'IconsCyan',
  },
  tidy = {
    glyph = '󰌝',
    hl = 'IconsBlue',
  },
  tiger = {
    glyph = '󰄛',
    hl = 'IconsOrange',
  },
  tilde = {
    glyph = '󰜥',
    hl = 'IconsRed',
  },
  tiltfile = {
    glyph = '󰬁',
    hl = 'IconsYellow',
  },
  tla = {
    glyph = '󰬁',
    hl = 'IconsAzure',
  },
  tli = {
    glyph = '󰬁',
    hl = 'IconsCyan',
  },
  tmux = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  toml = {
    glyph = '',
    hl = 'IconsOrange',
  },
  tpp = {
    glyph = '󰐨',
    hl = 'IconsPurple',
  },
  trace32 = {
    glyph = '󰬁',
    hl = 'IconsCyan',
  },
  trasys = {
    glyph = '󰬁',
    hl = 'IconsBlue',
  },
  treetop = {
    glyph = '󰔱',
    hl = 'IconsGreen',
  },
  trig = {
    glyph = '󱁉',
    hl = 'IconsYellow',
  },
  trustees = {
    glyph = '󰬁',
    hl = 'IconsPurple',
  },
  tsalt = {
    glyph = '󰬁',
    hl = 'IconsPurple',
  },
  tsscl = {
    glyph = '󱣖',
    hl = 'IconsGreen',
  },
  tssgm = {
    glyph = '󱣖',
    hl = 'IconsYellow',
  },
  tssop = {
    glyph = '󱣖',
    hl = 'IconsGrey',
  },
  tsv = {
    glyph = '',
    hl = 'IconsBlue',
  },
  tt2 = {
    glyph = '',
    hl = 'IconsAzure',
  },
  tt2html = {
    glyph = '',
    hl = 'IconsOrange',
  },
  tt2js = {
    glyph = '',
    hl = 'IconsYellow',
  },
  turtle = {
    glyph = '󰳗',
    hl = 'IconsGreen',
  },
  tutor = {
    glyph = '󱆀',
    hl = 'IconsPurple',
  },
  twig = {
    glyph = '',
    hl = 'IconsGreen',
  },
  typescript = {
    glyph = '󰛦',
    hl = 'IconsAzure',
  },
  ['typescript.glimmer'] = {
    glyph = '󰛦',
    hl = 'IconsRed',
  },
  typescriptreact = {
    glyph = '',
    hl = 'IconsBlue',
  },
  typespec = {
    glyph = '󰬁',
    hl = 'IconsPurple',
  },
  typst = {
    glyph = '󰬛',
    hl = 'IconsAzure',
  },
  uc = {
    glyph = '󰬂',
    hl = 'IconsGrey',
  },
  uci = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  udevconf = {
    glyph = '󰒓',
    hl = 'IconsOrange',
  },
  udevperm = {
    glyph = '󰬂',
    hl = 'IconsOrange',
  },
  udevrules = {
    glyph = '󰬂',
    hl = 'IconsBlue',
  },
  uil = {
    glyph = '󰬂',
    hl = 'IconsGrey',
  },
  ungrammar = {
    glyph = '󱘎',
    hl = 'IconsYellow',
  },
  unison = {
    glyph = '󰡉',
    hl = 'IconsYellow',
  },
  updatedb = {
    glyph = '󰒓',
    hl = 'IconsGrey',
  },
  upstart = {
    glyph = '󰬂',
    hl = 'IconsCyan',
  },
  upstreamdat = {
    glyph = '󰬂',
    hl = 'IconsGreen',
  },
  upstreaminstalllog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  upstreamlog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  upstreamrpt = {
    glyph = '󰬂',
    hl = 'IconsYellow',
  },
  urlshortcut = {
    glyph = '󰌷',
    hl = 'IconsPurple',
  },
  usd = {
    glyph = '󰻇',
    hl = 'IconsAzure',
  },
  usserverlog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  usw2kagtlog = {
    glyph = '󰷐',
    hl = 'IconsBlue',
  },
  v = {
    glyph = '',
    hl = 'IconsBlue',
  },
  vala = {
    glyph = '󰬝',
    hl = 'IconsPurple',
  },
  valgrind = {
    glyph = '󰍛',
    hl = 'IconsGrey',
  },
  vb = {
    glyph = '󰛤',
    hl = 'IconsPurple',
  },
  vdf = {
    glyph = '󰬃',
    hl = 'IconsCyan',
  },
  vdmpp = {
    glyph = '󱂌',
    hl = 'IconsYellow',
  },
  vdmrt = {
    glyph = '󱂌',
    hl = 'IconsGreen',
  },
  vdmsl = {
    glyph = '󱂌',
    hl = 'IconsAzure',
  },
  vento = {
    glyph = '󱂌',
    hl = 'IconsPurple',
  },
  vera = {
    glyph = '󰬃',
    hl = 'IconsCyan',
  },
  verilog = {
    glyph = '󰍛',
    hl = 'IconsGreen',
  },
  verilogams = {
    glyph = '󰍛',
    hl = 'IconsGreen',
  },
  vgrindefs = {
    glyph = '󰬃',
    hl = 'IconsPurple',
  },
  vhdl = {
    glyph = '󰍛',
    hl = 'IconsGreen',
  },
  vhs = {
    glyph = '󰨛',
    hl = 'IconsBlue',
  },
  vim = {
    glyph = '',
    hl = 'IconsGreen',
  },
  viminfo = {
    glyph = '',
    hl = 'IconsBlue',
  },
  virata = {
    glyph = '󰒓',
    hl = 'IconsCyan',
  },
  vmasm = {
    glyph = '',
    hl = 'IconsPurple',
  },
  voscm = {
    glyph = '󰬃',
    hl = 'IconsCyan',
  },
  vrml = {
    glyph = '󰬃',
    hl = 'IconsBlue',
  },
  vroom = {
    glyph = '',
    hl = 'IconsOrange',
  },
  vsejcl = {
    glyph = '󰬃',
    hl = 'IconsCyan',
  },
  vue = {
    glyph = '󰡄',
    hl = 'IconsGreen',
  },
  wat = {
    glyph = '',
    hl = 'IconsPurple',
  },
  wdiff = {
    glyph = '󰦓',
    hl = 'IconsBlue',
  },
  wdl = {
    glyph = '󰬄',
    hl = 'IconsGrey',
  },
  web = {
    glyph = '󰯊',
    hl = 'IconsGrey',
  },
  webmacro = {
    glyph = '󰬄',
    hl = 'IconsCyan',
  },
  wget = {
    glyph = '󰒓',
    hl = 'IconsYellow',
  },
  wget2 = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  wgsl = {
    glyph = '󰬄',
    hl = 'IconsBlue',
  },
  winbatch = {
    glyph = '󰯂',
    hl = 'IconsBlue',
  },
  wit = {
    glyph = '',
    hl = 'IconsCyan',
  },
  wml = {
    glyph = '󰖟',
    hl = 'IconsGreen',
  },
  wsh = {
    glyph = '󰯂',
    hl = 'IconsPurple',
  },
  wsml = {
    glyph = '󰬄',
    hl = 'IconsAzure',
  },
  wvdial = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  xbl = {
    glyph = '󰬅',
    hl = 'IconsAzure',
  },
  xcompose = {
    glyph = '󰌌',
    hl = 'IconsOrange',
  },
  xdefaults = {
    glyph = '󰒓',
    hl = 'IconsBlue',
  },
  xf86conf = {
    glyph = '󰒓',
    hl = 'IconsAzure',
  },
  xhtml = {
    glyph = '󰌝',
    hl = 'IconsOrange',
  },
  xinetd = {
    glyph = '󰒓',
    hl = 'IconsGreen',
  },
  xkb = {
    glyph = '󰌌',
    hl = 'IconsPurple',
  },
  xmath = {
    glyph = '󰬅',
    hl = 'IconsYellow',
  },
  xml = {
    glyph = '󰗀',
    hl = 'IconsOrange',
  },
  xmodmap = {
    glyph = '󰬅',
    hl = 'IconsCyan',
  },
  xpm = {
    glyph = '󰍹',
    hl = 'IconsYellow',
  },
  xpm2 = {
    glyph = '󰍹',
    hl = 'IconsGreen',
  },
  xquery = {
    glyph = '󰗀',
    hl = 'IconsAzure',
  },
  xs = {
    glyph = '',
    hl = 'IconsRed',
  },
  xsd = {
    glyph = '󰗀',
    hl = 'IconsYellow',
  },
  xslt = {
    glyph = '󰗀',
    hl = 'IconsGreen',
  },
  xxd = {
    glyph = '󰬅',
    hl = 'IconsBlue',
  },
  yacc = {
    glyph = '󰬆',
    hl = 'IconsOrange',
  },
  yaml = {
    glyph = '',
    hl = 'IconsPurple',
  },
  ['yaml.ansible'] = {
    glyph = '󱂚',
    hl = 'IconsGrey',
  },
  ['yaml.docker-compose'] = {
    glyph = '󰡨',
    hl = 'IconsYellow',
  },

  yang = {
    glyph = '󰬆',
    hl = 'IconsCyan',
  },
  yuck = {
    glyph = '󰬆',
    hl = 'IconsYellow',
  },
  z8a = {
    glyph = '',
    hl = 'IconsGrey',
  },
  zathurarc = {
    glyph = '󰒓',
    hl = 'IconsRed',
  },
  zig = {
    glyph = '',
    hl = 'IconsOrange',
  },
  ziggy = {
    glyph = '󰬇',
    hl = 'IconsBlue',
  },
  ziggy_schema = {
    glyph = '󰬇',
    hl = 'IconsAzure',
  },
  zimbu = {
    glyph = '󰬇',
    hl = 'IconsGreen',
  },
  zimbutempl = {
    glyph = '󰬇',
    hl = 'IconsOrange',
  },
  zip = {
    glyph = '󰗄',
    hl = 'IconsGreen',
  },
  zir = {
    glyph = '',
    hl = 'IconsOrange',
  },
  zserio = {
    glyph = '󰬇',
    hl = 'IconsGrey',
  },
  zsh = {
    glyph = '',
    hl = 'IconsGreen',
  },
}
M.lsp_icons = {
  array = {
    glyph = '',
    hl = 'IconsOrange',
  },
  boolean = {
    glyph = '',
    hl = 'IconsOrange',
  },
  class = {
    glyph = '',
    hl = 'IconsPurple',
  },
  color = {
    glyph = '',
    hl = 'IconsRed',
  },
  constant = {
    glyph = '',
    hl = 'IconsOrange',
  },
  constructor = {
    glyph = '',
    hl = 'IconsAzure',
  },
  enum = {
    glyph = '',
    hl = 'IconsPurple',
  },
  enummember = {
    glyph = '',
    hl = 'IconsYellow',
  },
  event = {
    glyph = '',
    hl = 'IconsRed',
  },
  field = {
    glyph = '',
    hl = 'IconsYellow',
  },
  file = {
    glyph = '',
    hl = 'IconsBlue',
  },
  folder = {
    glyph = '',
    hl = 'IconsBlue',
  },
  ['function'] = {
    glyph = '',
    hl = 'IconsAzure',
  },
  interface = {
    glyph = '',
    hl = 'IconsPurple',
  },
  key = {
    glyph = '',
    hl = 'IconsYellow',
  },
  keyword = {
    glyph = '',
    hl = 'IconsCyan',
  },
  method = {
    glyph = '',
    hl = 'IconsAzure',
  },
  module = {
    glyph = '',
    hl = 'IconsPurple',
  },
  namespace = {
    glyph = '',
    hl = 'IconsRed',
  },
  null = {
    glyph = '',
    hl = 'IconsGrey',
  },
  number = {
    glyph = '',
    hl = 'IconsOrange',
  },
  object = {
    glyph = '',
    hl = 'IconsGrey',
  },
  operator = {
    glyph = '',
    hl = 'IconsCyan',
  },
  package = {
    glyph = '',
    hl = 'IconsPurple',
  },
  property = {
    glyph = '',
    hl = 'IconsYellow',
  },
  reference = {
    glyph = '',
    hl = 'IconsCyan',
  },
  snippet = {
    glyph = '',
    hl = 'IconsGreen',
  },
  string = {
    glyph = '',
    hl = 'IconsGreen',
  },
  struct = {
    glyph = '',
    hl = 'IconsPurple',
  },
  text = {
    glyph = '',
    hl = 'IconsGreen',
  },
  typeparameter = {
    glyph = '',
    hl = 'IconsCyan',
  },
  unit = {
    glyph = '',
    hl = 'IconsCyan',
  },
  value = {
    glyph = '',
    hl = 'IconsBlue',
  },
  variable = {
    glyph = '',
    hl = 'IconsCyan',
  },
}

M.os_icons = {
  android = {
    glyph = '󰀲',
    hl = 'IconsGreen',
  },
  arch = {
    glyph = '󰣇',
    hl = 'IconsAzure',
  },
  centos = {
    glyph = '󱄚',
    hl = 'IconsRed',
  },
  debian = {
    glyph = '󰣚',
    hl = 'IconsRed',
  },
  fedora = {
    glyph = '󰣛',
    hl = 'IconsBlue',
  },
  freebsd = {
    glyph = '󰣠',
    hl = 'IconsRed',
  },
  gentoo = {
    glyph = '󰣨',
    hl = 'IconsPurple',
  },
  ios = {
    glyph = '󰀷',
    hl = 'IconsYellow',
  },
  linux = {
    glyph = '󰌽',
    hl = 'IconsCyan',
  },
  macos = {
    glyph = '󰀵',
    hl = 'IconsGrey',
  },
  manjaro = {
    glyph = '󱘊',
    hl = 'IconsGreen',
  },
  mint = {
    glyph = '󰣭',
    hl = 'IconsGreen',
  },
  nixos = {
    glyph = '󱄅',
    hl = 'IconsAzure',
  },
  raspberry_pi = {
    glyph = '󰐿',
    hl = 'IconsRed',
  },
  redhat = {
    glyph = '󱄛',
    hl = 'IconsRed',
  },
  ubuntu = {
    glyph = '󰕈',
    hl = 'IconsOrange',
  },
  windows = {
    glyph = '󰖳',
    hl = 'IconsBlue',
  },
}
M.setup_config = function(config)
  M.check_type('config', config, 'table', true)
  config = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
  M.check_type('style', config.style, 'string')
  M.check_type('default', config.default, 'table')
  M.check_type('directory', config.directory, 'table')
  M.check_type('extension', config.extension, 'table')
  M.check_type('file', config.file, 'table')
  M.check_type('filetype', config.filetype, 'table')
  M.check_type('lsp', config.lsp, 'table')
  M.check_type('os', config.os, 'table')
  M.check_type('use_file_extension', config.use_file_extension, 'function')
  return config
end

M.apply_config = function(config)
  M.config = config
  M.init_cache(config)
end
M.create_autocommands = function()
  local gr = vim.api.nvim_create_augroup('Icons', {})
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = gr,
    callback = M.create_default_hl,
    desc = 'Ensure colors',
  })
end
M.create_default_hl = function()
  local hi = function(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end

  hi('IconsAzure', {
    link = 'Function',
  })
  hi('IconsBlue', {
    link = 'DiagnosticInfo',
  })
  hi('IconsCyan', {
    link = 'DiagnosticHint',
  })
  hi('IconsGreen', {
    link = 'DiagnosticOk',
  })
  hi('IconsGrey', {})
  hi('IconsOrange', {
    link = 'DiagnosticWarn',
  })
  hi('IconsPurple', {
    link = 'Constant',
  })
  hi('IconsRed', {
    link = 'DiagnosticError',
  })
  hi('IconsYellow', {
    link = 'DiagnosticWarn',
  })
end

function M.icons_cfg(opts)
  opts = opts or {}
  M.icons_devicons(opts)
  M.icons_nonicons(opts)
  M.icons_highlights()
  M.lsp_icons()
end

return M