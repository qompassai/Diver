#!/usr/bin/env bash

# render_cs.sh
# Qompass AI - [ ]
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
set -euo pipefail
csd="${1:?input csd required}"
out="${2:?output wav required}"
csound -o "$out" "$csd"
