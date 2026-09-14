-- #################################################################
-- ~/.config/nvim/lua/formatters/bibtex_tidy.lua
-- Qompass AI Diver Native BibTeX Tidy Formatter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- bibtex-tidy 1.15.1 JS API, invoked with Node, no Neovim plugin.
-- Native formatters/init.lua supplies FormatterSpec/FormatterContext.
-- All upstream options are explicitly represented below, including CLI-only
-- options (ignored by tidy()). No config files are discovered or executed.
-- No source paths are sent to Node. No automatic installation or file writes.
-- The runner owns timeout, cancellation, undo and stale-result rejection.
local fs = vim.fs

-- Complete option inventory from bibtex-tidy 1.15.1's declaration file.
-- CLI-only values are inert API metadata; this wrapper always uses stdin/stdout.
local CONFIG = {
  help = false,
  v2 = '', -- CLI-only experimental mode disabled.
  outputPath = '', -- CLI-only: no output file.
  modify = false,
  omit = {}, -- No fields removed; JSON [] is intended.
  curly = false, -- Preserve quoted/braced value choice.
  numeric = false,
  months = false,
  space = 2,
  tab = false,
  align = 14,
  blankLines = true,
  sort = false,
  duplicates = false, -- No duplicate detection on the formatting path.
  merge = false,
  stripEnclosingBraces = false,
  dropAllCaps = false,
  escape = false, -- Preserve Unicode for modern BibLaTeX/Biber workflows.
  unescape = false,
  sortFields = false,
  sortProperties = false, -- Legacy alias, same policy as sortFields.
  stripComments = false,
  trailingCommas = false,
  encodeUrls = false,
  tidyComments = false,
  removeEmptyFields = false,
  removeDuplicateFields = false,
  generateKeys = false, -- Never invalidate existing citation references.
  maxAuthors = 0, -- Upstream truthiness check: zero disables truncation.
  lowercase = false,
  enclosingBraces = false,
  removeBraces = false,
  wrap = false,
  version = false,
  quiet = true,
  backup = false,
}
local TOOLING = {
  node = 'node',
  package_version = '1.15.1',
  directory = fs.joinpath(vim.fn.stdpath('data'), 'formatters', 'bibtex-tidy'),
  js_heap_mib = 256, -- V8 old-space limit, not total process memory.
  max_input_bytes = 2 * 1024 * 1024,
  max_output_bytes = 4 * 1024 * 1024,
  reject_warnings = true, -- Preserve the buffer if tidy reports a warning.
}

local WRAPPER = [==[
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
// Conservative completeness check: tidy can silently discard unterminated values.
// Outside entries, BibTeX permits free-form comments. This is not a full parser.
function checkComplete(source) {
  const start = /@[a-zA-Z]+\s*([({])/g;
  let match;
  while ((match = start.exec(source)) !== null) {
    const parenthesized = match[1] === '(';
    let depth = parenthesized ? 0 : 1;
    let quoted = false;
    let closed = false;
    let i = start.lastIndex;
    for (; i < source.length; i++) {
      const char = source[i];
      if (char === '\\') { i++; continue; }
      if (char === '"' && depth === (parenthesized ? 0 : 1)) quoted = !quoted;
      if (char === '{') depth++;
      if (char === '}') {
        depth--;
        if (depth < 0) throw new Error('Unbalanced BibTeX braces');
        if (!parenthesized && depth === 0 && !quoted) { closed = true; break; }
      }
      if (parenthesized && char === ')' && depth === 0 && !quoted) { closed = true; break; }
    }
    if (!closed || quoted) throw new Error('Incomplete BibTeX entry; buffer preserved');
    start.lastIndex = i + 1;
  }
}
try {
  const [directory, version, json, inputLimit, outputLimit, rejectWarnings] = process.argv.slice(1);
  const packageDir = join(directory, 'node_modules', 'bibtex-tidy');
  const manifest = JSON.parse(await readFile(join(packageDir, 'package.json'), 'utf8'));
  if (manifest.name !== 'bibtex-tidy' || manifest.version !== version) {
    throw new Error(`Expected bibtex-tidy ${version}; install the pinned package`);
  }
  const { tidy } = await import(pathToFileURL(join(packageDir, 'bibtex-tidy.js')).href);
  const chunks = [];
  let bytes = 0;
  for await (const chunk of process.stdin) {
    bytes += chunk.length;
    if (bytes > Number(inputLimit)) throw new Error('BibTeX input exceeds byte limit');
    chunks.push(chunk);
  }
  const input = new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks));
  if (input.includes('\0')) throw new Error('NUL in BibTeX input');
  checkComplete(input);
  const result = tidy(input, JSON.parse(json));
  if (!result || typeof result.bibtex !== 'string' || !Array.isArray(result.warnings)) {
    throw new Error('Invalid bibtex-tidy result');
  }
  if (rejectWarnings === 'true' && result.warnings.length) {
    throw new Error(result.warnings.slice(0, 8).map(w => String(w.message).slice(0, 512)).join('\n'));
  }
  if (result.bibtex.includes('\0') || Buffer.byteLength(result.bibtex, 'utf8') > Number(outputLimit)) {
    throw new Error('Invalid or oversized BibTeX output');
  }
  process.stdout.write(result.bibtex);
} catch (error) {
  process.stderr.write(`bibtex-tidy: ${String(error instanceof Error ? error.message : error).slice(0, 8192)}\n`);
  process.exitCode = 1;
}
]==]

---@param context FormatterContext
---@return string[]
local function arguments(context)
  if context.filetype ~= 'bib' then
    error('bibtex_tidy requires the bib filetype')
  end
  local manifest = fs.joinpath(TOOLING.directory, 'node_modules', 'bibtex-tidy', 'package.json')
  local stat = vim.uv.fs_stat(manifest)
  if not stat or stat.type ~= 'file' then
    error('Install bibtex-tidy@' .. TOOLING.package_version .. ' under ' .. TOOLING.directory)
  end
  return {
    '--max-old-space-size=' .. tostring(TOOLING.js_heap_mib),
    '--input-type=module',
    '--eval',
    WRAPPER,
    '--',
    TOOLING.directory,
    TOOLING.package_version,
    vim.json.encode(CONFIG),
    tostring(TOOLING.max_input_bytes),
    tostring(TOOLING.max_output_bytes),
    tostring(TOOLING.reject_warnings),
  }
end

---@param context FormatterContext
---@return string
local function working_directory(context)
  return context.root
end

---@type FormatterSpec
return {
  cmd = TOOLING.node,
  args = arguments,
  mode = 'stdin',
  output = 'stdout',
  cwd = working_directory,
  root_markers = { '.latexmkrc', 'latexmkrc', 'tectonic.toml', '.git' },
  env = { NO_COLOR = '1', NODE_OPTIONS = '', NODE_PATH = '' },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
  extension = 'bib',
}