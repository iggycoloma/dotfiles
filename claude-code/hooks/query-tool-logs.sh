#!/usr/bin/env bash
# Query tool logs - Helper script for searching Claude Code tool usage logs
# Usage: query-tool-logs.sh [command] [options]

set -euo pipefail

LOGS_DIR="$HOME/.claude/logs"

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this script" >&2
    exit 1
fi

# Print usage
usage() {
    cat << EOF
Usage: query-tool-logs.sh [COMMAND] [OPTIONS]

Commands:
  last                  Show tools from the most recent session
  session <session-id>  Show tools from a specific session
  sessions              List all available sessions
  bash [session-id]     Show only Bash commands (all sessions or specific)
  tool <tool-name>      Show usage of a specific tool (e.g., Write, Edit, Bash)
  search <pattern>      Search for pattern in tool inputs/commands
  stats [session-id]    Show statistics for session(s)
  watch                 Watch the current session's log in real-time

Options:
  -n, --lines N         Show only the last N entries (default: all)
  -v, --verbose         Show full tool input/response (not truncated)
  --json                Output raw JSONL instead of formatted text

Examples:
  query-tool-logs.sh last              # Show last session's tools
  query-tool-logs.sh bash              # Show all bash commands
  query-tool-logs.sh tool Write        # Show all Write operations
  query-tool-logs.sh search "git"      # Find all git-related commands
  query-tool-logs.sh stats             # Show stats for all sessions
  query-tool-logs.sh watch             # Watch current session

EOF
    exit 1
}

# Get the most recent log file
get_latest_log() {
    find "$LOGS_DIR" -name "session-*.jsonl" -type f -printf "%T@ %p\n" 2>/dev/null | \
        sort -rn | head -1 | cut -d' ' -f2-
}

# List all sessions
list_sessions() {
    echo "Available sessions:"
    echo "==================="

    find "$LOGS_DIR" -name "session-*.jsonl" -type f -printf "%T@ %f %s\n" 2>/dev/null | \
        sort -rn | while read -r mtime filename size; do
            session_id="${filename#session-}"
            session_id="${session_id%.jsonl}"

            # Get session details
            log_file="$LOGS_DIR/$filename"
            entry_count=$(wc -l < "$log_file")
            first_entry=$(head -1 "$log_file" | jq -r '.timestamp // "unknown"')
            last_entry=$(tail -1 "$log_file" | jq -r '.timestamp // "unknown"')

            # Format size
            if [[ $size -gt 1048576 ]]; then
                size_fmt="$(( size / 1048576 ))M"
            elif [[ $size -gt 1024 ]]; then
                size_fmt="$(( size / 1024 ))K"
            else
                size_fmt="${size}B"
            fi

            echo "Session: $session_id"
            echo "  Entries: $entry_count"
            echo "  Size: $size_fmt"
            echo "  Time: $first_entry → $last_entry"
            echo ""
        done
}

