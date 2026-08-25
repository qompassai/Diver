-- gnupg.lua - GnuPG utility for Neovim
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {} ---@version JIT
local api = vim.api
local b = vim.b
local contains = vim.tbl_contains
local GPGHomedir = vim.b.GPGHomedir
local GPGRecipients = vim.b.GPGRecipients
local cmd = vim.cmd
local echo = vim.api.nvim_echo
local env = vim.env
local fmt = string.format
local fn = vim.fn
local g = vim.g
local GPG_MAGIC_STRING = '\t \t'
local insert = table.insert
local KEY_PATTERN = '%%(%?0x%%)?[[:xdigit:]]{8,16}'
local GPGCommand = ''
local GPGPubkey = ''
local GPGCipher = ''
local GPGHash = ''
local GPGCompress = ''
local GPGHome = ''
local useCygpath = false
local stderrredirnull = ''
local shellredir = ''
local shell = ''
local shelltemp = true
local shellredirsave = ''
local shellsave = ''
local shelltempsave = true
local split = vim.split
local messages_lang = ''
local init_run = false
local function shellescape( ---@return string
    s, ---@param s string
    opts ---@param opts? table
)
  opts = opts or {}
  local special = opts.special or false
  local cygpath = opts.cygpath or false
  local str = s
  if cygpath and useCygpath then
    local result = vim.system({
      'cygpath',
      '-am',
      s,
    }):wait()
    if result.code == 0 then
      str = vim.trim(result.stdout or '')
    end
  end
  if vim.fn.exists('+shellslash') == 1 and vim.o.shell == env.COMSPEC then
    local ssl = vim.o.shellslash
    vim.o.shellslash = false
    local escaped = fn.shellescape(str, special)
    vim.o.shellslash = ssl
    return escaped
  else
    return fn.shellescape(str, special)
  end
end
local function unencrypted() ---@return boolean
  if vim.b.GPGEncrypted == 0 then
    echo({
      {
        'File is not encrypted, all GPG functions disabled!',
        'WarningMsg',
      },
    }, true, {})
    return true
  end
  return false
end
---@param level integer
---@param text string
local function debug(level, text)
  local debug_level = g.GPGDebugLevel or 0
  if debug_level >= level or vim.o.verbose >= level then
    if vim.g.GPGDebugLog then
      local log = io.open(vim.g.GPGDebugLog, 'a')
      if log then
        log:write('GnuPG: ' .. text .. '\n')
        log:close()
      end
    else
      vim.notify('GnuPG: ' .. text, vim.log.levels.INFO)
    end
  end
end
local function pre_cmd()
  vim.o.shellredir = shellredir
  vim.o.shell = shell
  vim.o.shelltemp = shelltemp
  messages_lang = vim.v.lang
  cmd('language messages C')
end
local function post_cmd()
  vim.o.shellredir = shellredirsave
  vim.o.shell = shellsave
  vim.o.shelltemp = shelltempsave
  cmd('language messages ' .. messages_lang)
  if not vim.g.goneovide and vim.fn.has('gui_running') == 0 then
    vim.o.term = vim.o.term
    cmd('silent doautocmd TermChanged')
  end
end

local function gpg_system( ---@return string
    dict ---@param dict table
)
  local commandline = GPGCommand
  if GPGHomedir and GPGHomedir ~= '' then
    commandline = commandline .. ' --homedir ' .. shellescape(GPGHomedir, {
      cygpath = true,
    })
  end
  commandline = commandline .. ' ' .. dict.args
  commandline = commandline .. ' ' .. stderrredirnull
  debug(dict.level or 2, 'command: ' .. commandline)
  pre_cmd()
  local result = vim.system(split(commandline, ' '), {
    text = true,
  }):wait()
  post_cmd()
  debug(dict.level or 2, 'rc: ' .. result.code)
  debug(dict.level or 2, 'output: ' .. (result.stdout or ''))
  return result.stdout or ''
