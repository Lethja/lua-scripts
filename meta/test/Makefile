MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

DIRS := $(wildcard $(MAKEFILE_DIR)/*/)
TARGETS := $(notdir $(patsubst %/,%,$(DIRS)))

.PHONY: all $(TARGETS)

all: $(TARGETS)

$(TARGETS):
	@cd $(MAKEFILE_DIR)/$@ && ./test.sh