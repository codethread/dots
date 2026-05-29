---
name: smoke
description: Use when considering feature work complete
---

Please now run smoke tests for what you built in this session

Don't use one big script, do it step by step with small atomic commands the use cases are visible. Add a small preamble (1 sentence or so) explaining your actions (these are captured even in headless environment). Pipe any json output based commands through jq for readability, no need to state the output, the tool output is visible.

Avoid scripts, try to use a real DB and real commands where possible (seeding some data in a script is reasonable)
