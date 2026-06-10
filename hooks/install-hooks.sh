#!/bin/bash
# Install Ring hooks for Claude Code

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/ring-hook.js"

# Find Claude Code settings directory
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Ensure Claude directory exists
mkdir -p "$CLAUDE_DIR"

# Check if Node.js is available
if ! command -v node &>/dev/null; then
    echo "Error: Node.js is required but not found in PATH"
    echo "Please install Node.js first"
    exit 1
fi

NODE_PATH=$(command -v node)

# Events to hook
EVENTS=(
    "SessionStart"
    "SessionEnd"
    "UserPromptSubmit"
    "PreToolUse"
    "PostToolUse"
    "PostToolUseFailure"
    "Stop"
    "StopFailure"
    "ApiError"
    "SubagentStart"
    "SubagentStop"
    "PreCompact"
    "PostCompact"
    "Notification"
    "Elicitation"
    "PermissionRequest"
)

echo "Installing Ring hooks for Claude Code..."
echo "Hook script: $HOOK_SCRIPT"

# Build hooks configuration
HOOKS_CONFIG="{"
FIRST=true
for EVENT in "${EVENTS[@]}"; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        HOOKS_CONFIG+=","
    fi
    HOOKS_CONFIG+="\"$EVENT\":[{\"command\":\"$NODE_PATH $HOOK_SCRIPT $EVENT\"}]"
done
HOOKS_CONFIG+="}"

# Read existing settings or create new
if [ -f "$SETTINGS_FILE" ]; then
    echo "Existing settings found at $SETTINGS_FILE"
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%Y%m%d%H%M%S)"
    echo "Backup created"

    # Check if hooks already exist
    if grep -q '"hooks"' "$SETTINGS_FILE"; then
        echo "Warning: Hooks configuration already exists"
        echo "Please manually merge the hooks configuration"
        echo ""
        echo "Add this to your hooks section:"
        echo "$HOOKS_CONFIG" | python3 -m json.tool 2>/dev/null || echo "$HOOKS_CONFIG"
        exit 0
    fi

    # Add hooks to existing settings
    python3 -c "
import json
import sys

with open('$SETTINGS_FILE', 'r') as f:
    settings = json.load(f)

hooks = $HOOKS_CONFIG
settings['hooks'] = hooks

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)

print('Hooks added to existing settings')
"
else
    # Create new settings file
    cat > "$SETTINGS_FILE" << EOF
{
  "hooks": $HOOKS_CONFIG
}
EOF
    echo "New settings file created at $SETTINGS_FILE"
fi

echo ""
echo "Ring hooks installed successfully!"
echo ""
echo "The ring will now respond to Claude Code events:"
echo "  - Rotate when Claude Code is working"
echo "  - Flash green when task completes"
echo "  - Show popup when confirmation is needed"
echo ""
echo "Make sure the Ring app is running before using Claude Code"
