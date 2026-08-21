#!/usr/bin/env bash
# Version floors shared across the repo -- the single source of truth for
# "what is our minimum git".
#
# Sourced by bootstrap/packages.sh (PPA upgrade floor) and bin/dc-audit.sh
# (devcontainer rubric floor). claude-code/hooks/worktree-create.sh deploys
# as a standalone script that cannot source a checkout file at runtime, and
# wt (worktree-orchestrator) is a separate repo entirely, so both inline the
# same value; tests/test-consistency.sh asserts the copies match, which is
# how a floor bump propagates safely.

# Minimum git. Two features set it: `git worktree add --relative-paths` /
# worktree.useRelativePaths -- which per-worktree dev containers depend on --
# landed in 2.48, and key::<literal-pubkey> signingkey needs 2.35. No
# supported LTS ships 2.48 stock (Ubuntu 24.04: 2.43, Debian bookworm: 2.39).
export DOTFILES_MIN_GIT="2.48.0"
