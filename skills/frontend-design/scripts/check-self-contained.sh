#!/usr/bin/env bash
# check-self-contained.sh — verify a single-file HTML artifact is truly
# self-contained and phone-sane, per the frontend-design skill.
#
# Hard checks (exit 1 on failure):
#   1. No external fetches: no http(s):// in src=/href=/@import/url()
#      (the skill forbids CDN and webfont fetches — the artifact must open
#      offline from a zip or email attachment)
#   2. <meta name="viewport"> present (phone-first readability)
#
# Advisory (warning only):
#   3. :hover selectors get flagged — confirm nothing depends on hover
#      alone (phones don't hover)
#
# Usage: check-self-contained.sh artifact.html

set -euo pipefail
file="${1:?usage: check-self-contained.sh artifact.html}"
fail=0
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'FAIL: %s\n' "$*" >&2; fail=1; }

[ -f "$file" ] || { die "not a file: $file"; exit 1; }

# 1: external fetches in resource attributes / CSS imports
if grep -n -iE '(src|href)[[:space:]]*=[[:space:]]*"https?://' "$file" \
    | grep -v '<!--' ; then
    die "external URL fetch in src/href (artifact must be self-contained)"
else
    printf 'ok: no external fetches in src/href\n'
fi
if grep -n -iE '@import[[:space:]]+("?)https?://|url\([[:space:]]*("?)https?://' "$file" \
    | grep -v '<!--'; then
    die "external URL fetch in CSS @import/url()"
else
    printf 'ok: no external fetches in CSS\n'
fi

# 2: viewport meta
if grep -qi '<meta[^>]*name="viewport"' "$file"; then
    printf 'ok: viewport meta present\n'
else
    die 'missing <meta name="viewport">'
fi

# 3: hover-only affordances (advisory)
if grep -n ':hover' "$file" | head -5; then
    warn ":hover selectors found — confirm nothing depends on hover alone"
fi

printf 'size: %s bytes\n' "$(wc -c < "$file")"

if [ "$fail" -eq 0 ]; then printf 'SELF-CONTAINED OK\n'; fi
exit "$fail"