end
local function gpg_execute(dict) ---@param dict table
  local commandline = dict.ex .. GPGCommand
  if GPGHomedir and GPGHomedir ~= '' then
    commandline = commandline
        .. ' --homedir '
        .. shellescape(GPGHomedir, {
          special = true,
          cygpath = true,
        })
  end
  commandline = commandline .. ' ' .. dict.args
  if dict.redirect then
    commandline = commandline .. ' ' .. dict.redirect
  end
  commandline = commandline .. ' ' .. stderrredirnull
  debug(dict.level or 2, 'command: ' .. commandline)
  pre_cmd()
  cmd(commandline)
  post_cmd()
  debug(dict.level or 2, 'rc: ' .. vim.v.shell_error)
end

---@return string
local function gpg_name_to_id(name) ---@param name string
  debug(3, '>>>>>>>> Entering gpg_name_to_id()')
  local output = gpg_system({
    level = 2,
    args = '--quiet --with-colons --fixed-list-mode --list-keys ' .. shellescape(name),
  })
  if vim.o.encoding ~= 'utf-8' then
    output = vim.fn.iconv(output, 'utf-8', vim.o.encoding)
  end
  local lines = split(output, '\n')
  local gpgids = {}
  local seen_keys = {}
  local skip_key = false
  local choices = 'The name "' .. name .. '" is ambiguous. Please select the correct key:\n'
  local counter = 0
  for _, line in ipairs(lines) do
    local fields = split(line, ':')
    if fields[1] == 'pub' then
      if seen_keys[fields[5]] then
        skip_key = true
      else
        skip_key = false
        seen_keys[fields[5]] = true
        if fields[12] and fields[12]:match('[eE]') then
          local identity = fields[5]
          insert(gpgids, identity)
          if fn.exists('*strftime') == 1 then
            local ts = tonumber(fields[6])
            if ts then
              ---@cast ts integer
              choices = choices
                  .. counter
                  .. ': ID: 0x'
                  .. identity
                  .. ' created at '
                  .. fn.strftime('%c', ts)
                  .. '\n'
            end
          else
            choices = choices .. counter .. ': ID: 0x' .. identity .. '\n'
          end
          counter = counter + 1
        end
      end
    elseif not skip_key and fields[1] == 'uid' then
      choices = choices .. '   ' .. fields[10] .. '\n'
    end
  end
  local answer = 0
  if counter > 1 then
    choices = choices .. 'Enter number: '
    answer = tonumber(fn.input(choices, '0')) or 0
  end
  debug(3, '<<<<<<<< Leaving gpg_name_to_id()')
  return gpgids[answer + 1] or ''
end

local function check_recipients(tocheck) ---@param tocheck table
  debug(3, '>>>>>>>> Entering check_recipients()')
  local recipients = { valid = {}, unknown = {} }
  if type(tocheck) == 'table' then
    for _, recipient in ipairs(tocheck) do
      local gpgid = gpg_name_to_id(recipient)
      if gpgid ~= '' then
        if not contains(recipients.valid, gpgid) then
          insert(recipients.valid, gpgid)
        end
      else
        if not contains(recipients.unknown, recipient) then
          insert(recipients.unknown, recipient)
          echo({
            {
              'The recipient "' .. recipient .. '" is not in your public keyring!',
              'WarningMsg',
            },
          }, true, {})
        end
      end
    end
  end
  debug(2, 'recipients are: ' .. vim.inspect(recipients.valid))
  debug(2, 'unknown recipients are: ' .. vim.inspect(recipients.unknown))
  debug(3, '<<<<<<<< Leaving check_recipients()')
  return recipients ---@return table
end
---@return string
local function gpg_id_to_name(identity) ---@param identity string
  debug(3, '>>>>>>>> Entering gpg_id_to_name()')
  local output = gpg_system({
    level = 2,
    args = '--quiet --with-colons --fixed-list-mode --list-keys ' .. identity,
  })
  if vim.o.encoding ~= 'utf-8' then
    output = vim.fn.iconv(output, 'utf-8', vim.o.encoding)
  end
  local lines = split(output, '\n')
  local pubseen = false
  local uid = ''
  for _, line in ipairs(lines) do
    local fields = split(line, ':')
    if not pubseen then
      if fields[1] == 'pub' then
        if fields[12] and fields[12]:match('[eE]') then
          pubseen = true
        end
      end
    else
      if fields[1] == 'uid' then
        if fn.exists('*strftime') == 1 then
          local ts = tonumber(fields[6])
          if ts then
            ---@cast ts integer
            uid = fields[10]
                .. GPG_MAGIC_STRING
                .. '(ID: 0x'
                .. identity
                .. ' created at '
                .. fn.strftime('%c', ts)
                .. ')'
          end
        else
          uid = fields[10] .. GPG_MAGIC_STRING .. '(ID: 0x' .. identity .. ')'
        end
        break
      end
    end
  end
  debug(3, '<<<<<<<< Leaving gpg_id_to_name()')
  return uid
