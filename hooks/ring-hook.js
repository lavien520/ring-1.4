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

function postPermission(payload) {
  const body = JSON.stringify(payload);

  const options = {
    hostname: "127.0.0.1",
    port: RING_SERVER_PORT,
    path: "/permission",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
    },
    timeout: 60000,
  };

  return new Promise((resolve) => {
    const req = http.request(options, (res) => {
      let responseBody = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        if (responseBody.length < 1024) responseBody += chunk;
      });
      res.on("end", () => {
        try {
          resolve(JSON.parse(responseBody));
        } catch {
          resolve(null);
        }
      });
    });

    req.on("error", () => resolve(null));
    req.on("timeout", () => {
      req.destroy();
      resolve(null);
    });

    req.end(body);
  });
}

async function main() {
  const event = process.argv[2];

  // Debug: log hook invocation to file
  try {
    fs.appendFileSync(
      path.join(os.tmpdir(), "ring-hook.log"),
      `[${new Date().toISOString()}] event=${event} args=${process.argv.slice(2).join(" ")}\n`
    );
  } catch {}

  const payload = (await readStdinJson()) || {};
  const sessionId = payload.session_id || "default";
  const agentId = payload.agent_id || "claude-code";

  // PermissionRequest: send to ring app, wait for user decision
  if (event === "PermissionRequest") {
    const toolName = payload.tool_name || "unknown";
    const result = await postPermission({
      tool_name: toolName,
      session_id: sessionId,
      agent_id: agentId,
    });

    if (result && result.hookSpecificOutput) {
      process.stdout.write(JSON.stringify(result) + "\n");
    }
    process.exit(0);
  }

  const state = EVENT_TO_STATE[event];

  if (!state) {
    process.exit(0);
  }

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
