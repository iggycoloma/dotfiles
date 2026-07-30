.PHONY: lint test test-unit test-packages test-integration test-install test-consistency test-policy test-ralph test-dc-audit test-drift test-hooks test-matchers lint-devcontainers lint-settings-drift

# Find all shell scripts in the repo (excluding hidden dirs like .git)
SHELL_SCRIPTS := $(shell find . -name '*.sh' -not -path './.git/*' -not -path './.devcontainer/*')

lint: lint-settings-drift lint-devcontainers
	shellcheck $(SHELL_SCRIPTS)

# Verify host vs container settings variants (claude-code, codex) stay in sync
# on every key outside the per-tier sandbox block. Catches "added a permission
# to settings.json and forgot settings.container.json" at lint time.
lint-settings-drift:
	@bin/settings-drift.sh --quiet

test: test-unit test-packages test-integration test-consistency test-policy test-ralph test-dc-audit test-drift test-hooks test-matchers

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

# The agent-hook guards themselves (sensitive paths, no-emoji, commit-msg).
# These suites existed but were wired into neither `make test` nor CI, so 180
# assertions covering the security guards never ran on a change.
test-hooks:
	bash tests/test-security-hook.sh
	bash tests/test-emoji-hook.sh
	bash tests/test-commit-msg-hook.sh

# Verify each hook matcher in claude-code/settings.json and codex/hooks.json
# names a tool its platform actually emits, and that the wired hook dispatches
# on it. The suites above bypass the matcher layer, so a dead matcher passes
# them silently -- which is how the Codex Read|Write|Edit matchers shipped.
test-matchers:
	bash tests/test-hook-matchers.sh

# Audit the repo's own devcontainer.json files. Exits non-zero on Error-severity
# findings (Info/Warn are surfaced but do not fail the build). The profile-per-
# directory mapping below is locked by a test in tests/test-dc-audit.sh.
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
