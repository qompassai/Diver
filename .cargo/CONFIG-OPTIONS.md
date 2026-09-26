# Cargo configuration options worksheet

Companion to `.cargo/config.toml` in this repo. Every documented cargo
configuration key, organized alphabetically by section and by key, with a
blank **Your value** column to fill in for each part of the config.

- Config reference: <https://doc.rust-lang.org/cargo/reference/config.html>
- Profiles reference: <https://doc.rust-lang.org/cargo/reference/profiles.html>
- Unstable flags: <https://doc.rust-lang.org/cargo/reference/unstable.html>
- Package manifest (`Cargo.toml` — a different file):
  <https://doc.rust-lang.org/cargo/reference/manifest.html>

How to use:

1. Find the section you care about.
2. Write your choice in **Your value**.
3. Copy it into `.cargo/config.toml` (uncomment the key there if needed).

Precedence, highest wins: `cargo --config KEY=VALUE` >
`CARGO_<SECTION>_<KEY>` environment variables (uppercased, dots/dashes become
underscores) > `.cargo/config.toml` files (deeper directories win) >
`$CARGO_HOME/config.toml`.

Conventions below:

- **Default: none** means the key is unset unless you set it.
- Secrets (`token`) belong in `$CARGO_HOME/credentials.toml`, never in a
  checked-in config file.
- `[unstable]` keys require nightly cargo; they are an error on stable.

---

## Top-level keys

Docs: <https://doc.rust-lang.org/cargo/reference/config.html> (see `include`
and `paths` at the top of the page)

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `include` |  | array of string or `{path, optional}` tables | none | not supported |
| `paths` |  | array of paths | none | not supported |

`include` loads extra config files (paths relative to the file that includes
them; only `*.toml`; `{ path = "x.toml", optional = true }` skips missing
files). `paths` lists local packages used as overrides for dependencies.

---

## `[alias]` — command aliases

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#alias>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `<name>` |  | string or array of strings | built-ins: `b=build`, `c=check`, `d=doc`, `t=test`, `r=run`, `rm=remove` | `CARGO_ALIAS_<name>` |

The value is the command to run; a string is split on spaces, an array is
explicit (`rr = ["run", "--release"]`). Aliases may be recursive but may not
redefine built-in commands.

---

## `[build]` — build-time operations and compiler settings

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#build>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `build-dir` |  | string (path, templated) | follows `build.target-dir` | `CARGO_BUILD_BUILD_DIR` |
| `dep-info-basedir` |  | string (path) | none — deprecated, unused | `CARGO_BUILD_DEP_INFO_BASEDIR` |
| `incremental` |  | boolean | from the active profile | `CARGO_BUILD_INCREMENTAL` / `CARGO_INCREMENTAL` |
| `jobs` |  | integer, negative integer, or `"default"` | number of logical CPUs | `CARGO_BUILD_JOBS` |
| `pipelining` |  | boolean | deprecated, unused (always on) | — |
| `rustc` |  | string (program path) | `"rustc"` | `CARGO_BUILD_RUSTC` / `RUSTC` |
| `rustc-wrapper` |  | string (program path) | none | `CARGO_BUILD_RUSTC_WRAPPER` / `RUSTC_WRAPPER` |
| `rustc-workspace-wrapper` |  | string (program path) | none | `CARGO_BUILD_RUSTC_WORKSPACE_WRAPPER` / `RUSTC_WORKSPACE_WRAPPER` |
| `rustdoc` |  | string (program path) | `"rustdoc"` | `CARGO_BUILD_RUSTDOC` / `RUSTDOC` |
| `rustdocflags` |  | string or array of strings | none | `CARGO_BUILD_RUSTDOCFLAGS` / `CARGO_ENCODED_RUSTDOCFLAGS` / `RUSTDOCFLAGS` |
| `rustflags` |  | string or array of strings | none | `CARGO_BUILD_RUSTFLAGS` / `CARGO_ENCODED_RUSTFLAGS` / `RUSTFLAGS` |
| `target` |  | string or array of strings | host platform | `CARGO_BUILD_TARGET` |
| `target-dir` |  | string (path) | `"target"` at workspace root | `CARGO_BUILD_TARGET_DIR` / `CARGO_TARGET_DIR` |
| `warnings` |  | `"warn"` / `"allow"` / `"deny"` | `"warn"` | `CARGO_BUILD_WARNINGS` |

