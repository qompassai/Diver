# /qompassai/Diver/docs/learn-lua/Makefile
# Qompass AI Diver Luadoc MakeFile
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------------------------------------------
# Targets:
#   make            build the HTML docs into ./build (default)
#   make serve      build, then serve ./build at http://localhost:8000
#   make clean      remove ./build
#   make check      sanity-check that ldoc is installed
#

LDOC    ?= ldoc
CONFIG  ?= config.ld
OUT     ?= build
PORT    ?= 8000

.PHONY: all docs serve clean check

all: docs

docs: check
	$(LDOC) -c $(CONFIG) .
	@echo "Docs written to ./$(OUT)/index.html"

serve: docs
	@echo "Serving ./$(OUT) at http://localhost:$(PORT)  (Ctrl-C to stop)"
	@cd $(OUT) && python3 -m http.server $(PORT)

clean:
	rm -rf $(OUT)
	@echo "Removed ./$(OUT)"

check:
	@command -v $(LDOC) >/dev/null 2>&1 || { \
		echo "ERROR: '$(LDOC)' not found. Install it with:"; \
		echo "    luarocks install ldoc"; \
		echo "    luarocks install markdown"; \
		exit 1; }