end
function M.view_recipients()
  debug(3, '>>>>>>>> Entering view_recipients()')
  if unencrypted() then
    debug(3, '<<<<<<<< Leaving view_recipients()')
    return
  end
  local recipients = check_recipients(GPGRecipients)
  print('This file has following recipients (Unknown recipients have a prepended "!"):')
  if #recipients.valid == 0 then
    api.nvim_echo({
      { 'There are no known recipients!', 'ErrorMsg' },
    }, true, {})
  else
    for _, id in ipairs(recipients.valid) do
      print(gpg_id_to_name(id))
    end
  end
  if #recipients.unknown > 0 then
    echo({
      {
        table.concat(
          vim.tbl_map(function(r)
            return '!' .. r
          end, recipients.unknown),
          '\n'
        ),
        'WarningMsg',
      },
    }, true, {})
  end
  debug(3, '<<<<<<<< Leaving view_recipients()')
end

function M.edit_recipients()
  debug(3, '>>>>>>>> Entering edit_recipients()')
  if unencrypted() then
    debug(3, '<<<<<<<< Leaving edit_recipients()')
    return
  end
  local recipients = check_recipients(GPGRecipients)
  local input_list = {}
  for _, name in ipairs(recipients.valid) do
    insert(input_list, gpg_id_to_name(name))
  end
  for _, name in ipairs(recipients.unknown) do
    insert(input_list, '!' .. name)
  end
  print('Current recipients:')
  print(table.concat(input_list, '\n'))

  debug(3, '<<<<<<<< Leaving edit_recipients()')
end

function M.init(bufread) ---@param bufread boolean
  debug(3, fmt('>>>>>>>> Entering init(%s)', bufread))
  if bufread then
    vim.opt_local.swapfile = false
    if vim.fn.exists('+undofile') == 1 then
      vim.opt_local.undofile = false
    end
    vim.o.viminfo = ''
  end
  if init_run then
    return
  end
  if not vim.g.GPGExecutable then
    if fn.executable('gpg') == 1 then
      vim.g.GPGExecutable = 'gpg --trust-model always'
    else
      vim.g.GPGExecutable = 'gpg2 --trust-model always'
    end
  end
  vim.g.GPGUseAgent = vim.g.GPGUseAgent or 1
  vim.g.GPGPreferSymmetric = vim.g.GPGPreferSymmetric or 0
  vim.g.GPGPreferSign = vim.g.GPGPreferSign or 0
  vim.g.GPGDefaultRecipients = vim.g.GPGDefaultRecipients or {}
  vim.g.GPGPossibleRecipients = vim.g.GPGPossibleRecipients or {}
  vim.g.GPGUsePipes = vim.g.GPGUsePipes or 0
  GPGHomedir = GPGHomedir or ''
  GPGCommand = vim.g.GPGExecutable
  shellredirsave = vim.o.shellredir
  shellsave = vim.o.shell
  shelltempsave = vim.o.shelltemp
  shelltemp = not (vim.g.GPGUsePipes == 1)
  if vim.fn.has('unix') == 1 then
    shellredir = '>%s 2>&1'
    shell = '/bin/sh'
    stderrredirnull = '2>/dev/null'
  else
    shellredir = '>%s'
    shell = vim.o.shell
    stderrredirnull = '2>nul'
  end
  if not vim.fn.has('gui_running') or vim.fn.has('gui_win32') == 1 then
    GPGCommand = GPGCommand .. ' --no-tty'
  end
  local output = gpg_system({ level = 2, args = '--version' })
  local gpgversion = output:match('^gpg %(GnuPG%) ([0-9]+%.[0-9]+)')
  GPGPubkey = output:match('Pubkey: ([^\n]+)') or ''
  GPGCipher = output:match('Cipher: ([^\n]+)') or ''
  GPGHash = output:match('Hash: ([^\n]+)') or ''
  GPGCompress = output:match('Compress[^:]*: ([^\n]+)') or ''
  GPGHome = output:match('Home: ([^\r\n]+)') or ''
  if vim.fn.has('win32unix') == 1 and GPGHome:match('^%a:[/\\]') then
    debug(1, 'Enabling use of cygpath')
    useCygpath = true
  end
  local ver = tonumber(gpgversion) or 0
  if ver >= 2.1 or (env.GPG_AGENT_INFO and vim.g.GPGUseAgent == 1) then
    if not env.GPG_TTY and vim.fn.has('gui_running') == 0 then
      if fn.executable('tty') == 1 then
        local result = vim.system({
          'tty',
        }, {
          text = true,
        }):wait()
        if result.code == 0 then
          env.GPG_TTY = vim.trim(result.stdout or '')
        else
          env.GPG_TTY = ''
          echo({
            { '$GPG_TTY is not set and the `tty` command failed! gpg-agent might not work.', 'WarningMsg' },
          }, true, {})
        end
      end
    end
    GPGCommand = GPGCommand .. ' --use-agent'
  else
    GPGCommand = GPGCommand .. ' --no-use-agent'
  end
  debug(2, 'public key algorithms: ' .. GPGPubkey)
  debug(2, 'cipher algorithms: ' .. GPGCipher)
  debug(2, 'hashing algorithms: ' .. GPGHash)
  debug(2, 'compression algorithms: ' .. GPGCompress)
  debug(3, '<<<<<<<< Leaving init()')
  init_run = true
