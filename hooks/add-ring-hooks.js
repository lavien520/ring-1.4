#!/usr/bin/env node
// Add Ring hooks to Claude Code settings

const fs = require("fs");
const path = require("path");
const os = require("os");

const SETTINGS_PATH = path.join(os.homedir(), ".claude", "settings.json");
const HOOK_SCRIPT = path.join(__dirname, "ring-hook.js");
const NODE_PATH = process.execPath;

// Events to hook
const EVENTS = [
  "SessionStart",
  "SessionEnd",
  "UserPromptSubmit",
  "PreToolUse",
  "PostToolUse",
  "PostToolUseFailure",
  "Stop",
  "StopFailure",
  "ApiError",
  "SubagentStart",
  "SubagentStop",
  "PreCompact",
  "PostCompact",
  "Notification",
  "Elicitation",
  "PermissionRequest",
];

function createHookEntry(event) {
  return {
    matcher: "",
    hooks: [
      {
        type: "command",
        command: `"${NODE_PATH}" "${HOOK_SCRIPT}" ${event}`,
        timeout: 5,
        async: true,
      },
    ],
  };
}

function addRingHooks(settings) {
  if (!settings.hooks) {
    settings.hooks = {};
  }

  for (const event of EVENTS) {
    if (!settings.hooks[event]) {
      settings.hooks[event] = [];
    }

    // Check if Ring hook already exists
    const hasRingHook = settings.hooks[event].some((entry) =>
      entry.hooks?.some((h) => h.command?.includes("ring-hook.js"))
    );

    if (!hasRingHook) {
      // Add Ring hook at the end
      settings.hooks[event].push(createHookEntry(event));
    }
  }

  return settings;
}

function main() {
  console.log("Adding Ring hooks to Claude Code settings...");
  console.log("Hook script:", HOOK_SCRIPT);

  // Read existing settings
  let settings = {};
  try {
    const content = fs.readFileSync(SETTINGS_PATH, "utf8");
    settings = JSON.parse(content);
    console.log("Existing settings loaded");
  } catch (err) {
    console.log("No existing settings found, creating new");
  }

  // Backup
  const backupPath = SETTINGS_PATH + ".backup." + Date.now();
  try {
    fs.copyFileSync(SETTINGS_PATH, backupPath);
    console.log("Backup created:", backupPath);
  } catch {
    // Ignore if file doesn't exist
  }

  // Add Ring hooks
  settings = addRingHooks(settings);

  // Write updated settings
  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), "utf8");
  console.log("Settings updated successfully!");

  console.log("\nRing hooks added for events:");
  EVENTS.forEach((e) => console.log(`  - ${e}`));

  console.log("\nThe ring will now respond to Claude Code events:");
  console.log("  - Rotate when Claude Code is working");
  console.log("  - Flash green when task completes");
  console.log("  - Show popup when confirmation is needed");

  console.log("\nMake sure the Ring app is running before using Claude Code");
}

main();
