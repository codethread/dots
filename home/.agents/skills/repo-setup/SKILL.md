---
name: repo-setup
description: >
    Set up or repair shared agent instructions, manage repository skills with Skillbox, pin tools and bootstrap development with mise, migrate Node tooling or consolidate workspaces, adopt Botlake, configure Markdown format-on-commit in a repository, or set up a projects or work host from its source repositories.
disable-model-invocation: true
---

# Repository setup

Use this skill as a routing layer. Read only the references needed for the requested setup; do not treat a partial setup request as permission to apply every recipe.

If not specific request is made, present the options to the user. Study the existing codebase first to gain context on the likely change the user wants before offering redundant recipes.

## Maintaining this skill

When editing `repo-setup` itself (this router or any supporting file), you must first read [Maintaining repo-setup](references/maintaining-repo-setup.md). That reference is for maintaining this skill in the dots repository only; it is not a setup recipe for other repositories.

## Route the work

| Requested outcome | Read before making changes |
| --- | --- |
| Set up or repair shared repository instructions | [Shared instructions](references/shared-instructions.md) |
| Install, migrate, or author repository skills with Skillbox | [Skills with Skillbox](references/skillbox.md) |
| Pin tools or provide repeatable project bootstrap with `mise run` | [Tooling and bootstrap with mise](references/mise-bootstrap.md) |
| Assess or migrate Node tooling, or consolidate maintained packages into workspaces | [Existing Node tooling and workspaces](references/node-workspaces.md) |
| Add a Markdown format command and format-on-commit | [Markdown formatting](references/markdown-formatting.md) |
| Adopt or configure Botlake for repository agent workflows | [Botlake integration](references/botlake.md) |

Follow references' links to shared prerequisites when they apply; load the shared procedure rather than duplicating it. In particular, the mise reference owns tool pinning and project bootstrap for every workflow.

For combined requests:

- Settle package-manager and workspace decisions before wiring bootstrap, CI, or formatting commands to them.
- Read the shared-instructions reference when another change requires updating repository instructions, and the Skillbox reference when it changes skill installation or discovery.
- Follow every applicable reference's validation steps, not just this entrypoint's completion checks.

## Host setup references

For workstation setup rather than a single repository, select the relevant host reference. These point to the current source repositories; they are not instructions to apply every repository recipe above.

| Host                          | Read before making changes                         |
| ----------------------------- | -------------------------------------------------- |
| Projects / public development | [Projects host setup](references/host-projects.md) |
| Work                          | [Work host setup](references/host-work.md)         |

## Complete the setup

Verify requested instruction and skill links resolve and are discoverable by the selected harnesses. When Botlake is in scope, verify its running lake and available operations as described in its reference. For formatting changes, use the behavior checks in the Markdown reference. Keep hook activation reproducible through tracked setup instructions or an entrypoint.

Report what was created or reused, which checks passed, and any remaining setup decisions or unverified behavior. Do not commit, push, discard pre-existing work, or rewrite the user's staged state without authorization.
