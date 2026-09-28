# primo tool installs (2026-09-28)

## What was missing

Verified via `ssh primo` before touching anything:

| Tool | Before | After |
|---|---|---|
| `vulkaninfo` | `/usr/bin/vulkaninfo` ✓ (instance 1.4.357, 34 layers) | — |
| `glslangValidator` | `/usr/bin/glslangValidator` ✓ | — |
| `glslc` | `/usr/bin/glslc` ✓ | — |
| `renderdoccmd` | `/usr/bin/renderdoccmd` ✓ (v1.46) | — |
| `vkconfig` | `/usr/bin/vkconfig` ✓ | — |
| `glsl_analyzer` | `/usr/bin/glsl_analyzer` ✓ | — |
| `clangd` | `/usr/bin/clangd` ✓ | — |
| `dxc` | **missing** | installed |
| `slangc` | **missing** | installed |
| `VULKAN_SDK` | **empty** | left empty (see below) |

Only `dxc` and `slangc` were installed — exactly what was authorized.
Nothing else on primo was touched, and no system-wide environment
variables were set.

## Sources (official release channels only)

- **dxc**: https://github.com/microsoft/DirectXShaderCompiler —
  release tag `v1.9.2607` (latest, stable, not a prerelease),
  asset `linux_dxc_2026_07_29.x86_x64.tar.gz`
- **slangc**: https://github.com/shader-slang/slang —
  release tag `v2026.18.3` (latest, stable),
  asset `slang-2026.18.3-linux-x86_64.tar.gz`

Tags and asset names were resolved through the GitHub API, not guessed.

## Verification

Neither release publishes checksums or signatures (checked the full
asset lists via the API — no `.sha256`/`.asc`/sigstore files exist).
What was verified instead:

1. **HTTPS transport** — downloads over TLS from github.com.
2. **Exact tag pinning** — `v1.9.2607` / `v2026.18.3`, both `draft: false`,
   `prerelease: false`.
3. **Independent hash confirmation (dxc)** — the downloaded tarball's
   SHA-256 is `55665c87824051ed4774ff3280a79ccbbb7d39243b9736ca5e98222134112d54`,
   which **exactly matches** the hash pinned by the third-party
   `kstocky/hlsl-lsp` project's `docs/linux.md` for the same asset —
   two independent downloads of the same file agreeing byte-for-byte.
4. **Smoke tests on primo** —
   `dxc --version` → `libdxcompiler.so: 1.9(1-0d3ee6b5)(1.9.0.1)`;
   `slangc -v` → `2026.18.3`; `ldd` shows no missing libraries for either.
5. **End-to-end** — compiled an HLSL vertex shader with
   `dxc -spirv -T vs_6_8 -E main` → valid 280-byte SPIR-V.

Recorded hashes:

```
55665c87824051ed4774ff3280a79ccbbb7d39243b9736ca5e98222134112d54  dxc.tar.gz
4d664ca905124ae68204ee05170f5acd8dc53956baf850b2e7b23215cfb78f7b  slang.tar.gz
```

## Install locations (user space, no sudo, no system env)

- `~/workspace/tools/dxc-1.9.2607/` — `bin/dxc`, `lib/libdxcompiler.so`, …
- `~/workspace/tools/slang-2026.18.3/` — `bin/slangc`, `lib/`, `include/`, …
- `~/workspace/tools/vulkan-dl/` — the original tarballs, kept for re-verification.

To use them in a shell (not set system-wide, by design):

```sh
export PATH="$HOME/workspace/tools/dxc-1.9.2607/bin:$HOME/workspace/tools/slang-2026.18.3/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/workspace/tools/dxc-1.9.2607/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

(DXC needs its `lib/` on the loader path; slangc is self-contained.)

Diver's toolchain prober finds them via `PATH` — add the export to the
shell rc if `:VulkanToolchain` should see them in every session.

## What was deliberately not done

- **No `VULKAN_SDK`.** The distro provides loader/layers/tools without
  the SDK env marker; setting it to a fake path would be worse than
  leaving it empty. Detection falls back to well-known paths.
- **No AUR builds.** `paru -S directx-shader-compiler` exists, but the
  authorization was for official GitHub release channels, so release
  binaries were used.
- **No system directories.** Everything is under `~/workspace/tools/`.