Notes:

- `rustflags` sources are mutually exclusive, first match wins:
  `CARGO_ENCODED_RUSTFLAGS` > `RUSTFLAGS` > matching
  `target.<triple|cfg>.rustflags` > `build.rustflags`. Same scheme for
  `rustdocflags`.
- `target` accepts any `rustc --print target-list` triple, `"host-tuple"`,
  or a path to a custom target spec. Ignored by `cargo install`.
- `build-dir` supports `{workspace-root}`, `{cargo-cache-home}`,
  `{workspace-path-hash}` templating.
- `warnings` adjusts the effective lint level for local packages only.

---

## `[cache]` — global cache housekeeping

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#cache>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `auto-clean-frequency` |  | string | `"1 day"` | `CARGO_CACHE_AUTO_CLEAN_FREQUENCY` |

Values: `"never"`, `"always"`, or `"<n> seconds|minutes|hours|days|weeks|months"`.
This controls how often cargo checks; files are deleted after 3 months unused
(network downloads) or 1 month unused (regenerable files).

---

## `[cargo-new]` — defaults for `cargo new`

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#cargo-new>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `vcs` |  | string | `"git"`, or `"none"` inside a VCS repo | `CARGO_CARGO_NEW_VCS` |

Values: `git`, `hg`, `pijul`, `fossil`, `none`. The old `name`/`email` keys
were removed and are not accepted.

---

## `[credential-alias]` — named credential-provider aliases

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#credential-alias>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `<name>` |  | string or array of strings | none | `CARGO_CREDENTIAL_ALIAS_<name>` |

A string is split on spaces into program + args; an array is explicit.
Referenced as `registries.<name>.credential-provider` or inside
`registry.global-credential-providers`.

---

## `[doc]` — `cargo doc` options

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#doc>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `browser` |  | string or array (program + args) | `$BROWSER` or system default | — |

Used by `cargo doc --open`.

---

## `[env]` — environment variables for builds

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#env>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `<VAR_NAME>` |  | string or `{ value, force, relative }` table | none | — |

Applies to build scripts, rustc invocations, `cargo run`, `cargo build`.
Plain values do not override existing environment variables; `force = true`
does. `relative = true` resolves `value` against the parent of the `.cargo`
directory containing the config.

---

## `[future-incompat-report]` — future-incompat notifications

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#future-incompat-report>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `frequency` |  | `"always"` / `"never"` | `"always"` | `CARGO_FUTURE_INCOMPAT_REPORT_FREQUENCY` |

---

## `[http]` — HTTP behavior

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#http>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `cainfo` |  | string (path) | none (system certificates) | `CARGO_HTTP_CAINFO` |
| `check-revoke` |  | boolean | `true` on Windows, `false` elsewhere | `CARGO_HTTP_CHECK_REVOKE` |
| `debug` |  | boolean | `false` | `CARGO_HTTP_DEBUG` |
| `low-speed-limit` |  | integer (bytes/sec) | `10` | `CARGO_HTTP_LOW_SPEED_LIMIT` |
| `multiplexing` |  | boolean | `true` | `CARGO_HTTP_MULTIPLEXING` |
| `proxy` |  | string (libcurl format) | none | `CARGO_HTTP_PROXY` / `HTTPS_PROXY` / `https_proxy` / `http_proxy` |
| `proxy-cainfo` |  | string (path) | falls back to `http.cainfo` | `CARGO_HTTP_PROXY_CAINFO` |
| `ssl-version` |  | string, or `[http.ssl-version]` with `min`/`max` | min `"tlsv1.0"`, max = platform newest | `CARGO_HTTP_SSL_VERSION` |
| `timeout` |  | integer (seconds) | `30` | `CARGO_HTTP_TIMEOUT` / `HTTP_TIMEOUT` |
| `user-agent` |  | string | cargo's version string | `CARGO_HTTP_USER_AGENT` |

