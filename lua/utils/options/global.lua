-- /qompassai/Diver/lua/utils/options/global.lua
-- Qompass AI Diver Global Options
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--- Every global-scoped Neovim option, set explicitly and alphabetically.
---
--- Plain-language version: this file lists every global Neovim option
--- alphabetically and sets each one on purpose, so the whole global
--- configuration is visible in one place instead of hiding in defaults.
---@module 'utils.options.global'

local o = vim.o

-- Deliberately NOT set here (dynamic or manager-owned; see reason):
--   backupdir, directory, viewdir, packlockfile ... dynamic defaults derived
--       from stdpath(); a literal would freeze another machine's paths
--   columns, lines ... terminal geometry, per-session
--   filetype, syntax ... owned by filetype/syntax detection
--   helpfile ........... dynamic default derived from $VIMRUNTIME
--   loadplugins ........ owned by lazy.nvim (sets it false during setup)
--   packpath, runtimepath ... owned by Neovim + the plugin manager
--   shell .............. default comes from $SHELL; a literal would
--                        override the user's shell on every machine

local M = {}

--- Apply every global-scoped option (plus tab-scoped cmdheight, the only one). Idempotent.
--- Values marked (custom) are Matt's explicit choices; the rest are
--- Neovim's own defaults, written out so nothing is implicit.
function M.setup()
    o.aleph = 224
    o.allowrevins = true -- custom
    o.ambiwidth = 'single' -- custom
    o.arabicshape = true
    o.autochdir = true -- custom
    o.autocompletedelay = 0 -- custom
    o.autocompletetimeout = 80 -- custom
    o.autowrite = true -- custom
    o.autowriteall = true -- custom
    o.background = 'dark' -- custom
    o.backspace = 'indent,eol,start' -- custom
    o.backup = false -- custom
    o.backupext = '~'
    o.backupskip = '/tmp/*'
    o.belloff = 'all'
    o.breakat = ' \9!@*-+;:,./?'
    o.browsedir = ''
    o.casemap = 'internal,keepascii'
    o.cdhome = true
    o.cdpath = ',,'
    o.cedit = '\6'
    o.charconvert = ''
    o.chistory = 10
    o.clipboard = 'unnamedplus' -- custom
    o.cmdheight = 1 -- custom
    o.cmdwinheight = 7
    o.compatible = false
    o.completeitemalign = 'abbr,kind,menu' -- custom
    o.completetimeout = 150 -- custom
    o.confirm = true -- custom
    o.cpoptions = 'aABceFs_'
    o.debug = 'msg' -- custom
    o.delcombine = false
    o.diffexpr = ''
    o.diffopt = 'internal,filler,closeoff,algorithm:histogram,indent-heuristic,linematch:60' -- custom
    o.digraph = false
    o.display = 'lastline'
    o.eadirection = 'both'
    o.edcompatible = false
    o.emoji = true
    o.encoding = 'utf-8' -- custom
    o.equalalways = true
    o.errorbells = false -- custom
    o.errorfile = 'errors.err'
    o.eventignore = ''
    o.exrc = true -- custom
    o.fileencodings = 'ucs-bom,utf-8,default' -- custom
    o.fileformats = 'unix,dos,mac' -- custom
    o.fileignorecase = false
    o.foldclose = ''
    o.foldlevelstart = -1
    o.foldopen = 'block,hor,mark,percent,quickfix,search,tag,undo'
    o.gdefault = false
    o.guicursor = 'n-v-c:block-Cursor/lCursor,i-ci-ve:ver25-Cursor/lCursor,r-cr-o:hor20-Cursor/lCursor' -- custom
    o.guifont = 'Source Code Pro,DejaVu Sans Mono,Courier New,monospace'
    o.guifontwide = ''
    o.guioptions = ''
    o.guitablabel = ''
    o.guitabtooltip = ''
    o.helpheight = 20
    o.helplang = ''
    o.hidden = true -- custom
    o.highlight = '8:SpecialKey,~:EndOfBuffer,z:TermCursor,@:NonText,d:Directory,e:ErrorMsg,'
        .. 'i:IncSearch,l:Search,y:CurSearch,m:MoreMsg,M:ModeMsg,n:LineNr,a:LineNrAbove,'
        .. 'b:LineNrBelow,N:CursorLineNr,G:CursorLineSign,O:CursorLineFold,r:Question,'
        .. 's:StatusLine,S:StatusLineNC,c:VertSplit,t:Title,v:Visual,V:VisualNOS,w:WarningMsg,'
        .. 'W:WildMenu,f:Folded,F:FoldColumn,A:DiffAdd,C:DiffChange,D:DiffDelete,T:DiffText,'
        .. 'E:DiffTextAdd,>:SignColumn,-:Conceal,B:SpellBad,P:SpellCap,R:SpellRare,L:SpellLocal,'
        .. '+:Pmenu,=:PmenuSel,k:PmenuMatch,<:PmenuMatchSel,[:PmenuKind,]:PmenuKindSel,'
        .. '{:PmenuExtra,}:PmenuExtraSel,x:PmenuSbar,X:PmenuThumb,*:TabLine,#:TabLineSel,'
        .. '_:TabLineFill,!:CursorColumn,.:CursorLine,o:ColorColumn,q:QuickFixLine,'
        .. 'z:StatusLineTerm,Z:StatusLineTermNC,g:MsgArea,h:ComplMatchIns,0:Whitespace,I:PreInsert'
    o.history = 1000 -- custom
    o.hkmap = false
    o.hkmapp = false
    o.hlsearch = true -- custom
    o.icon = false -- custom
    o.iconstring = ''
    o.ignorecase = true -- custom
    o.imcmdline = false
    o.imdisable = false
    o.inccommand = 'split' -- custom
    o.incsearch = true -- custom
    o.insertmode = false
    o.isfname = '@,48-57,/,.,-,_,+,,,#,$,%,~,='
    o.isident = '@,48-57,_,192-255'
    o.isprint = '@,161-255' -- custom
    o.joinspaces = true -- custom
    o.jumpoptions = 'clean' -- custom
    o.keymodel = ''
    o.langmap = ''
    o.langmenu = ''
    o.langnoremap = true -- custom
    o.langremap = false -- custom
    o.laststatus = 3 -- custom
    o.lazyredraw = true -- custom
    o.linespace = 0 -- custom
    o.magic = true -- custom
    o.makeef = ''
    o.matchtime = 2 -- custom
    o.maxcombine = 6
    o.maxfuncdepth = 100
    o.maxmapdepth = 1000
    o.maxmempattern = 1000
    o.maxsearchcount = 999 -- custom
    o.menuitems = 25
    o.messagesopt = 'hit-enter,history:500,progress:c'
    o.mkspellmem = '460000,2000,500'
    o.modelineexpr = false
    o.modelines = 5 -- custom
    o.more = true
    o.mouse = 'a' -- custom
    o.mousefocus = false
    o.mousehide = true
    o.mousemodel = 'popup_setpos'
    o.mousemoveevent = false
    o.mousescroll = 'ver:3,hor:6' -- custom
    o.mouseshape = ''
    o.mousetime = 500
    o.opendevice = false
    o.operatorfunc = ''
    o.paragraphs = 'IPLPPPQPP TPHPLIPpLpItpplpipbp'
    o.paste = false
    o.pastetoggle = ''
    o.patchexpr = ''
    o.patchmode = ''
    o.previewheight = 12
    o.previewpopup = ''
    o.prompt = true
    o.pumblend = 40 -- custom
    o.pumborder = ''
    o.pumheight = 15 -- custom
    o.pummaxwidth = 0
    o.pumwidth = 15
    o.pyxversion = 3
    o.quickfixtextfunc = ''
    o.redrawdebug = ''
    o.redrawtime = 10000 -- custom
    o.regexpengine = 0
    o.remap = true
    o.report = 9999 -- custom
    o.revins = false
    o.ruler = true -- custom
    o.rulerformat = '%18(%l,%c%V%= %P%)%<'
    o.scrolljump = 1
    o.scrollopt = 'ver,jump'
    o.sections = 'SHNHH HUnhsh'
    o.secure = true -- custom
    o.selection = 'inclusive'
    o.selectmode = ''
    o.sessionoptions = 'curdir,folds,help,tabpages,terminal,winsize' -- custom
    o.shada = "!,'100,<50,s10,h,r/tmp/,r/private/"
    o.shadafile = ''
    o.shellcmdflag = '-c' -- custom
    o.shellpipe = '2>&1| tee' -- custom
    o.shellquote = '' -- custom
    o.shellredir = '>%s 2>&1' -- custom
    o.shellslash = true -- custom
    o.shelltemp = false
    o.shellxescape = ''
    o.shellxquote = '' -- custom
    o.shiftround = false
    o.shortmess = 'IF' -- custom
    o.showcmd = true
    o.showcmdloc = 'last'
    o.showfulltag = false
    o.showmatch = false
    o.showmode = false -- custom
    o.showtabline = 2 -- custom
    o.sidescroll = 1 -- custom
    o.smartcase = true -- custom
    o.smarttab = true -- custom
    o.spellsuggest = 'best'
    o.splitbelow = true -- custom
    o.splitkeep = 'cursor'
    o.splitright = true -- custom
    o.startofline = false -- custom
    o.suffixes = '.bak,~,.o,.h,.info,.swp,.obj'
    o.switchbuf = 'uselast' -- custom
    o.tabclose = ''
    o.tabline = ''
    o.tabpagemax = 50 -- custom
    o.tagbsearch = true
    o.taglength = 0
    o.tagrelative = true
    o.tagstack = true
    o.termbidi = false
    o.termencoding = ''
    o.termguicolors = true -- custom
    o.termpastefilter = 'BS,HT,ESC,DEL'
    o.termsync = true
    o.terse = false
    o.tildeop = false
    o.timeout = true -- custom
    o.timeoutlen = 300 -- custom
    o.title = true -- custom
    o.titlelen = 85
    o.titleold = ''
    o.titlestring = ''
    o.ttimeout = true
    o.ttimeoutlen = 10 -- custom
    o.ttyfast = true -- custom
    o.undodir = vim.fn.stdpath('data') .. '/undo' -- custom
    o.undoreload = 10000
    o.updatecount = 200
    o.updatetime = 50 -- custom
    o.verbose = 0
    o.verbosefile = ''
    o.viewoptions = 'unix,slash' -- custom
    o.visualbell = false
    o.warn = true
    o.whichwrap = 'b,s'
    o.wildchar = 9
    o.wildcharm = 0
    o.wildignore = '*.a' -- custom
    o.wildignorecase = true -- custom
    o.wildmenu = true -- custom
    o.wildmode = 'noselect' -- custom
    o.wildoptions = 'pum,tagfile'
    o.winaltkeys = 'menu'
    o.winborder = 'rounded' -- custom
    o.window = 23
    o.winheight = 1
    o.winminheight = 1
    o.winminwidth = 1
    o.winwidth = 20
    o.wrapscan = true
    o.write = true
    o.writeany = false
    o.writebackup = true -- custom
    o.writedelay = 0

    -- Global defaults for global-local options that init.lua set via o.*.
    -- o.* writes both the global default and the current local value; the
    -- local side lives in buffer.lua / window.lua, these lines restore the
    -- global side so buffers/windows opened later inherit init.lua's choice.
    -- (go.expandtab is covered by the go_set tail in buffer.lua.)
    vim.go.autocomplete = false -- custom
    vim.go.autoread = true -- custom
    vim.go.completeopt = 'menu,menuone,noselect,fuzzy' -- custom
    vim.go.scrolloff = 8 -- custom
    vim.go.tags = './tags;,tags' -- custom
    -- Windows shell: pwsh when available, powershell as fallback.
    -- Kept conditional exactly as in init.lua; `shell` itself is never
    -- given a literal outside this branch (see the note at the top).
    if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
        o.shell = vim.fn.executable('pwsh') == 1 and 'pwsh' or 'powershell'
        o.shellcmdflag = [[-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Consol]]
            .. [[e]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-F]]
            .. [[ile:Encoding']="utf8";]]
        o.shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
        o.shellpipe = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
        o.shellquote = ''
        o.shellxquote = ''
    end
end

return M
