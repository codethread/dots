# Minimal Neovim Config

## Syntax validation

After editing any `.lua` file, validate syntax before considering the change done.

`loadfile` parses without executing, so `vim.*` globals won't cause false failures:

```bash
nvim --headless -l /dev/stdin <file> <<'EOF'
local f, err = loadfile(arg[1])
if err then
  io.stderr:write(err .. "\n")
  os.exit(1)
end
EOF
```
