# sml-httpc-tool build (IMPURE socket driver -- a TOOL, not a pure library)
#
#   make            build the httpc CLI with MLton (default)
#   make build      build bin/httpc
#   make poly-check load the sources under Poly/ML to confirm they compile
#   make smoke      build, then fetch http://example.com (REQUIRES NETWORK)
#   make clean      remove build artifacts
#
# This tool opens real TCP sockets and is NOT part of the dual-compiler,
# deterministic purity guarantee. There is no deterministic test suite: the
# protocol logic is tested in the pure sml-httpc core. CI only compiles the
# tool (no network).

MLTON      ?= mlton
POLY       ?= poly
BIN        := bin
URIDIR     := lib/github.com/sjqtentacles/sml-uri
HTTPDIR    := lib/github.com/sjqtentacles/sml-http
HTTPCDIR   := lib/github.com/sjqtentacles/sml-httpc
CLI_MLB    := cli/httpc.mlb
SRCS       := $(wildcard $(URIDIR)/* $(HTTPDIR)/* $(HTTPCDIR)/* src/* cli/*) $(CLI_MLB)

.PHONY: all build poly-check smoke clean

all: build

build: $(BIN)/httpc

$(BIN)/httpc: $(SRCS) | $(BIN)
	$(MLTON) -output $@ $(CLI_MLB)

# Compile-only check under Poly/ML: load every source (the Socket-based driver
# included) so we know the tool stays buildable on Poly/ML too. No network.
poly-check:
	printf 'use "$(URIDIR)/percent.sig";\nuse "$(URIDIR)/percent.sml";\nuse "$(URIDIR)/query.sig";\nuse "$(URIDIR)/query.sml";\nuse "$(URIDIR)/uri.sig";\nuse "$(URIDIR)/uri.sml";\nuse "$(HTTPDIR)/headers.sig";\nuse "$(HTTPDIR)/headers.sml";\nuse "$(HTTPDIR)/status.sig";\nuse "$(HTTPDIR)/status.sml";\nuse "$(HTTPDIR)/http.sig";\nuse "$(HTTPDIR)/http.sml";\nuse "$(HTTPCDIR)/httpc.sig";\nuse "$(HTTPCDIR)/httpc.sml";\nuse "src/httpc_tool.sig";\nuse "src/httpc_tool.sml";\nval () = print "poly-check: sources compiled\\n";\n' | $(POLY) -q --error-exit

smoke: build
	./$(BIN)/httpc -i http://example.com/

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -f $(BIN)/httpc
