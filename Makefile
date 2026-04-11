.PHONY: lint test test-unit test-packages test-integration test-install test-consistency

# Find all shell scripts in the repo (excluding hidden dirs like .git)
SHELL_SCRIPTS := $(shell find . -name '*.sh' -not -path './.git/*' -not -path './.devcontainer/*')

lint:
	shellcheck $(SHELL_SCRIPTS)

test: test-unit test-packages test-integration test-consistency

test-unit:
	bash tests/unit-tests.sh

test-packages:
	bash tests/test-packages.sh

test-integration:
	bash tests/test-install.sh

test-consistency:
	bash tests/test-consistency.sh

# Alias for integration tests
test-install: test-integration
