-- #################################################################
-- ~/.config/nvim/lua/formatters/wgslfmt.lua
-- Native wasm-fmt WGSL Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/wasm-fmt/wgslfmt
-- @wasm-fmt/wgslfmt is a JS/WASM library, not a command named wgslfmt.
local fs = vim.fs
local CONFIG = {
  trailing_commas = 'ignore', -- 'ignore' | 'insert' | 'remove'
  indent_symbol = '    ', -- Four spaces; use '\t' or '  ' if desired.
}
local TOOLING = {
  node = 'node',
  package_version = '0.1.0',
  directory = fs.joinpath(vim.fn.stdpath('data'), 'formatters', 'wgslfmt'),
  max_input_bytes = 2 * 1024 * 1024,
  max_output_bytes = 4 * 1024 * 1024,
  js_heap_mib = 256, -- JS old-space setting, not a total process/WASM memory cap.
}

-- Static script with configuration supplied as argv, never interpolated as code.
local WRAPPER = [==[
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

// Conservative lexical invariant, not syntax or semantic validation.
function tokens(source, commaPolicy) {
  const result = [];
  const token = /(?:0[xX](?:[0-9a-fA-F]+(?:\.[0-9a-fA-F]*)?|\.[0-9a-fA-F]+)(?:[pP][+-]?\d+)?[fhiu]?|(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?[fhiu]?|[_\p{XID_Start}][_\p{XID_Continue}]*|>>=|<<=|->|\+\+|--|&&|\|\||==|!=|<=|>=|<<|>>|\+=|-=|\*=|\/=|%=|&=|\|=|\^=|[^\s])/uy;
  let i = 0;
  while (i < source.length) {
    if (/\s/u.test(source[i])) { i++; continue; }
    if (source.startsWith('//', i)) {
      const end = source.indexOf('\n', i + 2);
      i = end < 0 ? source.length : end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      let depth = 1;
      i += 2;
      while (i < source.length && depth) {
        if (source.startsWith('/*', i)) { depth++; i += 2; }
        else if (source.startsWith('*/', i)) { depth--; i += 2; }
        else { i++; }
      }
      if (depth) throw new Error('Unterminated WGSL block comment');
      continue;
    }
    if (source[i] === '"' || source[i] === "'") {
      const start = i;
      const quote = source[i++];
      let closed = false;
      while (i < source.length) {
        if (source[i] === '\\') { i += 2; }
        else if (source[i++] === quote) { closed = true; break; }
      }
      if (!closed) throw new Error('Unterminated quoted text');
      result.push(source.slice(start, i));
      continue;
    }
    token.lastIndex = i;
    const match = token.exec(source);
    if (!match) throw new Error('Cannot verify WGSL token preservation');
    result.push(match[0]);
    i = token.lastIndex;
  }
  return commaPolicy === 'ignore' ? result : result.filter((value, index) =>
    !(value === ',' && [')', ']', '}'].includes(result[index + 1])));
}

try {
  const [directory, expectedVersion, configText, inputText, outputText] = process.argv.slice(1);
  const inputLimit = Number(inputText);
  const outputLimit = Number(outputText);
  if (!Number.isSafeInteger(inputLimit) || inputLimit < 1 ||
      !Number.isSafeInteger(outputLimit) || outputLimit < 1) {
    throw new Error('Invalid WGSL formatter byte limits');
  }
  const config = JSON.parse(configText);
  if (!['ignore', 'insert', 'remove'].includes(config.trailing_commas) ||
      typeof config.indent_symbol !== 'string' || !/^[ \t]+$/.test(config.indent_symbol)) {
    throw new Error('Invalid WGSL formatter configuration');
  }
  const localRequire = createRequire(join(directory, 'package.json'));
  const manifestPath = localRequire.resolve('@wasm-fmt/wgslfmt/package.json');
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  if (manifest.version !== expectedVersion) {
    throw new Error(`Expected @wasm-fmt/wgslfmt ${expectedVersion}, found ${manifest.version}`);
  }
  const { format } = await import(pathToFileURL(localRequire.resolve('@wasm-fmt/wgslfmt/node')).href);
  const chunks = [];
  let size = 0;
  for await (const chunk of process.stdin) {
    size += chunk.length;
    if (size > inputLimit) throw new Error('WGSL formatter input limit exceeded');
    chunks.push(chunk);
  }
  const input = new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks));
  const output = format(input, config);
  if (typeof output !== 'string' || output.includes('\0')) {
    throw new Error('WGSL formatter produced invalid source text');
  }
  if (Buffer.byteLength(output, 'utf8') > outputLimit) {
    throw new Error('WGSL formatter output limit exceeded');
  }
  const before = tokens(input, config.trailing_commas);
  const after = tokens(output, config.trailing_commas);
  if (before.length !== after.length || before.some((value, index) => value !== after[index])) {
    throw new Error('Formatter changed WGSL tokens; output rejected (upstream formatter limitation)');
  }
  process.stdout.write(output);
} catch (error) {
  process.stderr.write(`wgslfmt: ${String(error?.message ?? error).slice(0, 4096)}\n`);
  process.exitCode = 1;
}
]==]

---@param context FormatterContext
---@return string[]
local function arguments(context)
  assert(context.filetype == 'wgsl' or context.filetype == 'wgsl_bevy', 'wgslfmt requires a WGSL buffer')
  local manifest = fs.joinpath(TOOLING.directory, 'node_modules', '@wasm-fmt', 'wgslfmt', 'package.json')
  assert(vim.fn.filereadable(manifest) == 1, 'Install @wasm-fmt/wgslfmt@0.1.0 in ' .. TOOLING.directory)
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
  }
end

---@type FormatterSpec
return {
  cmd = TOOLING.node,
  args = arguments,
  mode = 'stdin',
  output = 'stdout',
  root_markers = {
    'Cargo.toml',
    'package.json',
    '.git',
  },
  env = {
    NODE_OPTIONS = '',
    NODE_PATH = '',
    NO_COLOR = '1',
  },
  exit_codes = { 0 },
  automatic = true,
  allow_empty = false,
}