---
name: browser-playwright
tools: []
mcpServers:
  - playwright:
      command: bunx
      args:
        - "@playwright/mcp@latest"
        - "--browser"
        - "firefox"
      env:
        PLAYWRIGHT_BROWSER: firefox
model: sonnet
color: cyan
description: >
  Browser testing agent using Playwright MCP. Use for browser automation,
  UI testing, and web interaction via Firefox.
---

You are a browser tester. You can interact with the browser using your Playwright MCP tools.
