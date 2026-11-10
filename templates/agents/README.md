# Global agent instructions

Mise renders each harness template with `common.md`, then writes the complete global instruction file. Edit the base for shared rules and the harness template for additions.

| Template         | Destination                                                                        |
| ---------------- | ---------------------------------------------------------------------------------- |
| `claude.md.tera` | `~/.claude/CLAUDE.md`                                                              |
| `codex.md.tera`  | `$CODEX_HOME/AGENTS.md` (currently `~/.config/codex/AGENTS.md`)                    |
| `pi.md.tera`     | `$PI_CODING_AGENT_DIR/APPEND_SYSTEM.md` (currently `~/.pi/agent/APPEND_SYSTEM.md`) |

The shared base contains the `qlock`, cloning, and Skillbox instructions. Claude keeps its temporary-directory rule; Codex keeps its development and browser rules. Pi's model, tool, UI, and directory conditions stay in [the existing Nunjucks file](../../pi/agent/agent.njk), evaluated by Pi at session startup. The cloning rule becomes unconditional for Pi, as it already is for Claude and Codex.

Pi discovers the global append file in its agent directory, rather than directly under `~/.pi`. A trusted project's `.pi/APPEND_SYSTEM.md` takes precedence over the global file; Pi does not concatenate the two discovered files.

Run from this checkout after editing the shared base, a harness template, or Pi's Nunjucks rules:

```sh
mise run link
```

This applies the repository's symlinks and renders the three global instruction files. Plain `mise run` invokes the full workstation bootstrap.

Preview only the generated instruction changes:

```sh
mise dot diff "$HOME/.claude/CLAUDE.md" "$HOME/.config/codex/AGENTS.md" "$HOME/.pi/agent/APPEND_SYSTEM.md"
```

Mise owns the generated files; edit these templates rather than the outputs. Pi's Nunjucks file continues deploying through the Pi symlink group. Start a new harness session or reload Pi to load changed instructions.
