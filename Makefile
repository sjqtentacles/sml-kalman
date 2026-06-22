# sml-kalman build
#
#   make            build the test binary with MLton (default)
#   make test       build + run tests under MLton
#   make test-poly  run tests under Poly/ML (use-and-run; no link step)
#   make all-tests  run the suite under both compilers
#   make example    build + run examples/demo.sml (writes assets/filter-track.txt)
#   make clean      remove build artifacts
#
# Layout B (dependent): own sources live in src/; sml-matrix is vendored under
# lib/ and loaded first, in dependency order.  Real-arithmetic heavy => CI
# Variant B (Poly/ML 5.9.1 built from source).

MLTON      ?= mlton
POLY       ?= poly
BIN        := bin
MATRIXDIR  := lib/github.com/sjqtentacles/sml-matrix
TEST_MLB   := test/sources.mlb
SRCS       := $(wildcard $(MATRIXDIR)/* src/* test/*.sml) $(TEST_MLB)

.PHONY: all test poly test-poly all-tests example clean

all: $(BIN)/test-mlton

example: $(BIN)/demo
	mkdir -p assets
	./$(BIN)/demo | tee assets/filter-track.txt

$(BIN)/demo: $(SRCS) examples/demo.sml examples/sources.mlb | $(BIN)
	$(MLTON) -output $@ examples/sources.mlb

$(BIN)/test-mlton: $(SRCS) | $(BIN)
	$(MLTON) -output $@ $(TEST_MLB)

test: $(BIN)/test-mlton
	$(BIN)/test-mlton

# Poly/ML has no native .mlb support; the suite runs at top level and exits on
# its own. Load the vendored sml-matrix first, then the kalman sources, then the
# test driver, in dependency order.
poly test-poly:
	printf 'use "$(MATRIXDIR)/matrix.sig";\nuse "$(MATRIXDIR)/matrix.sml";\nuse "src/kalman.sig";\nuse "src/kalman.sml";\nuse "test/harness.sml";\nuse "test/support.sml";\nuse "test/test_filter.sml";\nuse "test/test_tracking.sml";\nuse "test/test_rls.sml";\nuse "test/entry.sml";\nuse "test/main.sml";\n' | $(POLY) -q --error-exit

all-tests: test test-poly

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -f $(BIN)/test-mlton $(BIN)/demo
