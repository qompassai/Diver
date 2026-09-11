
-- ~/.config/nvim/lua/utils/docs/equations.lua
-- Live equation preview: LuaLaTeX -> PNG -> native vim.ui.img (Neovim 0.13+).
-- No plugin dependencies. Call require('utils.docs.equations').setup().
-- Sources: Neovim runtime/lua/vim/ui/img.lua; LuaTeX CLI; Poppler pdftoppm.
local M = {}
local api, uv = vim.api, vim.uv
local defaults = {
  debounce_ms = 500,
  timeout_ms = 15000,
  width = 60,
  max_height = 20,
  dpi = 160,
  cell_aspect = 2.0, -- terminal cell height / width; adjust for your font
  preamble = '', -- explicit macros only; no automatic project preamble imports
}
local opts = vim.deepcopy(defaults)
local MAX_BUFFER = 256 * 1024
local MAX_EQUATION = 16 * 1024
local MAX_PNG = 8 * 1024 * 1024
local MAX_LOG = 8192
local environments = { 
equation = true, ['equation*'] = true, align = true,
  ['align*'] = true, gather = true, ['gather*'] = true, multline = true,
  ['multline*'] = true, displaymath = true, math = true
 }
local state = {
 generation = 0, buf = nil, timer = nil, job = nil,
  image = nil, win = nil, preview_buf = nil, key = nil, png = nil, error = nil
 }
local group
local directories = {}
local img

local function escaped(text, index)
  local slashes = 0
  index = index - 1
  while index > 0 and text:sub(index, index) == '\\' do
    slashes, index = slashes + 1, index - 1
  end
  return slashes % 2 == 1
end

