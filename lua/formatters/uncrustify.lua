-- #################################################################
-- /qompassai/lua/formatters/uncrustify.lua
-- Qompass AI Uncrustify Native Formatter Spec
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- All Uncrustify policy is defined in this module. No uncrustify.cfg file is
-- read and no -c configuration-file argument is passed to Uncrustify.
--
-- To add settings from a former uncrustify.cfg, paste `name = value` lines
-- into an add_uncrustify_options(STATIC_OPTIONS, [[ ... ]]) block below.
-- Each line becomes: --set name=value
-- #################################################################
---@source https://github.com/uncrustify/uncrustify/tree/uncrustify-0.83.0
---@source https://neovim.io/doc/user/lua.html#vim.system()

local api = vim.api
local fs = vim.fs

local INPUT_BYTES_MAX = 2 * 1024 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local PATH_BYTES_MAX = 4096
local TAB_SIZE_MAX = 32
local COMMAND = '/usr/bin/uncrustify'

---@type table<string, string>
local LANGUAGES = {
  c = 'C',
  cpp = 'CPP',
  cs = 'CS',
  d = 'D',
  dlang = 'D',
  java = 'JAVA',
  objc = 'OC',
  objcpp = 'OC+',
  pawn = 'PAWN',
  vala = 'VALA',
}

---@type string[]
local ROOT_MARKERS = {
  '.git',
  '.hg',
  'CMakeLists.txt',
  'meson.build',
  'Makefile',
  'compile_commands.json',
  'configure.ac',
  'build.gradle',
  'build.gradle.kts',
  'pom.xml',
  'dub.json',
  'dub.sdl',
}

