-- #################################################################
-- ~/.config/nvim/lua/formatters/init.lua
-- Native Formatter Runner — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
-- Native vim.system + one selected native LSP client; no formatter plugin.
-- require('formatters').setup() enables commands; format-on-save is opt-in.
-- Built-in definitions cover the ten existing fixer names. Future modules are
-- lazy-loaded from lua/formatters/<name>.lua only when that file exists.
-- Existing fixers/*.lua are not executed: diagnostic parsers / direct disk
-- writes are not a formatter contract. Move/adapt custom definitions instead.
local api = vim.api
local uv = vim.uv
local fs = vim.fs
local M = {}

---@class FormatterContext
---@field bufnr integer
---@field filename string Original absolute filename; never a write target.
---@field filetype string
---@field root string
---@field cwd string
---@field input string Current pipeline text, encoded as UTF-8 with LF endings.
---@field tempfile? string Private copy for mode='tempfile'.
---@field shiftwidth integer
---@field expandtab boolean

---@class FormatterSpec
---@field cmd string|string[] Ordered executable candidates, not shell commands.
---@field args? string[]|fun(context: FormatterContext): string[]
---@field mode? 'stdin'|'tempfile'
---@field cwd? string|fun(context: FormatterContext): string
---@field env? table<string,string>
---@field root_markers? string[]
---@field exit_codes? integer[]
---@field output? 'stdout'|'file'
---@field decode? fun(output: string, context: FormatterContext): string
---@field allow_empty? boolean Explicit permission to turn nonempty input into empty output.
---@field automatic? boolean Permit use in default chains and on save.
---@field extension? string Tempfile extension for unnamed buffers.

---@class FormatterRunOptions
---@field bufnr? integer
---@field names? string[] Explicit sequential formatter names.
---@field async? boolean Default true; false waits within timeout_ms.
---@field timeout_ms? integer Total deadline for all stages, not per stage.
---@field lsp? 'fallback'|'never'|'only'
---@field notify? boolean
---@field automatic? boolean Internal/on-save use; respects automatic=false.

M.options = {
  enabled = true,
  format_on_save = false,
  timeout_ms = 3000,
  save_timeout_ms = 1500,
  max_input_bytes = 2 * 1024 * 1024,
  max_output_bytes = 4 * 1024 * 1024,
  max_stderr_bytes = 128 * 1024,
  max_lsp_edits = 10000,
  lsp = 'fallback',
  preserve_eol = true,
  blackd_url = 'http://127.0.0.1:45484/',
  sql_language = 'sql',
  lsp_preference = { 'stylua_ls', 'biome_ls', 'ruff_ls', 'clangd_ls', 'gop_ls', 'rustana_ls' },
}
---@type table<string, FormatterSpec>
M.definitions = {}
---@type table<string,string>
M.load_errors = {}
---@type table<string,string>
M.module_sources = {
  ['aiken_fmt'] = 'formatters.aiken_fmt',
  ['air'] = 'formatters.air',
  ['alejandra'] = 'formatters.alejandra',
  ['autopep8'] = 'formatters.autopep8',
  ['awkfmt'] = 'formatters.awkfmt',
  ['bean_format'] = 'formatters.bean_format',
  ['bibclean'] = 'formatters.bibclean',
  ['bibtex_tidy'] = 'formatters.bibtex_tidy',
  ['bicep_format'] = 'formatters.bicep_format',
  ['biome'] = 'formatters.biome',
  ['black'] = 'formatters.black',
  ['blackd'] = 'formatters.blackd',
  ['brittany'] = 'formatters.brittany',
  ['buf_format'] = 'formatters.buf_format',
  ['buildifier'] = 'formatters.buildifier',
  ['cabal_fmt'] = 'formatters.cabal_fmt',
  ['cl_format'] = 'formatters.cl_format',
  ['clang_format'] = 'formatters.clang_format',
  ['cljfmt'] = 'formatters.cljfmt',
  ['cmake_format'] = 'formatters.cmake_format',
  ['cookstyle'] = 'formatters.cookstyle',
  ['csharpier'] = 'formatters.csharpier',
  ['css-beautify'] = 'formatters.css-beautify',
  ['cue_fmt'] = 'formatters.cue_fmt',
  ['dart_format'] = 'formatters.dart_format',
  ['deno_fmt'] = 'formatters.deno_fmt',
  ['dfmt'] = 'formatters.dfmt',
  ['dhall_format'] = 'formatters.dhall_format',
  ['djlint'] = 'formatters.djlint',
  ['docstrfmt'] = 'formatters.docstrfmt',
  ['dprint'] = 'formatters.dprint',
  ['efmt'] = 'formatters.efmt',
  ['elm_format'] = 'formatters.elm_format',
  ['erb_formatter'] = 'formatters.erb_formatter',
  ['erlfmt'] = 'formatters.erlfmt',
  ['fantomas'] = 'formatters.fantomas',
  ['findent'] = 'formatters.findent',
  ['fish_indent'] = 'formatters.fish_indent',
  ['fnlfmt'] = 'formatters.fnlfmt',
  ['forge_fmt'] = 'formatters.forge_fmt',
  ['fourmolu'] = 'formatters.fourmolu',
  ['fprettify'] = 'formatters.fprettify',
  ['gdformat'] = 'formatters.gdformat',
  ['gleam_format'] = 'formatters.gleam_format',
  ['gofmt'] = 'formatters.gofmt',
  ['gofumpt'] = 'formatters.gofumpt',
  ['goimports'] = 'formatters.goimports',
  ['google_java_format'] = 'formatters.google_java_format',
  ['grain_format'] = 'formatters.grain_format',
  ['hclfmt'] = 'formatters.hclfmt',
  ['hledger_fmt'] = 'formatters.hledger_fmt',
  ['htmlbeautify'] = 'formatters.htmlbeautify',
  ['janet_format'] = 'formatters.janet_format',
  ['jq'] = 'formatters.jq',
  ['jsonnetfmt'] = 'formatters.jsonnetfmt',
  ['julia_formatter'] = 'formatters.julia_formatter',
  ['just_fmt'] = 'formatters.just_fmt',
  ['kcl_fmt'] = 'formatters.kcl_fmt',
  ['ktfmt'] = 'formatters.ktfmt',
  ['ktlint'] = 'formatters.ktlint',
  ['kulala_fmt'] = 'formatters.kulala_fmt',
  ['latexindent'] = 'formatters.latexindent',
  ['mago_format'] = 'formatters.mago_format',
  ['mbake'] = 'formatters.mbake',
  ['mdformat'] = 'formatters.mdformat',
  ['mh_style'] = 'formatters.mh_style',
  ['mix_format'] = 'formatters.mix_format',
  ['muon_fmt'] = 'formatters.muon_fmt',
  ['nginxfmt'] = 'formatters.nginxfmt',
  ['nickel_format'] = 'formatters.nickel_format',
  ['nixfmt'] = 'formatters.nixfmt',
  ['nixpkgs_fmt'] = 'formatters.nixpkgs_fmt',
  ['nomad_fmt'] = 'formatters.nomad_fmt',
  ['nufmt'] = 'formatters.nufmt',
  ['ocamlformat'] = 'formatters.ocamlformat',
  ['opa_fmt'] = 'formatters.opa_fmt',
  ['ormolu'] = 'formatters.ormolu',
  ['packer_fmt'] = 'formatters.packer_fmt',
  ['panache'] = 'formatters.panache',
  ['perltidy'] = 'formatters.perltidy',
  ['pg_format'] = 'formatters.pg_format',
  ['phpcbf'] = 'formatters.phpcbf',
  ['phpcsfixer'] = 'formatters.phpcsfixer',
  ['pint'] = 'formatters.pint',
  ['powershell_formatter'] = 'formatters.powershell_formatter',
  ['prettier'] = 'formatters.prettier',
  ['prettierd'] = 'formatters.prettierd',
  ['ptop'] = 'formatters.ptop',
  ['puppet_lint_fix'] = 'formatters.puppet_lint_fix',
  ['purs_tidy'] = 'formatters.purs_tidy',
  ['qmlformat'] = 'formatters.qmlformat',
  ['raco_fmt'] = 'formatters.raco_fmt',
  ['refmt'] = 'formatters.refmt',
  ['rescript_format'] = 'formatters.rescript_format',
  ['robotidy'] = 'formatters.robotidy',
  ['rubocop'] = 'formatters.rubocop',
  ['rubyfmt'] = 'formatters.rubyfmt',
  ['ruff_format'] = 'formatters.ruff_format',
  ['rumdl_fmt'] = 'formatters.rumdl_fmt',
  ['rustfmt'] = 'formatters.rustfmt',
  ['scalafmt'] = 'formatters.scalafmt',
  ['scarb_fmt'] = 'formatters.scarb_fmt',
  ['schemat'] = 'formatters.schemat',
  ['shellharden'] = 'formatters.shellharden',
  ['shfmt'] = 'formatters.shfmt',
  ['snakefmt'] = 'formatters.snakefmt',
  ['sql-formatter'] = 'formatters.sql-formatter',
  ['sqlfluff'] = 'formatters.sqlfluff',
  ['sqruff'] = 'formatters.sqruff',
  ['standardrb'] = 'formatters.standardrb',
  ['styler'] = 'formatters.styler',
  ['stylua'] = 'formatters.stylua',
  ['superhtml'] = 'formatters.superhtml',
  ['swift_format'] = 'formatters.swift_format',
  ['swiftformat'] = 'formatters.swiftformat',
  ['taplo'] = 'formatters.taplo',
  ['templ_fmt'] = 'formatters.templ_fmt',
  ['terraform_fmt'] = 'formatters.terraform_fmt',
  ['tex_fmt'] = 'formatters.tex_fmt',
  ['tofu_fmt'] = 'formatters.tofu_fmt',
  ['tombi'] = 'formatters.tombi',
  ['twig_cs_fixer'] = 'formatters.twig_cs_fixer',
  ['typstfmt'] = 'formatters.typstfmt',
  ['typstyle'] = 'formatters.typstyle',
  ['uncrustify'] = 'formatters.uncrustify',
  ['v_fmt'] = 'formatters.v_fmt',
  ['verible_verilog_format'] = 'formatters.verible_verilog_format',
  ['vsg'] = 'formatters.vsg',
  ['wgslfmt'] = 'formatters.wgslfmt',
  ['xmlformat'] = 'formatters.xmlformat',
  ['xmllint'] = 'formatters.xmllint',
  ['yamlfmt'] = 'formatters.yamlfmt',
  ['yapf'] = 'formatters.yapf',
  ['zigfmt'] = 'formatters.zigfmt',
  ['zprint'] = 'formatters.zprint',
}

-- Outer entries are sequential stages. A nested list chooses the first available
-- alternative; it does NOT run every competing formatter. Missing future modules
-- are inactive. Go intentionally runs goimports and then gofumpt/gofmt.
---@type table<string, (string|string[])[]>
M.formatters_by_ft = {
  ['nix'] = { { 'alejandra', 'nixfmt', 'nixpkgs_fmt' } },
  ['python'] = { { 'ruff_format', 'blackd', 'black', 'yapf', 'autopep8' } },
  ['ruby'] = { { 'cookstyle', 'rubocop', 'standardrb', 'rubyfmt' } },
  ['eruby'] = { { 'erb_formatter', 'htmlbeautify' } },
  ['css'] = { { 'css-beautify', 'biome', 'prettierd', 'prettier' } },
  ['scss'] = { { 'prettierd', 'prettier' } },
  ['less'] = { { 'prettierd', 'prettier' } },
  ['go'] = { 'goimports', { 'gofumpt', 'gofmt' } },
  ['html'] = { { 'htmlbeautify', 'prettierd', 'prettier', 'superhtml' } },
  ['htmlangular'] = { { 'prettierd', 'prettier' } },
  ['php'] = { { 'phpcsfixer', 'mago_format', 'pint', 'phpcbf' } },
  ['sql'] = { { 'sql-formatter', 'sqlfluff', 'sqruff', 'pg_format' } },
  ['lua'] = { { 'stylua' } },
  ['luau'] = { { 'stylua' } },
  ['fennel'] = { { 'fnlfmt' } },
  ['sh'] = { { 'shfmt' } },
  ['bash'] = { { 'shfmt' } },
  ['fish'] = { { 'fish_indent' } },
  ['awk'] = { { 'awkfmt' } },
  ['c'] = { { 'clang_format', 'uncrustify' } },
  ['cpp'] = { { 'clang_format', 'uncrustify' } },
  ['objc'] = { { 'clang_format' } },
  ['objcpp'] = { { 'clang_format' } },
  ['cuda'] = { { 'clang_format' } },
  ['opencl'] = { { 'clang_format' } },
  ['glsl'] = { { 'clang_format' } },
  ['hlsl'] = { { 'clang_format' } },
  ['rust'] = { { 'rustfmt' } },
  ['zig'] = { { 'zigfmt' } },
  ['javascript'] = { { 'biome', 'prettierd', 'prettier', 'deno_fmt' } },
  ['javascriptreact'] = { { 'biome', 'prettierd', 'prettier', 'deno_fmt' } },
  ['typescript'] = { { 'biome', 'prettierd', 'prettier', 'deno_fmt' } },
  ['typescriptreact'] = { { 'biome', 'prettierd', 'prettier', 'deno_fmt' } },
  ['json'] = { { 'biome', 'prettierd', 'prettier', 'jq' } },
  ['jsonc'] = { { 'biome', 'prettierd', 'prettier' } },
  ['json5'] = { { 'prettierd', 'prettier' } },
  ['yaml'] = { { 'yamlfmt', 'prettierd', 'prettier' } },
  ['toml'] = { { 'taplo', 'tombi' } },
  ['xml'] = { { 'xmlformat', 'xmllint' } },
  ['svg'] = { { 'prettierd', 'prettier', 'xmlformat' } },
  ['vue'] = { { 'prettierd', 'prettier' } },
  ['svelte'] = { { 'prettierd', 'prettier' } },
  ['astro'] = { { 'prettierd', 'prettier' } },
  ['markdown'] = { { 'rumdl_fmt', 'prettierd', 'prettier', 'mdformat', 'panache' } },
  ['mdx'] = { { 'prettierd', 'prettier' } },
  ['rst'] = { { 'docstrfmt' } },
  ['tex'] = { { 'latexindent', 'tex_fmt' } },
  ['plaintex'] = { { 'latexindent', 'tex_fmt' } },
  ['bib'] = { { 'bibtex_tidy', 'bibclean' } },
  ['typst'] = { { 'typstyle', 'typstfmt' } },
  ['htmljinja'] = { { 'djlint' } },
  ['htmldjango'] = { { 'djlint' } },
  ['jinja'] = { { 'djlint' } },
  ['twig'] = { { 'twig_cs_fixer', 'prettier' } },
  ['liquid'] = { { 'prettier' } },
  ['graphql'] = { { 'prettierd', 'prettier' } },
  ['java'] = { { 'google_java_format', 'clang_format' } },
  ['kotlin'] = { { 'ktfmt', 'ktlint' } },
  ['cs'] = { { 'csharpier' } },
  ['fsharp'] = { { 'fantomas' } },
  ['scala'] = { { 'scalafmt' } },
  ['sbt'] = { { 'scalafmt' } },
  ['clojure'] = { { 'cljfmt', 'zprint' } },
  ['haskell'] = { { 'fourmolu', 'ormolu', 'brittany' } },
  ['cabal'] = { { 'cabal_fmt' } },
  ['ocaml'] = { { 'ocamlformat' } },
  ['ocamlinterface'] = { { 'ocamlformat' } },
  ['reason'] = { { 'refmt' } },
  ['elixir'] = { { 'mix_format' } },
  ['eelixir'] = { { 'mix_format' } },
  ['heex'] = { { 'mix_format' } },
  ['erlang'] = { { 'erlfmt', 'efmt' } },
  ['elm'] = { { 'elm_format' } },
  ['gleam'] = { { 'gleam_format' } },
  ['dart'] = { { 'dart_format' } },
  ['swift'] = { { 'swift_format', 'swiftformat' } },
  ['perl'] = { { 'perltidy' } },
  ['r'] = { { 'air', 'styler' } },
  ['julia'] = { { 'julia_formatter' } },
  ['fortran'] = { { 'fprettify', 'findent' } },
  ['matlab'] = { { 'mh_style' } },
  ['gdscript'] = { { 'gdformat' } },
  ['qml'] = { { 'qmlformat' } },
  ['cmake'] = { { 'cmake_format' } },
  ['make'] = { { 'mbake' } },
  ['meson'] = { { 'muon_fmt' } },
  ['starlark'] = { { 'buildifier' } },
  ['bzl'] = { { 'buildifier' } },
  ['bzlmod'] = { { 'buildifier' } },
  ['proto'] = { { 'buf_format', 'clang_format' } },
  ['terraform'] = { { 'terraform_fmt', 'tofu_fmt' } },
  ['terraform-vars'] = { { 'terraform_fmt', 'tofu_fmt' } },
  ['hcl'] = { { 'hclfmt', 'packer_fmt' } },
  ['nomad'] = { { 'nomad_fmt' } },
  ['rego'] = { { 'opa_fmt' } },
  ['cue'] = { { 'cue_fmt' } },
  ['dhall'] = { { 'dhall_format' } },
  ['nickel'] = { { 'nickel_format' } },
  ['jsonnet'] = { { 'jsonnetfmt' } },
  ['beancount'] = { { 'bean_format' } },
  ['ledger'] = { { 'hledger_fmt' } },
  ['hledger'] = { { 'hledger_fmt' } },
  ['nushell'] = { { 'nufmt' } },
  ['ps1'] = { { 'powershell_formatter' } },
  ['puppet'] = { { 'puppet_lint_fix' } },
  ['robot'] = { { 'robotidy' } },
  ['snakemake'] = { { 'snakefmt' } },
  ['solidity'] = { { 'forge_fmt', 'prettier' } },
  ['verilog'] = { { 'verible_verilog_format' } },
  ['systemverilog'] = { { 'verible_verilog_format' } },
  ['vhdl'] = { { 'vsg' } },
  ['wgsl'] = { { 'wgslfmt' } },
  ['d'] = { { 'dfmt' } },
  ['dlang'] = { { 'dfmt' } },
  ['pascal'] = { { 'ptop' } },
  ['racket'] = { { 'raco_fmt' } },
  ['scheme'] = { { 'schemat' } },
  ['commonlisp'] = { { 'cl_format' } },
  ['janet'] = { { 'janet_format' } },
  ['rescript'] = { { 'rescript_format' } },
  ['grain'] = { { 'grain_format' } },
  ['purescript'] = { { 'purs_tidy' } },
  ['just'] = { { 'just_fmt' } },
  ['nginx'] = { { 'nginxfmt' } },
  ['http'] = { { 'kulala_fmt' } },
  ['dockerfile'] = { { 'dprint' } },
  ['templ'] = { { 'templ_fmt' } },
  ['v'] = { { 'v_fmt' } },
  ['cairo'] = { { 'scarb_fmt' } },
  ['aiken'] = { { 'aiken_fmt' } },
  ['kcl'] = { { 'kcl_fmt' } },
  ['bicep'] = { { 'bicep_format' } },
}

-- Shellharden changes quoting semantics and is deliberately explicit-use only.
M.manual_formatters = { shellharden = true }

local function positive(value)
  return type(value) == 'number' and value > 0 and value == math.floor(value)
end

local function message(value)
  return tostring(value):gsub('[%z\1-\31\127]', ' '):sub(1, 4096)
end

local function notify(text, level)
  vim.notify(text, level or vim.log.levels.INFO, { title = 'Native formatters' })
end

local function current(bufnr)
  if not bufnr or bufnr == 0 then
    return api.nvim_get_current_buf()
  end
  return bufnr
end

local function readable(path)
  local stat = uv.fs_stat(path)
  return stat and stat.type == 'file'
end

local function executable(candidates)
  if type(candidates) == 'string' then
    candidates = { candidates }
  end
  for _, candidate in ipairs(candidates or {}) do
    if type(candidate) == 'string' and vim.fn.executable(candidate) == 1 then
      return vim.fn.exepath(candidate)
    end
  end
end

local function name_valid(name)
  return type(name) == 'string' and name:match('^[%w_-]+$') ~= nil
end

---@param name string
---@param definition FormatterSpec
function M.register(name, definition)
  assert(name_valid(name), 'Invalid formatter name')
  assert(type(definition) == 'table' and definition.cmd, 'Formatter requires cmd')
  local commands = type(definition.cmd) == 'string' and { definition.cmd } or definition.cmd
  assert(
    type(commands) == 'table' and vim.islist(commands) and #commands > 0,
    'cmd must be a string or nonempty candidate list'
  )
  for _, command in ipairs(commands) do
    assert(
      type(command) == 'string' and command ~= '' and not command:find('%z'),
      'Invalid formatter executable'
    )
  end
  assert(
    rawget(definition, 'parser') == nil and rawget(definition, 'ignore_exitcode') == nil,
    'Legacy linter/fixer spec: use FormatterSpec and explicit exit_codes'
  )
  assert(
    rawget(definition, 'stdin') == nil and rawget(definition, 'append_fname') == nil,
    'Use mode and explicit argv paths instead of legacy stdin/append_fname'
  )
  assert(
    definition.mode == nil or definition.mode == 'stdin' or definition.mode == 'tempfile',
    'Invalid mode'
  )
  assert(
    definition.output == nil or definition.output == 'stdout' or definition.output == 'file',
    'Invalid output'
  )
  assert(
    definition.output ~= 'file' or definition.mode == 'tempfile',
    'File output requires a private tempfile'
  )
  M.definitions[name] = definition
  M.load_errors[name] = nil
end

local loaded = {}
---@param name string
---@return FormatterSpec?
function M.get_definition(name)
  if not name_valid(name) then
    return nil
  end
  local source = M.module_sources[name] or ('formatters.' .. name)
  if not loaded[name] then
    local path = source:gsub('%.', '/')
    local exists = package.preload[source] ~= nil
      or package.loaded[source] ~= nil
      or #api.nvim_get_runtime_file('lua/' .. path .. '.lua', false) > 0
      or #api.nvim_get_runtime_file('lua/' .. path .. '/init.lua', false) > 0
    if exists then
      loaded[name] = true
      local ok, definition = pcall(require, source)
      if ok then
        ok, definition = pcall(M.register, name, definition)
      end
      if not ok then
        M.load_errors[name] = message(definition)
        return nil
      end
    end
  end
  if M.load_errors[name] then
    return nil
  end
  return M.definitions[name]
end

local function available(name, automatic)
  local definition = M.get_definition(name)
  if not definition then
    return nil
  end
  if automatic and (definition.automatic == false or M.manual_formatters[name]) then
    return nil
  end
  local cmd = executable(definition.cmd)
  if cmd then
    return { name = name, definition = definition, cmd = cmd }
  end
end

local function select_steps(bufnr, names, automatic)
  local steps = {}
  if names then
    assert(type(names) == 'table' and #names > 0, 'Explicit formatter list must not be empty')
    for _, name in ipairs(names) do
      local step = available(name, automatic)
      assert(step, M.load_errors[name] or ('Formatter unavailable: ' .. tostring(name)))
      steps[#steps + 1] = step
    end
  else
    for _, entry in ipairs(M.formatters_by_ft[vim.bo[bufnr].filetype] or {}) do
      for _, name in ipairs(type(entry) == 'table' and entry or { entry }) do
        local step = available(name, true)
        if step then
          steps[#steps + 1] = step
          break
        end
      end
    end
  end
  return steps
end

local function context_for(bufnr, definition, input)
  local filename = api.nvim_buf_get_name(bufnr)
  local cwd = vim.fn.getcwd()
  local markers = definition.root_markers
    or { '.git', 'package.json', 'composer.json', 'go.mod', 'pyproject.toml' }
  local root = filename ~= '' and fs.root(filename, markers) or nil
  root = root or (filename ~= '' and fs.dirname(filename)) or cwd
  local width = vim.bo[bufnr].shiftwidth
  local context = {
    bufnr = bufnr,
    filename = filename,
    filetype = vim.bo[bufnr].filetype,
    root = root,
    cwd = root,
    input = input,
    shiftwidth = width == 0 and vim.bo[bufnr].tabstop or width,
    expandtab = vim.bo[bufnr].expandtab,
  }
  local specified = definition.cwd
  if type(specified) == 'function' then
    context.cwd = specified(context)
  elseif type(specified) == 'string' then
    context.cwd = specified
  end
  assert(
    type(context.cwd) == 'string' and vim.fn.isdirectory(context.cwd) == 1,
    'Formatter cwd is not a directory'
  )
  return context
end

local function snapshot(bufnr)
  assert(api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr), 'Buffer is not loaded')
  local bo = vim.bo[bufnr]
  assert(
    bo.buftype == '' and bo.modifiable and not bo.readonly and not bo.binary,
    'Buffer is not eligible for formatting'
  )
  assert(
    api.nvim_buf_get_offset(bufnr, api.nvim_buf_line_count(bufnr)) <= M.options.max_input_bytes,
    'Buffer exceeds formatter input limit'
  )
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    assert(not line:find('[%z\n]'), 'Binary/NUL buffer cannot be formatted')
  end
  local text = table.concat(lines, '\n') .. (bo.endofline and '\n' or '')
  assert(#text <= M.options.max_input_bytes, 'Buffer exceeds formatter input limit')
  return {
    lines = lines,
    text = text,
    tick = api.nvim_buf_get_changedtick(bufnr),
    filename = api.nvim_buf_get_name(bufnr),
    filetype = bo.filetype,
    eol = bo.endofline,
    fileformat = bo.fileformat,
    encoding = bo.fileencoding,
    bomb = bo.bomb,
  }
end

local jobs = {}
local sequence = 0
local function fresh(job)
  local b, s = job.bufnr, job.snapshot
  return api.nvim_buf_is_valid(b)
    and api.nvim_buf_is_loaded(b)
    and api.nvim_buf_get_changedtick(b) == s.tick
    and api.nvim_buf_get_name(b) == s.filename
    and vim.bo[b].filetype == s.filetype
    and vim.bo[b].endofline == s.eol
    and vim.bo[b].fileformat == s.fileformat
    and vim.bo[b].fileencoding == s.encoding
    and vim.bo[b].bomb == s.bomb
    and vim.bo[b].modifiable
    and not vim.bo[b].readonly
end

local function cleanup_temp(job)
  if job.tempfile then
    uv.fs_unlink(job.tempfile)
    job.tempfile = nil
  end
  if job.tempdir then
    uv.fs_rmdir(job.tempdir)
    job.tempdir = nil
  end
end

local function finish(job, status, detail)
  if job.done then
    return
  end
  job.done, job.status, job.error = true, status, detail
  if job.timer and not job.timer:is_closing() then
    job.timer:stop()
    job.timer:close()
  end
  if jobs[job.bufnr] == job then
    jobs[job.bufnr] = nil
  end
  if not job.proc then
    cleanup_temp(job)
  end
  if job.opts.notify ~= false and detail and status ~= 'cancelled' then
    notify(message(detail), status == 'stale' and vim.log.levels.WARN or vim.log.levels.ERROR)
  end
  if job.callback then
    local ok, error_text = pcall(job.callback, job)
    if not ok then
      notify(message(error_text), vim.log.levels.ERROR)
    end
  end
end

local function cancel(job, reason)
  if not job or job.done then
    return
  end
  if job.proc then
    pcall(job.proc.kill, job.proc, 9)
  end
  if job.client and job.request_id then
    pcall(job.client.cancel_request, job.client, job.request_id)
  end
  finish(
    job,
    reason == 'timeout' and 'timeout' or 'cancelled',
    reason == 'timeout' and 'Formatting deadline exceeded' or nil
  )
end

function M.stop(bufnr)
  cancel(jobs[current(bufnr)], 'cancelled')
end

local function output_lines(text)
  assert(type(text) == 'string' and not text:find('%z'), 'Formatter produced invalid/binary text')
  text = text:gsub('\r\n', '\n')
  assert(not text:find('\r'), 'Formatter produced unsupported bare CR text')
  assert(#text <= M.options.max_output_bytes, 'Formatter output exceeds limit')
  local eol = text:sub(-1) == '\n'
  if eol then
    text = text:sub(1, -2)
  end
  return vim.split(text, '\n', { plain = true }), eol
end

local function apply(job)
  if job.done then
    return
  end
  if not fresh(job) then
    finish(job, 'stale', 'Buffer changed while formatting; result discarded')
    return
  end
  local ok, detail = pcall(function()
    local lines, eol = output_lines(job.text)
    local old = job.snapshot.lines
    local first = 1
    while first <= math.min(#old, #lines) and old[first] == lines[first] do
      first = first + 1
    end
    local last_old, last_new = #old, #lines
    while last_old >= first and last_new >= first and old[last_old] == lines[last_new] do
      last_old, last_new = last_old - 1, last_new - 1
    end
    if first <= last_old or first <= last_new then
      local views = {}
      for _, win in ipairs(vim.fn.win_findbuf(job.bufnr)) do
        views[win] = api.nvim_win_call(win, vim.fn.winsaveview)
      end
      local replacement = {}
      for index = first, last_new do
        replacement[#replacement + 1] = lines[index]
      end
      -- One buffer edit per entire pipeline: one undo operation, no partial stages.
      api.nvim_buf_set_lines(job.bufnr, first - 1, last_old, false, replacement)
      job.changed = true
      for win, view in pairs(views) do
        if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == job.bufnr then
          api.nvim_win_call(win, function()
            vim.fn.winrestview(view)
          end)
        end
      end
    end
    if not M.options.preserve_eol and vim.bo[job.bufnr].endofline ~= eol then
      vim.bo[job.bufnr].endofline = eol
      job.changed = true
    end
  end)
  finish(job, ok and 'ok' or 'error', not ok and message(detail) or nil)
end

local function write_temp(job, context, definition)
  job.tempdir = assert(uv.fs_mkdtemp(vim.fn.tempname() .. '-format-XXXXXX'))
  local basename = context.filename ~= '' and fs.basename(context.filename)
    or ('buffer.' .. (definition.extension or context.filetype or 'txt'))
  job.tempfile = fs.joinpath(job.tempdir, basename)
  context.tempfile = job.tempfile
  local fd = assert(uv.fs_open(job.tempfile, 'wx', 384))
  local offset = 0
  while offset < #context.input do
    local count, err = uv.fs_write(fd, context.input:sub(offset + 1), offset)
    if not count or count == 0 then
      uv.fs_close(fd)
      error(err or 'Cannot write formatter tempfile')
    end
    offset = offset + count
  end
  assert(uv.fs_close(fd))
end

local function read_temp(path)
  local stat = uv.fs_lstat(path)
  assert(
    stat and stat.type == 'file' and stat.size <= M.options.max_output_bytes,
    'Invalid/oversized formatter tempfile'
  )
  local fd = assert(uv.fs_open(path, 'r', 0))
  local text, err = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  assert(text, err)
  return text
end

local run_step
run_step = function(job, index)
  if job.done then
    return
  end
  if not fresh(job) then
    finish(job, 'stale', 'Buffer changed while formatting; result discarded')
    return
  end
  local step = job.steps[index]
  if not step then
    apply(job)
    return
  end
  local definition = step.definition
  local ok, setup = pcall(function()
    local context = context_for(job.bufnr, definition, job.text)
    if definition.mode == 'tempfile' then
      write_temp(job, context, definition)
    end
    local args = type(definition.args) == 'function' and definition.args(context)
      or definition.args
      or {}
    assert(type(args) == 'table' and vim.islist(args), 'Formatter args must be a list')
    local argv = { step.cmd }
    for _, arg in ipairs(args) do
      assert(
        type(arg) == 'string' and not arg:find('%z'),
        'Formatter argv requires NUL-free strings'
      )
      argv[#argv + 1] = arg
    end
    return { context = context, argv = argv }
  end)
  if not ok then
    cleanup_temp(job)
    finish(job, 'error', message(setup))
    return
  end
  job.active = step.name
  local stdout, stderr = {}, {}
  local stdout_size, stderr_size = 0, 0
  local capture_error
  local function capture(which, err, data)
    if err then
      capture_error = tostring(err)
    end
    if data and not capture_error then
      if which == 'stdout' then
        stdout_size = stdout_size + #data
        if stdout_size <= M.options.max_output_bytes then
          stdout[#stdout + 1] = data
        else
          capture_error = 'Formatter stdout limit exceeded'
        end
      else
        stderr_size = stderr_size + #data
        if stderr_size <= M.options.max_stderr_bytes then
          stderr[#stderr + 1] = data
        else
          capture_error = 'Formatter stderr limit exceeded'
        end
      end
    end
    if capture_error and job.proc then
      pcall(job.proc.kill, job.proc, 9)
    end
  end
  local spawned, process = pcall(vim.system, setup.argv, {
    cwd = setup.context.cwd,
    env = definition.env,
    stdin = definition.mode ~= 'tempfile' and job.text or nil,
    stdout = function(err, data)
      capture('stdout', err, data)
    end,
    stderr = function(err, data)
      capture('stderr', err, data)
    end,
  }, function(result)
    vim.schedule(function()
      job.proc = nil
      if job.done then
        cleanup_temp(job)
        return
      end
      local accepted = vim.tbl_contains(definition.exit_codes or { 0 }, result.code)
      local success, transformed = pcall(function()
        assert(not capture_error, capture_error)
        assert(
          result.signal == 0 and accepted,
          step.name .. ' exited ' .. result.code .. ': ' .. message(table.concat(stderr))
        )
        local text = definition.output == 'file' and read_temp(job.tempfile) or table.concat(stdout)
        if definition.decode then
          text = definition.decode(text, setup.context)
        end
        assert(type(text) == 'string', 'Formatter must return text')
        assert(
          text ~= '' or job.text == '' or definition.allow_empty,
          'Empty formatter output rejected'
        )
        output_lines(text)
        return text:gsub('\r\n', '\n')
      end)
      cleanup_temp(job)
      if not success then
        finish(job, 'error', message(transformed))
        return
      end
      job.text = transformed
      run_step(job, index + 1)
    end)
  end)
  if not spawned then
    cleanup_temp(job)
    finish(job, 'error', message(process))
  else
    job.proc = process
  end
end

local function lsp_client(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/formatting' })
  local rank = {}
  for index, name in ipairs(M.options.lsp_preference) do
    rank[name] = index
  end
  table.sort(clients, function(a, b)
    local ar, br = rank[a.name] or 10000, rank[b.name] or 10000
    return ar == br and a.id < b.id or ar < br
  end)
  return clients[1]
end

local function run_lsp(job)
  local client = lsp_client(job.bufnr)
  if not client then
    finish(
      job,
      'unavailable',
      'No external formatter or formatting-capable LSP client is available'
    )
    return
  end
  job.client, job.active = client, 'LSP:' .. client.name
  local width = vim.bo[job.bufnr].shiftwidth
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(job.bufnr) },
    options = {
      tabSize = width == 0 and vim.bo[job.bufnr].tabstop or width,
      insertSpaces = vim.bo[job.bufnr].expandtab,
    },
  }
  local requested, request_id = client:request(
    'textDocument/formatting',
    params,
    function(err, edits)
      if job.done then
        return
      end
      if not fresh(job) then
        finish(job, 'stale', 'Buffer changed while LSP formatting; result discarded')
        return
      end
      if err then
        finish(job, 'error', 'LSP formatting failed: ' .. message(err.message or err))
        return
      end
      if edits == nil or edits == vim.NIL then
        finish(job, 'ok')
        return
      end
      local scratch
      local ok, result = pcall(function()
        assert(
          type(edits) == 'table' and vim.islist(edits) and #edits <= M.options.max_lsp_edits,
          'Invalid/oversized LSP edit list'
        )
        local size = 0
        for _, edit in ipairs(edits) do
          assert(
            type(edit) == 'table' and type(edit.newText) == 'string' and not edit.newText:find('%z'),
            'Invalid LSP text edit'
          )
          local range = edit.range
          assert(
            type(range) == 'table'
              and type(range.start) == 'table'
              and type(range['end']) == 'table',
            'LSP edit requires range'
          )
          for _, point in ipairs({ range.start, range['end'] }) do
            assert(
              type(point.line) == 'number'
                and point.line >= 0
                and point.line == math.floor(point.line)
                and point.line <= #job.snapshot.lines
                and type(point.character) == 'number'
                and point.character >= 0
                and point.character == math.floor(point.character),
              'Invalid LSP edit position'
            )
          end
          assert(
            range['end'].line > range.start.line
              or (
                range['end'].line == range.start.line
                and range['end'].character >= range.start.character
              ),
            'Reversed LSP edit range'
          )
          size = size + #edit.newText
          assert(size <= M.options.max_output_bytes, 'LSP edit output limit exceeded')
        end
        scratch = api.nvim_create_buf(false, true)
        api.nvim_buf_set_lines(scratch, 0, -1, false, job.snapshot.lines)
        vim.bo[scratch].endofline = job.snapshot.eol
        vim.lsp.util.apply_text_edits(edits, scratch, client.offset_encoding or 'utf-16')
        local text = table.concat(api.nvim_buf_get_lines(scratch, 0, -1, false), '\n')
          .. (vim.bo[scratch].endofline and '\n' or '')
        output_lines(text)
        return text
      end)
      if scratch and api.nvim_buf_is_valid(scratch) then
        api.nvim_buf_delete(scratch, { force = true })
      end
      if not ok then
        finish(job, 'error', message(result))
        return
      end
      job.text = result
      apply(job)
    end,
    job.bufnr
  )
  if requested then
    job.request_id = request_id
  else
    finish(job, 'error', 'LSP formatting request could not be sent')
  end
end

---@param opts? FormatterRunOptions
---@param callback? fun(result: table)
---@return table
function M.format(opts, callback)
  opts = vim.deepcopy(opts or {})
  local bufnr = current(opts.bufnr or 0)
  local timeout = opts.timeout_ms or M.options.timeout_ms
  assert(positive(timeout), 'timeout_ms must be a positive integer')
  M.stop(bufnr)
  sequence = sequence + 1
  local job = {
    id = sequence,
    bufnr = bufnr,
    opts = opts,
    callback = callback,
    done = false,
    changed = false,
    status = 'running',
  }
  if not M.options.enabled or vim.b[bufnr].format_disabled then
    finish(job, 'disabled')
    return job
  end
  local ok, prepared = pcall(function()
    local state = snapshot(bufnr)
    local mode = opts.lsp or M.options.lsp
    assert(mode == 'fallback' or mode == 'never' or mode == 'only', 'Invalid LSP mode')
    assert(not (opts.names and mode == 'only'), 'Explicit formatter names conflict with lsp=only')
    local steps = mode == 'only' and {} or select_steps(bufnr, opts.names, opts.automatic == true)
    return { snapshot = state, mode = mode, steps = steps }
  end)
  if not ok then
    finish(job, 'error', message(prepared))
    return job
  end
  job.snapshot, job.steps, job.text = prepared.snapshot, prepared.steps, prepared.snapshot.text
  jobs[bufnr] = job
  job.timer = vim.defer_fn(function()
    cancel(job, 'timeout')
  end, timeout)
  if #job.steps > 0 then
    run_step(job, 1)
  elseif prepared.mode ~= 'never' and not opts.names then
    run_lsp(job)
  else
    finish(job, 'unavailable', 'No configured formatter is available')
  end
  if opts.async == false and not job.done then
    local completed = vim.wait(timeout + 50, function()
      return job.done
    end, 5)
    if not completed then
      cancel(job, 'timeout')
    end
  end
  return job
end

function M.run(bufnr, opts, names)
  opts = vim.tbl_extend('force', opts or {}, { bufnr = bufnr or 0 })
  if names then
    opts.names = names
  end
  return M.format(opts)
end

function M.info(bufnr, all)
  bufnr = current(bufnr or 0)
  local names = {}
  if all then
    for name in pairs(M.module_sources) do
      names[name] = true
    end
    for name in pairs(M.definitions) do
      names[name] = true
    end
  else
    for _, entry in ipairs(M.formatters_by_ft[vim.bo[bufnr].filetype] or {}) do
      for _, name in ipairs(type(entry) == 'table' and entry or { entry }) do
        names[name] = true
      end
    end
  end
  local lines = { 'Filetype: ' .. vim.bo[bufnr].filetype }
  for _, name in ipairs(vim.fn.sort(vim.tbl_keys(names))) do
    local definition = M.get_definition(name)
    local state
    if M.load_errors[name] then
      state = 'invalid: ' .. M.load_errors[name]
    elseif not definition then
      state = 'planned; module not installed'
    elseif executable(definition.cmd) then
      state = 'available'
    else
      state = 'executable missing'
    end
    lines[#lines + 1] = name .. ': ' .. state
  end
  local client = lsp_client(bufnr)
  lines[#lines + 1] = 'LSP fallback: ' .. (client and client.name or 'none')
  return table.concat(lines, '\n')
end

function M.validate()
  local errors = {}
  for ft, stages in pairs(M.formatters_by_ft) do
    if type(stages) ~= 'table' then
      errors[#errors + 1] = ft .. ': expected a pipeline'
    else
      for _, stage in ipairs(stages) do
        for _, name in ipairs(type(stage) == 'table' and stage or { stage }) do
          if not name_valid(name) then
            errors[#errors + 1] = ft .. ': invalid formatter name'
          end
        end
      end
    end
  end
  for name, problem in pairs(M.load_errors) do
    errors[#errors + 1] = name .. ': ' .. problem
  end
  return errors
end

local function completions(lead)
  local names = {}
  for name in pairs(M.module_sources) do
    if name:sub(1, #lead) == lead then
      names[#names + 1] = name
    end
  end
  for name in pairs(M.definitions) do
    if not M.module_sources[name] and name:sub(1, #lead) == lead then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

function M.setup(opts)
  for _, job in pairs(jobs) do
    cancel(job, 'cancelled')
  end
  if opts then
    for key, value in pairs(opts) do
      assert(M.options[key] ~= nil, 'Unknown formatter setup option: ' .. key)
      M.options[key] = vim.deepcopy(value)
    end
  end
  for _, key in ipairs({
    'timeout_ms',
    'save_timeout_ms',
    'max_input_bytes',
    'max_output_bytes',
    'max_stderr_bytes',
    'max_lsp_edits',
  }) do
    assert(positive(M.options[key]), 'Invalid formatter option: ' .. key)
  end
  local group = api.nvim_create_augroup('native_formatters', { clear = true })
  api.nvim_create_autocmd({ 'BufWipeout', 'BufUnload' }, {
    group = group,
    callback = function(event)
      M.stop(event.buf)
    end,
    desc = 'Cancel pending formatting',
  })
  api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      for _, job in pairs(jobs) do
        cancel(job, 'cancelled')
      end
    end,
    desc = 'Stop native formatter processes',
  })
  api.nvim_create_autocmd('BufWritePre', {
    group = group,
    desc = 'Optional bounded native formatting before save',
    callback = function(event)
      if
        M.options.enabled
        and M.options.format_on_save
        and not vim.b[event.buf].format_disabled
      then
        M.format({
          bufnr = event.buf,
          async = false,
          automatic = true,
          timeout_ms = M.options.save_timeout_ms,
          notify = false,
        }, function(result)
          if result.error and result.status ~= 'unavailable' then
            vim.schedule(function()
              notify('Saved without formatting: ' .. message(result.error), vim.log.levels.WARN)
            end)
          end
        end)
      end
    end,
  })
  api.nvim_create_user_command('Format', function(command)
    M.format({ names = #command.fargs > 0 and command.fargs or nil, async = not command.bang })
  end, {
    nargs = '*',
    bang = true,
    complete = completions,
    force = true,
    desc = 'Format buffer; bang waits synchronously',
  })
  api.nvim_create_user_command('FormatLsp', function()
    M.format({ lsp = 'only' })
  end, { force = true, desc = 'Format with one native LSP client' })
  api.nvim_create_user_command('FormatStop', function()
    M.stop(0)
  end, { force = true, desc = 'Cancel formatting' })
  api.nvim_create_user_command('FormatDisable', function()
    vim.b.format_disabled = true
    M.stop(0)
  end, { force = true, desc = 'Disable formatting for this buffer' })
  api.nvim_create_user_command('FormatEnable', function()
    vim.b.format_disabled = false
  end, { force = true, desc = 'Enable formatting for this buffer' })
  api.nvim_create_user_command(
    'FormatInfo',
    function(command)
      notify(M.info(0, command.bang))
    end,
    { bang = true, force = true, desc = 'Show formatter availability; bang lists the full catalog' }
  )
  api.nvim_create_user_command('FormatValidate', function()
    local errors = M.validate()
    notify(
      #errors == 0 and 'Formatter registry is valid' or table.concat(errors, '\n'),
      #errors == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
    )
  end, { force = true, desc = 'Validate formatter registry' })
  return M
end

-- Built-in adapters for the ten existing fixer names. A file in
-- lua/formatters/<name>.lua may replace a built-in through lazy loading.
local function nearest(context, names)
  local start = context.filename ~= '' and context.filename or context.cwd
  local root = fs.root(start, names)
  if root then
    for _, name in ipairs(names) do
      local path = fs.joinpath(root, name)
      if readable(path) then
        return path
      end
    end
  end
end

M.register('alejandra', { cmd = 'alejandra', args = {}, mode = 'stdin', exit_codes = { 0 } })
M.register('gofumpt', { cmd = 'gofumpt', args = {}, mode = 'stdin', exit_codes = { 0 } })
M.register('goimports', {
  cmd = 'goimports',
  mode = 'stdin',
  exit_codes = { 0 },
  root_markers = { 'go.work', 'go.mod', '.git' },
  args = function(context)
    return {
      '-srcdir',
      context.filename ~= '' and context.filename or fs.joinpath(context.root, 'buffer.go'),
    }
  end,
})
M.register('css-beautify', {
  cmd = 'css-beautify',
  mode = 'stdin',
  exit_codes = { 0 },
  args = function(context)
    return { '--stdin', '--indent-size', tostring(context.shiftwidth), '--end-with-newline' }
  end,
})
M.register('htmlbeautify', {
  cmd = 'html-beautify',
  mode = 'stdin',
  exit_codes = { 0 },
  args = function(context)
    return { '--stdin', '--indent-size', tostring(context.shiftwidth), '--end-with-newline' }
  end,
})
M.register('sql-formatter', {
  cmd = 'sql-formatter',
  mode = 'stdin',
  exit_codes = { 0 },
  args = function(context)
    local config = nearest(context, { '.sql-formatter.json' })
    if config then
      return { '--config', config }
    end
    return { '--language', M.options.sql_language }
  end,
})
M.register('blackd', {
  cmd = 'curl',
  mode = 'stdin',
  exit_codes = { 0 },
  args = function()
    -- Fixed loopback policy: never send buffer text to an external URL or proxy.
    assert(
      M.options.blackd_url:match('^http://127%.0%.0%.1:%d+/?$'),
      'blackd_url must be an HTTP IPv4 loopback endpoint'
    )
    return {
      '--disable',
      '--silent',
      '--show-error',
      '--noproxy',
      '*',
      '--proto',
      '=http',
      '--connect-timeout',
      '1',
      '--max-time',
      '10',
      '--request',
      'POST',
      '--header',
      'Content-Type: text/plain; charset=utf-8',
      '--header',
      'X-Protocol-Version: 1',
      '--data-binary',
      '@-',
      '--write-out',
      '\nNVIM_FORMAT_HTTP:%{http_code}',
      M.options.blackd_url,
    }
  end,
  decode = function(output, context)
    local body, code = output:match('^(.*)\nNVIM_FORMAT_HTTP:(%d%d%d)$')
    assert(code, 'Blackd response has no HTTP status')
    if code == '204' then
      return context.input
    end
    assert(code == '200', 'Blackd HTTP ' .. code .. ': ' .. message(body))
    return body
  end,
})
M.register('cookstyle', {
  cmd = 'cookstyle',
  mode = 'stdin',
  exit_codes = { 0, 1 },
  root_markers = { '.rubocop.yml', 'Gemfile', '.git' },
  args = function(context)
    -- RuboCop's --stderr sends reports AND the separator to stderr, leaving
    -- only corrected stdin source on stdout. JSON format would suppress it.
    assert(context.filename ~= '', 'Cookstyle requires a filename for configuration/exclusions')
    return {
      '--autocorrect',
      '--force-exclusion',
      '--no-color',
      '--stderr',
      '--format',
      'progress',
      '--stdin',
      context.filename,
    }
  end,
})
M.register('phpcsfixer', {
  cmd = 'php-cs-fixer',
  mode = 'tempfile',
  output = 'file',
  exit_codes = { 0 },
  extension = 'php',
  root_markers = { '.php-cs-fixer.php', '.php-cs-fixer.dist.php', 'composer.json', '.git' },
  args = function(context)
    local args = {
      'fix',
      '--using-cache=no',
      '--allow-risky=no',
      '--show-progress=none',
      '--format=json',
      '--path-mode=override',
      '--sequential',
      '--no-ansi',
      '--no-interaction',
    }
    local config = nearest(context, { '.php-cs-fixer.php', '.php-cs-fixer.dist.php' })
    if config then
      args[#args + 1] = '--config=' .. config
    else
      args[#args + 1] = '--rules=@PSR12'
    end
    args[#args + 1] = '--'
    args[#args + 1] = assert(context.tempfile)
    return args
  end,
})
M.register('shellharden', {
  cmd = 'shellharden',
  mode = 'tempfile',
  output = 'file',
  exit_codes = { 0 },
  automatic = false,
  extension = 'sh',
  args = function(context)
    return { '--transform', '--replace', assert(context.tempfile) }
  end,
})

return M