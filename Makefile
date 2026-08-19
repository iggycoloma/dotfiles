.PHONY: lint test test-unit test-packages test-integration test-install test-consistency test-policy test-ralph test-dc-audit test-drift test-hooks test-matchers test-signing test-wt lint-devcontainers lint-settings-drift lint-settings-sync lint-prompt-drift prompt-stats lint-prompt-stats sync-settings

# Find all shell scripts in the repo (excluding hidden dirs like .git).
# .claude is excluded because Claude Code nests worktrees at
# .claude/worktrees/<name>/ -- full repo copies at other commits, whose
# stale scripts would otherwise be linted as if they were ours.
# bin/wt is listed explicitly: it carries no extension, and it is the largest
# shell file in the repo to be going unchecked.
SHELL_SCRIPTS := $(shell find . \( -name '*.sh' -o -name '*.bash' \) -not -path './.git/*' -not -path './.devcontainer/*' -not -path './.claude/*' -not -path './.worktrees/*') ./bin/wt

lint: lint-settings-sync lint-settings-drift lint-prompt-drift lint-prompt-stats lint-devcontainers
	shellcheck $(SHELL_SCRIPTS)

# Regenerate claude-code/settings.container.json from settings.json. The two
# differ only in the .sandbox block, so the container variant is derived rather
# than hand-maintained -- which makes "edited one file, forgot the other"
# impossible instead of merely detectable. Commit the result.
sync-settings:
	@bin/sync-settings.sh

# Fail if the committed container variant no longer matches the generator,
# i.e. someone hand-edited it or changed settings.json without re-syncing.
lint-settings-sync:
	@bin/sync-settings.sh --check

# Two drift classes: host vs container variants (claude-code, codex) on every
# key outside the per-tier sandbox block, and Read/Write/Edit deny-list parity
# inside settings.json. Catches "added a permission to settings.json and forgot
# settings.container.json" and "denied it for Read but not Edit" at lint time.
lint-settings-drift:
	@bin/settings-drift.sh --quiet

# Deployed instruction files (~/.claude, ~/.codex, ~/.copilot) are outputs of
# bootstrap/symlinks.sh; tracked sources are authoritative. Symlinked deploys
# cannot drift, but devcontainer managed copies go stale between a source edit
# and the next rebuild. Skips pairs not deployed in this environment.
lint-prompt-drift:
	@bin/prompt-drift.sh --quiet

# Regenerate docs/prompt-stats.md (token costs and loading graph of the
# instruction files). Run after editing any prompt source; commit the result.
prompt-stats:
	@bin/prompt-stats.sh

# Fail if docs/prompt-stats.md no longer matches what the generator would
# write, i.e. a prompt file changed without regenerating the stats table.
lint-prompt-stats:
	@bin/prompt-stats.sh --check

test: test-unit test-packages test-integration test-consistency test-policy test-ralph test-dc-audit test-drift test-hooks test-matchers test-signing test-wt

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
test-wt:
	bash tests/test-wt.sh

test-hooks:
	bash tests/test-security-hook.sh
	bash tests/test-emoji-hook.sh
	bash tests/test-commit-msg-hook.sh
	bash tests/test-agent-observability-hooks.sh
	bash tests/test-pre-push-hook.sh
	bash tests/test-project-hooks.sh

# Verify each hook matcher in claude-code/settings.json and codex/hooks.json
# names a tool its platform actually emits, and that the wired hook dispatches
# on it. The suites above bypass the matcher layer, so a dead matcher passes
# them silently -- which is how the Codex Read|Write|Edit matchers shipped.
test-matchers:
	bash tests/test-hook-matchers.sh

# SSH signing key auto-detection: agent vs file-based, ed25519 vs rsa, the
# devcontainer agent-only carve-out, and allowed_signers resolution. Runs
# against a fake ssh-add and a throwaway HOME, so it never touches the real
# agent or gitconfig.
test-signing:
	bash tests/test-signing.sh

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
