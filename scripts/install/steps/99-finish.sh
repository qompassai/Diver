#!/usr/bin/env bash
# steps/99-finish.sh — final wiring + health report.
#
#   - ensures $BIN_DIR is on PATH in shell startup files (idempotent)
#   - probes every binary the cascade manages (step manifests) and reports
#     present vs missing
#   - lists DIVER_UNSUPPORTED binaries honestly (no clean rootless path)
#   - prints installed versions of the key binaries
#   - runs nvim --headless :checkhealth and summarises errors

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
# shellcheck source=../lib/toolchain.sh
source "$LIB_DIR/toolchain.sh"
diver_detect_platform

diver_ensure_path_rc

# ------------------------------------------------- toolchain manifest ---

echo
diver_log "toolchain audit (binaries the cascade manages):"
manifest_dir="$XDG_DATA_HOME/diver/install/manifest.d"
present=0
missing=()
if [[ -d $manifest_dir ]]; then
  while IFS= read -r bin; do
    [[ -z $bin ]] && continue
    if diver_have "$bin"; then
      present=$((present + 1))
    else
      missing+=("$bin")
    fi
  done < <(cat "$manifest_dir"/*.txt 2>/dev/null | sort -u)
  diver_ok "$present managed binaries on PATH"
  if ((${#missing[@]} > 0)); then
    diver_warn "${#missing[@]} managed binaries still missing:"
    printf '    %s\n' "${missing[@]}" | head -40 >&2
    ((${#missing[@]} > 40)) && diver_warn "... and $((${#missing[@]} - 40)) more"
  fi
else
  diver_warn "no step manifests found (did 60/70/80 run?)"
fi

# ------------------------------------------------------- unsupported ---

echo
diver_log "known-unsupported on a rootless install (not attempted):"
printf '    %s\n' "${DIVER_UNSUPPORTED[@]}"

# ------------------------------------------------------------- versions ---

echo
diver_log "key versions:"
for b in nvim git lua-language-server node pnpm uv go cargo python3 java; do
  if diver_have "$b"; then
    ver="$("$b" --version 2>&1 | head -1)"
    printf '  %-20s %s\n' "$b" "$ver"
  else
    printf '  %-20s %s\n' "$b" "(missing)"
  fi
done

# ----------------------------------------------------------- checkhealth ---

echo
if diver_have nvim; then
  diver_log "running :checkhealth (headless)"
  health_log="$DIVER_TMP_DIR/checkhealth.log"
  nvim --headless -c 'checkhealth' -c 'q!' >"$health_log" 2>&1 || true
  errors="$(grep -c 'ERROR' "$health_log" || true)"
  warnings="$(grep -c 'WARNING' "$health_log" || true)"
  if [[ $errors == 0 ]]; then
    diver_ok "checkhealth: 0 errors, $warnings warnings (full log: $health_log)"
  else
    diver_warn "checkhealth: $errors errors, $warnings warnings"
    grep -B2 'ERROR' "$health_log" | head -40 >&2 || true
  fi
  # Keep the log somewhere durable for later inspection.
  mkdir -p "$XDG_DATA_HOME/nvim"
  cp "$health_log" "$XDG_DATA_HOME/nvim/install-checkhealth.log"
  diver_log "full checkhealth log → $XDG_DATA_HOME/nvim/install-checkhealth.log"
fi

echo
diver_ok "Diver install complete — open a new shell and run: nvim"