Notes:

- `ssl-version` values: `default`, `tlsv1`, `tlsv1.0`, `tlsv1.1`, `tlsv1.2`, `tlsv1.3`.
- `low-speed-limit`: connection aborts if average speed stays below this for
  `http.timeout` seconds.
- `check-revoke` only works on Windows.
- `debug` output may contain auth tokens — review logs before sharing.

---

## `[install]` — defaults for `cargo install`

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#install>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `root` |  | string (path) | `$CARGO_HOME` | `CARGO_INSTALL_ROOT` |

Binaries go in `<root>/bin`; `.crates.toml`/`.crates2.json` are tracked there.
Overridable with `--root`.

---

## `[net]` — networking

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#net>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `git-fetch-with-cli` |  | boolean | `false` | `CARGO_NET_GIT_FETCH_WITH_CLI` |
| `offline` |  | boolean | `false` | `CARGO_NET_OFFLINE` |
| `retry` |  | integer | `3` | `CARGO_NET_RETRY` |
| `ssh.known-hosts` |  | array of strings | see below | not supported |

`git-fetch-with-cli = true` uses the `git` executable instead of the built-in
git library (useful for special auth setups). `known-hosts` entries are
OpenSSH `known_hosts`-style lines (`"host ssh-ed25519 AAAAC3..."`); cargo also
loads keys from OpenSSH locations and ships github.com's keys built in.

---

## `[patch.<registry>]` — dependency patching

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#patch>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `[patch.<registry>]` |  | same format as `[patch]` in `Cargo.toml` | none | — |

Applies to every build under this config. Prefer `[patch]` in `Cargo.toml`
(checked in) so other developers get the same build; config patches are for
externally generated overrides. Relative `path` deps resolve against the
config file they appear in.

---

## `[profile.<name>]` — global profile settings

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#profile> and
<https://doc.rust-lang.org/cargo/reference/profiles.html>

Same keys as profiles in `Cargo.toml`; config values override `Cargo.toml`.
`test` inherits `dev`; `bench` inherits `release`. Custom profiles must set `inherits`.

| Option | Your value | Type | dev default | release default | Env var |
| --- | --- | --- | --- | --- | --- |
| `codegen-units` |  | integer > 0 | `256` | `16` | `CARGO_PROFILE_<name>_CODEGEN_UNITS` |
| `debug` |  | integer / boolean / string | `true` (`"full"`) | `false` (`"none"`) | `CARGO_PROFILE_<name>_DEBUG` |
| `debug-assertions` |  | boolean | `true` | `false` | `CARGO_PROFILE_<name>_DEBUG_ASSERTIONS` |
| `incremental` |  | boolean | `true` | `false` | `CARGO_PROFILE_<name>_INCREMENTAL` |
| `inherits` |  | string | n/a (built-in) | n/a (built-in) | — |
| `lto` |  | boolean / string | `false` | `false` | `CARGO_PROFILE_<name>_LTO` |
| `opt-level` |  | integer / string | `0` | `3` | `CARGO_PROFILE_<name>_OPT_LEVEL` |
| `overflow-checks` |  | boolean | `true` | `false` | `CARGO_PROFILE_<name>_OVERFLOW_CHECKS` |
| `panic` |  | `"unwind"` / `"abort"` | `"unwind"` | `"unwind"` | `CARGO_PROFILE_<name>_PANIC` |
| `relocation-model` |  | `"pic"` / `"static"` / `"dynamic-nopic"` | rustc platform default | rustc platform default | — |
| `rpath` |  | boolean | `false` | `false` | `CARGO_PROFILE_<name>_RPATH` |
| `split-debuginfo` |  | string | platform-specific | platform-specific | `CARGO_PROFILE_<name>_SPLIT_DEBUGINFO` |
| `strip` |  | boolean / string | `"none"` | `"none"` | `CARGO_PROFILE_<name>_STRIP` |

