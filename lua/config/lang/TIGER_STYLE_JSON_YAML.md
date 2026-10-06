# Tiger Style for JSON and YAML

**Safety > performance > developer experience.**

A practical standard for JSON and YAML data files, configuration, and
schemas on Arch Linux. Written for the Diver language documentation
directory. This is an independent interpretation of
[TigerBeetle's Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md),
not an official TigerBeetle, ECMA, or YAML specification document.

| Policy | Baseline |
| --- | --- |
| JSON | RFC 8259; UTF-8; no comments, no trailing commas |
| YAML | YAML 1.2 core schema; block style preferred |
| Schema language | JSON Schema 2020-12 for both formats |
| Formatting | Prettier for JSON; `yamlfmt` or Prettier for YAML; two-space indent |
| File size | Review config files above 500 physical lines |
| Primary platform | Arch Linux; parser claims require tested parser versions |
| Document reviewed | 2026-10-06 |

JSON and YAML are the two formats most likely to carry secrets, credentials,
and privilege decisions into a system — and the two most likely to be parsed
carelessly. YAML's expressive power (anchors, merge keys, custom tags) is
also its attack surface: billion-laughs expansion, deserialization gadgets,
and type-confusion surprises. JSON's simplicity is safer but not safe:
duplicate keys, deep nesting, and oversized numbers all need explicit policy.
Treat every parsed document as untrusted input until validated against a
schema.

## Contents

- [1. Engineering contract](#1-engineering-contract)
- [2. Toolchain and build trust](#2-toolchain-and-build-trust)
- [3. Structure and naming](#3-structure-and-naming)
- [4. Types and state](#4-types-and-state)
- [5. Contracts and errors](#5-contracts-and-errors)
- [6. Bounds and arithmetic](#6-bounds-and-arithmetic)
- [7. Ownership and memory](#7-ownership-and-memory)
- [8. Control flow and concurrency](#8-control-flow-and-concurrency)
- [9. Unsafe code and foreign interfaces](#9-unsafe-code-and-foreign-interfaces)
- [10. Operating-system boundaries](#10-operating-system-boundaries)
- [11. Performance and reproducibility](#11-performance-and-reproducibility)
- [12. Tests and review gates](#12-tests-and-review-gates)
- [13. Complete reference module](#13-complete-reference-module)
- [14. Neovim integration](#14-neovim-integration)

## 1. Engineering contract

Correctness comes before speed. Speed comes before convenience when the tradeoff is real.
Measure that tradeoff; do not use the priority order to justify speculative complexity.

Every JSON or YAML document consumed by a system must identify:

1. Accepted inputs, rejected inputs, and the trust boundary. A config file
   written by the operator is trusted differently from a webhook payload.
2. Maximum document bytes, nesting depth, and decoded expansion factor.
3. The owner of the schema: who may add fields, who reviews changes.
4. The point at which parsed data influences behavior (config load,
   request handling, credential use).
5. Failure behavior: what happens when parsing fails, validation fails,
   or a required field is absent. Fail closed for security-relevant config.
6. The evidence supporting the result: schema validation output, parser
   version, or a test fixture.

Use this rule for exceptions: name the rule, explain the need, bound the
resulting risk, and record a test or review condition. An exception belongs
near the affected document or in its design record. Blanket waivers are
difficult to maintain.

Choose the format deliberately:

| Use JSON when | Use YAML when |
| --- | --- |
| Machine-to-machine data exchange | Human-authored configuration |
| Strict schema enforcement matters | Comments and readability matter |
| The consumer is a browser or API client | The consumer is an operator or deploy pipeline |
| Duplicate keys must be rejected loudly | Anchors reduce repetition without templating |

Do not use JSON5, HJSON, or other JSON supersets for interchange — they
are not JSON, parsers disagree on the extensions, and "JSON with comments"
becomes a compatibility trap. If comments are needed, that is the signal
to use YAML.

## 2. Toolchain and build trust

Pin parser and validator versions in the project. YAML parsers differ
meaningfully: PyYAML, ruamel.yaml, go-yaml, and serde_yaml disagree on
edge cases (duplicate keys, merge-key semantics, timestamp parsing).
Record the exact parser and version with the document that depends on it.

A minimal toolchain declaration:

```json
{
  "devDependencies": {
    "prettier": "3.3.3",
    "ajv-cli": "5.0.0"
  }
}
```

```toml
# requirements-dev.txt (pip) — pin the YAML parser.
pyyaml==6.0.2
jsonschema==4.23.0
```

Treat schema files as code: they are reviewed, versioned, and tested like
code. A schema change is a contract change — it needs the same review as
an API change, because every producer and consumer is affected.

Never parse YAML with an unsafe loader. In Python, `yaml.load()` without
an explicit `Loader` is arbitrary code execution; the safe baseline is
`yaml.safe_load()`. In Ruby, `YAML.load` has the same history — use
`YAML.safe_load`. In Go, be aware that `gopkg.in/yaml.v3` unmarshals into
`interface{}` with surprising type coercions; prefer typed structs. Audit
every YAML parsing call site for its loader choice; the default is
frequently the dangerous one.

Keep generated JSON/YAML distinct from authored files. Generated files
live in a build directory, are gitignored, and are never hand-edited.
Regenerate from source rather than patching output.

## 3. Structure and naming

Top-level structure is a contract. Prefer a single top-level object
(mapping) over a bare array or scalar — it gives the schema a stable
anchor for versioning and extension:

```yaml
# Good: versioned, extensible.
version: 1
server:
  host: "127.0.0.1"
  port: 8080
```

```yaml
# Bad: no place to put a version or new top-level concerns.
- host: "127.0.0.1"
  port: 8080
```

Name keys in `snake_case`. Be consistent within a document and across a
project's documents — `max_connections` in one file and `maxConnections`
in another is a defect, not a style choice. Document the naming convention
in the schema's `description` fields.

Order keys logically and keep that order stable: identity and version
first, then required operational fields, then optional tuning. Within
YAML, key order is preserved by most parsers and matters to human
readers; within JSON, do not depend on key order — the specification
declares objects unordered, and some parsers will not preserve it.

Use block style in YAML, not flow style, for anything a human will read
or review. Flow style (`{a: 1, b: [2, 3]}`) is JSON wearing a YAML
costume; it sacrifices the readability that justified YAML in the first
place. Reserve flow style for compact machine-generated fragments.

Quote strings that the YAML core schema might misinterpret. The classic
traps:

```yaml
# All of these are NOT strings under common schemas:
version: 1.10        # float 1.1, not "1.10"
enabled: yes         # boolean true under YAML 1.1
port: 080           # invalid octal / string "080" depending on parser
id: 2026-10-06      # timestamp, not a string
```

The rule: if a scalar looks like a number, boolean, null, or timestamp
but means a string, quote it. When in doubt, quote it — quoted strings
are never misinterpreted, unquoted ones frequently are.

Comments explain why a value is what it is, not what the key means —
the schema documents the key. `port: 8080  # IANA unassigned, avoids
privileged-port requirement` records a decision. `port: 8080  # the port`
narrates the obvious.

> **In plain terms:** YAML's implicit typing is a helpful feature with a dark side: unquoted `yes` becomes boolean `true`, `1.10` becomes a float, and `2026-10-06` becomes a timestamp object — the parser is guessing your intent, and sometimes it guesses wrong in ways that change program behavior. The rule is simple and slightly paranoid: quote any scalar that isn't obviously meant to be a number or boolean. Paranoia is cheap; debugging a boolean that used to be a country code is not.


## 4. Types and state

JSON has six value kinds: object, array, string, number, boolean, null.
YAML 1.2 core schema resolves scalars to a similar set, plus timestamps
and binary. Every value that crosses a trust boundary needs a declared
type in the schema — "it's probably a string" is not a contract.

Distinguish these states explicitly in schemas:

| State | Representation | Policy |
| --- | --- | --- |
| Absent | Key missing | Allowed only if the schema marks it optional |
| Null | Explicit `null` | Allowed only if the schema type includes `null` |
| Empty | `""`, `[]`, `{}` | Valid values, not substitutes for absent |
| Zero/false | `0`, `false` | Valid values; never treat as missing |

The conflation bugs live here: code that treats `""`, `null`, and absent
as interchangeable will misbehave exactly when the distinction matters
— an absent `tls` section (use defaults) versus `"tls": null` (explicitly
disabled) versus `"tls": {}` (enabled with defaults) are three different
security postures.

Numbers need bounds and meaning. JSON numbers are arbitrary precision in
the specification but become IEEE-754 doubles in most parsers — integers
above 2^53 lose precision silently. For identifiers, money, and anything
compared for equality, use strings. Declare `minimum`, `maximum`, and
whether floats are accepted in the schema.

Timestamps: declare the format (`date-time` per RFC 3339), the timezone
rule (UTC required, `Z` suffix), and reject everything else. YAML's
implicit timestamp parsing is a recurring source of type confusion —
`2026-10-06` becoming a date object when the consumer expected a string
has caused real outages. Quote it or type it explicitly.

Enums beat free strings for any field that drives behavior. `mode:
"active"` with `"enum": ["active", "passive"]` in the schema rejects
`"Active"`, `"ACTIVe"`, and `" act ive"` at validation time instead of
silently falling through to a default at runtime.

> **In plain terms:** Fail-closed config loading means a missing, malformed, or suspicious config stops the program instead of letting it limp along on defaults that might be insecure. It feels hostile during development — "why won't it just start?" — but the alternative is a service running with an empty allow-list or a disabled auth check because someone fat-fingered the YAML. Loud failure at startup beats silent insecurity at 3 AM.


## 5. Contracts and errors

Validate every document against its schema at the trust boundary, before
the data influences behavior. Validation is not optional for untrusted
input and not redundant for trusted config — operators make mistakes,
and a schema catches them before the mistake becomes an incident.

```python
# Validate-then-use. The parsed document is not trusted until this returns.
import json, jsonschema

with open("config.json", "rb") as f:
    raw = f.read(MAX_CONFIG_BYTES + 1)
if len(raw) > MAX_CONFIG_BYTES:
    raise ConfigError(f"config exceeds {MAX_CONFIG_BYTES} bytes")
doc = json.loads(raw)  # may raise json.JSONDecodeError -> ConfigError
jsonschema.validate(doc, SCHEMA)  # raises ValidationError on mismatch
apply_config(doc)
```

| Situation | Preferred response |
| --- | --- |
| Malformed syntax | Reject with line/column; never attempt repair |
| Schema violation | Reject with the failing path and constraint |
| Unknown fields | Reject by default (`additionalProperties: false`); allowlist additions |
| Missing required field | Reject; do not substitute silent defaults for security fields |
| Duplicate keys (JSON) | Reject — parsers disagree on winner; ambiguity is a defect |
| Type coercion surprise | Reject; do not accept `"8080"` where `8080` is declared |

Fail closed. A config that fails validation must not start the service
with partial or default configuration — especially for TLS, auth, and
network bindings. The safe failure is a loud refusal to start, not a
quiet run with insecure defaults.

Error messages name the document, the path (`$.server.port`), the
constraint violated, and the offending value's type — never the full
offending value when it might contain secrets. `$.database.password:
expected string, got object` is correct. Echoing the value is a leak.

Distinguish parse errors from validation errors in logs and exit codes.
A parse error means the document is not even the right format; a
validation error means it is well-formed but violates the contract. The
remediation differs, so the signal must differ.

> **In plain terms:** The billion-laughs attack is YAML's party trick: nine lines of nested entity definitions that expand to gigabytes when parsed, because each level multiplies the last exponentially. It's the data-format equivalent of a fork bomb, and the defense is equally unglamorous — cap document size, cap nesting depth, and cap the ratio of parsed output to raw input before the parser ever sees hostile bytes.


## 6. Bounds and arithmetic

Name resource limits with units. The reference limits below are starting
points; choose from the actual workload.

| Resource | Required contract |
| --- | --- |
| Document bytes | Maximum raw size; reject before parsing |
| Nesting depth | Maximum object/array depth (YAML anchors can hide depth) |
| Decoded expansion | Maximum ratio of parsed size to raw bytes (billion-laughs defense) |
| Collection length | Maximum array items and object keys |
| String length | Maximum scalar length, especially for logged or displayed values |
| Number magnitude | Reject integers beyond 2^53 unless the consumer handles big integers |

The billion-laughs attack is the canonical YAML bomb:

```yaml
# DO NOT USE. 9 levels of doubling -> ~1GB from ~500 bytes.
a: &a ["x","x","x","x","x","x","x","x","x"]
b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a]
c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b]
# ... six more levels
```

Defenses, in order: bound raw document bytes first (cheap), bound
nesting depth during parsing, and bound total anchor expansions where
the parser supports it (PyYAML does not natively — this is a reason to
prefer ruamel.yaml or to pre-scan). A parser without expansion limits
must only see size-bounded, trusted documents.

For JSON numbers that become doubles, decide the policy explicitly:
reject non-integers where integers are declared (`"type": "integer"` in
JSON Schema does this), reject infinities and NaN (not valid JSON —
a parser that accepts them is non-conformant; treat acceptance as a
defect), and use strings for identifiers.

Bound retry and timeout values found in config. A `retry_count: 999999`
or `timeout_ms: 0` in a config file is either a mistake or an attack;
the schema should bound them (`minimum`, `maximum`) so the mistake is
caught at load time.

## 7. Ownership and memory

Every config value has one writer and a documented precedence. When
multiple sources contribute (file, environment, CLI flags, defaults),
the merge order is a contract, stated once, in one place:

```yaml
# Precedence, highest to lowest. Documented in the schema's $comment.
# 1. CLI flags
# 2. Environment variables (APP_*)
# 3. Config file
# 4. Built-in defaults
```

Deep-merge semantics must be explicit: does an environment override
replace a whole subsection or merge into it? Whole-section replacement
is simpler to reason about; deep merge is friendlier but produces
surprising results when a nested key is meant to be removed. Choose one
and document it. There is no way to "remove" a key with deep merge
unless the format defines one (JSON Merge Patch's `null` convention).

Secrets have a lifecycle: loaded, used, and never written back. Rules:

- Secrets arrive via environment or a secrets manager, never in the
  config file committed to version control.
- Parsed secrets are held in memory only as long as needed; do not log
  them, do not include them in error messages, do not serialize the
  config back to disk with secrets included.
- Config files have restrictive permissions (`0600`) when they must
  contain secrets; prefer `0600` by default for any config with
  credentials adjacent.
- Scan committed files for secrets in CI (gitleaks, trufflehog). A
  committed secret is compromised — rotate it, do not just delete it
  from the file; git history remembers.

YAML anchors are aliases, not copies. An anchored mapping reused in ten
places is one object referenced ten times — mutating through one
reference affects all of them in languages where the parser preserves
aliasing. Know whether your parser materializes shared references or
deep copies; the difference determines whether a "template" section can
be safely specialized per use.

## 8. Control flow and concurrency

JSON and YAML have no control flow — and that is a feature to protect.
The moment a config format gains conditionals, loops, or templating, it
stops being data and becomes code, with code's attack surface and review
burden. Resist adding Jinja, ERB, or shell interpolation to YAML configs.

If templating is genuinely required, isolate it: one explicit
preprocessing step, with its own documented syntax, operating on the raw
text before parsing — never string interpolation after parsing, which
produces syntactically valid but semantically surprising documents.
And bound the template's power: variable substitution is data; loops and
conditionals are logic that belongs in the application.

Merge keys (`<<: *anchor`) deserve special attention. The YAML merge
specification is subtle — later keys override earlier ones, but the
interaction with nested merges and multiple merge sources varies by
parser. Prefer explicit repetition over clever merges for
security-relevant config; a reviewer should see the effective value
without simulating parser-specific merge semantics in their head.

When multiple documents or files compose one configuration (base +
environment overlays), the composition order and conflict resolution are
part of the contract. Later files override earlier ones, key by key, with
no deep merge unless stated. Test the composed result, not just each
file in isolation — the bug lives in the interaction.

Concurrent writers to a config file need atomicity: write to a temporary
file in the same directory, fsync, then rename. Readers that parse a
half-written file get syntax errors at best and silently truncated data
at worst. For hot-reload, validate the new document fully before
swapping it into the running configuration; a failed reload keeps the
old valid config, it never leaves the service half-configured.

> **In plain terms:** Some YAML parsers will happily instantiate arbitrary objects from tags like `!ruby/object` — which means a config file can become a remote-code-execution payload the moment it's parsed. This isn't a theoretical concern; it's a CVE with a body count. `safe_load` exists precisely to draw the line: plain data structures only, no object construction, no exceptions. If your parser offers anything fancier, that's not a feature, it's a liability.


## 9. Unsafe code and foreign interfaces

In data formats, "unsafe" means parser features that execute code or
exhaust resources. The inventory, by severity:

| Feature | Risk | Policy |
| --- | --- | --- |
| YAML custom tags (`!ruby/object`) | Arbitrary object deserialization → RCE | Forbidden. `safe_load` only |
| YAML anchors + aliases | Billion-laughs expansion → DoS | Bound; see section 6 |
| YAML merge keys (`<<`) | Parser-dependent semantics | Avoid in security config |
| Duplicate JSON keys | Parser-dependent winner | Reject at parse or schema level |
| JSON numbers > 2^53 | Silent precision loss | Use strings for identifiers |
| Implicit YAML typing | `"yes"` → `true`, dates → objects | Quote ambiguous scalars |
| External refs (`$ref` to URL) | SSRF during validation | Only local refs; no network fetch |

Custom YAML tags are the deserialization gadget vector. `!ruby/object:OpenStruct`,
`!python/object/apply:os.system`, and their cousins in other languages turn
"parse this config file" into "run this command". The defense is absolute:
only allowlisted tags, which in practice means the safe schema's tags
(strings, numbers, booleans, null, sequences, mappings, timestamps). Any
code path that parses YAML with a full loader needs a named justification
and a review — the same exception rule as section 1.

JSON Schema `$ref` resolution is a foreign interface: a `$ref` pointing
at a URL makes the validator perform a network fetch, which is SSRF when
the schema or document is attacker-influenced. Resolve refs locally from
a pinned schema directory; disable remote ref fetching in the validator.

Treat schema registries and remote base URIs like any other dependency:
pinned, reviewed, and vendored where the validation must work offline.
A validator that silently skips unresolvable refs is misconfigured —
unresolvable means unvalidatable, which means reject.

## 10. Operating-system boundaries

Config files live on filesystems, and filesystems have permissions,
races, and symlinks. The contracts:

- Create config files with restrictive permissions from the start
  (`0600` for secrets-adjacent, `0640` at most for shared operational
  config). Fixing permissions after creation leaves an exposure window.
- Never follow symlinks when resolving config paths unless the symlink
  policy is explicit and reviewed. A config path influenced by user
  input plus symlink following is arbitrary file read.
- Validate environment-derived paths (`$CONFIG_DIR`, `$HOME`) before
  use: reject empty values, reject relative paths that escape the
  expected root, canonicalize and re-check containment.
- Keep configuration, state, and cache in separate directories with
  separate permissions. A writable cache directory is not a safe place
  for a config file.

Atomic writes are the commit protocol: temporary file in the destination
directory, write, fsync the file, rename over the target, fsync the
directory. Crash during write leaves either the old or the new config,
never a truncated hybrid. This applies to programmatic config updates
and to deployment tooling alike.

Log config load events (path, version, validation result) but never log
values. A debug log line containing the parsed config is a secret leak
with a timestamp. Structure logs so that secret fields are redacted by
construction — separate the secret-bearing struct from the loggable
struct, or redact at the serialization boundary.

## 11. Performance and reproducibility

Establish correct parsing before tuning. Measure with representative
documents: the largest real config, the deepest real nesting, the
payload with the most anchors. Report parse time percentiles, peak
memory during parse, and validation time separately — schema validation
can dominate for large documents with complex subschemas.

The dominant costs:

1. **Validation complexity.** JSON Schema constructs like `anyOf` with
   overlapping branches, unbounded `patternProperties`, and deeply
   nested `allOf` can make validation superlinear. Keep schemas flat
   where possible; test validation time against adversarial documents,
   not just happy-path fixtures.
2. **Anchor expansion.** See section 6 — a small document can decode to
   gigabytes. Bound before parsing, not after.
3. **Repeated parsing.** Config parsed on every request instead of once
   at startup is a performance bug and a consistency bug (the file can
   change between parses). Parse once, validate once, share the
   immutable result.

Reproducibility means byte-stable serialization: sorted keys, fixed
indentation, no trailing whitespace, LF line endings, and no timestamps
unless the document is explicitly versioned. Canonical JSON (sorted
keys, no insignificant whitespace) is required when documents are
hashed, signed, or diffed. Two serializations of the same logical
document must be byte-identical, or signatures and caches break.

Prefer streaming parsers (or iterative decoding) for documents whose
size is not bounded below available memory. A DOM-style parse of a
500MB JSON log into a single object graph is an allocation failure
waiting for a production incident.

## 12. Tests and review gates

Test the contract, not the formatting. Valuable data-file tests:

- Schema validation passes on the shipped example configs.
- Schema validation rejects: wrong types, missing required fields,
  unknown fields, out-of-range numbers, duplicate JSON keys,
  billion-laughs YAML, custom-tag YAML.
- Parser-behavior tests: the document parses identically on the pinned
  parser version; quoted scalars stay strings; timestamps parse as
  declared.
- Secret tests: example configs contain no real secrets; CI secret
  scanning passes; error messages contain no secret values.
- Round-trip tests: parse → serialize → parse yields an equal document
  (catches precision loss and type coercion).
- Adversarial fixtures: deeply nested input, oversized input, null
  bytes in strings, Unicode normalization surprises in keys.

Typical gates for a reviewed JSON/YAML change:

```sh
# Format check
npx prettier --check "**/*.{json,yaml,yml}"
# Schema validation (ajv for JSON Schema)
npx ajv-cli validate -s schema.json -d config.json --strict
# YAML parse + safe-load check
python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" config.yaml
# Secret scan
gitleaks detect --source . --no-git
# OpenAPI-specific
npx vacuum lint openapi.yaml
```

A passing formatter is not a passing schema validation. A passing schema
validation is not a secret scan. A passing secret scan does not establish
that the parser handles adversarial input safely. Report each kind of
evidence accurately.

Review checklist for every JSON/YAML change:

- [ ] Schema updated and validated against all example documents.
- [ ] No secrets, credentials, or tokens in the committed file.
- [ ] Ambiguous YAML scalars are quoted; types are explicit.
- [ ] Numeric bounds (`minimum`/`maximum`) declared for behavioral fields.
- [ ] `additionalProperties: false` (or explicit allowlist) on objects.
- [ ] Anchors and merge keys bounded and reviewed; no custom tags.
- [ ] File permissions restrictive where secrets are adjacent.
- [ ] Change tested against the pinned parser version.

## 13. Complete reference module

Save the schema fence as `service-config.schema.json` and the document
fence as `service-config.yaml`. Together they demonstrate versioned
structure, explicit types, bounded numbers, quoted ambiguous scalars,
no custom tags, and secrets kept out of the file.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://example.com/schemas/service-config/v1",
  "title": "Service configuration, version 1",
  "type": "object",
  "additionalProperties": false,
  "required": ["version", "server", "logging"],
  "properties": {
    "version": { "const": 1, "description": "Schema version. Bump on breaking change." },
    "server": {
      "type": "object",
      "additionalProperties": false,
      "required": ["host", "port"],
      "properties": {
        "host": { "type": "string", "minLength": 1, "maxLength": 253 },
        "port": { "type": "integer", "minimum": 1, "maximum": 65535 },
        "tls": {
          "type": "object",
          "additionalProperties": false,
          "required": ["cert_file", "key_file"],
          "properties": {
            "cert_file": { "type": "string", "minLength": 1 },
            "key_file": { "type": "string", "minLength": 1 }
          }
        }
      }
    },
    "logging": {
      "type": "object",
      "additionalProperties": false,
      "required": ["level"],
      "properties": {
        "level": { "enum": ["debug", "info", "warn", "error"] }
      }
    },
    "limits": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "max_request_bytes": { "type": "integer", "minimum": 1024, "maximum": 104857600 },
        "request_timeout_ms": { "type": "integer", "minimum": 100, "maximum": 300000 }
      }
    }
  }
}
```

```yaml
# service-config.yaml — validated against service-config.schema.json.
# Secrets come from the environment (APP_DB_PASSWORD), never from this file.
version: 1
server:
  host: "127.0.0.1"
  port: 8080
  tls:
    cert_file: "/etc/service/tls/cert.pem"
    key_file: "/etc/service/tls/key.pem"
logging:
  level: "info"
limits:
  max_request_bytes: 1048576
  request_timeout_ms: 5000
```

And the loader that enforces the contract — bounded read, safe parse,
schema validation, fail-closed:

```python
"""config_loader.py — bounded, validated config loading. Requires jsonschema and pyyaml."""
from __future__ import annotations

import json
import os
import stat

import jsonschema
import yaml

MAX_CONFIG_BYTES = 1 << 20  # 1 MiB raw document cap.
MAX_NESTING_DEPTH = 32


class ConfigError(Exception):
    """Config failed to load or validate. Never carries secret values."""


def _check_permissions(path: str) -> None:
    mode = os.stat(path).st_mode
    if mode & (stat.S_IRWXG | stat.S_IRWXO):
        raise ConfigError(f"config file {path} is group/world-accessible")


def _check_depth(node, depth: int = 0) -> None:
    if depth > MAX_NESTING_DEPTH:
        raise ConfigError("config exceeds maximum nesting depth")
    if isinstance(node, dict):
        for v in node.values():
            _check_depth(v, depth + 1)
    elif isinstance(node, list):
        for v in node:
            _check_depth(v, depth + 1)


def load_config(path: str, schema: dict) -> dict:
    """Load, bound, parse, and validate a YAML config file. Fail closed."""
    _check_permissions(path)
    with open(path, "rb") as f:
        raw = f.read(MAX_CONFIG_BYTES + 1)
    if len(raw) > MAX_CONFIG_BYTES:
        raise ConfigError(f"config exceeds {MAX_CONFIG_BYTES} bytes")
    try:
        # safe_load: no custom tags, no object deserialization. Ever.
        doc = yaml.safe_load(raw)
    except yaml.YAMLError as e:
        raise ConfigError(f"config parse failed: {type(e).__name__}") from e
    if not isinstance(doc, dict):
        raise ConfigError("config top level must be a mapping")
    _check_depth(doc)
    try:
        jsonschema.validate(doc, schema)
    except jsonschema.ValidationError as e:
        # Path and constraint only; never echo values (may be secrets).
        raise ConfigError(
            f"config invalid at {list(e.absolute_path)}: {e.validator}"
        ) from e
    return doc


# Adversarial checks (run with pytest):
def test_rejects_custom_tags(tmp_path):
    p = tmp_path / "evil.yaml"
    p.write_text("x: !!python/object/apply:os.system ['id']\n")
    try:
        load_config(str(p), {"type": "object"})
    except ConfigError:
        return
    raise AssertionError("custom tag was not rejected")


def test_rejects_oversize(tmp_path):
    p = tmp_path / "big.yaml"
    p.write_bytes(b"x: " + b"y" * (MAX_CONFIG_BYTES + 1))
    try:
        load_config(str(p), {"type": "object"})
    except ConfigError:
        return
    raise AssertionError("oversize document was not rejected")
```

Validation for the reference:

```sh
# YAML is valid and safe-loads:
python3 -c "import yaml; print(yaml.safe_load(open('service-config.yaml')))"
# JSON Schema validates the equivalent JSON:
python3 -c "
import json, yaml, jsonschema
schema = json.load(open('service-config.schema.json'))
doc = yaml.safe_load(open('service-config.yaml'))
jsonschema.validate(doc, schema)
print('schema OK')
"
# No secrets committed:
gitleaks detect --source . --no-git
```

## 14. Neovim integration

Place this document at `lua/config/lang/TIGER_STYLE_JSON_YAML.md` in
Diver. Markdown is reference material; do not `require()` it from
`init.lua`. Your JSON/YAML language configuration, LSP definitions,
lint runner, and formatter remain their own Lua modules.

Recommended tooling, consistent across editor and CI:

| Role | Tool | Notes |
| --- | --- | --- |
| JSON language server | `jsonls` (vscode-json-languageserver) | Schema-aware completion, validation |
| YAML language server | `yamlls` (yaml-language-server) | Schema store, validation, hover |
| Formatter | Prettier | JSON and YAML; two-space indent |
| JSON Schema validation | `ajv-cli` | `--strict` mode in CI |
| OpenAPI lint | `vacuum` | Replaces spectral; no network calls |
| Secret scan | `gitleaks` | Pre-commit hook and CI |

Configure `jsonls` and `yamlls` with the project's schemas, not just
the public schema store. A `.vscode/settings.json` or editor config
that maps `service-config.yaml` to the local schema file gives
completion and inline validation while editing:

```json
{
  "yaml.schemas": {
    "./schemas/service-config.schema.json": "service-config.yaml"
  }
}
```

Keep one owner for format-on-save and avoid duplicate validation
runners. Compare the editor's Prettier version with the project's
pinned version before changing diagnostics to conceal a mismatch.

When a schema changes, the editor should surface validation errors
immediately — this is the cheapest review gate available. Treat a red
squiggle on a config file with the same seriousness as a compiler
error: the document is making a claim the contract rejects.

Make project execution deliberate: workspace trust gates schema
downloads, remote `$ref` resolution, and local preview servers.
Read-only browsing and editing should remain possible before trust.

**Maintenance:** review this guide whenever the pinned parser versions
change, a new config format is adopted, the schema versioning policy
changes, or a new deserialization CVE affects the toolchain. Keep the
rule and the evidence together. Remove obsolete workarounds when their
underlying constraint disappears.