end

function M.decrypt(bufread) ---@param bufread boolean
  debug(3, fmt('>>>>>>>> Entering decrypt(%s)', bufread))
  local filename = fn.resolve(fn.expand('<afile>:p'))
  if type(vim.g.GPGDefaultRecipients) == 'table' then
    GPGRecipients = vim.deepcopy(vim.g.GPGDefaultRecipients)
  else
    GPGRecipients = {}
    echo({
      {
        'g:GPGDefaultRecipients is not a Vim list, please correct this in your gpg config!',
        'WarningMsg',
      },
    }, true, {})
  end
  b.GPGOptions = {}
  local autocmd_filename = fn.fnamemodify(filename, ':r')
  if fn.filereadable(filename) == 0 then
    if not bufread then
      cmd('redraw!')
      api.nvim_echo({
        { 'E484: Can\'t open file ' .. filename, 'ErrorMsg' },
      }, true, {})
      return
    end
    cmd('silent doautocmd User GnuPG')
    cmd('silent doautocmd BufNewFile ' .. fn.fnameescape(autocmd_filename))
    debug(2, 'called BufNewFile autocommand for ' .. autocmd_filename)
    vim.opt_local.buftype = 'acwrite'
    cmd('silent 0file')
    cmd('silent file ' .. fn.fnameescape(filename))
    if g.GPGPreferSymmetric == 0 then
      M.edit_recipients()
    end
    return
  end
  b.GPGEncrypted = 0
  local output = gpg_system({
    level = 3,
    args = '--verbose --decrypt --list-only --dry-run --no-use-agent --logger-fd 1 ' .. shellescape(filename, {
      cygpath = true,
    }),
  })
  local silent = bufread and 'silent ' or ''
  local asym_pattern = 'gpg: public key is ' .. KEY_PATTERN
  if output:match('gpg: encrypted with [[:digit:]]+ passphrase') then
    vim.b.GPGEncrypted = 1
    debug(1, 'this file is symmetric encrypted')
    insert(vim.b.GPGOptions, 'symmetric')
    local cipher = output:match('gpg: ([^ ]+) encrypted data')
    if cipher and GPGCipher:match('%f[%w]' .. cipher .. '%f[%W]') then
      insert(vim.b.GPGOptions, 'cipher-algo ' .. cipher)
      debug(1, 'cipher-algo is ' .. cipher)
    end
  elseif output:match(asym_pattern) then
    vim.b.GPGEncrypted = 1
    debug(1, 'this file is asymmetric encrypted')
    insert(vim.b.GPGOptions, 'encrypt')
    for recipient in output:gmatch('gpg: public key is (' .. KEY_PATTERN .. ')') do
      debug(1, 'recipient is ' .. recipient)
      if not recipient:match('^0x0+$') then
        local name = gpg_name_to_id(recipient)
        if name ~= '' then
          insert(GPGRecipients, name)
          debug(1, 'name of recipient is ' .. name)
        else
          insert(GPGRecipients, recipient)
          echo({
            { 'The recipient "' .. recipient .. '" is not in your public keyring!', 'WarningMsg' },
          }, true, {})
        end
      end
    end
  else
    b.GPGEncrypted = 0
    debug(1, 'this file is not encrypted')
    echo({
      {
        'File is not encrypted, all GPG functions disabled!',
        'WarningMsg',
      },
    }, true, {})
  end
  local bufname = vim.b.GPGEncrypted == 1 and autocmd_filename or filename
  if bufread then
    cmd('silent doautocmd BufReadPre ' .. fn.fnameescape(bufname))
    debug(2, 'called BufReadPre autocommand for ' .. bufname)
  else
    cmd('silent doautocmd FileReadPre ' .. fn.fnameescape(bufname))
    debug(2, 'called FileReadPre autocommand for ' .. bufname)
  end
  if vim.b.GPGEncrypted == 1 then
    local first_line = fn.readfile(filename, '', 1)[1]
    if first_line and first_line:match('^%-%-%-%-%-BEGIN PGP') then
      debug(1, 'this file is armored')
      insert(vim.b.GPGOptions, 'armor')
    end
    debug(1, 'decrypting file')
    gpg_execute({
      level = 1,
      ex = silent .. 'read ++edit !',
      args = '--quiet --decrypt ' .. shellescape(filename, {
        special = true,
        cygpath = true,
      }),
    })
    if vim.v.shell_error ~= 0 then
      echo({
        { 'Message could not be decrypted! (Press ENTER)', 'ErrorMsg' },
      }, true, {})
      fn.input('')
      if bufread then
        cmd('silent bwipeout!')
      end
      debug(3, '<<<<<<<< Leaving decrypt()')
      return
    end
    if bufread then
      vim.opt_local.buftype = 'acwrite'
      cmd('file ' .. fn.fnameescape(filename))
    end
  else
    cmd(silent .. 'read ' .. fn.fnameescape(filename))
  end
  if bufread then
    local levels = vim.o.undolevels
    vim.o.undolevels = -1
    cmd('silent 1delete')
    api.nvim_buf_set_mark(0, '[', 1, 0, {})
    api.nvim_buf_set_mark(0, ']', fn.line('$'), 0, {})
    vim.o.undolevels = levels
    local readonly = vim.o.readonly or (fn.filereadable(filename) == 1 and fn.filewritable(filename) == 0)
    vim.opt_local.readonly = readonly
    cmd('silent doautocmd BufReadPost ' .. fn.fnameescape(bufname))
    debug(2, 'called BufReadPost autocommand for ' .. bufname)
  else
    cmd('silent doautocmd FileReadPost ' .. fn.fnameescape(bufname))
    debug(2, 'called FileReadPost autocommand for ' .. bufname)
  end
  if vim.b.GPGEncrypted == 1 then
    cmd('silent doautocmd User GnuPG')
    cmd('redraw!')
  end
  debug(3, '<<<<<<<< Leaving decrypt()')
