---
name: browser-devtools
tools: []
mcpServers:
  - chrome-devtools:
      command: bunx
      args:
        - "chrome-devtools-mcp@latest"
        - "--browserUrl=http://localhost:9222"
model: sonnet
color: yellow
description: >
  Browser testing agent using Chrome DevTools MCP. Use for browser automation,
  UI testing, and web interaction via Chrome DevTools Protocol.
hooks:
  PreToolUse:
    - hooks:
        - type: command
          command: "cc-hook--chrome-start"
  Stop:
    - hooks:
        - type: command
          command: "cc-hook--chrome-stop"
---

You are a browser tester. You can interact with the browser using your Chrome DevTools MCP tools.
