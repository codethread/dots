---
name: mise-diff
description: >-
    Preview what applying mise-managed dotfiles would change, including native structured merges, and pull live JSON template edits back into a machine overlay. Use when asked what `mise dot apply` or `mise bootstrap` would change, reviewing shared Codex settings or a template edit, or checking and syncing generated Claude settings.
---

# mise-diff

Show what `mise dot apply` will change before writing anything. Distinguish whole-file templates from native merge entries: templates replace their output, while merges preserve unrelated live keys.

## Run the helper

Requires mise 2026.10.4+, Bun, `patch`, and `diff`. Run the helper directly: a routine preview needs no implementation read, launcher-existence check, or dependency/config inventory. Investigate prerequisites if execution fails. The launcher locates this checkout and runs the tested Oven implementation without needing a build:

```nu
.agents/skills/mise-diff/scripts/mise-dot-diff
.agents/skills/mise-diff/scripts/mise-dot-diff ~/.claude/settings.json
.agents/skills/mise-diff/scripts/mise-dot-diff templates/codex-config.toml
.agents/skills/mise-diff/scripts/mise-dot-diff ~/.config/codex/config.toml/shared
```

`TARGET` accepts a destination, a destination/edit-id, or a configured source path. With no arguments, the helper checks drifting entries in **both** `files` and `edits` from `mise dot status -J`; tracked-only entries are not deployment drift. A destination selects all its edits; a source or edit-id can narrow the selection.

- Whole-file diffs reconstruct the desired file from `mise dot diff`; JSON is normalized to ignore key order and formatting. Non-JSON remains a text diff.
- Merge, block, and line entries use mise's native diff, scoped to each edit-id. Native merges already ignore unrelated keys and formatting-only differences.
- The helper prints apply commands but never runs them. Previews write only temporary files. Exit status 1 means an entry failed; report the failure rather than presenting a partial preview as complete.

## Scope and stopping rules

Use the requested target/profile; otherwise use no target and the current environment. Keep that selection unchanged through preview and any authorized apply. This checks native `[dotfiles]` entries, not dotty links or every bootstrap resource.

```text
Run helper
  |-- error    -> report the failed entry; do not call the preview complete
  |-- no drift -> report the checked scope and stop; no apply needed
  `-- drift    -> summarize changes, then follow the relevant ownership workflow below
```

A successful “all configured dotfiles are applied” result needs no follow-up source reads, config greps, or profile sweep. Reply with one sentence stating the checked scope, no drift, and no apply needed; omit routine tables, generic caveats, and offers to rerun. If the user requests a per-target inventory, use one untruncated `mise dot status -J` call instead.

Reading `MISE_ENV` is sufficient to name an explicitly selected default; otherwise say “current environment.” Do not enumerate local config files just to describe the selection, or infer other profiles are converged from an absence of `[dotfiles]` declarations: variables and loaded configuration can still change the output.

## Codex: native merge, not an overlay

Root `mise.toml` merges `templates/codex-config.toml` into `~/.config/codex/config.toml` through the `shared` edit. Use native commands directly if only this entry matters:

```nu
mise dot diff ~/.config/codex/config.toml/shared
mise dot apply --dry-run ~/.config/codex/config.toml/shared
# After reviewing and obtaining apply authorization:
mise dot apply ~/.config/codex/config.toml/shared
```

Tables merge recursively. Target-only keys, comments, and untouched TOML formatting survive. Arrays, including `skills.config`, are replaced wholesale; there is no per-path skill merge. Removing a source key leaves its target value behind. Malformed TOML fails without overwriting the target.

`--pull` is unnecessary for unrelated live keys and is **not supported for merge entries**. To keep a live edit to a managed key, update that key in the source explicitly before applying. Do not capture the entire live Codex file into the shared source: that would claim machine-local state and potentially secrets. There is no automatic reverse sync.

## Claude: pull live JSON template edits

Whole-file templates still overwrite application edits. Capture wanted live changes into the overlay before applying:

```nu
.agents/skills/mise-diff/scripts/mise-dot-diff --pull ~/.claude/settings.json
# After reviewing and obtaining write authorization:
.agents/skills/mise-diff/scripts/mise-dot-diff --pull --write ~/.claude/settings.json
mise dot apply ~/.claude/settings.json
```

`--pull` handles one whole-file JSON-object template. It prints differing or additional live values, merges them into the overlay, and reports template-owned keys absent from live (apply restores those; edit the template to remove them). Arrays replace wholesale in the pulled overlay; the template then unions `permissions` lists with its base, so a pulled permission list is harmless but redundant—trim it to the additions. `--write` saves the overlay; without it nothing persistent is written.

Claude's template defaults to `~/.config/claude/settings-overlay.json`. Other JSON templates require `--into FILE` and must already consume that overlay; choosing a path does not wire it into the template. Malformed JSON fails visibly. Never use `mise dot add` on a template: it copies the rendered output over the source. For copy-mode entries, `mise dot add TARGET` is the native capture operation.

## Present the result

1. State the target/profile scope actually checked. On no drift, stop there; otherwise summarize actual setting changes and an apply recommendation per drifting target.
2. For merges, flag replacements of managed values/arrays, not unrelated live keys. For whole-file templates, flag any live-only values an apply would erase.
3. End with the narrow apply commands, only after review. `--yes` skips confirmation; it does not grant authorization.

## Caveats

- `status` and `diff` can execute trusted template functions. Claude's template shells out to `jq` and reads its overlay. A preview does not apply files, but is not inert.
- `mise dot diff` exits 0 even when content differs; inspect its output. Template `--dry-run` skips rendering, so use `diff` for an exact preview.
- Keep the same `MISE_ENV` and uncommitted `mise.local.toml` selection as the intended apply.
- History commands (`mise dot track`, `save`, `history`, `rollback`, `undo`) operate on live-file checkpoints, not reverse synchronization into merge sources.
- See the `mise` skill for changing `[dotfiles]` ownership. The helper implementation and tests live in `oven/bin/mise-dot-diff.ts` and `oven/tests/mise-dot-diff.test.ts`.
