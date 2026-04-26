# Kitty Agent Notifications Specification

**Status:** Not Yet Implemented
**Last Updated:** 2026-04-21

## Purpose

Prevent Kitty desktop notifications from firing for agent CLI processes while leaving normal terminal notifications unchanged.

## Scope

Applies to the agent CLIs listed in [agentic-config.md](./agentic-config.md): `claude-code`, `codex`, and `pi`.

## Intended Behavior

- Kitty command-finish notifications stay enabled globally.
- Agent processes are excluded from those notifications.
- Filtering should be program-aware, not just based on window state.