end

function M.encrypt()
  debug(3, '>>>>>>>> Entering encrypt()')
  local au_type = 'BufWrite'
  if vim.fn.line('\'[') ~= 1 or vim.fn.line('\']') ~= fn.line('$') then
    au_type = 'FileWrite'
  end
  local autocmd_filename = fn.expand('<afile>:p:r')
  cmd('silent doautocmd ' .. au_type .. 'Pre ' .. fn.fnameescape(autocmd_filename))
  debug(2, 'called ' .. au_type .. 'Pre autocommand for ' .. autocmd_filename)
  if vim.b.GPGEncrypted == 0 then
    echo({
      { 'Message could not be encrypted! (Press ENTER)', 'ErrorMsg' },
    }, true, {})
    fn.input('')
    debug(3, '<<<<<<<< Leaving encrypt()')
    return
  end
  local filename = fn.resolve(fn.expand('<afile>:p'))
  if not vim.b.GPGOptions or #vim.b.GPGOptions == 0 then
    vim.b.GPGOptions = {}
    if vim.g.GPGPreferSymmetric == 1 then
      insert(vim.b.GPGOptions, 'symmetric')
      GPGRecipients = {}
    else
      insert(vim.b.GPGOptions, 'encrypt')
    end
    local preferArmor = vim.g.GPGPreferArmor or -1
    if (preferArmor >= 0 and preferArmor == 1) or filename:match('%.asc$') then
      insert(vim.b.GPGOptions, 'armor')
    end
    if vim.g.GPGPreferSign == 1 then
      insert(vim.b.GPGOptions, 'sign')
    end
    debug(1, 'no options set, using default options: ' .. vim.inspect(vim.b.GPGOptions))
  end
  local options = ''
  for _, option in ipairs(vim.b.GPGOptions) do
    options = options .. ' --' .. option
  end
  GPGRecipients = GPGRecipients or {}
  local recipients = check_recipients(GPGRecipients)
  if #recipients.unknown > 0 then
    echo({
      {
        'Please use GPGEditRecipients to correct!!',
        'WarningMsg',
      },
    }, true, {})
    fn.input('Press ENTER to quit')
  end
  for _, recipient in ipairs(recipients.valid) do
    options = options .. ' -r ' .. recipient
  end
  local destfile = fn.tempname()
  local ex_cmd = au_type == 'FileWrite' and '\'[,\']write !' or 'write !'
  gpg_execute({
    level = 1,
    ex = ex_cmd,
    args = '--quiet --no-encrypt-to ' .. options,
    redirect = '>' .. shellescape(destfile, { special = true, cygpath = true }),
  })
  if vim.v.shell_error ~= 0 then
    fn.delete(destfile)
    echo({
      { 'Message could not be encrypted! (Press ENTER)', 'ErrorMsg' },
    }, true, {})
    fn.input('')
    debug(3, '<<<<<<<< Leaving encrypt()')
    return
  end
  if fn.rename(destfile, filename) ~= 0 then
    fn.delete(destfile)
    echo({
      {
        fmt('"%s" E212: Can\'t open file for writing', filename),
        'ErrorMsg',
      },
    }, true, {})
    return
  end
  if au_type == 'BufWrite' then
    if fn.expand('%:p') == filename then
      vim.opt_local.modified = false
    end
    vim.opt_local.buftype = 'acwrite'
    vim.opt_local.readonly = fn.filereadable(filename) == 1 and fn.filewritable(filename) == 0
  end
  cmd('silent doautocmd ' .. au_type .. 'Post ' .. fn.fnameescape(autocmd_filename))
  debug(2, 'called ' .. au_type .. 'Post autocommand for ' .. autocmd_filename)
  debug(3, '<<<<<<<< Leaving encrypt()')
