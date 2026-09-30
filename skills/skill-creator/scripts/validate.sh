#!/usr/bin/env bash
# validate.sh — Matt's full skill-validation gates for one skill directory.
#
# Runs, in order:
#   1. skills-ref validate      (structural gate, official reference)
#   2. skill-validator          (quality gate — zero warnings tolerated)
#   3. Manual checks neither gate fully owns:
#      - directory name == frontmatter `name`
#      - frontmatter parses as YAML
#      - every relative markdown reference resolves to a real file
#      - bundled scripts pass syntax checks (bash -n / python3 -m py_compile)
#      - `git diff --check` clean (when inside a git repo)
#
# Usage: validate.sh /path/to/skill-name
# Env overrides: SKILLS_REF, SKILL_VALIDATOR (paths or PATH names)

set -euo pipefail

skill="${1:?usage: validate.sh /path/to/skill-dir}"
skill="$(cd "$skill" && pwd)"
fail=0

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'FAIL: %s\n' "$*" >&2; fail=1; }

# $1 = explicit path or bare name, $2 = default absolute path, $3 = PATH name
find_bin() {
    local explicit="$1" default_path="$2" path_name="$3"
    if [ -n "$explicit" ] && [ -x "$explicit" ]; then printf '%s' "$explicit"; return 0; fi
    if [ -x "$default_path" ]; then printf '%s' "$default_path"; return 0; fi
    if command -v "$path_name" >/dev/null 2>&1; then command -v "$path_name"; return 0; fi
    return 1
}

# 1+2: the two validators (skipped with a warning when not installed)
if ref="$(find_bin "${SKILLS_REF:-}" /home/phaedrus/.local/bin/skills-ref skills-ref)"; then
    say "== skills-ref =="
    "$ref" validate "$skill" || die "skills-ref reported errors"
else
    warn "skills-ref not found — structural gate skipped"
fi

if val="$(find_bin "${SKILL_VALIDATOR:-}" /home/phaedrus/go/bin/skill-validator skill-validator)"; then
    say "== skill-validator =="
    "$val" "$skill" || die "skill-validator reported errors/warnings"
else
    warn "skill-validator not found — quality gate skipped"
fi

# 3a: name == dir (first --- block only, so body rules can't confuse it)
say "== name == dir =="
front_name="$(awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$skill/SKILL.md" \
    | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')"
if [ "${front_name:-}" = "$(basename "$skill")" ]; then
    say "ok: name '${front_name}' matches directory"
else
    die "frontmatter name '${front_name:-<missing>}' != directory '$(basename "$skill")'"
fi

# 3b: frontmatter parses as YAML
say "== frontmatter YAML =="
if python3 - "$skill/SKILL.md" <<'PYEOF' >/dev/null 2>&1
import sys, yaml
text = open(sys.argv[1]).read()
yaml.safe_load(text.split('---')[1])
PYEOF
then
    say "ok: frontmatter parses"
else
    die "frontmatter does not parse as YAML"
fi

# 3c: relative markdown references resolve
say "== relative references =="
missing=0
while IFS= read -r ref; do
    ref="${ref%%#*}"  # strip anchors
    case "$ref" in ""|http://*|https://*|mailto:*|/*) continue;; esac
    if [ ! -e "$skill/$ref" ]; then
        warn "dangling reference: $ref"; missing=1
    fi
done < <(grep -oE '\]\([^)]+\)' "$skill/SKILL.md" | sed 's/^](//; s/)$//' | sort -u)
if [ "$missing" -eq 0 ]; then say "ok: all relative references resolve"; else die "dangling references found"; fi

# 3d: bundled script syntax checks
say "== script syntax =="
if [ -d "$skill/scripts" ]; then
    while IFS= read -r -d '' f; do
        case "$f" in
            *.sh) bash -n "$f" && say "ok: $f" || die "syntax error: $f";;
            *.py) python3 -m py_compile "$f" && say "ok: $f" || die "syntax error: $f";;
            *)    warn "no syntax check for: $f";;
        esac
    done < <(find "$skill/scripts" -type d -name __pycache__ -prune -o -type f -print0)
    # py_compile leaves __pycache__ in the tree — never ship it
    find "$skill/scripts" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null
else
    say "(no scripts/ dir)"
fi

# 3e: git diff --check when inside a repo
if git -C "$skill" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    say "== git diff --check =="
    git -C "$skill" diff --check || die "whitespace errors in diff"
fi

if [ "$fail" -eq 0 ]; then say "ALL GATES PASS"; else printf 'GATES FAILED\n' >&2; fi
exit "$fail"
