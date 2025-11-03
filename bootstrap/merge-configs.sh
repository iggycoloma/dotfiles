#!/usr/bin/env bash
# Configuration merge for devcontainers/volumes
# Intelligently copies config files without overwriting existing customizations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}==>${NC} $1"
}

log_success() {
    echo -e "${GREEN}==>${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}==>${NC} $1"
}

log_error() {
    echo -e "${RED}==>${NC} $1"
}

# Copy a single file if it doesn't exist
# Args: source_file dest_file [force]
copy_if_not_exists() {
    local source=$1
    local dest=$2
    local force=${3:-false}

    if [[ ! -f "$source" ]]; then
        log_error "Source file does not exist: $source"
        return 1
    fi

    # Create parent directory if needed
    local dest_dir
    dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir"

    # Check if destination exists
    if [[ -f "$dest" ]] && [[ "$force" != "true" ]]; then
        log_warn "Skipping $(basename "$dest") (already exists, preserving local version)"
        return 0
    fi

    # Copy the file
    cp "$source" "$dest"
    log_success "Copied $(basename "$source") -> $dest"
}

# Recursively merge directory contents
# Args: source_dir dest_dir [force_patterns...]
# force_patterns: glob patterns to always update (e.g., "*.sh" or "agents/*")
merge_directory() {
    local source_dir=$1
    local dest_dir=$2
    shift 2
    local force_patterns=("$@")

    if [[ ! -d "$source_dir" ]]; then
        log_error "Source directory does not exist: $source_dir"
        return 1
    fi

    mkdir -p "$dest_dir"

    # Iterate through all files and directories in source
    local item
    while IFS= read -r -d '' item; do
        local rel_path="${item#$source_dir/}"
        local dest_path="$dest_dir/$rel_path"

        # Check if this item matches any force patterns
        local should_force=false
        for pattern in "${force_patterns[@]}"; do
            if [[ "$rel_path" == $pattern ]]; then
                should_force=true
                break
            fi
        done

        if [[ -d "$item" ]]; then
            # Recursively handle directories
            mkdir -p "$dest_path"
        elif [[ -f "$item" ]]; then
            # Copy file
            if [[ "$should_force" == "true" ]]; then
                cp "$item" "$dest_path"
                log_success "Force-updated $rel_path"
            else
                copy_if_not_exists "$item" "$dest_path" false
            fi
        fi
    done < <(find "$source_dir" -mindepth 1 -print0)
}

# Main merge function for config directories
# Handles .claude and .codex with smart merging
# Args: source_config_dir dest_config_dir
merge_configs() {
    local source=$1
    local dest=$2

    if [[ ! -d "$source" ]]; then
        log_error "Source config directory does not exist: $source"
        return 1
    fi

    log_info "Merging configs from $source to $dest"
    mkdir -p "$dest"

    # Define what should be force-updated (always copy from dotfiles)
    # These are typically shared resources that should be kept in sync
    # NOTE: Patterns with wildcards (e.g., "agents/*.md") match files within
    # subdirectories during recursive merge. Top-level patterns (e.g., "statusline.sh")
    # match files in the root config directory.
    local force_update_patterns=(
        "agents/*.md"
        "commands/*.md"
        "hooks/*.sh"
        "statusline.sh"
    )

    # Files that should never be overwritten (project-specific customizations)
    # These patterns only check the basename at the top level
    local skip_patterns=(
        "settings.json"
        "*.local.*"
    )

    # Process each item in source directory
    for item in "$source"/*; do
        [[ -e "$item" ]] || continue

        local basename_item
        basename_item=$(basename "$item")
        local dest_item="$dest/$basename_item"

        # Check if this matches skip patterns
        local should_skip=false
        for pattern in "${skip_patterns[@]}"; do
            if [[ "$basename_item" == $pattern ]] && [[ -e "$dest_item" ]]; then
                should_skip=true
                log_warn "Skipping $basename_item (preserving local customization)"
                break
            fi
        done

        [[ "$should_skip" == "true" ]] && continue

        if [[ -d "$item" ]]; then
            # For directories, recursively merge with force patterns
            log_info "Merging directory: $basename_item"
            merge_directory "$item" "$dest_item" "${force_update_patterns[@]}"
        elif [[ -f "$item" ]]; then
            # For files, check if it should be forced or copied conditionally
            local should_force=false
            for pattern in "${force_update_patterns[@]}"; do
                if [[ "$basename_item" == $pattern ]]; then
                    should_force=true
                    break
                fi
            done

            if [[ "$should_force" == "true" ]] || [[ ! -e "$dest_item" ]]; then
                cp "$item" "$dest_item"
                # Preserve source file permissions
                chmod --reference="$item" "$dest_item" 2>/dev/null || true
                log_success "Copied $basename_item"
            else
                log_warn "Skipping $basename_item (already exists)"
            fi
        fi
    done

    # Create version marker
    local version_file="$dest/.dotfiles-version"
    date +%Y%m%d_%H%M%S > "$version_file"
    log_success "Created version marker: $version_file"
}

# Setup Claude Code configuration with merge strategy
# Args: dotfiles_claude_dir
setup_claude_merge() {
    local source_dir=$1
    local dest_dir="$HOME/.claude"

    if [[ ! -d "$source_dir" ]]; then
        log_warn "Claude Code source directory not found: $source_dir"
        return 1
    fi

    log_info "Setting up Claude Code configuration (merge mode for devcontainer)"
    merge_configs "$source_dir" "$dest_dir"
    log_success "Claude Code configuration merged successfully"
}

# Setup .codex configuration with merge strategy (if exists)
# Args: dotfiles_codex_dir
setup_codex_merge() {
    local source_dir=$1
    local dest_dir="$HOME/.codex"

    if [[ ! -d "$source_dir" ]]; then
        log_info ".codex source directory not found, skipping"
        return 0
    fi

    log_info "Setting up .codex configuration (merge mode for devcontainer)"
    merge_configs "$source_dir" "$dest_dir"
    log_success ".codex configuration merged successfully"
}

# If run directly (not sourced), show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Usage: source this file and call merge_configs, setup_claude_merge, or setup_codex_merge"
    echo "Example: merge_configs /path/to/source /path/to/dest"
fi