Sub-tables (fill in per part as needed):

| Option | Your value | Notes |
| --- | --- | --- |
| `[profile.<name>.build-override]` |  | Same keys as a profile; applies to build scripts, proc macros, and their deps. Env: `CARGO_PROFILE_<name>_BUILD_OVERRIDE_<key>`. |
| `[profile.<name>.package.<name>]` |  | Same keys minus `panic`, `lto`, `rpath`; `<name>` is a package ID spec (e.g. `"foo:2.1.0"`), `"*"` matches all non-workspace members. |

Value notes: `debug` accepts `0`/`false`/`"none"`, `"line-directives-only"`,
`"line-tables-only"`, `1`/`"limited"`, `2`/`true`/`"full"`. `opt-level`
accepts `0`–`3`, `"s"`, `"z"`. `lto` accepts `false`, `"off"`, `"thin"`,
`true`/`"fat"`. `strip` accepts `true`/`"symbols"`, `false`/`"none"`,
`"debuginfo"`. `relocation-model` mirrors `rustc -C relocation-model`
(accepted by cargo; used by this repo's `rose-tokenizers` crate).

---

## `[registries.<name>]` — additional registries

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#registries>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `registries.<name>.credential-provider` |  | string or array (program + args) | none (falls back to global list) | `CARGO_REGISTRIES_<name>_CREDENTIAL_PROVIDER` |
| `registries.<name>.index` |  | string (URL) | none | `CARGO_REGISTRIES_<name>_INDEX` |
| `registries.<name>.token` |  | string | none — keep in `$CARGO_HOME/credentials.toml` | `CARGO_REGISTRIES_<name>_TOKEN` |
| `registries.crates-io.protocol` |  | `"sparse"` / `"git"` | `"sparse"` | `CARGO_REGISTRIES_CRATES_IO_PROTOCOL` |

`sparse` downloads only what's needed over HTTPS; `git` clones the full
crates.io index.

---

## `[registry]` — the default registry

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#registry>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `credential-provider` |  | string or array (program + args) | none (falls back to global list) | `CARGO_REGISTRY_CREDENTIAL_PROVIDER` |
| `default` |  | string (registry name) | `"crates-io"` | `CARGO_REGISTRY_DEFAULT` |
| `global-credential-providers` |  | array | `["cargo:token"]` | `CARGO_REGISTRY_GLOBAL_CREDENTIAL_PROVIDERS` |
| `index` |  | — | **do not use** — no longer accepted | — |
| `token` |  | string | none — keep in `$CARGO_HOME/credentials.toml` | `CARGO_REGISTRY_TOKEN` |

Later entries in `global-credential-providers` take precedence. A provider
named in `[credential-alias]` may be referenced by its alias.

---

## `[resolver]` — dependency resolution

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#resolver>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `incompatible-rust-versions` |  | `"allow"` / `"fallback"` | see resolver docs | `CARGO_RESOLVER_INCOMPATIBLE_RUST_VERSIONS` |
| `lockfile-path` |  | string (path, must end in `Cargo.lock`) | `<workspace_root>/Cargo.lock` | `CARGO_RESOLVER_LOCKFILE_PATH` |

`allow` treats `rust-version`-incompatible versions like any other;
`fallback` only considers them if nothing else matched (`fallback` respected
as of 1.84; `lockfile-path` requires 1.97+). Does not affect `cargo install`.

---

## `[source.<name>]` — source replacement

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#source>

Define exactly one kind per source. Env vars: not supported for any key.

| Option | Your value | Type | Default |
| --- | --- | --- | --- |
| `branch` |  | string | none (`"master"` if no branch/tag/rev given) |
| `directory` |  | string (path) | none |
| `git` |  | string (URL) | none |
| `local-registry` |  | string (path) | none |
| `registry` |  | string (URL) | none |
| `replace-with` |  | string (source or registry name) | none |
| `rev` |  | string | none (`"master"` if no branch/tag/rev given) |
| `tag` |  | string | none (`"master"` if no branch/tag/rev given) |

Typical shape:

```toml
[source.vendored-sources]
directory = "vendor"

[source.crates-io]
replace-with = "vendored-sources"
```

---

## `[target.*]` — per-target settings

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#target>

Each sub-table is a target triple (`target.x86_64-unknown-linux-gnu`) or a
`cfg()` expression (`target.'cfg(all(target_arch = "arm", target_os = "none"))'`).
Triple entries take precedence over `cfg()` entries when both match.

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `target.<triple\|cfg>.linker` |  | string (program path) | none | `CARGO_TARGET_<triple>_LINKER` |
| `target.<triple\|cfg>.runner` |  | string or array (program + args) | none (execute directly) | `CARGO_TARGET_<triple>_RUNNER` |
| `target.<triple\|cfg>.rustflags` |  | string or array of strings | none | `CARGO_TARGET_<triple>_RUSTFLAGS` |
| `target.<triple>.rustdocflags` |  | string or array of strings | none | `CARGO_TARGET_<triple>_RUSTDOCFLAGS` |

`rustdocflags` is triple-only (no `cfg()` form). `runner` applies to `cargo
run` / `cargo test` / `cargo bench`. `cfg()` matching uses built-in
`rustc --print=cfg` values plus extra `--cfg` flags — not `debug_assertions`,
`test`, features, or build-script cfgs.

`[target.<triple>.<links>]` overrides a build script (the script is not run;
these values are used instead):

| Option | Your value | Type |
| --- | --- | --- |
| `rustc-link-lib` |  | array of strings |
| `rustc-link-search` |  | array of strings |
| `rustc-flags` |  | string |
| `rustc-cfg` |  | array of strings |
| `rustc-env` |  | table of string = string |
| `rustc-cdylib-link-arg` |  | array of strings |
| `<metadata_key>` |  | string (arbitrary `DEP_<links>_<key>` metadata) |

---

## `[term]` — terminal output

Docs: <https://doc.rust-lang.org/cargo/reference/config.html#term>

| Option | Your value | Type | Default | Env var |
| --- | --- | --- | --- | --- |
| `color` |  | `"auto"` / `"always"` / `"never"` | `"auto"` | `CARGO_TERM_COLOR` |
| `hyperlinks` |  | boolean | auto-detect | `CARGO_TERM_HYPERLINKS` |
| `progress.term-integration` |  | boolean | auto-detect | `CARGO_TERM_PROGRESS_TERM_INTEGRATION` |
| `progress.when` |  | `"auto"` / `"always"` / `"never"` | `"auto"` | `CARGO_TERM_PROGRESS_WHEN` |
| `progress.width` |  | integer | none (automatic) | `CARGO_TERM_PROGRESS_WIDTH` |
| `quiet` |  | boolean | `false` | `CARGO_TERM_QUIET` |
| `unicode` |  | boolean | auto-detect | `CARGO_TERM_UNICODE` |
| `verbose` |  | boolean | `false` | `CARGO_TERM_VERBOSE` |

`--quiet`/`--verbose`/`--color` CLI flags override the corresponding keys.

---

## `[unstable]` — nightly-only flags

Docs: <https://doc.rust-lang.org/cargo/reference/unstable.html>

| Option | Your value | Notes |
| --- | --- | --- |
| `[unstable]` |  | Table of nightly feature flags, e.g. `[unstable]` + `<flag> = true`. Setting any key here on **stable** cargo is an error. See the unstable chapter for the current list — it changes between nightlies, so it is not enumerated here. |
