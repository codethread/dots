# Tmux Config

## Syntax validation

After editing tmux config files, validate syntax before considering the change done.

`-n` parses without executing and needs no running tmux server:

```bash
tmux source-file -n <file>
```
