#!/usr/bin/env node
// Ring — Claude Code Hook Script
// Usage: node ring-hook.js <event_name>
// Reads stdin JSON from Claude Code for session info

const http = require("http");
const fs = require("fs");
const os = require("os");
const path = require("path");

const RING_SERVER_PORT = 23334;
const RING_SERVER_HEADER = "x-ring-server";

// Event to state mapping (similar to Clawd on Desk)
// PermissionRequest is handled via HTTP hook directly (blocking),
// not via this command hook. See ~/.claude/settings.json.
const EVENT_TO_STATE = {
  SessionStart: "idle",
  SessionEnd: "sleeping",
  UserPromptSubmit: "thinking",
  PreToolUse: "working",
  PostToolUse: "working",
  PostToolUseFailure: "error",
  Stop: "idle",
  StopFailure: "error",
  ApiError: "error",
  SubagentStart: "working",
  SubagentStop: "working",
  PreCompact: "working",
  PostCompact: "idle",
  Notification: "notification",
  Elicitation: "attention",
};

function readStdinJson() {
  return new Promise((resolve) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => (data += chunk));
    process.stdin.on("end", () => {
      try {
        resolve(JSON.parse(data));
      } catch {
        resolve(null);
      }
    });
    process.stdin.on("error", () => resolve(null));
  });
}

function postState(payload) {
  const body = JSON.stringify(payload);

  const options = {
    hostname: "127.0.0.1",
    port: RING_SERVER_PORT,
    path: "/state",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
    },
    timeout: 100,
  };

  return new Promise((resolve) => {
    const req = http.request(options, (res) => {
      let responseBody = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        if (responseBody.length < 256) responseBody += chunk;
      });
      res.on("end", () => {
        const isRing =
          res.headers[RING_SERVER_HEADER] === "ring" ||
          (responseBody && responseBody.includes('"app":"ring"'));
        resolve(isRing);
      });
    });

    req.on("error", () => resolve(false));
    req.on("timeout", () => {
      req.destroy();
      resolve(false);
    });

    req.end(body);
  });
}

function extractSessionTitle(payload) {
  if (payload.session_title) return payload.session_title;
  if (payload.prompt) {
    const lines = payload.prompt.split(/\r?\n/);
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed && trimmed.length <= 80) return trimmed;
    }
  }
  return null;
}

async function main() {
  const event = process.argv[2];
  const state = EVENT_TO_STATE[event];

  if (!state) {
    process.exit(0);
  }

  const payload = (await readStdinJson()) || {};
  const sessionId = payload.session_id || "default";
  const agentId = payload.agent_id || "claude-code";

  const body = {
    state,
    session_id: sessionId,
    event,
    agent_id: agentId,
  };

  const title = extractSessionTitle(payload);
  if (title) body.session_title = title;

  if (payload.cwd) body.cwd = payload.cwd;
  if (payload.tool_name) body.tool_name = payload.tool_name;

  await postState(body);
  process.exit(0);
}

main();
