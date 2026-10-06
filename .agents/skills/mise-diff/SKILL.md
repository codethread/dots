---
name: mise-diff
description: >-
    Preview what applying mise-managed dotfiles would change, with canonical diffs that ignore key order and formatting noise, and pull live-only edits (for example settings an app rewrote) back into the machine overlay. Use when asked what `mise dot apply` or `mise bootstrap` would change, when reviewing a `templates/*.tera` edit before applying, or when checking or syncing the generated `~/.claude/settings.json` and other `[dotfiles]` targets.
---

# mise-diff

Show what `mise dot apply` will change before anything is written, and strip the reordering/whitespace noise from the rendered diff.

## Run the helper

Run the helper; it locates the dots checkout itself:

```sh
.agents/skills/mise-diff/scripts/mise-dot-diff                     # all entries with drift
.agents/skills/mise-diff/scripts/mise-dot-diff ~/.claude/settings.json
.agents/skills/mise-diff/scripts/mise-dot-diff templates/claude-settings.json.tera
```

`TARGET` is either the destination path or the configured source path; with no argument every `[dotfiles]` entry not in state `applied` is checked. The helper:

- runs `mise dot diff` (renders with the current profile, vars, and overlay);
- rebuilds the rendered desired file and compares canonical JSON (`jq -S`), so key order, indentation, and blank lines do not appear as changes;
- prints per-target diffs and the exact apply commands; it writes nothing.

Exit status 1 means at least one entry failed to render or the desired side could not be reconstructed. Report that error plainly; do not present a partial diff as complete.

## Pull live edits back

Apps such as Claude Code rewrite `~/.claude/settings.json` directly, and the next render would undo those edits. Capture only the live-only changes into the machine overlay:

```sh
.agents/skills/mise-diff/scripts/mise-dot-diff --pull ~/.claude/settings.json          # show the merge
.agents/skills/mise-diff/scripts/mise-dot-diff --pull --write ~/.claude/settings.json  # save overlay
mise dot apply ~/.claude/settings.json                                                 # render it back
```

`--pull` takes one target, prints the live-only patch and the overlay it merges into, and lists template-owned keys missing from live (apply restores those, so edit the template if the deletion was intentional). `--into FILE` overrides the overlay path, which defaults to the Claude settings overlay only for that template. Never run `mise dot add` on a template target: it copies the rendered file over the `.tera` source. For copy-mode entries, `mise dot add TARGET` (or `mise dot add --changed`) is the built-in equivalent.

## Command map

| Need                              | Command                                                         |
| --------------------------------- | --------------------------------------------------------------- |
| See drift                         | `mise dot diff TARGET`, `mise dot status -J`, this helper       |
| Let the render win                | `mise dot apply TARGET`                                         |
| Keep live-only edits              | `--pull --write TARGET`, then apply                             |
| Seed a copy-mode source from live | `mise dot add TARGET`                                           |
| Audit live edits                  | `mise dot track PATH`, `mise dot save`, `mise dot history diff` |
| Restore a checkpoint              | `mise dot rollback`, `mise dot undo`                            |

## Present the result

Lead with the semantic changes, not the raw diff:

1. One line per target: number of real changes and an apply recommendation.
2. Bullet the actual changes (e.g. `autoCompactEnabled: true → false`, `extraKnownMarketplaces.harnesses` removed).
3. Flag anything an apply would overwrite: live-only keys, edits made directly to the generated file, or settings Claude Code rewrote itself.
4. End with the apply command(s), noting `--yes` skips the confirmation prompt.

## Caveats

- Rendering executes trusted template functions. `templates/claude-settings.json.tera` shells out to `jq` and reads `~/.config/claude/settings-overlay.json`; the preview writes nothing to the target but is not inert.
- `mise dot diff` exits 0 even when content differs; judge by the output.
- Non-JSON templates fall back to the raw unified diff.
- `MISE_ENV` and uncommitted `mise.local.toml` values are part of the preview; use the same environment selection as the machine being previewed.
- Durable customizations belong in the template or the overlay, never in the generated file. See the `mise` skill for `[dotfiles]` configuration changes.
