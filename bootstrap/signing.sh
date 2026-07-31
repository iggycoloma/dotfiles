#!/usr/bin/env bash
# signing.sh -- SSH commit signing setup. Split out of install.sh so the branch
# matrix is reachable from tests; every branch here has caused a real bug (#58,
# #68). Callers must have sourced bootstrap/logging.sh and bootstrap/detect.sh.

# `ssh-add -L` prints "The agent has no identities." on stdout and exits 1 when
# the agent is empty, so filter to real key lines -- otherwise that sentence is
# captured as the signing key (#68).
_signing_key_from_agent() {
    local agent_keys
    agent_keys=$(ssh-add -L 2>/dev/null |
        grep -E '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-|sk-ssh-ed25519@|sk-ecdsa-sha2-) ' || true)
    [[ -n "$agent_keys" ]] || return 1
    echo "$agent_keys" | grep -m1 'ssh-ed25519' || echo "$agent_keys" | head -1
}

# `user.signingkey` has two shapes: `key::<literal-pubkey>` for agent-based
# signing (git >= 2.35), or a path to a .pub file for file-based signing.
_signing_key_content() {
    local key_value="$1"
    if [[ "$key_value" == key::* ]]; then
        printf '%s' "${key_value#key::}"
    elif [[ -f "$key_value" ]]; then
        command cat "$key_value"
    fi
}

# APPENDS, idempotently. allowed_signers is shared state listing every signer
# you trust, so it routinely holds teammates' keys. Truncating it destroys the
# ability to verify their commits, surfacing much later as "unknown signer".
_write_allowed_signers() {
    local key_value local_email signers_file key_content
    key_value=$(git config user.signingkey 2>/dev/null) || return 0
    [[ -n "$key_value" ]] || return 0

    key_content=$(_signing_key_content "$key_value")
    [[ -n "$key_content" ]] || return 0

    local_email=$(git config user.email 2>/dev/null || echo "unknown")
    signers_file="$HOME/.config/git/allowed_signers"
    mkdir -p "$(dirname "$signers_file")"

    if grep -qF "$key_content" "$signers_file" 2>/dev/null; then
        return 0
    fi

    # A file that does not end in a newline would otherwise splice our entry
    # onto the last existing one, corrupting both.
    if [[ -s "$signers_file" ]] && [[ -n "$(tail -c 1 "$signers_file")" ]]; then
        echo >> "$signers_file"
    fi

    echo "$local_email $key_content" >> "$signers_file"
    log_success "Added signing key to allowed_signers"
}

configure_ssh_signing() {
    # Opt-out: this function shells out to ssh-add and reads ~/.ssh/*.pub.
    if [[ "${DOTFILES_NO_SSH_SIGNING:-}" == "1" ]]; then
        log_info "DOTFILES_NO_SSH_SIGNING=1, skipping SSH signing setup"
        return 0
    fi

    # Never clobber a key the user chose deliberately.
    if git config user.signingkey >/dev/null 2>&1; then
        log_success "SSH commit signing already configured"
        return 0
    fi

    local signing_key
    signing_key=$(_signing_key_from_agent || true)

    if [[ -n "$signing_key" ]]; then
        git config --global user.signingkey "key::$signing_key"
        git config --global commit.gpgsign true
        log_success "SSH commit signing configured (from agent)"
    elif is_devcontainer; then
        # Devcontainers are agent-only by policy. A file-based key inside the
        # container is a long-lived credential that survives rebuilds in the
        # persisted state volume, handing container-resident code (and any
        # prompt-injected agent) a signing primitive with no user in the loop.
        log_warn "No SSH agent forwarded into container -- commit signing disabled"
        log_info "Forward ssh-agent into the devcontainer to enable signing"
        return 0
    elif [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        git config --global user.signingkey "$HOME/.ssh/id_ed25519.pub"
        git config --global commit.gpgsign true
        log_success "SSH commit signing configured (ed25519)"
    elif [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
        git config --global user.signingkey "$HOME/.ssh/id_rsa.pub"
        git config --global commit.gpgsign true
        log_success "SSH commit signing configured (rsa)"
    else
        log_warn "No SSH key found -- commit signing disabled"
        log_info "Add an SSH key and re-run install.sh to enable signing"
        return 0
    fi

    _write_allowed_signers
}
