# Agent instructions (via user CLAUDE.md)

## Ways of working

- read relavent README.md files when working in nested directories
- always check CLAUDE.md files after completing work to ensure they remain in sync with your changes
- When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
- Sub-agent concurrency: spawn multiple read-only agents freely (explore, research, browser), but only ever one mutating agent (e.g. coding) at a time. Don't run read-only agents alongside a mutating agent — they may read stale data.

## GitHub issues and PRs

- When reading GitHub issues or PRs, always use `gh issue view <n> --json title,body,comments` (or `gh pr view --json`) instead of plain `gh issue view`. The plaintext view strips images and embedded content.
- After extracting the JSON body, check for image URLs (`![](...)`, `<img src=...>`, `github.com/user-attachments/`). If present, download them with `curl` and view with the Read tool — they often contain critical context.

## Mandatory final review step

- After completing work and finishing verification, always run `code-review <prompt>` with the `Bash` Tool for a final review before reporting done.
  - `code-review` is long-running cli utility that invokes an API LLM; always invoke it with an extremely long timeout.
- In the review prompt, explicitly state what you worked on and why (goal and intent), not how you implemented it.
- If work is tied to a task/plan, explicitly reference that task/plan so reviewer can assess alignment with original requirements.
- Treat reviewer output as required follow-up: action all material feedback before final hand-off.
- Re-review: small fixes do not need to go back through re-review

## Code comments

### Changes to code

When commenting on code, always write in reference to the latest state of the code, unless the change should be explicitly called out.

- **BAD:** comment states the obvious
  ```js
  // fetch ther user
  const userInfo = await externalUserApi(userId);
  ```
- **GOOD:** comment explains ambiguous argument needed for api with reason
  ```js
  // api requires explicit null to avoid nested table joins, we aggregate extra data elsewhere
  const userInfo = await externalUserApi(userId, null);
  ```
- **BAD:** comment explains a change relative to old code, which no longer makes sense in isolation (this is the role of `git diff` and changelogs)
  ```diff
  - // api requires explicit null to avoid nested table joins, we aggregate extra data elsewhere
  - const userInfo = await externalUserApi(userId, null)
  + // api no longer requires null to avoid joins
  + const userInfo = await externalUserApiV2(userId)
  ```
- **BAD:** comment removed on improved api
  ```diff
  - // api requires explicit null to avoid nested table joins, we aggregate extra data elsewhere
  - const userInfo = await externalUserApi(userId, null)
  + const userInfo = await externalUserApiV2(userId)
  ```
