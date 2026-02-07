#!/usr/bin/env bash
# Notification hook - Cross-platform desktop alert when Claude needs attention
# Triggered on the Notification event (user input required)

TITLE="Claude Code"
MESSAGE="Waiting for your input"

# macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null
    exit 0
fi

# WSL (Windows Subsystem for Linux)
if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
    powershell.exe -Command "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('$MESSAGE','$TITLE','OK','Information')" &>/dev/null &
    exit 0
fi

# Native Linux
if command -v notify-send &>/dev/null; then
    notify-send "$TITLE" "$MESSAGE" 2>/dev/null
    exit 0
fi

# Fallback: no notification available, silent success
exit 0