end

function M.edit_recipients()
  debug(3, '>>>>>>>> Entering edit_recipients()')
  if unencrypted() then
    debug(3, '<<<<<<<< Leaving edit_recipients()')
    return
  end
  local recipients = check_recipients(GPGRecipients)
  local input_list = {}
  for _, name in ipairs(recipients.valid) do
    insert(input_list, gpg_id_to_name(name))
  end
  for _, name in ipairs(recipients.unknown) do
    insert(input_list, '!' .. name)
  end
  print('Current recipients:')
  print(table.concat(input_list, '\n'))
  debug(3, '<<<<<<<< Leaving edit_recipients()')
end

function M.view_options()
  debug(3, '>>>>>>>> Entering view_options()')
  if unencrypted() then
    debug(3, '<<<<<<<< Leaving view_options()')
    return
  end
  if vim.b.GPGOptions then
    print('This file has following options:')
    print(table.concat(vim.b.GPGOptions, '\n'))
  end
  debug(3, '<<<<<<<< Leaving view_options()')
end

function M.view_options()
  debug(3, '>>>>>>>> Entering view_options()')
  if unencrypted() then
    debug(3, '<<<<<<<< Leaving view_options()')
    return
  end
  if vim.b.GPGOptions then
    print('This file has following options:')
    print(table.concat(vim.b.GPGOptions, '\n'))
  end
  debug(3, '<<<<<<<< Leaving view_options()')
end

return M