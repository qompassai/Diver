# Shader toolchain: the four compilers and compile-on-save

## The four compilers

| Tool | Compiles | Why you'd use it |
|---|---|---|
| `glslangValidator` | GLSL → SPIR-V | The reference GLSL frontend; default for `.vert`/`.frag`/`.comp`/… |
| `glslc` | GLSL → SPIR-V | Google's friendlier wrapper around the same core |
| `dxc` | HLSL → SPIR-V (or DXIL) | Microsoft's HLSL compiler; `-spirv` backend targets Vulkan |
| `slangc` | Slang → SPIR-V | The Slang language: one source, many targets |

Diver already had native linters for `glslc`, `dxc`, and Slang-as-SystemVerilog
(`lua/linters/glslc.lua`, `dxc.lua`, `slang.lua`) — those *check* code.
This workstream adds *compiling* it: probing which compilers exist and
producing the SPIR-V artifact your renderer loads.

## How it was done

`lua/dev/vulkan/toolchain.lua` splits the job in two:

- **`M.probe(name)`** — is it installed? which version? `found` is
  authoritative; `version` is best-effort and honestly `nil` when the
  version flag fails. One subtlety, verified on primo: `slangc` does
  **not** accept `--version` (it errors `E00017`); its flag is `-v`.
- **`M.build_argv(tool, opts)`** — pure function returning the exact
  command line. No process is spawned, so `tests/lua/vulkan_toolchain.lua`
  verifies every flag without needing the tools installed.

### Flags, and where each was verified

- `glslangValidator -V -S <stage> --target-env vulkan1.3 -o <out> <src>` —
  from `glslangValidator --help` on primo (`-S` overrides the stage,
  `-V` emits SPIR-V).
- `glslc --target-env=vulkan1.3 -fshader-stage=<stage> -o <out> <src>` —
  shaderc documented flags.
- `dxc -spirv -T <profile> -E <entry> -Fo <out> <src>` — verified by a
  real compile on primo (HLSL vertex shader → 280-byte SPIR-V).
- `slangc -target spirv -stage <stage> -entry <entry> -o <out> <src>` —
  from `slangc --help` on primo.

Bare `.glsl` is **ambiguous** (no stage in the extension) and returns an
error instead of a guess — pass `stage` explicitly or use a staged
suffix like `.vert.glsl`.

## Compile-on-save

`lua/dev/vulkan/compile.lua` registers a `BufWritePost` autocmd for
`*.vert *.frag *.tesc *.tese *.geom *.comp *.mesh *.task *.rgen *.rint
*.rahit *.rchit *.rmiss *.rcall *.glsl *.hlsl *.slang`. On save it:

1. Picks the compiler (`.hlsl`→dxc, `.slang`→slangc, else glslangValidator).
2. Compiles to `<file>.spv` next to the source (or `output_dir`).
3. Parses `file:line:col: severity: message` output into findings and
   publishes them with `vim.diagnostic` — the same surface the native
   linters use.
4. Drops stale results: if the buffer was closed or edited while the
   compiler ran, the diagnostics are discarded.

It is deliberately separate from the linter framework: linters check,
this produces the artifact. `:VulkanCompile` runs it on demand.

## Try it

```
:VulkanToolchain   " probe report for all four compilers
:VulkanCompile     " compile the current buffer now
```

Save any shader file and watch the diagnostics appear.

## What was learned

- `slangc --version` is not a thing (`-v` is). Probing code that assumes
  `--version` everywhere would report slangc as versionless.
- The DXC Linux tarball is ~500 MB because it ships a full LLVM tree —
  `bin/dxc` needs `lib/libdxcompiler.so` beside it (`LD_LIBRARY_PATH`).
- dxc's `--version` prints the *library* version (`libdxcompiler.so:
  1.9(1-0d3ee6b5)(1.9.0.1)`), not a `dxc X.Y.Z` line — parse accordingly.
