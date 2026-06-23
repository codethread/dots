# Kitty Agent Notifications Specification

Document ID: SPEC-005
Configuration identification: SPEC-005; migrated from `specs/kitty-notifications.md`; canonical path `devflow/specs/kitty-notifications.md`.
**Status:** Not Yet Implemented
**Last Updated:** 2026-04-21

## [SPEC-005-S1] Purpose

Prevent Kitty desktop notifications from firing for agent CLI processes while leaving normal terminal notifications unchanged.

## [SPEC-005-S2] Scope

Applies to the agent CLIs listed in [agentic-config.md](./agentic-config.md): `claude-code`, `codex`, and `pi`.

## [SPEC-005-S3] Intended Behavior

- Kitty command-finish notifications stay enabled globally.
- Agent processes are excluded from those notifications.
- Filtering should be program-aware, not just based on window state.
