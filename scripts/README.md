# Diver scripts

This directory contains bootstrap, installer, and integration scripts for the Diver Neovim configuration.

## Installer cascade (rootless)

`scripts/install.sh` (Bash) and `scripts/install.ps1` (native PowerShell) install Diver and its tooling **without root/admin**, one small step at a time:

```bash
bash ./scripts/install.sh                 # full install
bash ./scripts/install.sh --list          # list steps
bash ./scripts/install.sh --only 10-prereqs,20-neovim
bash ./scripts/install.sh --skip 60-formatters,70-linters
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Only 10-prereqs,20-neovim
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -List
```

### Steps

| Step | Installs |
|---|---|
| `10-prereqs` | build toolchain for the source build: git/curl/tar/make, clang (LLVM) or gcc, cmake, ninja, gettext, pkg-config — bootstrapped user-local when missing; platform detection (WSL, Termux, Nix-on-Droid) |
| `20-neovim` | Neovim nightly **built from source** (optimized Release: `-O3 -march=native`, Ninja, clang/gcc) into `~/.local` (Linux/WSL); `nix profile` (Nix-on-Droid); `pkg` (Termux); prebuilt release with `--prebuilt` |
| `30-config` | links this checkout as `~/.config/nvim` (or copies with `DIVER_CONFIG_COPY=1`) |
| `40-toolchains` | rustup, Go, Node+pnpm, uv-managed Python, JDK, Ruby — all user-local |
| `50-lsp` | language servers via go/cargo/pnpm/uv/gem/dotnet/opam/coursier channels |
| `60-formatters` | formatter binaries via the shared channel primitives |
| `70-linters` | linter binaries via the shared channel primitives |
| `80-dap` | DAP backends: debugpy, delve, codelldb, netcoredbg, vscode-js-debug, php-debug-adapter, probe-rs, elixir-ls, moonwalk |
| `90-treesitter` | `:TSInstallSync` headless (needs a C compiler on PATH) |
| `95-hosts` | node/python/ruby providers, lua-language-server + `lua_ls` shim |
| `99-finish` | toolchain audit, unsupported report, versions, `:checkhealth` |

Steps are idempotent: a step skips anything already on PATH. Every step records the binaries it manages in a manifest (`$XDG_DATA_HOME/diver/install/manifest.d/`), and `99-finish` probes each one and reports **present vs missing** — a missing binary is reported, never silently claimed.

Useful environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `DIVER_NVIM_PREBUILT` / `--prebuilt` | `0` | `1` takes the prebuilt Neovim nightly instead of building from source |
| `DIVER_NVIM_SOURCE` / `--source` | `1` | `0` takes the prebuilt release (legacy name for the same switch) |
| `DIVER_NVIM_BUILD_TYPE` | `Release` | cmake build type: `Release` \| `RelWithDebInfo` \| `Debug` |
| `DIVER_NVIM_CFLAGS` | `-O3 -march=native` | extra C/C++ flags for the source build |
| `DIVER_NVIM_LTO` | `0` | `1` enables link-time optimization (slower, occasionally fails upstream) |
| `DIVER_NVIM_DRY_RUN` | `0` | `1` validates clone + cmake configure, then stops before compiling |
| `DIVER_INSTALL_LSPS` | `1` | `0` skips step 50 |
| `DIVER_INSTALL_FORMATTERS` | `1` | `0` skips step 60 |
| `DIVER_INSTALL_LINTERS` | `1` | `0` skips step 70 |
| `DIVER_INSTALL_DAP` | `1` | `0` skips step 80 |
| `DIVER_TS_PARSERS` | config's `ensure_installed` | override the tree-sitter parser list |
| `DIVER_MOONWALK_DIR` | `~/GH/Qompass/moonwalk` | moonwalk checkout for step 80 |
| `DIVER_CONFIG_COPY=1` | link | copy the config instead of symlinking it |
| `BUILD_DIR` | `~/src/neovim-nightly` | Neovim source checkout for the source build |

### Platform capability matrix

