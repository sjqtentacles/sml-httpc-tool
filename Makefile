# sml-httpc-tool build (IMPURE socket driver -- a TOOL, not a pure library)
#
#   make            build the httpc CLI with MLton (default)
#   make build      build bin/httpc
#   make test       build + run the deterministic port-parsing suite (MLton)
#   make test-poly  run the deterministic port-parsing suite (Poly/ML)
#   make all-tests  run the suite under both compilers
#   make poly-check load the sources under Poly/ML to confirm they compile
#   make smoke      build, then fetch http://example.com (REQUIRES NETWORK)
#   make clean      remove build artifacts
#
# This tool opens real TCP sockets and is NOT part of the dual-compiler,
# deterministic purity guarantee. The socket driver has no deterministic test
# (the protocol logic is tested in the pure sml-httpc core), but the one pure
# part -- parsing a TCP port from an untrusted URL authority -- IS covered by a
# byte-identical suite under both compilers. CI only compiles the tool (no
# network).

MLTON      ?= mlton
POLY       ?= poly
BIN        := bin
URIDIR     := lib/github.com/sjqtentacles/sml-uri
HTTPDIR    := lib/github.com/sjqtentacles/sml-http
HTTPCDIR   := lib/github.com/sjqtentacles/sml-httpc
CLI_MLB    := cli/httpc.mlb
TEST_MLB   := test/sources.mlb
SRCS       := $(wildcard $(URIDIR)/* $(HTTPDIR)/* $(HTTPCDIR)/* src/* cli/*) $(CLI_MLB)
TEST_SRCS  := $(wildcard $(URIDIR)/* $(HTTPDIR)/* $(HTTPCDIR)/* src/* test/*) $(TEST_MLB)

.PHONY: all build test test-poly verify-identical all-tests poly-check smoke clean

all: build

build: $(BIN)/httpc

$(BIN)/httpc: $(SRCS) | $(BIN)
	$(MLTON) -output $@ $(CLI_MLB)

$(BIN)/test-mlton: $(TEST_SRCS) | $(BIN)
	$(MLTON) -output $@ $(TEST_MLB)

test: $(BIN)/test-mlton
	$(BIN)/test-mlton

# Poly/ML has no native .mlb support; the suite runs at top level and exits on
# its own. Load the vendored sml-uri -> sml-http -> sml-httpc sources (in
# dependency order), then the tool sources, then the harness + test driver.
poly test-poly:
	printf 'use "$(URIDIR)/percent.sig";\nuse "$(URIDIR)/percent.sml";\nuse "$(URIDIR)/query.sig";\nuse "$(URIDIR)/query.sml";\nuse "$(URIDIR)/uri.sig";\nuse "$(URIDIR)/uri.sml";\nuse "$(HTTPDIR)/headers.sig";\nuse "$(HTTPDIR)/headers.sml";\nuse "$(HTTPDIR)/status.sig";\nuse "$(HTTPDIR)/status.sml";\nuse "$(HTTPDIR)/http.sig";\nuse "$(HTTPDIR)/http.sml";\nuse "$(HTTPCDIR)/httpc.sig";\nuse "$(HTTPCDIR)/httpc.sml";\nuse "src/httpc_tool.sig";\nuse "src/httpc_tool.sml";\nuse "test/harness.sml";\nuse "test/test_port.sml";\nuse "test/entry.sml";\nuse "test/main.sml";\n' | $(POLY) -q --error-exit

all-tests: test test-poly verify-identical

# Compile-only check under Poly/ML: load every source (the Socket-based driver
# included) so we know the tool stays buildable on Poly/ML too. No network.
poly-check:
	printf 'use "$(URIDIR)/percent.sig";\nuse "$(URIDIR)/percent.sml";\nuse "$(URIDIR)/query.sig";\nuse "$(URIDIR)/query.sml";\nuse "$(URIDIR)/uri.sig";\nuse "$(URIDIR)/uri.sml";\nuse "$(HTTPDIR)/headers.sig";\nuse "$(HTTPDIR)/headers.sml";\nuse "$(HTTPDIR)/status.sig";\nuse "$(HTTPDIR)/status.sml";\nuse "$(HTTPDIR)/http.sig";\nuse "$(HTTPDIR)/http.sml";\nuse "$(HTTPCDIR)/httpc.sig";\nuse "$(HTTPCDIR)/httpc.sml";\nuse "src/httpc_tool.sig";\nuse "src/httpc_tool.sml";\nval () = print "poly-check: sources compiled\\n";\n' | $(POLY) -q --error-exit

smoke: build
	./$(BIN)/httpc -i http://example.com/

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -f $(BIN)/httpc $(BIN)/test-mlton

# The dual-compiler contract: both suites must print byte-identical output.
# Recursive make -s captures the raw suite stdout regardless of poly strategy.
verify-identical:
	$(MAKE) -s test > $(BIN)/out-mlton.txt
	$(MAKE) -s test-poly > $(BIN)/out-poly.txt
	diff $(BIN)/out-mlton.txt $(BIN)/out-poly.txt
	@echo "byte-identical: OK"
