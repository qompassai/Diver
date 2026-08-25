#!/usr/bin/env bash
# /qompassai/diver/scripts/clir_ls.sh
# Qompass AI Clang IR (clir) LSP Build Script
# Copyright (C) 2025 Qompass AI, All rights reserved
# ----------------------------------------
set -euo pipefail
CLIRLS_DIR="${HOME}/.GH/llvm-project"
git clone https://github.com/llvm/clangir.git --recursive "${CLIRLS_DIR}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export LLVM_PREFIX="${XDG_DATA_HOME}/llvm"
mkdir -p "${LLVM_PREFIX}"
cd "${CLIRLS_DIR}"
mkdir -p build-release
cd build-release
cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$LLVM_PREFIX" \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_TARGETS_TO_BUILD="host" \
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;lld;lldb;mlir;openmp;polly;flang;bolt;libc" \
  -DCLANG_ENABLE_CIR=ON \
  -DLLVM_OCAML_INSTALL_PATH="$LLVM_PREFIX/lib/ocaml" \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  ../
ninja install
# It's a Chonky Boi--> # [269/12367 |   2% | 33.421] Building CXX object tools/mlir/tools/mlir-tblgen/CMakeFiles/mlir-tblgen.dir/PassCAPIGen.cpp.o