# Format entry for display
format_entry() {
    local entry="$1"
    local verbose="${2:-false}"

    local timestamp=$(echo "$entry" | jq -r '.timestamp')
    local tool_name=$(echo "$entry" | jq -r '.tool_name')
    local cwd=$(echo "$entry" | jq -r '.cwd // ""')
    local git_branch=$(echo "$entry" | jq -r '.git_branch // ""')

    # Time formatting (just HH:MM:SS)
    local time=$(echo "$timestamp" | cut -d'T' -f2 | cut -d'.' -f1)

    echo "[$time] $tool_name"

    if [[ -n "$git_branch" ]]; then
        echo "  Branch: $git_branch"
    fi

    # Tool-specific formatting
    case "$tool_name" in
        Bash)
            local command=$(echo "$entry" | jq -r '.tool_input.command // ""')
            local exit_code=$(echo "$entry" | jq -r '.tool_response.exitCode // "?"')
            local description=$(echo "$entry" | jq -r '.tool_input.description // ""')

            echo "  Command: $command"
            if [[ -n "$description" ]]; then
                echo "  Description: $description"
            fi
            echo "  Exit code: $exit_code"

            if [[ "$verbose" == "true" ]]; then
                local stdout=$(echo "$entry" | jq -r '.tool_response.stdout // ""')
                if [[ -n "$stdout" ]]; then
                    echo "  Output:"
                    echo "$stdout" | sed 's/^/    /'
                fi
            fi
            ;;

        Write)
            local file_path=$(echo "$entry" | jq -r '.tool_input.file_path // ""')
            local content_length=$(echo "$entry" | jq -r '.tool_input.metadata.content_length // "?"')
            local content_lines=$(echo "$entry" | jq -r '.tool_input.metadata.content_lines // "?"')

            echo "  File: $file_path"
            echo "  Size: $content_length chars, $content_lines lines"

            if [[ "$verbose" == "true" ]]; then
                local content=$(echo "$entry" | jq -r '.tool_input.content // ""')
                if [[ -n "$content" ]]; then
                    echo "  Content preview:"
                    echo "$content" | head -20 | sed 's/^/    /'
                fi
            fi
            ;;

        Edit)
            local file_path=$(echo "$entry" | jq -r '.tool_input.file_path // ""')
            local old_length=$(echo "$entry" | jq -r '.tool_input.metadata.old_string_length // "?"')
            local new_length=$(echo "$entry" | jq -r '.tool_input.metadata.new_string_length // "?"')
            local replace_all=$(echo "$entry" | jq -r '.tool_input.replace_all // false')

            echo "  File: $file_path"
            echo "  Changes: $old_length → $new_length chars"
            if [[ "$replace_all" == "true" ]]; then
                echo "  Mode: replace_all"
            fi

            if [[ "$verbose" == "true" ]]; then
                local old_string=$(echo "$entry" | jq -r '.tool_input.old_string // ""')
                local new_string=$(echo "$entry" | jq -r '.tool_input.new_string // ""')
                echo "  Old string:"
                echo "$old_string" | sed 's/^/    /'
                echo "  New string:"
                echo "$new_string" | sed 's/^/    /'
            fi
            ;;

        *)
            if [[ "$verbose" == "true" ]]; then
                echo "  Input:"
                echo "$entry" | jq -r '.tool_input' | sed 's/^/    /'
            fi
            ;;
    esac

    echo ""
}

# Show statistics
show_stats() {
    local log_file="$1"

    echo "Statistics for $(basename "$log_file")"
    echo "========================================"

    # Total entries
    local total=$(wc -l < "$log_file")
    echo "Total tool uses: $total"
    echo ""

    # Tool breakdown
    echo "Tool usage breakdown:"
    jq -r '.tool_name' "$log_file" | sort | uniq -c | sort -rn | \
        awk '{printf "  %-20s %d\n", $2, $1}'
    echo ""

    # Bash commands breakdown
    local bash_count=$(jq -r 'select(.tool_name == "Bash")' "$log_file" | wc -l)
    if [[ $bash_count -gt 0 ]]; then
        echo "Bash commands: $bash_count"

        # Exit code stats
        local success=$(jq -r 'select(.tool_name == "Bash" and .tool_response.exitCode == 0)' "$log_file" | wc -l)
        local failure=$(jq -r 'select(.tool_name == "Bash" and .tool_response.exitCode != 0)' "$log_file" | wc -l)

        echo "  Successful: $success"
        echo "  Failed: $failure"
        echo ""
    fi

    # Time range
    local first=$(head -1 "$log_file" | jq -r '.timestamp')
    local last=$(tail -1 "$log_file" | jq -r '.timestamp')
    echo "Time range: $first → $last"

    # Git branches
    local branches=$(jq -r '.git_branch // empty' "$log_file" | sort -u)
    if [[ -n "$branches" ]]; then
        echo ""
        echo "Git branches:"
        echo "$branches" | sed 's/^/  /'
    fi
}

# Main command processing
COMMAND="${1:-}"
shift || true

VERBOSE=false
JSON_OUTPUT=false
LIMIT=""

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -n|--lines)
            LIMIT="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

