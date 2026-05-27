.PHONY: lint test test-unit test-packages test-integration test-install test-consistency test-policy test-ralph test-dc-audit test-drift lint-devcontainers lint-settings-drift

# Find all shell scripts in the repo (excluding hidden dirs like .git)
SHELL_SCRIPTS := $(shell find . -name '*.sh' -not -path './.git/*' -not -path './.devcontainer/*')

lint: lint-settings-drift
	shellcheck $(SHELL_SCRIPTS)

# Verify host vs container settings variants (claude-code, codex) stay in sync
# on every key outside the per-tier sandbox block. Catches "added a permission
# to settings.json and forgot settings.container.json" at lint time.
lint-settings-drift:
	@bin/settings-drift.sh --quiet

test: test-unit test-packages test-integration test-consistency test-policy test-ralph test-dc-audit test-drift

test-unit:
	bash tests/unit-tests.sh

test-packages:
	bash tests/test-packages.sh

test-integration:
	bash tests/test-install.sh

test-consistency:
	bash tests/test-consistency.sh

test-policy:
	bash tests/test-gh-repo-policy.sh

test-ralph:
	bash tests/test-ralph.sh

test-dc-audit:
	bash tests/test-dc-audit.sh

test-drift:
	bash tests/test-settings-drift.sh

# Audit the repo's own devcontainer.json files (advisory only, not fatal).
lint-devcontainers:
	@for f in .devcontainer/*/devcontainer.json; do \
		[ -f "$$f" ] || continue; \
		case "$$f" in \
			*/unattended/*) profile=unattended ;; \
			*) profile=attended ;; \
		esac; \
		bin/dc-audit.sh --profile $$profile "$$f"; \
	done

# Alias for integration tests
test-install: test-integration