---@param options string[][]
---@param text string
local function add_uncrustify_options(options, text)
  assert(type(options) == 'table', 'uncrustify options must be a table')
  assert(type(text) == 'string', 'uncrustify option text must be a string')

  for raw_line in text:gmatch('[^\r\n]+') do
    local line = raw_line:gsub('%s*#.*$', '')
    line = vim.trim(line)

    if line ~= '' then
      local name, value = line:match('^([%a_][%w_]*)%s*=%s*(.-)%s*$')
      if not name or value == '' then
        error('uncrustify: invalid embedded option: ' .. raw_line, 0)
      end
      options[#options + 1] = { name, value }
    end
  end
end

---@type string[][]
local STATIC_OPTIONS = {
  { 'newlines', 'lf' },
  { 'output_tab_size', '4' },
  { 'string_escape_char', '92' },
  { 'string_escape_char2', '0' },
  { 'string_replace_tab_chars', 'false' },
  { 'utf8_bom', 'remove' },
  { 'utf8_force', 'true' },
  { 'utf8_byte', 'false' },

  { 'tok_split_gte', 'false' },
  { 'disable_processing_nl_cont', 'true' },
  { 'disable_processing_cmt', ' *INDENT-OFF*' },
  { 'enable_processing_cmt', ' *INDENT-ON*' },
  { 'enable_digraphs', 'false' },

  { 'nl_after_semicolon', 'true' },
  { 'nl_if_brace', 'add' },
  { 'nl_for_brace', 'add' },
  { 'nl_while_brace', 'add' },
  { 'nl_func_type_name', 'remove' },
  { 'cmt_width', '120' },
  { 'cmt_indent_multi', 'true' },
  { 'pp_indent', 'add' },
  { 'pp_space_after', 'add' },
  { 'mod_full_brace_if', 'add' },
  { 'mod_full_brace_for', 'add' },
  { 'mod_full_brace_while', 'add' },

  { 'indent_columns', '4' },
  { 'indent_with_tabs', '0' },
  { 'indent_continue', '4' },
  { 'indent_ignore_first_continue', 'false' },
  { 'indent_continue_class_head', '0' },
  { 'indent_single_newlines', 'false' },
  { 'indent_param', '0' },
  { 'indent_cmt_with_tabs', 'false' },
  { 'indent_align_string', 'false' },
  { 'indent_xml_string', '0' },
  { 'indent_brace', '0' },
  { 'indent_braces', 'false' },
  { 'indent_braces_no_func', 'false' },
  { 'indent_braces_no_class', 'false' },
  { 'indent_braces_no_struct', 'false' },
  { 'indent_brace_parent', 'false' },
  { 'indent_paren_open_brace', 'false' },
  { 'indent_cs_delegate_brace', 'false' },
  { 'indent_cs_delegate_body', 'false' },
  { 'indent_namespace', 'false' },
  { 'indent_namespace_single_indent', 'false' },
  { 'indent_namespace_level', '0' },
  { 'indent_namespace_limit', '0' },
  { 'indent_namespace_inner_only', 'false' },
  { 'indent_extern', 'false' },
  { 'indent_class', 'true' },
  {
    'nl_class_brace',
    'add',
  },
}

add_uncrustify_options(
  STATIC_OPTIONS,
  [[
sp_arith = force
sp_arith_additive = force
sp_assign = force
sp_cpp_lambda_assign = ignore
sp_cpp_lambda_square_paren = ignore
sp_cpp_lambda_square_brace = ignore
sp_cpp_lambda_argument_list_empty = ignore
sp_cpp_lambda_argument_list = ignore
sp_cpp_lambda_paren_brace = ignore
sp_cpp_lambda_fparen = ignore
sp_assign_default = force
sp_before_assign = ignore
sp_after_assign = ignore
sp_enum_brace = add
sp_enum_paren = ignore
sp_enum_assign = ignore
sp_enum_before_assign = ignore
sp_enum_after_assign = ignore
sp_enum_colon = ignore
sp_pp_concat = ignore
sp_pp_stringify = ignore
sp_before_pp_stringify = ignore
sp_bool = force
sp_compare = force
sp_inside_paren = remove
sp_paren_paren = remove
sp_cparen_oparen = ignore
sp_paren_brace = ignore
sp_brace_brace = ignore
sp_before_ptr_star = force
sp_before_unnamed_ptr_star = ignore
sp_before_qualifier_ptr_star = ignore
sp_before_operator_ptr_star = ignore
sp_before_scope_ptr_star = ignore
sp_before_global_scope_ptr_star = ignore
sp_qualifier_unnamed_ptr_star = ignore
sp_between_ptr_star = remove
sp_between_ptr_ref = ignore
sp_after_ptr_star = remove
sp_after_ptr_block_caret = ignore
sp_after_ptr_star_qualifier = ignore
sp_after_ptr_star_func = ignore
sp_after_ptr_star_trailing = ignore
sp_ptr_star_func_var = ignore
sp_ptr_star_func_type = ignore
sp_ptr_star_paren = ignore
sp_before_ptr_star_func = ignore
sp_qualifier_ptr_star_func = ignore
sp_before_ptr_star_trailing = ignore
sp_qualifier_ptr_star_trailing = ignore
sp_before_byref = force
sp_before_unnamed_byref = ignore
sp_after_byref = remove
sp_after_byref_func = ignore
sp_before_byref_func = ignore
sp_byref_paren = ignore
sp_before_ref_qualifier = ignore
sp_after_ref_qualifier = ignore
sp_after_type = force
sp_after_decltype = ignore
sp_before_template_paren = ignore
sp_template_angle = ignore
sp_before_angle = ignore
sp_inside_angle = ignore
sp_inside_angle_empty = ignore
sp_angle_colon = ignore
sp_after_angle = ignore
sp_angle_paren = ignore
sp_angle_paren_empty = ignore
sp_angle_word = ignore
sp_angle_shift = ignore
sp_permit_cpp11_shift = false
sp_before_sparen = force
sp_inside_sparen = remove
sp_inside_sparen_open = ignore
sp_inside_sparen_close = ignore
sp_inside_for = remove
sp_inside_for_open = ignore
sp_inside_for_close = ignore
sp_sparen_paren = ignore
sp_after_sparen = force
sp_sparen_brace = force
sp_do_brace_open = force
sp_brace_close_while = force
sp_while_paren_open = ignore
sp_invariant_paren = ignore
sp_after_invariant_paren = ignore
sp_special_semi = ignore
sp_before_semi = remove
sp_before_semi_for = remove
sp_before_semi_for_empty = ignore
sp_between_semi_for_empty = ignore
sp_after_semi = force
sp_after_semi_for = force
sp_after_semi_for_empty = ignore
sp_before_square = remove
sp_before_vardef_square = remove
sp_before_square_asm_block = ignore
sp_before_squares = ignore
sp_cpp_before_struct_binding_after_byref = ignore
sp_cpp_before_struct_binding = ignore
sp_inside_square = remove
sp_inside_square_empty = ignore
sp_inside_square_oc_array = ignore
sp_after_comma = force
sp_before_comma = remove
sp_after_mdatype_commas = ignore
sp_before_mdatype_commas = ignore
sp_between_mdatype_commas = ignore
sp_paren_comma = force
sp_type_colon = ignore
sp_after_ellipsis = ignore
sp_before_ellipsis = ignore
sp_type_ellipsis = ignore
sp_ptr_type_ellipsis = ignore
sp_paren_ellipsis = ignore
sp_byref_ellipsis = ignore
sp_paren_qualifier = ignore
sp_paren_noexcept = ignore
sp_paren_deref = ignore
sp_after_class_colon = ignore
sp_before_class_colon = ignore
sp_after_constr_colon = add
sp_before_constr_colon = add
sp_before_case_colon = remove
sp_after_operator = ignore
sp_after_operator_sym = ignore
sp_after_operator_sym_empty = ignore
sp_after_cast = ignore
sp_inside_paren_cast = remove
sp_cpp_cast_paren = ignore
sp_sizeof_paren = remove
sp_sizeof_ellipsis = ignore
sp_sizeof_ellipsis_paren = ignore
sp_ellipsis_parameter_pack = ignore
sp_parameter_pack_ellipsis = ignore
sp_decltype_paren = ignore
sp_after_tag = ignore
sp_inside_braces_enum = ignore
sp_inside_braces_struct = ignore
sp_inside_braces_oc_dict = ignore
sp_after_type_brace_init_lst_open = ignore
sp_before_type_brace_init_lst_close = ignore
sp_inside_type_brace_init_lst = ignore
sp_inside_braces = ignore
sp_inside_braces_empty = ignore
sp_trailing_return = ignore
sp_type_func = force
sp_type_brace_init_lst = ignore
sp_func_proto_paren = remove
sp_func_proto_paren_empty = ignore
sp_func_type_paren = ignore
sp_func_def_paren = remove
sp_func_def_paren_empty = ignore
sp_inside_fparens = ignore
sp_inside_fparen = remove
sp_func_call_user_inside_rparen = ignore
sp_inside_rparens = ignore
sp_inside_rparen = ignore
sp_inside_tparen = ignore
sp_after_tparen_close = ignore
sp_square_fparen = ignore
sp_fparen_brace = force
sp_fparen_brace_initializer = ignore
sp_fparen_dbrace = ignore
sp_func_call_paren = remove
sp_func_call_paren_empty = ignore
sp_func_call_user_paren = ignore
sp_func_call_user_inside_fparen = ignore
sp_func_call_user_paren_paren = ignore
sp_func_class_paren = remove
sp_func_class_paren_empty = ignore
sp_deduction_guide_paren = ignore
sp_deduction_guide_paren_empty = ignore
sp_deduction_guide_arrow = ignore
sp_return = force
sp_return_paren = force
sp_return_brace = force
sp_attribute_paren = ignore
sp_defined_paren = ignore
sp_throw_paren = ignore
sp_after_throw = ignore
sp_catch_paren = ignore
sp_oc_catch_paren = ignore
sp_before_oc_proto_list = ignore
sp_oc_classname_paren = ignore
sp_version_paren = ignore
sp_scope_paren = ignore
sp_super_paren = remove
sp_this_paren = remove
sp_macro = ignore
sp_macro_func = ignore
sp_else_brace = force
sp_brace_else = force
sp_brace_typedef = ignore
sp_catch_brace = force
sp_oc_catch_brace = ignore
sp_brace_catch = force
sp_oc_brace_catch = ignore
sp_finally_brace = ignore
sp_brace_finally = force
sp_try_brace = ignore
sp_getset_brace = ignore
sp_word_brace_init_lst = ignore
sp_word_brace_ns = add
sp_before_dc = ignore
sp_after_dc = ignore
sp_d_array_colon = ignore
sp_not = remove
sp_not_not = ignore
sp_inv = remove
sp_addr = remove
sp_member = remove
sp_deref = remove
sp_sign = remove
sp_incdec = remove
sp_before_nl_cont = add
sp_after_oc_scope = ignore
sp_after_oc_colon = ignore
sp_before_oc_colon = ignore
sp_after_oc_dict_colon = ignore
sp_before_oc_dict_colon = ignore
sp_after_send_oc_colon = ignore
sp_before_send_oc_colon = ignore
sp_after_oc_type = ignore
sp_after_oc_return_type = ignore
sp_after_oc_at_sel = ignore
sp_after_oc_at_sel_parens = ignore
sp_inside_oc_at_sel_parens = ignore
sp_before_oc_block_caret = ignore
sp_after_oc_block_caret = ignore
sp_after_oc_msg_receiver = ignore
sp_after_oc_property = ignore
sp_after_oc_synchronized = ignore
sp_cond_colon = force
sp_cond_colon_before = ignore
sp_cond_colon_after = ignore
sp_cond_question = force
sp_cond_question_before = ignore
sp_cond_question_after = ignore
sp_cond_ternary_short = ignore
sp_case_label = force
sp_range = ignore
sp_after_for_colon = ignore
sp_before_for_colon = ignore
sp_extern_paren = ignore
sp_cmt_cpp_start = ignore
sp_cmt_cpp_pvs = false
sp_cmt_cpp_lint = false
sp_cmt_cpp_region = ignore
sp_cmt_cpp_doxygen = false
sp_cmt_cpp_qttr = false
sp_endif_cmt = ignore
sp_after_new = ignore
sp_between_new_paren = ignore
sp_after_newop_paren = ignore
sp_inside_newop_paren = ignore
sp_inside_newop_paren_open = ignore
sp_inside_newop_paren_close = ignore
sp_before_tr_cmt = ignore
sp_num_before_tr_cmt = 0
sp_before_emb_cmt = force
sp_num_before_emb_cmt = 1
sp_after_emb_cmt = force
sp_num_after_emb_cmt = 1
sp_emb_cmt_priority = false
sp_annotation_paren = ignore
sp_skip_vbrace_tokens = false
sp_after_noexcept = ignore
sp_vala_after_translation = ignore
sp_before_bit_colon = ignore
sp_after_bit_colon = ignore
]]
)

---@param value unknown
---@param label string
---@return string
local function absolute_path(value, label)
  if type(value) ~= 'string' or value == '' then
    error('uncrustify: ' .. label .. ' must be a nonempty absolute path', 0)
  end

  if #value > PATH_BYTES_MAX or value:find('[%z\1-\31\127]') then
    error('uncrustify: invalid or oversized ' .. label, 0)
  end

  if value:sub(1, 1) ~= '/' then
    error('uncrustify: ' .. label .. ' must be absolute; expand ~ explicitly', 0)
  end

  return fs.normalize(value)
end

---@param context FormatterContext
---@return string
local function working_directory(context)
  assert(type(context) == 'table', 'uncrustify requires FormatterContext')
  return absolute_path(context.root, 'working directory')
end

---@param args string[]
---@param name string
---@param value string
local function add_option(args, name, value)
  assert(type(name) == 'string' and name ~= '', 'uncrustify option name must be nonempty')
  assert(type(value) == 'string', 'uncrustify option value must be a string')
  assert(not name:find('[%z\1-\31\127]'), 'uncrustify option name contains a control character')
  assert(not value:find('%z'), 'uncrustify option value contains NUL')

  args[#args + 1] = '--set'
  args[#args + 1] = name .. '=' .. value
end

---@param context FormatterContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'uncrustify requires FormatterContext')
  assert(type(context.bufnr) == 'number', 'uncrustify requires context.bufnr')
  assert(context.bufnr > 0 and context.bufnr % 1 == 0, 'uncrustify buffer number is invalid')
  assert(api.nvim_buf_is_valid(context.bufnr), 'uncrustify buffer is invalid')
  assert(type(context.input) == 'string', 'uncrustify requires context.input')
  assert(type(context.filetype) == 'string', 'uncrustify requires context.filetype')

  if #context.input > INPUT_BYTES_MAX or context.input:find('%z') then
    error('uncrustify: binary input or input larger than 2 MiB rejected', 0)
  end

  local language = LANGUAGES[context.filetype]
  if language == nil then
    error('uncrustify: unsupported filetype: ' .. context.filetype, 0)
  end

  local tab_size = vim.bo[context.bufnr].tabstop
  if tab_size < 1 or tab_size > TAB_SIZE_MAX then
    error('uncrustify: tabstop must be between 1 and 32', 0)
  end

  if vim.bo[context.bufnr].vartabstop ~= '' then
    error('uncrustify: variable tab stops cannot be represented by input_tab_size', 0)
  end

  local args = {
    '-l',
    language,
    '-L',
    '1-2',
  }

  add_option(args, 'input_tab_size', tostring(tab_size))

  for _, option in ipairs(STATIC_OPTIONS) do
    add_option(args, option[1], option[2])
  end

  return args
end

---@param output string
---@param context FormatterContext
---@return string
local function decode(output, context)
  assert(type(output) == 'string', 'uncrustify output must be a string')
  assert(type(context) == 'table', 'uncrustify decode requires FormatterContext')
  assert(type(context.input) == 'string', 'uncrustify decode requires context.input')

  if #output > OUTPUT_BYTES_MAX or output:find('%z') then
    error('uncrustify: binary output or output larger than 4 MiB rejected', 0)
  end

  if output == '' and context.input ~= '' then
    if context.input:find('%S') == nil then
      return context.input
    end
    error('uncrustify: empty replacement rejected', 0)
  end

  if output:sub(1, 3) == '\239\187\191' or output:find('\r', 1, true) then
    error('uncrustify: expected UTF-8 text without a BOM and with LF endings', 0)
  end

  return output
end

---@type FormatterSpec
return {
  cmd = COMMAND,
  args = arguments,
  mode = 'stdin',
  cwd = working_directory,
  env = {
    LANG = 'C',
    LC_ALL = 'C',
    TZ = 'UTC',
  },
  root_markers = ROOT_MARKERS,
  exit_codes = {
    0,
  },
  output = 'stdout',
  decode = decode,
  allow_empty = false,
  automatic = true,
  extension = nil,
}
