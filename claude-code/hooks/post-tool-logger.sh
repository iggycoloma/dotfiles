#!/usr/bin/env bash
# Post-tool logging hook - Track all Claude Code tool usage
# Logs to JSONL format in ~/.claude/logs/session-{session_id}.jsonl

set -euo pipefail

# Validate dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

# Read hook input (read all stdin, not just first line)
input=$(cat)

# Extract core fields
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$input" | jq -c '.tool_input // {}')
TOOL_RESPONSE=$(echo "$input" | jq -c '.tool_response // {}')
CWD=$(echo "$input" | jq -r '.cwd // ""')

# Get timestamp and git info
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
GIT_BRANCH=""
if [[ -n "$CWD" ]] && [[ -d "$CWD/.git" ]]; then
    GIT_BRANCH=$(cd "$CWD" && git branch --show-current 2>/dev/null || echo "")
fi

# ============================================================================
# INTELLIGENT TRUNCATION BASED ON TOOL TYPE
# ============================================================================

# Configuration: which tools to log
# Options: "bash_only", "state_modifying", "all"
LOG_LEVEL="${CLAUDE_LOG_LEVEL:-state_modifying}"

# Check if we should log this tool
should_log() {
    case "$LOG_LEVEL" in
        bash_only)
            [[ "$TOOL_NAME" == "Bash" ]]
            ;;
        state_modifying)
            [[ "$TOOL_NAME" =~ ^(Bash|Write|Edit|NotebookEdit)$ ]]
            ;;
        all)
            true
            ;;
        *)
            # Default to state_modifying
            [[ "$TOOL_NAME" =~ ^(Bash|Write|Edit|NotebookEdit)$ ]]
            ;;
    esac
}

if ! should_log; then
    exit 0
fi