---Extract the math span containing a 1-based row and zero-based byte column.
---Fenced Markdown code, inline code, escaped dollars and TeX comments are skipped.
---@param lines string[]
---@param row integer
---@param col integer
---@param filetype string
---@return string? equation
---@return string? error
function M.extract(lines, row, col, filetype)
  local size, cursor, masked, fence = 0, nil, {}, nil
  local markdown = filetype == 'markdown' or filetype == 'quarto' or filetype == 'rmd'
  for number, line in ipairs(lines) do
    if number == row then cursor = size + math.min(col, #line) + 1 end
    size = size + #line + 1
    if size > MAX_BUFFER then return nil, 'Buffer exceeds the 256 KiB preview limit.' end
    local clean = line
    if markdown then
      local marker = line:match('^%s*(```+)' ) or line:match('^%s*(~~~+)')
      if fence then
        clean = string.rep(' ', #line)
        if marker and marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then fence = nil end
      elseif marker then
        fence, clean = marker, string.rep(' ', #line)
      else
        -- Mask paired inline backtick runs, preserving byte positions.
        local start = 1
        while start <= #clean do
          local first, last = clean:find('`+', start)
          if not first then break end
          local ending = clean:find(clean:sub(first, last), last + 1, true)
          if not ending then break end
          local finish = ending + last - first
          clean = clean:sub(1, first - 1) .. string.rep(' ', finish - first + 1) .. clean:sub(finish + 1)
          start = finish + 1
        end
      end
    else
      local start = 1
      while true do
        local at = clean:find('%%', start)
        if not at then break end
        if not escaped(clean, at) then
          clean = clean:sub(1, at - 1) .. string.rep(' ', #clean - at + 1)
          break
        end
        start = at + 1
      end
    end
    masked[#masked + 1] = clean
  end
  if not cursor then return nil end
  local text, original = table.concat(masked, '\n'), table.concat(lines, '\n')
  local index = 1
  while index <= #text do
    local char, pair = text:sub(index, index), text:sub(index, index + 1)
    local closing, open_length, is_environment
    if not escaped(text, index) then
      if pair == '$$' then closing, open_length = '$$', 2
      elseif char == '$' then closing, open_length = '$', 1
      elseif pair == '\\(' then closing, open_length = '\\)', 2
      elseif pair == '\\[' then closing, open_length = '\\]', 2
      elseif text:sub(index, index + 6) == '\\begin{' then
        local env = text:sub(index):match('^\\begin{([%a*]+)}')
        if env and environments[env] then
          closing, open_length, is_environment = '\\end{' .. env .. '}', #env + 8, true
        end
      end
    end
    if closing then
      local search, finish = index + open_length, nil
      while search <= #text do
        local at = text:find(closing, search, true)
        if not at then break end
        if not escaped(text, at) then finish = at + #closing - 1; break end
        search = at + #closing
      end
      if not finish then return nil end
      if cursor >= index and cursor <= finish then
        if finish - index + 1 > MAX_EQUATION then return nil, 'Equation exceeds 16 KiB.' end
        local equation = original:sub(index, finish)
        if is_environment then return equation end
        local body = original:sub(index + open_length, finish - #closing)
        return '\\[\n' .. body .. '\n\\]'
      end
      index = finish + 1
    else
      index = index + 1
    end
  end
  return nil
end

---Construct an isolated document. Project files are never imported implicitly.
---@param equation string
---@return string
function M.document(equation)
  return table.concat({
    '\\documentclass[12pt]{article}', '\\usepackage{amsmath,amssymb,varwidth}',
    '\\pagestyle{empty}', opts.preamble,
    '\\newsavebox{\\equationbox}', '\\begin{document}',
    '\\begin{lrbox}{\\equationbox}\\begin{varwidth}{30cm}',
    equation, '\\end{varwidth}\\end{lrbox}',
    '\\pagewidth=\\dimexpr\\wd\\equationbox+8pt\\relax',
    '\\pageheight=\\dimexpr\\ht\\equationbox+\\dp\\equationbox+8pt\\relax',
    '\\hoffset=-1in\\voffset=-1in',
    '\\shipout\\vbox{\\kern4pt\\hbox{\\kern4pt\\usebox{\\equationbox}\\kern4pt}\\kern4pt}',
    '\\end{document}', '',
  }, '\n')
end

local function hide()
  if state.image and img then pcall(img.del, state.image) end
  state.image = nil
  if state.win and api.nvim_win_is_valid(state.win) then pcall(api.nvim_win_close, state.win, true) end
  state.win = nil
  if state.preview_buf and api.nvim_buf_is_valid(state.preview_buf) then
    pcall(api.nvim_buf_delete, state.preview_buf, { force = true })
  end
  state.preview_buf = nil
end

local function cancel()
  state.generation = state.generation + 1
  if state.timer then state.timer:stop() end
  if state.job then pcall(state.job.kill, state.job, 9); state.job = nil end
end

local function failure(message)
  state.error = message:sub(1, MAX_LOG)
  hide() -- never leave a stale equation displayed as if it were current
end

local function read_file(path, maximum)
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= 'file' or stat.size > maximum then return nil end
  local fd = uv.fs_open(path, 'r', 384)
  if not fd then return nil end
  local bytes = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return bytes
end

local function png_size(bytes)
  if #bytes < 24 or bytes:sub(1, 8) ~= '\137PNG\r\n\26\n' then return nil end
  local function number(at)
    local a, b, c, d = bytes:byte(at, at + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  local width, height = number(17), number(21)
  if width < 1 or height < 1 or width > 8192 or height > 8192 then return nil end
  return width, height
end

local function display(bytes)
  if state.buf ~= api.nvim_get_current_buf() then return end
  local pixels_w, pixels_h = png_size(bytes)
  if not pixels_w or not pixels_h then failure('Renderer returned an invalid or oversized PNG.'); return end
  hide()
  local width = math.max(1, math.min(opts.width, vim.o.columns - 4))
  local height = math.max(1, math.ceil(width * pixels_h / pixels_w / opts.cell_aspect))
  local max_height = math.max(1, math.min(opts.max_height, vim.o.lines - vim.o.cmdheight - 5))
  if height > max_height then
    width = math.max(1, math.floor(width * max_height / height))
    height = max_height
  end
  local row, col = 1, math.max(0, vim.o.columns - width - 3)
  state.preview_buf = api.nvim_create_buf(false, true)
  state.win = api.nvim_open_win(state.preview_buf, false, {
    relative = 'editor', row = row, col = col, width = width, height = height,
    style = 'minimal', focusable = false, border = 'single', zindex = 60,
    title = ' Equation ', title_pos = 'center', noautocmd = true,
  })
  -- Native image coordinates are 1-based screen cells, including float border.
  local ok, id = pcall(img.set, bytes, { row = row + 2, col = col + 2,
    width = width, height = height, zindex = 61 })
  if not ok then failure('Native image display failed: ' .. tostring(id)); return end
  state.image, state.png, state.error = id, bytes, nil
end

-- Only system TeX/font/runtime trees are readable. /work is the sole persistent
-- writable mount. No project/home mount, network, shell, or inherited Lua env.
local function sandbox(directory, command)
  local args = { vim.fn.exepath('bwrap'), '--unshare-all', '--die-with-parent',
    '--new-session', '--clearenv' }
  for _, path in ipairs({ '/usr', '/bin', '/lib', '/lib64', '/etc/fonts',
    '/etc/texmf', '/var/lib/texmf', '/var/cache/fontconfig' }) do
    if uv.fs_stat(path) then vim.list_extend(args, { '--ro-bind', path, path }) end
  end
  vim.list_extend(args, { '--proc', '/proc', '--dev', '/dev', '--tmpfs', '/tmp',
    '--bind', directory, '/work', '--chdir', '/work',
    '--setenv', 'PATH', '/usr/bin:/bin', '--setenv', 'HOME', '/work',
    '--setenv', 'LANG', 'C.UTF-8', '--setenv', 'TEXMFVAR', '/work/texmf-var',
    '--setenv', 'TEXMFCONFIG', '/work/texmf-config', '--setenv', 'TEXMFCACHE', '/work/texmf-var',
    '--setenv', 'openin_any', 'p', '--setenv', 'openout_any', 'p',
    '--', '/usr/bin/prlimit', '--as=1073741824', '--cpu=12', '--fsize=16777216', '--' })
  vim.list_extend(args, command)
  return args
end

local function render(equation)
  local key = vim.fn.sha256(equation .. '\n' .. opts.preamble)
  if state.key == key and state.png then display(state.png); return end
  cancel()
  local generation, bufnr = state.generation, state.buf
  local directory, err = uv.fs_mkdtemp(vim.fn.stdpath('cache') .. '/equation-XXXXXX')
  if not directory then failure('Cannot create private rendering directory: ' .. tostring(err)); return end
  directories[directory] = true
  uv.fs_chmod(directory, 448)
  local fd = uv.fs_open(directory .. '/equation.tex', 'w', 384)
  if not fd then vim.fn.delete(directory, 'rf'); failure('Cannot write equation.tex'); return end
  local document = M.document(equation)
  local written = uv.fs_write(fd, document, 0)
  uv.fs_close(fd)
  if written ~= #document then vim.fn.delete(directory, 'rf'); failure('Incomplete equation write'); return end
  local function current()
    return state.generation == generation and state.buf == bufnr and api.nvim_buf_is_valid(bufnr)
  end
  local function cleanup()
    vim.fn.delete(directory, 'rf')
    directories[directory] = nil
  end
  local function run(command, callback)
    local log, length = {}, 0
    local function collect(error, data)
      local chunk = data or error
      if chunk and length < MAX_LOG then
        chunk = chunk:sub(1, MAX_LOG - length)
        log[#log + 1], length = chunk, length + #chunk
      end
    end
    local ok, job = pcall(vim.system, sandbox(directory, command), {
      text = true, timeout = opts.timeout_ms, stdout = collect, stderr = collect,
    }, function(result)
      vim.schedule(function()
        if not current() then cleanup(); return end
        state.job = nil
        if result.code ~= 0 then
          cleanup()
          failure('Equation render failed (exit ' .. result.code .. ').\n' .. table.concat(log))
          return
        end
        callback()
      end)
    end)
    if ok then state.job = job else cleanup(); failure(tostring(job)) end
  end
  run({ '/usr/bin/lualatex', '--safer', '--nosocket', '--no-shell-escape',
    '--halt-on-error', '--interaction=nonstopmode', '--file-line-error', 'equation.tex' }, function()
    run({ '/usr/bin/pdftoppm', '-f', '1', '-singlefile', '-scale-to', '2048',
      '-r', tostring(opts.dpi), '-png', 'equation.pdf', 'equation' }, function()
      local bytes = read_file(directory .. '/equation.png', MAX_PNG)
      cleanup()
      if not bytes then failure('PNG missing or larger than 8 MiB.'); return end
      state.key, state.png = key, bytes
      display(bytes)
    end)
  end)
end

local function update()
  if not state.buf or state.buf ~= api.nvim_get_current_buf() then return end
  local count = api.nvim_buf_line_count(state.buf)
  if api.nvim_buf_get_offset(state.buf, count) > MAX_BUFFER then
    failure('Buffer exceeds the 256 KiB preview limit.'); return
  end
  local cursor = api.nvim_win_get_cursor(0)
  local equation, err = M.extract(api.nvim_buf_get_lines(state.buf, 0, -1, false),
    cursor[1], cursor[2], vim.bo[state.buf].filetype)
  if not equation then cancel(); hide(); state.error = err; return end
  render(equation)
end

local function queue()
  if not state.buf or state.buf ~= api.nvim_get_current_buf() then return end
  cancel()
  hide()
  state.timer:start(opts.debounce_ms, 0, vim.schedule_wrap(update))
end

---Stop previewing and release only this module's images/processes.
function M.stop()
  cancel()
  hide()
  state.buf, state.key, state.png, state.error = nil, nil, nil, nil
  if state.timer then state.timer:close(); state.timer = nil end
end

---Enable live rendering for the current buffer. Nothing executes at setup time.
function M.start()
  local ok, backend = pcall(function() return vim.ui.img end)
  if not ok or type(backend) ~= 'table' or type(backend.set) ~= 'function'
    or type(backend.del) ~= 'function' then
    vim.notify('This Neovim build lacks native vim.ui.img.', vim.log.levels.ERROR); return
  end
  for _, executable in ipairs({ 'bwrap', 'lualatex', 'pdftoppm', 'prlimit' }) do
    if vim.fn.executable('/usr/bin/' .. executable) ~= 1 then
      vim.notify('Missing Arch dependency: /usr/bin/' .. executable, vim.log.levels.ERROR); return
    end
  end
  M.stop()
  img = backend
  vim.fn.mkdir(vim.fn.stdpath('cache'), 'p')
  local timer = uv.new_timer()
  if not timer then
    vim.notify('Cannot allocate equation preview timer.', vim.log.levels.ERROR); return
  end
  state.buf, state.timer = api.nvim_get_current_buf(), timer
  update()
end

---Register commands/autocommands; safe to call repeatedly.
---@param options? table
function M.setup(options)
  M.stop()
  opts = vim.tbl_extend('force', defaults, options or {})
  for name, range in pairs({ debounce_ms = { 100, 5000 }, timeout_ms = { 1000, 60000 },
    width = { 5, 200 }, max_height = { 2, 80 }, dpi = { 72, 300 } }) do
    local value = opts[name]
    assert(type(value) == 'number' and value == math.floor(value)
      and value >= range[1] and value <= range[2], 'Invalid latex_preview option: ' .. name)
  end
  assert(type(opts.cell_aspect) == 'number' and opts.cell_aspect >= 0.5 and opts.cell_aspect <= 4, 'Invalid cell_aspect')
  assert(type(opts.preamble) == 'string' and #opts.preamble <= MAX_EQUATION, 'Invalid preamble')
  group = api.nvim_create_augroup('NativeLatexPreview', {
 clear = true 
})
  api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'CursorMoved', 'CursorMovedI' }, { group = group, callback = queue })
  api.nvim_create_autocmd('BufEnter', { group = group, callback = queue })
  api.nvim_create_autocmd('BufLeave', { group = group, callback = function() cancel(); hide() end })
  api.nvim_create_autocmd('VimResized', { group = group, callback = queue })
  api.nvim_create_autocmd('BufWipeout', { group = group, callback = function(event)
    if event.buf == state.buf then M.stop() end
  end })
  api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
    M.stop()
    for directory in pairs(directories) do vim.fn.delete(directory, 'rf') end
  end })
  api.nvim_create_user_command('LatexPreview', M.start, { force = true, desc = 'Start live native equation preview in this buffer' })
  api.nvim_create_user_command('LatexPreviewStop', M.stop, { 
force = true, desc = 'Stop native equation preview'
 })
  api.nvim_create_user_command('LatexPreviewToggle', function()
    if state.buf == api.nvim_get_current_buf() then M.stop() else M.start() end
  end, {
 force = true, desc = 'Toggle live equation preview'
 })
  api.nvim_create_user_command('LatexPreviewLog', function()
    vim.notify(state.error or 'No rendering error. Place the cursor inside a complete equation.', vim.log.levels.INFO)
  end, {
 force = true, desc = 'Show the latest equation render error' 
})
end

return M