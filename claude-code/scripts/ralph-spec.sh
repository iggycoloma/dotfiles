#!/usr/bin/env bash
# ralph-spec.sh -- YAML frontmatter parsing helpers for ralph.sh --spec-file.
#
# A spec file is a markdown document whose first line is `---` and whose
# frontmatter contains a top-level `tasks:` list. Each task has at minimum
# id + description + verify + done. Example:
#
#     ---
#     spec_version: 1
#     tasks:
#       - id: add-auth
#         description: Add JWT middleware
#         verify: "make test"
#         done: false
#     ---
#
# This file is sourced by ralph.sh and tested directly by test-ralph.sh.
# It does NOT execute anything on source; it only defines functions.

# Extract the raw YAML frontmatter (between the first two `---` lines).
# Prints to stdout. Returns 0 if frontmatter found, 1 otherwise.
spec_extract_frontmatter() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    awk '
        BEGIN { in_fm = 0; seen_open = 0 }
        NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; seen_open = 1; next }
        in_fm && /^---[[:space:]]*$/ { exit }
        in_fm { print }
        END { if (!seen_open) exit 1 }
    ' "$file"
}

# Returns 0 if the file has a frontmatter block with a tasks: list, else 1.
spec_has_tasks() {
    local file="$1"
    local fm
    fm=$(spec_extract_frontmatter "$file" 2>/dev/null) || return 1
    grep -q '^tasks:' <<<"$fm"
}

# Print the id of the first task with done: false. Empty if none.
spec_next_task_id() {
    local file="$1"
    local fm
    fm=$(spec_extract_frontmatter "$file") || return 0

    if command -v yq &>/dev/null; then
        yq -r '.tasks[] | select(.done == false) | .id' <<<"$fm" 2>/dev/null | head -1
        return
    fi

    # awk fallback: walk the tasks block linearly. This is intentionally
    # conservative -- it only handles the canonical shape we document in
    # the template. Exotic YAML (anchors, flow maps) is not supported.
    # `exit` in awk still triggers END, so we pipe through head -1 to
    # dedupe if the loop printed a match before END ran.
    awk '
        /^tasks:/ { in_tasks = 1; next }
        in_tasks && /^[^[:space:]-]/ { in_tasks = 0 }
        in_tasks && /^[[:space:]]*-[[:space:]]*id:/ {
            if (found && !done_flag) { print id; exit }
            id = $0; sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", id)
            gsub(/^["'\'']|["'\'']$/, "", id)
            found = 1; done_flag = 0
        }
        in_tasks && /^[[:space:]]+done:/ {
            dv = $0; sub(/^[[:space:]]+done:[[:space:]]*/, "", dv)
            gsub(/[[:space:]]/, "", dv)
            if (dv == "true") done_flag = 1
        }
        END { if (found && !done_flag) print id }
    ' <<<"$fm" | head -1
}

# Print the verify command for a given task id. Empty if not found.
spec_task_verify() {
    local file="$1" task_id="$2"
    local fm
    fm=$(spec_extract_frontmatter "$file") || return 0

    if command -v yq &>/dev/null; then
        yq -r ".tasks[] | select(.id == \"$task_id\") | .verify // \"\"" <<<"$fm" 2>/dev/null
        return
    fi

    awk -v target="$task_id" '
        /^tasks:/ { in_tasks = 1; next }
        in_tasks && /^[^[:space:]-]/ { in_tasks = 0 }
        in_tasks && /^[[:space:]]*-[[:space:]]*id:/ {
            cur = $0; sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", cur)
            gsub(/^["'\'']|["'\'']$/, "", cur)
            match_task = (cur == target)
            verify = ""
        }
        in_tasks && match_task && /^[[:space:]]+verify:/ {
            verify = $0; sub(/^[[:space:]]+verify:[[:space:]]*/, "", verify)
            gsub(/^["'\'']|["'\'']$/, "", verify)
            print verify
            exit
        }
    ' <<<"$fm"
}

# Print "true" if all tasks in the spec have done: true, else "false".
spec_all_done() {
    local file="$1"
    local fm
    fm=$(spec_extract_frontmatter "$file") || { echo "false"; return; }

    if command -v yq &>/dev/null; then
        local total done_count
        total=$(yq '.tasks | length' <<<"$fm" 2>/dev/null || echo 0)
        done_count=$(yq '[.tasks[] | select(.done == true)] | length' <<<"$fm" 2>/dev/null || echo 0)
        if [[ "$total" -gt 0 ]] && [[ "$total" == "$done_count" ]]; then
            echo "true"
        else
            echo "false"
        fi
        return
    fi

    local total=0 done_count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*id: ]]; then
            total=$((total + 1))
        elif [[ "$line" =~ ^[[:space:]]+done:[[:space:]]*true ]]; then
            done_count=$((done_count + 1))
        fi
    done < <(awk '/^tasks:/ {in_tasks=1; next} in_tasks && /^[^[:space:]-]/ {in_tasks=0} in_tasks' <<<"$fm")

    if [[ $total -gt 0 ]] && [[ $total -eq $done_count ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Flip done: false -> done: true for the given task id, in place.
# Idempotent: no-op if the task is already done or not found.
spec_mark_done() {
    local file="$1" task_id="$2"
    [[ -f "$file" ]] || return 1

    # Use python if available for a safe, structure-aware edit. Otherwise
    # fall back to awk, which only handles the canonical template shape.
    if command -v python3 &>/dev/null; then
        python3 - "$file" "$task_id" <<'PYEOF'
import re, sys
path, task_id = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
if not m:
    sys.exit(0)
body_start = m.end()
fm = m.group(1)

# Find the block for the target id. We look for "  - id: <id>" and flip the
# matching done: line in that block (up to the next "- id:" or end of fm).
lines = fm.split("\n")
i = 0
in_target = False
while i < len(lines):
    line = lines[i]
    m2 = re.match(r'^(\s*)-\s*id:\s*["\']?([^"\'\s]+)["\']?\s*$', line)
    if m2:
        in_target = (m2.group(2) == task_id)
    elif in_target and re.match(r'^\s+done:\s*false\s*$', line):
        lines[i] = re.sub(r'done:\s*false', 'done: true', line)
        break
    i += 1

new_fm = "\n".join(lines)
with open(path, "w", encoding="utf-8") as f:
    f.write(f"---\n{new_fm}\n---\n{text[body_start:]}")
PYEOF
        return
    fi

    # Portable awk fallback.
    local tmp
    tmp=$(mktemp)
    awk -v target="$task_id" '
        BEGIN { in_fm = 0; in_target = 0; done_flipped = 0 }
        NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }
        in_fm && /^---[[:space:]]*$/ { in_fm = 0; in_target = 0; print; next }
        in_fm && /^[[:space:]]*-[[:space:]]*id:/ {
            cur = $0; sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", cur)
            gsub(/^["'\'']|["'\'']$/, "", cur); gsub(/[[:space:]]+$/, "", cur)
            in_target = (cur == target)
        }
        in_fm && in_target && !done_flipped && /^[[:space:]]+done:[[:space:]]*false/ {
            sub(/done:[[:space:]]*false/, "done: true")
            done_flipped = 1
        }
        { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Print the sha256 of the spec file (for version-drift detection).
spec_sha() {
    local file="$1"
    [[ -f "$file" ]] || { echo ""; return; }
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        echo ""
    fi
}
