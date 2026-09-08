# Diver Engineering Playbook

This plural `SKILLS.md` is a repository playbook referenced explicitly by `AGENTS.md`
and `CLAUDE.md`, not an automatically installed Agent Skill.
Do not source the user's entire configuration just to validate a small change.

## Lua implementation or nil-safety fix

1. Inspect the affected module, caller, scoped instructions and existing diagnostics.
   Read `lsp/lua_ls.lua`, `lsp/stylua_ls.lua`, `.luarc.json` and `.stylua.toml`.
2. Define the successful and failure contracts. Reproduce the bug with an isolated test.
3. Fix the boundary with precise types and guards; preserve public behavior and style.
4. Run the parser/formatter, completed LuaLS diagnostics and relevant runtime tests.
5. Review the final diff. Record tool versions, covered files, results and missing gates.

For a selected Lua file, set `FILE` to its actual repository-relative path:

```sh
stylua --check --config-path .stylua.toml --syntax LuaJIT "$FILE"
git diff --check
```

This does not run LuaLS or prove runtime behavior. Do not use whole-repository formatting
as a substitute for a surgical change. The checked-in formatter settings take precedence
over differing editor LSP defaults for this task.

## Strict LuaLS diagnostics

Preserve the exact current type and diagnostic settings from `lsp/lua_ls.lua`, including:

```text
runtime.version = "LuaJIT"
type.weakNilCheck = false
type.weakUnionCheck = false
type.checkTableShape = true
type.castNumberToInteger = false
type.inferParamType = true
diagnostics.groupSeverity["type-check"] = "Error"
diagnostics.severity["undefined-field"] = "Error"
```

For a headless run, promote `diagnostics.groupFileStatus["type-check"]` from `Opened`
to `Any`. Preserve other severity/disable settings and report coverage explicitly.
Read supported CLI flags for the installed LuaLS version; use a reviewed configuration
export rather than trying to execute an LSP configuration table as a CLI config.
Resolve Neovim/luv libraries on the actual machine, not another machine's home directory.

The root `.luarc.json` alone is not equivalent to the full strict LSP profile.
Do not call it a strict pass unless the actual effective settings match the contract.
Verify checker completion and report diagnostics by scope and severity; missing libraries
or skipped files remain limitations, not successes.

Use optional return annotations and runtime narrowing for missing files/modules, `fs_stat`,
`fs_fstat`, `loadfile`, `io.open`, uv handles and async state. Non-nil does not imply a
decoded object has the correct shape. Avoid blanket `any`, blind casts and suppressions.

## Native lint completion changes

Read `docs/native-lint-api.md`, `lua/linters/init.lua` and the affected definition.
Preserve the boolean first return, optional handle, one terminal completion per run,
`verified` only for `ok`, cancellation and stale-buffer behavior.

When an authorized Rose checkout is available, its existing integration tests cover this
API. From that checkout, with `DIVER_ROOT` set to this actual checkout:

```sh
make test-tooling DIVER_ROOT="$DIVER_ROOT"
ROSE_TEST_LSP="$(command -v basedpyright-langserver)" \
ROSE_TEST_RUFF="$(command -v ruff)" \
  make test-live DIVER_ROOT="$DIVER_ROOT"
```

Verify both executables exist before the optional live command; empty values can skip
coverage. Report such skips. Do not set those variables to `1`: they require paths.
If Rose is unavailable, use an isolated native harness or report integration unverified;
do not install a cross-project workflow for an unrelated configuration edit.

## Handoff for another model

Supply goal/non-goals, revision, allowed files, verified APIs, exact settings, nil/error
contracts, bounds, ordered steps and actual test commands. Include a small missing-file
example and expected result. Separate expected behavior from observed evidence.

The receiver checks for stale context, implements one bounded step and runs its gate.
It must stop for missing tools/permissions or conflicting contracts instead of inventing
APIs, suppressing diagnostics or expanding scope. Reusable lessons need a trigger,
procedure, failure/remedy and acceptance condition.
