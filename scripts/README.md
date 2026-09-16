# Diver scripts

This directory contains bootstrap, installer, and integration scripts for the Diver Neovim configuration.

The scripts are written for Bash. They are intended to run directly on Linux, inside WSL on Windows, or in Termux on Android. On native Windows, launch them through WSL rather than attempting to execute the `.sh` files from PowerShell or `cmd.exe` directly.

## Quickstart

`quickstart.sh` bootstraps a local Neovim build and then configures optional editor providers and language-server installers.

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

The primary bootstrap and installer scripts use Bash, Unix paths, and Unix package/tool conventions. They are not native PowerShell or `cmd.exe` scripts.

Use WSL from PowerShell:

```powershell
wsl.exe -- bash -lc 'cd ~/src/Diver && bash ./scripts/quickstart.sh'
```

If the repository is on the Windows filesystem, enter WSL first and use its translated path:

```powershell
wsl.exe
```

Then in the WSL shell:

```bash
cd /mnt/c/path/to/Diver
bash ./scripts/quickstart.sh
```

Building under `/mnt/c` or another `/mnt/*` path can be significantly slower than building under the Linux filesystem. Prefer a checkout such as `~/src/Diver` inside WSL when possible.

`cmd.exe` can launch the same WSL command:

```bat
wsl.exe -- bash -lc "cd ~/src/Diver && bash ./scripts/quickstart.sh"
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

1. Run `quickstart.sh` with `DIVER_INSTALL_LSPS=0` to validate the Neovim build environment.
2. Install the language toolchains you actually use.
3. Run only the matching language-server installers directly.
4. Once the set is stable, enable the quickstart LSP dispatcher for repeatable bootstrap.

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

The quickstart installs binaries into the selected prefix's `bin` directory:

- Linux/WSL: `~/.local/bin`
- Termux: `$PREFIX/bin`

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
bash ./scripts/quickstart.sh
```

## License

Unless a script states otherwise, follow the repository's license and the licenses of the tools each installer downloads or installs.
