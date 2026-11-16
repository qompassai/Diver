-- /qompassai/Diver/lua/games/wasm4/config.lua
-- Qompass AI WASM-4 Config
--- Options and verified WASM-4 CLI surface.
---
--- Every flag below comes from the w4 CLI itself (v2.7.1, `w4 <cmd>
--- --help`, verified 2026-11-15):
---   * `w4 new <dir> --lang <lang>` scaffolds a project per language.
---   * `w4 bundle <cart> --html|--windows|--mac|--linux <out>` packages
---     a built cart; `--title` names the game.
---   * `w4 png2src <images...> --lang <lang>` prints sprite source.
---   * `w4 run <cart>` serves the web runtime (port 4444, QR code);
---     `w4 run-native <cart>` opens the desktop runtime.
---   * `w4 watch` rebuilds and refreshes the web runtime on save.
---
--- Project kinds are detected from the template trees `w4 new` writes:
--- Rust builds with cargo, Go and WAT with their template Makefiles,
--- AssemblyScript with `npm run build`; every non-Rust template emits
--- `build/cart.wasm` (verified against the v2.7.1 templates).
---@module 'games.wasm4.config'

---@class games.wasm4.Options
---@field bin string? Binary name or absolute path of the w4 executable.
---@field bundle_format string? Default bundle target: html, linux, mac, or windows.
---@field default_language string? Language for png2src and programmatic scaffolds.
---@field projects_dir string? Directory prompted as the parent for new carts.
---@field run_mode string? Run target: auto, native, or web.

---@class games.wasm4.ResolvedOptions
---@field bin string
---@field bundle_format string
---@field default_language string
---@field projects_dir string
---@field run_mode string

---@class games.wasm4.ProjectKind
---@field build_argv string[] Build command run in the project root.
---@field cart string Built cart path, relative to the project root.
---@field marker string File whose presence identifies the kind.

local M = {}

M.binaries = { 'w4' }

---Bundle targets accepted by `w4 bundle <cart> --<format> <out>`.
---@type string[]
M.bundle_formats = {
    'html',
    'linux',
    'mac',
    'windows',
}

---@type games.wasm4.ResolvedOptions
M.current = {
    bin = 'w4',
    bundle_format = 'html',
    default_language = 'rust',
    projects_dir = '~/wasm4',
    run_mode = 'auto',
}

M.env_names = {
    'NVIM_WASM4_BIN',
    'WASM4_BIN',
}

M.group_order = {
    'Run',
    'Build',
    'Media',
    'Project',
}

---Languages accepted by `w4 new --lang` / `w4 png2src --lang` (v2.7.1).
---@type string[]
M.languages = {
    'assemblyscript',
    'c',
    'c3',
    'cpp',
    'd',
    'go',
    'grain',
    'nelua',
    'nim',
    'odin',
    'penne',
    'porth',
    'roc',
    'roland',
    'rust',
    'wat',
    'zig',
}

M.output_filetype = 'wasm4-output'

---Filetype for png2src output buffers, per language; languages without
---an entry fall back to M.output_filetype.
---@type table<string, string>
M.png2src_filetypes = {
    assemblyscript = 'typescript',
    c = 'c',
    cpp = 'cpp',
    go = 'go',
    rust = 'rust',
    wat = 'wat',
    zig = 'zig',
}

---Project kinds in detection order: the most specific template marker
---wins (Cargo.toml and main.wat are unambiguous; package.json is the
---weakest signal and is checked last).
---@type string[]
M.project_kind_order = {
    'rust',
    'wat',
    'go',
    'assemblyscript',
}

---@type table<string, games.wasm4.ProjectKind>
M.project_kinds = {
    assemblyscript = {
        build_argv = { 'npm', 'run', 'build' },
        cart = 'build/cart.wasm',
        marker = 'package.json',
    },
    go = {
        build_argv = { 'make' },
        cart = 'build/cart.wasm',
        marker = 'go.mod',
    },
    rust = {
        build_argv = { 'cargo', 'build', '--release' },
        cart = 'target/wasm32-unknown-unknown/release/cart.wasm',
        marker = 'Cargo.toml',
    },
    wat = {
        build_argv = { 'make' },
        cart = 'build/cart.wasm',
        marker = 'main.wat',
    },
}

---@param opts games.wasm4.Options?
---@return games.wasm4.ResolvedOptions
function M.resolve(opts)
    opts = opts or {}

    M.current = {
        bin = opts.bin or 'w4',
        bundle_format = opts.bundle_format or 'html',
        default_language = opts.default_language or 'rust',
        projects_dir = vim.fs.normalize(vim.fn.expand(opts.projects_dir or '~/wasm4')),
        run_mode = opts.run_mode or 'auto',
    }
    return M.current
end

return M
