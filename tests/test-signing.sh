#!/usr/bin/env bash
# Tests for bootstrap/signing.sh -- SSH commit signing auto-detection.
#
# Every branch here has shipped a bug: the agent-output filter (#68), the
# git >= 2.35 `key::` form (#58), and the devcontainer carve-out that must not
# silently fall back to a file-based key. The suite drives the real function
# with a fake `ssh-add` on PATH and a throwaway $HOME, so no test touches the
# developer's actual agent, keys, or gitconfig.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR_REAL="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/test-framework.sh"

ED25519_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFAKEKEYFORTESTSONLYxxxxxxxxxxxxxxxxxxxxxx test@example.com"
RSA_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQFAKERSAKEYFORTESTSONLYxxxxxxxxxxxx test@example.com"

# Build an isolated environment: throwaway HOME, a stub `ssh-add` whose output
# the caller controls, and stub log_* / is_devcontainer so we exercise
# signing.sh alone rather than the whole bootstrap chain.
#
#   $1  what the fake ssh-add prints on stdout
#   $2  exit code for the fake ssh-add
#   $3  "true" or "false" -- what is_devcontainer should report
#   $4  optional shell line run just before configure_ssh_signing (used to seed
#       state); keeps callers from having to rewrite the generated driver, which
#       previously needed a GNU-only `sed -i`.
signing_env() {
    local agent_output="$1" agent_rc="$2" in_container="$3" preamble="${4:-:}"
    local tmp
    tmp=$(mktemp -d)

    mkdir -p "$tmp/home/.ssh" "$tmp/bin"

    printf '#!/usr/bin/env bash\ncat <<"AGENTEOF"\n%s\nAGENTEOF\nexit %s\n' \
        "$agent_output" "$agent_rc" > "$tmp/bin/ssh-add"
    chmod +x "$tmp/bin/ssh-add"

    # `cd` into the throwaway HOME and neutralize system config. signing.sh
    # reads `git config user.signingkey` and `user.email` without --global, so
    # those are *merged* reads that include the repository config of whatever
    # directory the driver runs in. Left in the dotfiles checkout, a developer
    # with a per-repo signing key would see most of this suite fail against
    # correct code. $tmp/home is not a git repo, so no repo config is in scope.
    cat > "$tmp/driver.sh" <<DRIVER
set +e
export HOME="$tmp/home"
export PATH="$tmp/bin:\$PATH"
export GIT_CONFIG_GLOBAL="$tmp/home/.gitconfig"
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_NOSYSTEM=1
cd "$tmp/home" || exit 1
: > "\$GIT_CONFIG_GLOBAL"
git config --global user.email "test@example.com"

log_info()    { echo "INFO: \$*"; }
log_warn()    { echo "WARN: \$*"; }
log_success() { echo "OK: \$*"; }
log_error()   { echo "ERROR: \$*"; }
is_devcontainer() { $in_container; }

source "$DOTFILES_DIR_REAL/bootstrap/signing.sh"
$preamble
configure_ssh_signing
DRIVER

    printf '%s' "$tmp"
}

# Read a git config value out of a fixture's isolated global config.
fixture_config() {
    local tmp="$1" key="$2"
    GIT_CONFIG_GLOBAL="$tmp/home/.gitconfig" GIT_CONFIG_NOSYSTEM=1 \
        git config --global "$key" 2>/dev/null
}

# ---------------------------------------------------------------------------

test_suite "signing: syntax"

bash -n "$DOTFILES_DIR_REAL/bootstrap/signing.sh" 2>/dev/null
assert_return_code 0 $? "signing.sh passes bash -n"

# ---------------------------------------------------------------------------

test_suite "signing: agent-based key detection"

# A loaded agent wins, and the key is stored in the git >= 2.35 key:: form.
tmp=$(signing_env "$ED25519_KEY" 0 false)
out=$(bash "$tmp/driver.sh" 2>&1)
assert_equals "key::$ED25519_KEY" "$(fixture_config "$tmp" user.signingkey)" \
    "agent key is stored with the key:: prefix"
assert_equals "true" "$(fixture_config "$tmp" commit.gpgsign)" "enables commit.gpgsign"
assert_contains "$out" "from agent" "reports the agent as the source"
rm -rf "$tmp"

