.PHONY: lint test test-unit test-packages test-integration test-install

# Find all shell scripts in the repo (excluding hidden dirs like .git)
SHELL_SCRIPTS := $(shell find . -name '*.sh' -not -path './.git/*' -not -path './.devcontainer/*')

lint:
	shellcheck $(SHELL_SCRIPTS)

test: test-unit test-packages test-integration

test-unit:
	bash tests/unit-tests.sh

test-packages:
	bash tests/test-packages.sh

test-integration:
	bash tests/test-install.sh

# Alias for integration tests
test-install: test-integration