# Truncation functions
truncate_string() {
    local str="$1"
    local max_length="${2:-500}"
    local str_length=${#str}

    if [[ $str_length -le $max_length ]]; then
        echo "$str"
    else
        local half=$((max_length / 2))
        local start="${str:0:$half}"
        local end="${str: -$half}"
        echo "${start}...[truncated ${str_length} chars]...${end}"
    fi
}

truncate_lines() {
    local text="$1"
    local max_lines="${2:-500}"
    local head_lines="${3:-200}"
    local tail_lines="${4:-100}"

    local line_count=$(echo "$text" | wc -l)

    if [[ $line_count -le $max_lines ]]; then
        echo "$text"
    else
        local head_part=$(echo "$text" | head -n "$head_lines")
        local tail_part=$(echo "$text" | tail -n "$tail_lines")
        echo "${head_part}"
        echo "...[truncated $((line_count - head_lines - tail_lines)) lines]..."
        echo "${tail_part}"
    fi
}

# Apply tool-specific truncation
TRUNCATED_INPUT="$TOOL_INPUT"
TRUNCATED_RESPONSE="$TOOL_RESPONSE"

case "$TOOL_NAME" in
    Bash)
        # For Bash: truncate command output but keep full command
        COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')
        DESCRIPTION=$(echo "$TOOL_INPUT" | jq -r '.description // ""')

        # Extract response details with safe defaults
        STDOUT=$(echo "$TOOL_RESPONSE" | jq -r '.stdout // ""')
        STDERR=$(echo "$TOOL_RESPONSE" | jq -r '.stderr // ""')
        EXIT_CODE=$(echo "$TOOL_RESPONSE" | jq '.exitCode // null')  # Keep as JSON, not raw string

        # Truncate output
        TRUNCATED_STDOUT=$(truncate_lines "$STDOUT" 500 200 100)
        TRUNCATED_STDERR=$(truncate_lines "$STDERR" 100 50 50)

        # Get line counts safely
        STDOUT_LINES=$(echo "$STDOUT" | wc -l | tr -d ' ')
        STDERR_LINES=$(echo "$STDERR" | wc -l | tr -d ' ')

        # Rebuild response with truncation metadata
        TRUNCATED_RESPONSE=$(jq -n \
            --arg stdout "$TRUNCATED_STDOUT" \
            --arg stderr "$TRUNCATED_STDERR" \
            --argjson exitCode "${EXIT_CODE:-null}" \
            --argjson stdout_lines "$STDOUT_LINES" \
            --argjson stderr_lines "$STDERR_LINES" \
            '{
                stdout: $stdout,
                stderr: $stderr,
                exitCode: $exitCode,
                metadata: {
                    stdout_lines: $stdout_lines,
                    stderr_lines: $stderr_lines
                }
            }')
        ;;

    Write)
        # For Write: truncate content but keep file path
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
        CONTENT=$(echo "$TOOL_INPUT" | jq -r '.content // ""')
        CONTENT_LENGTH=${#CONTENT}
        CONTENT_LINES=$(echo "$CONTENT" | wc -l)

        TRUNCATED_CONTENT=$(truncate_string "$CONTENT" 500)

        TRUNCATED_INPUT=$(jq -n \
            --arg file_path "$FILE_PATH" \
            --arg content "$TRUNCATED_CONTENT" \
            --argjson content_length "$CONTENT_LENGTH" \
            --argjson content_lines "$CONTENT_LINES" \
            '{
                file_path: $file_path,
                content: $content,
                metadata: {
                    content_length: $content_length,
                    content_lines: $content_lines
                }
            }')
        ;;

    Edit)
        # For Edit: truncate old_string and new_string
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
        OLD_STRING=$(echo "$TOOL_INPUT" | jq -r '.old_string // ""')
        NEW_STRING=$(echo "$TOOL_INPUT" | jq -r '.new_string // ""')
        REPLACE_ALL=$(echo "$TOOL_INPUT" | jq -r '.replace_all // false')

        OLD_LENGTH=${#OLD_STRING}
        NEW_LENGTH=${#NEW_STRING}

        TRUNCATED_OLD=$(truncate_string "$OLD_STRING" 500)
        TRUNCATED_NEW=$(truncate_string "$NEW_STRING" 500)

        TRUNCATED_INPUT=$(jq -n \
            --arg file_path "$FILE_PATH" \
            --arg old_string "$TRUNCATED_OLD" \
            --arg new_string "$TRUNCATED_NEW" \
            --argjson replace_all "$REPLACE_ALL" \
            --argjson old_length "$OLD_LENGTH" \
            --argjson new_length "$NEW_LENGTH" \
            '{
                file_path: $file_path,
                old_string: $old_string,
                new_string: $new_string,
                replace_all: $replace_all,
                metadata: {
                    old_string_length: $old_length,
                    new_string_length: $new_length
                }
            }')
        ;;

    NotebookEdit)
        # For NotebookEdit: truncate source
        NOTEBOOK_PATH=$(echo "$TOOL_INPUT" | jq -r '.notebook_path // ""')
        NEW_SOURCE=$(echo "$TOOL_INPUT" | jq -r '.new_source // ""')
        SOURCE_LENGTH=${#NEW_SOURCE}

        TRUNCATED_SOURCE=$(truncate_string "$NEW_SOURCE" 500)

        TRUNCATED_INPUT=$(jq -n \
            --arg notebook_path "$NOTEBOOK_PATH" \
            --arg new_source "$TRUNCATED_SOURCE" \
            --argjson source_length "$SOURCE_LENGTH" \
            '{
                notebook_path: $notebook_path,
                new_source: $new_source,
                metadata: {
                    source_length: $source_length
                }
            }' \
            --argjson input "$TOOL_INPUT" \
            '. + ($input | {cell_id, cell_type, edit_mode})')
        ;;

    *)
        # For other tools: smart truncation that preserves JSON validity
        INPUT_SIZE=$(echo "$TOOL_INPUT" | jq -c . | wc -c | tr -d ' ')
        RESPONSE_SIZE=$(echo "$TOOL_RESPONSE" | jq -c . | wc -c | tr -d ' ')

        if [[ $INPUT_SIZE -gt 2000 ]]; then
            INPUT_PREVIEW=$(echo "$TOOL_INPUT" | jq -c . | head -c 500)
            TRUNCATED_INPUT=$(jq -n \
                --arg preview "${INPUT_PREVIEW}..." \
                --argjson size "$INPUT_SIZE" \
                '{_truncated: true, _size: $size, _preview: $preview}')
        else
            TRUNCATED_INPUT="$TOOL_INPUT"
        fi

        if [[ $RESPONSE_SIZE -gt 2000 ]]; then
            RESPONSE_PREVIEW=$(echo "$TOOL_RESPONSE" | jq -c . | head -c 500)
            TRUNCATED_RESPONSE=$(jq -n \
                --arg preview "${RESPONSE_PREVIEW}..." \
                --argjson size "$RESPONSE_SIZE" \
                '{_truncated: true, _size: $size, _preview: $preview}')
        else
            TRUNCATED_RESPONSE="$TOOL_RESPONSE"
        fi
        ;;
esac

# ============================================================================
# BUILD AND WRITE LOG ENTRY
# ============================================================================

LOG_FILE="$HOME/.claude/logs/session-${SESSION_ID}.jsonl"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Validate that we have valid JSON before building log entry
if ! echo "$TRUNCATED_INPUT" | jq empty 2>/dev/null; then
    TRUNCATED_INPUT=$(jq -n --arg error "Invalid JSON in input" --arg original "$TRUNCATED_INPUT" '{_error: $error, _original: $original}')
fi

if ! echo "$TRUNCATED_RESPONSE" | jq empty 2>/dev/null; then
    TRUNCATED_RESPONSE=$(jq -n --arg error "Invalid JSON in response" --arg original "$TRUNCATED_RESPONSE" '{_error: $error, _original: $original}')
fi

# Build log entry with error handling
if ! LOG_ENTRY=$(jq -nc \
    --arg timestamp "$TIMESTAMP" \
    --arg session_id "$SESSION_ID" \
    --arg tool_name "$TOOL_NAME" \
    --argjson tool_input "$TRUNCATED_INPUT" \
    --argjson tool_response "$TRUNCATED_RESPONSE" \
    --arg cwd "$CWD" \
    --arg git_branch "$GIT_BRANCH" \
    '{
        timestamp: $timestamp,
        session_id: $session_id,
        tool_name: $tool_name,
        tool_input: $tool_input,
        tool_response: $tool_response,
        cwd: $cwd,
        git_branch: $git_branch
    }' 2>/dev/null); then
    # Fallback: create minimal log entry on failure
    LOG_ENTRY=$(jq -nc \
        --arg timestamp "$TIMESTAMP" \
        --arg session_id "$SESSION_ID" \
        --arg tool_name "$TOOL_NAME" \
        --arg error "Failed to create full log entry" \
        --arg input_preview "${TRUNCATED_INPUT:0:200}" \
        --arg response_preview "${TRUNCATED_RESPONSE:0:200}" \
        '{
            timestamp: $timestamp,
            session_id: $session_id,
            tool_name: $tool_name,
            _error: $error,
            _input_preview: $input_preview,
            _response_preview: $response_preview
        }')
fi

# Append to log file (atomic write)
echo "$LOG_ENTRY" >> "$LOG_FILE"

# Success - don't block tool execution
exit 0