# ed25519 is preferred even when the agent lists rsa first.
tmp=$(signing_env "$RSA_KEY
$ED25519_KEY" 0 false)
bash "$tmp/driver.sh" >/dev/null 2>&1
assert_equals "key::$ED25519_KEY" "$(fixture_config "$tmp" user.signingkey)" \
    "prefers ed25519 over an earlier rsa key"
rm -rf "$tmp"

# With no ed25519 present, the first listed key is used.
tmp=$(signing_env "$RSA_KEY" 0 false)
bash "$tmp/driver.sh" >/dev/null 2>&1
assert_equals "key::$RSA_KEY" "$(fixture_config "$tmp" user.signingkey)" \
    "falls back to the first agent key when no ed25519 is loaded"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "signing: empty agent output is not mistaken for a key (#68)"

# `ssh-add -L` prints this on stdout and exits 1. Before #68 it was captured
# verbatim as the signing key, producing an unusable config.
tmp=$(signing_env "The agent has no identities." 1 false)
printf '%s\n' "$ED25519_KEY" > "$tmp/home/.ssh/id_ed25519.pub"
out=$(bash "$tmp/driver.sh" 2>&1)
key=$(fixture_config "$tmp" user.signingkey)
assert_not_contains "$key" "no identities" "does not capture the empty-agent sentence"
assert_equals "$tmp/home/.ssh/id_ed25519.pub" "$key" \
    "falls through to the file-based key instead"
rm -rf "$tmp"

# A connection error on stderr must not become a key either.
tmp=$(signing_env "" 2 false)
bash "$tmp/driver.sh" >/dev/null 2>&1
assert_equals "" "$(fixture_config "$tmp" user.signingkey)" \
    "leaves signingkey unset when the agent is unreachable and no key file exists"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "signing: file-based fallback on hosts"

# ed25519 file preferred over rsa file.
tmp=$(signing_env "" 1 false)
printf '%s\n' "$ED25519_KEY" > "$tmp/home/.ssh/id_ed25519.pub"
printf '%s\n' "$RSA_KEY" > "$tmp/home/.ssh/id_rsa.pub"
out=$(bash "$tmp/driver.sh" 2>&1)
assert_equals "$tmp/home/.ssh/id_ed25519.pub" "$(fixture_config "$tmp" user.signingkey)" \
    "prefers the ed25519 key file"
assert_contains "$out" "ed25519" "names the key type it chose"
rm -rf "$tmp"

# rsa file used when ed25519 is absent.
tmp=$(signing_env "" 1 false)
printf '%s\n' "$RSA_KEY" > "$tmp/home/.ssh/id_rsa.pub"
bash "$tmp/driver.sh" >/dev/null 2>&1
assert_equals "$tmp/home/.ssh/id_rsa.pub" "$(fixture_config "$tmp" user.signingkey)" \
    "uses the rsa key file when ed25519 is absent"
rm -rf "$tmp"

# No agent, no key files: signing stays off rather than half-configured.
tmp=$(signing_env "" 1 false)
out=$(bash "$tmp/driver.sh" 2>&1)
assert_equals "" "$(fixture_config "$tmp" user.signingkey)" "leaves signingkey unset"
assert_equals "" "$(fixture_config "$tmp" commit.gpgsign)" "leaves gpgsign unset"
assert_contains "$out" "No SSH key found" "warns that signing is disabled"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "signing: devcontainers are agent-only"

# The carve-out that matters: inside a container, a present key *file* must NOT
# be adopted. It would be a long-lived signing credential persisted across
# rebuilds with no user in the loop.
tmp=$(signing_env "" 1 true)
printf '%s\n' "$ED25519_KEY" > "$tmp/home/.ssh/id_ed25519.pub"
printf '%s\n' "$RSA_KEY" > "$tmp/home/.ssh/id_rsa.pub"
out=$(bash "$tmp/driver.sh" 2>&1)
assert_equals "" "$(fixture_config "$tmp" user.signingkey)" \
    "does not adopt a file-based key inside a container"
assert_contains "$out" "No SSH agent forwarded" "explains why signing is off"
rm -rf "$tmp"

# A forwarded agent still works inside a container -- that is the supported path.
tmp=$(signing_env "$ED25519_KEY" 0 true)
bash "$tmp/driver.sh" >/dev/null 2>&1
assert_equals "key::$ED25519_KEY" "$(fixture_config "$tmp" user.signingkey)" \
    "uses a forwarded agent key inside a container"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "signing: allowed_signers resolution"

# key:: form -- the prefix must be stripped, not written literally.
tmp=$(signing_env "$ED25519_KEY" 0 false)
bash "$tmp/driver.sh" >/dev/null 2>&1
signers="$tmp/home/.config/git/allowed_signers"
assert_file_exists "$signers" "writes allowed_signers for an agent key"
assert_equals "test@example.com $ED25519_KEY" "$(cat "$signers" 2>/dev/null)" \
    "strips the key:: prefix and pairs the key with the git email"
rm -rf "$tmp"

# File-based form -- the file's contents must be read, not its path.
tmp=$(signing_env "" 1 false)
printf '%s\n' "$ED25519_KEY" > "$tmp/home/.ssh/id_ed25519.pub"
bash "$tmp/driver.sh" >/dev/null 2>&1
signers="$tmp/home/.config/git/allowed_signers"
assert_file_exists "$signers" "writes allowed_signers for a file-based key"
assert_contains "$(cat "$signers" 2>/dev/null)" "$ED25519_KEY" \
    "resolves the key file to its contents"
assert_not_contains "$(cat "$signers" 2>/dev/null)" "id_ed25519.pub" \
    "does not write the key path instead of the key"
rm -rf "$tmp"

# No signing key configured means no allowed_signers file at all.
tmp=$(signing_env "" 1 false)
bash "$tmp/driver.sh" >/dev/null 2>&1
assert_file_not_exists "$tmp/home/.config/git/allowed_signers" \
    "skips allowed_signers when no key was configured"
rm -rf "$tmp"

# Existing entries must survive. allowed_signers is shared state -- it lists
# every signer you trust, so it routinely holds teammates' keys. Truncating it
# silently destroys verification of everyone else's commits.
TEAMMATE="colleague@example.com ssh-ed25519 AAAATEAMMATEKEYxxxxxxxxxxxxxxxxxxxxxxxxxxxx colleague@example.com"
tmp=$(signing_env "$ED25519_KEY" 0 false)
mkdir -p "$tmp/home/.config/git"
printf '%s\n' "$TEAMMATE" > "$tmp/home/.config/git/allowed_signers"
bash "$tmp/driver.sh" >/dev/null 2>&1
signers=$(cat "$tmp/home/.config/git/allowed_signers" 2>/dev/null)
assert_contains "$signers" "colleague@example.com" "preserves an existing teammate entry"
assert_contains "$signers" "$ED25519_KEY" "appends our own key alongside it"
assert_equals "2" "$(wc -l < "$tmp/home/.config/git/allowed_signers" | tr -d ' ')" \
    "leaves exactly two entries"
rm -rf "$tmp"

# A file with no trailing newline must not have our entry spliced onto its
# last line, which would corrupt both records.
tmp=$(signing_env "$ED25519_KEY" 0 false)
mkdir -p "$tmp/home/.config/git"
printf '%s' "$TEAMMATE" > "$tmp/home/.config/git/allowed_signers"
bash "$tmp/driver.sh" >/dev/null 2>&1
assert_equals "2" "$(wc -l < "$tmp/home/.config/git/allowed_signers" | tr -d ' ')" \
    "adds a separating newline when the file did not end in one"
assert_not_contains "$(head -1 "$tmp/home/.config/git/allowed_signers")" "test@example.com" \
    "does not splice our entry onto the existing last line"
rm -rf "$tmp"

# Re-running must not duplicate an entry that is already present.
tmp=$(signing_env "$ED25519_KEY" 0 false)
bash "$tmp/driver.sh" >/dev/null 2>&1
bash "$tmp/driver.sh" >/dev/null 2>&1
assert_equals "1" "$(grep -cF "$ED25519_KEY" "$tmp/home/.config/git/allowed_signers")" \
    "is idempotent across repeated runs"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "signing: opt-out and idempotency"

# DOTFILES_NO_SSH_SIGNING=1 short-circuits before ssh-add is ever consulted.
tmp=$(signing_env "$ED25519_KEY" 0 false)
out=$(DOTFILES_NO_SSH_SIGNING=1 bash "$tmp/driver.sh" 2>&1)
assert_equals "" "$(fixture_config "$tmp" user.signingkey)" \
    "opt-out leaves signingkey untouched"
assert_contains "$out" "skipping SSH signing setup" "reports the opt-out"
rm -rf "$tmp"

# An existing key is never overwritten, even when the agent offers a different
# one. The driver truncates the config on entry, so seed the key via the
# preamble hook rather than rewriting the generated script.
tmp=$(signing_env "$ED25519_KEY" 0 false \
    'git config --global user.signingkey "key::PREEXISTING"')
out=$(bash "$tmp/driver.sh" 2>&1)
assert_equals "key::PREEXISTING" "$(fixture_config "$tmp" user.signingkey)" \
    "does not overwrite an existing signingkey"
assert_contains "$out" "already configured" "reports the key as already configured"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

print_test_summary
