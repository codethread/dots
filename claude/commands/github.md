---
description: "Read GitHub issues and PRs with full context including images. Use when investigating or working on a GitHub issue or PR."
argument-hint: <issue-or-pr-number-or-url>
---

# GitHub Issue & PR Reading

You already have `gh` available — no special setup needed.

## Extracting full content

`gh issue view` and `gh pr view` render markdown to plaintext, which **drops images and embedded content**. Always use `--json` to get the raw body when the issue or PR might contain images, screenshots, or diagrams:

```bash
# Issues — get body + comments with image URLs intact
gh issue view <number> --json title,body,comments

# PRs — get body + comments
gh pr view <number> --json title,body,comments
```

## Viewing images

After extracting the JSON body, check for image URLs (patterns like `![...](https://...)`, `<img src=...>`, or `https://github.com/user-attachments/...`).

If images are present, **you must download and view them** — they often contain critical context like error screenshots, UI mockups, or architecture diagrams:

```bash
curl -fsSL "<image-url>" -o /tmp/image.png
```

Then use the Read tool on the downloaded file to view it.

Delegate image fetching to a subagent if there are many images.

## Arguments

$ARGUMENTS