| Target | Launcher | Neovim | Toolchains | Notes |
|---|---|---|---|---|
| Linux desktop | `install.sh` | **built from source** (optimized Release) → `~/.local` | rustup/Go/Node/uv/JDK user-local | full support |
| WSL | `install.sh` (inside WSL) | same as Linux | same as Linux | prefer a checkout inside the WSL filesystem, not `/mnt/c` |
| Native Windows | `install.ps1` | nightly ZIP → `%LOCALAPPDATA%\Diver` (**prebuilt default** — source build needs MSVC Build Tools, not bootstrapped) | winget (user scope) + user-local archives | PATH via HKCU user env; **syntax-checked only, not yet runtime-tested** |
| Nix-on-Droid | `install.sh` | `nix profile install` (nightly overlay, `nixpkgs` fallback) | `nixpkgs#` profiles | detection via `command -v nix-on-droid` |
| Termux | `install.sh` | `pkg` when available | `pkg` + channel installs | some upstream assets publish no Android builds — reported by `99-finish` |

### Unsupported, reported honestly

Some binaries Diver references have **no clean rootless install path** (proprietary tools, system-only packages, unmaintained scripts). The cascade does not pretend to install them: `99-finish` lists them from the shared `$DIVER_UNSUPPORTED` table (e.g. `matlab`, `nvcc`, `hh_client`, `systemd-analyze`, `desktop-file-validate`). Single-file upstream scripts that *do* have a clean path (`checkpatch.pl`, `apkbuild-lint`) are curled into `$BIN_DIR` by step 70.

### Update and supply-chain policy

- **Nightly Neovim** and `@latest` ecosystem packages move on every run — that is the point (bleeding edge), and the tradeoff is explicit: a rerun can change versions. Re-run the cascade to update.
- **Pinned where it matters**: the lua-language-server binary (`3.15.0`), golangci-lint (`v2.5.0`), and the Dart SDK version are pinned in the steps so a bad upstream release does not break a fresh install.
- **Checksums**: `diver_gh_release` verifies a sibling `.sha256` asset when the release publishes one, and refuses to install on mismatch. Many upstreams publish none — those installs are reported as unverified in the step output.
- Review a step before running it on a production workstation; steps never `sudo`, never touch system directories, and never modify the config checkout beyond linking it.

## Quickstart (legacy bootstrap)

`quickstart.sh` is the older monolithic bootstrap: it builds Neovim from source and optionally dispatches the per-language installers below. Prefer `install.sh` for new setups; `quickstart.sh` remains for source-build-first workflows.

At a high level, it:

1. Detects Termux and WSL.
2. Sets an installation prefix:
   - Linux/WSL: `~/.local`
   - Termux: `$PREFIX`, normally `/data/data/com.termux/files/usr`
3. Ensures core build tools are available: Git, curl, tar, make, Clang, CMake, Ninja, Bash, and pkg-config.
4. Clones or updates Neovim under `$BUILD_DIR`.
5. Builds bundled Neovim dependencies and Neovim itself with CMake and Ninja.
6. Installs Neovim into the local prefix.
7. Copies the installed runtime into Neovim's XDG data directory and adds a small `runtimepath` block to `init.lua` when needed.
8. Installs or configures LuaJIT, LuaRocks, and `lua-language-server` where supported.
9. Installs optional Node, Python, and Ruby Neovim providers when their package managers are available.
10. Optionally dispatches the language-server installer scripts documented below.

### Run it

From the repository root on Linux, WSL, or Termux:

```bash
bash ./scripts/quickstart.sh
```

The script uses these useful environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `BUILD_DIR` | `~/src/neovim-nightly` | Neovim source checkout and build directory |
| `DIVER_INSTALL_LSPS` | `1` | Set to `0` to skip language-server installers |
| `DIVER_LSP_DIR` | `../lsp` relative to `scripts/` | Override the directory containing LSP installer scripts |
| `DIVER_LSP_STRICT` | `0` | Set to `1` to stop at the first failed LSP installer |
| `NVIM_GODOT_EXECUTABLE` | unset | Optional path to a Godot or Redot executable |
| `NVIM_GDLINT_ROOT` | unset | Optional path to the godot-gdscript-linter checkout |

Examples:

```bash
# Build Neovim but do not run language-server installers.
DIVER_INSTALL_LSPS=0 bash ./scripts/quickstart.sh

# Use a custom language-server installer directory.
DIVER_LSP_DIR="$HOME/src/Diver/lsp" bash ./scripts/quickstart.sh

# Treat a failing installer as a quickstart failure.
DIVER_LSP_STRICT=1 bash ./scripts/quickstart.sh
```

### WSL and Windows

`install.sh` and `quickstart.sh` use Bash, Unix paths, and Unix package/tool conventions. On **native Windows** (no WSL), use the PowerShell cascade instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

To run the Bash scripts from PowerShell, go through WSL:

```powershell
wsl.exe -- bash -lc 'cd ~/src/Diver && bash ./scripts/install.sh'
```