case "$COMMAND" in
    last)
        LOG_FILE=$(get_latest_log)
        if [[ -z "$LOG_FILE" ]]; then
            echo "No logs found in $LOGS_DIR"
            exit 1
        fi

        echo "Latest session: $(basename "$LOG_FILE" .jsonl)"
        echo "=========================================="
        echo ""

        if [[ "$JSON_OUTPUT" == "true" ]]; then
            cat "$LOG_FILE"
        else
            cat "$LOG_FILE" | while IFS= read -r line; do
                format_entry "$line" "$VERBOSE"
            done
        fi
        ;;

    session)
        SESSION_ID="${1:-}"
        if [[ -z "$SESSION_ID" ]]; then
            echo "Error: session ID required"
            usage
        fi

        LOG_FILE="$LOGS_DIR/session-${SESSION_ID}.jsonl"
        if [[ ! -f "$LOG_FILE" ]]; then
            echo "Error: Session log not found: $LOG_FILE"
            exit 1
        fi

        if [[ "$JSON_OUTPUT" == "true" ]]; then
            cat "$LOG_FILE"
        else
            cat "$LOG_FILE" | while IFS= read -r line; do
                format_entry "$line" "$VERBOSE"
            done
        fi
        ;;

    sessions)
        list_sessions
        ;;

    bash)
        SESSION_ID="${1:-}"

        if [[ -n "$SESSION_ID" ]]; then
            LOG_FILE="$LOGS_DIR/session-${SESSION_ID}.jsonl"
        else
            LOG_FILE="$LOGS_DIR/session-*.jsonl"
        fi

        echo "Bash commands:"
        echo "=============="
        echo ""

        for file in $LOG_FILE; do
            [[ -f "$file" ]] || continue

            jq -c 'select(.tool_name == "Bash")' "$file" | while IFS= read -r line; do
                format_entry "$line" "$VERBOSE"
            done
        done
        ;;

    tool)
        TOOL_NAME="${1:-}"
        if [[ -z "$TOOL_NAME" ]]; then
            echo "Error: tool name required"
            usage
        fi

        echo "Tool: $TOOL_NAME"
        echo "================"
        echo ""

        for file in "$LOGS_DIR"/session-*.jsonl; do
            [[ -f "$file" ]] || continue

            jq -c --arg tool "$TOOL_NAME" 'select(.tool_name == $tool)' "$file" | \
                while IFS= read -r line; do
                    format_entry "$line" "$VERBOSE"
                done
        done
        ;;

    search)
        PATTERN="${1:-}"
        if [[ -z "$PATTERN" ]]; then
            echo "Error: search pattern required"
            usage
        fi

        echo "Searching for: $PATTERN"
        echo "======================="
        echo ""

        for file in "$LOGS_DIR"/session-*.jsonl; do
            [[ -f "$file" ]] || continue

            grep -i "$PATTERN" "$file" | while IFS= read -r line; do
                format_entry "$line" "$VERBOSE"
            done
        done
        ;;

    stats)
        SESSION_ID="${1:-}"

        if [[ -n "$SESSION_ID" ]]; then
            LOG_FILE="$LOGS_DIR/session-${SESSION_ID}.jsonl"
            if [[ ! -f "$LOG_FILE" ]]; then
                echo "Error: Session log not found: $LOG_FILE"
                exit 1
            fi
            show_stats "$LOG_FILE"
        else
            # Show stats for all sessions
            for file in "$LOGS_DIR"/session-*.jsonl; do
                [[ -f "$file" ]] || continue
                show_stats "$file"
                echo ""
            done
        fi
        ;;

    watch)
        LOG_FILE=$(get_latest_log)
        if [[ -z "$LOG_FILE" ]]; then
            echo "No logs found in $LOGS_DIR"
            exit 1
        fi

        echo "Watching: $LOG_FILE"
        echo "Press Ctrl+C to stop"
        echo ""

        tail -f "$LOG_FILE" | while IFS= read -r line; do
            format_entry "$line" "$VERBOSE"
        done
        ;;

    ""|-h|--help|help)
        usage
        ;;

    *)
        echo "Error: Unknown command: $COMMAND"
        usage
        ;;
esac