If the repository is on the Windows filesystem, enter WSL first and use its translated path:

```powershell
wsl.exe
```

Then in the WSL shell:

```bash
cd /mnt/c/path/to/Diver
bash ./scripts/install.sh
```

Building under `/mnt/c` or another `/mnt/*` path can be significantly slower than building under the Linux filesystem. Prefer a checkout such as `~/src/Diver` inside WSL when possible.

`cmd.exe` can launch the same WSL command:

```bat
wsl.exe -- bash -lc "cd ~/src/Diver && bash ./scripts/install.sh"
```

## Language-server installers

The quickstart dispatcher should only execute scripts stored in the dedicated LSP installer directory, normally `lsp/`. Do not place generic helpers or unrelated maintenance scripts in that directory.

Each installer is a separate Bash process. That gives each language ecosystem an isolated install step and allows the dispatcher to continue after an optional installer fails unless `DIVER_LSP_STRICT=1` is set.

You may run an installer directly:

```bash
bash ./lsp/go.sh
bash ./lsp/cargo.sh
bash ./lsp/js.sh
bash ./lsp/py.sh
```

### Installer groups

| Script | Installs through | Typical prerequisite |
|---|---|---|
| `go.sh` | `go install` | Go toolchain |
| `cargo.sh` | `rustup` and `cargo install` | Rust toolchain and Cargo |
| `js.sh` | `pnpm add -g` | Node.js and pnpm |
| `py.sh` | `pip` and `uv pip` | Python, pip, and optionally uv |
| `ruby.sh` | `gem install` | Ruby and RubyGems |
| `ocaml.sh` | OCaml tooling | OCaml package manager/toolchain |
| `idris2.sh` | Idris tooling | Idris 2 toolchain |
| `mojo.sh` | Mojo tooling | Mojo SDK/toolchain |
| `motoko.sh` | Motoko tooling | DFINITY/Motoko tooling |
| `pascal.sh` | Pascal tooling | Free Pascal or relevant Pascal tooling |
| `clir_ls.sh` | CLR/.NET tooling | .NET SDK/runtime |
| `vs.sh` | VSIX download and extraction | curl, archive extraction tools, Java runtime |

Some installers contain packages that may not publish binaries for Android/Termux or may require a native build toolchain. A failed optional installer does not mean the Neovim build failed.

## Supporting scripts

Not every shell script in this repository is an LSP installer.

- `api.sh` provides HTTP/download helper functions for other scripts; it is not a standalone bulk installer.
- `sf.sh` configures the Salesforce CLI plugin allowlist and installs Salesforce CLI plugins. Run it only after installing and authenticating the `sf` CLI.
- `schema.sh`, `jimmer.sh`, and `install_tilt.sh` are ecosystem-specific setup scripts. Review their contents and prerequisites before running them.

Run supporting scripts individually and intentionally:

```bash
bash ./scripts/sf.sh
bash ./scripts/install_tilt.sh
```

## Safety and maintenance

These scripts install packages, compile software, clone repositories, create symlinks, and may modify shell startup files or Neovim configuration. Review an installer before running it, particularly on a production workstation.

Recommended workflow:

1. Run `install.sh --only 10-prereqs,20-neovim,30-config` to validate the base environment.
2. Install the language toolchains you actually use (`--only 40-toolchains`).
3. Run the ecosystem steps you need (`50-lsp`, `60-formatters`, `70-linters`, `80-dap`).
4. Finish with `90-treesitter,95-hosts,99-finish` and read the audit report.

## Troubleshooting

### A language installer fails

Run that script directly to isolate the failure:

```bash
bash ./lsp/<installer>.sh
```

Then verify its package manager is available:

```bash
command -v go
command -v cargo
command -v pnpm
command -v python3
command -v pip
command -v gem
```

### Neovim is not found after install

The cascade installs binaries into the selected prefix's `bin` directory:

- Linux/WSL: `~/.local/bin`
- Termux: `$PREFIX/bin`
- Native Windows: `%LOCALAPPDATA%\Diver\bin` (HKCU user PATH)

Start a new shell after the script updates shell startup files, or export the path for the current shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### WSL builds are slow

Move the repository and `BUILD_DIR` from `/mnt/c/...` into the WSL filesystem, for example:

```bash
mkdir -p ~/src
cp -a /mnt/c/path/to/Diver ~/src/Diver
cd ~/src/Diver
bash ./scripts/install.sh
```

## License

Unless a script states otherwise, follow the repository's license and the licenses of the tools each installer downloads or installs.
