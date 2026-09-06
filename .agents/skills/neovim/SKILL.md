---
name: neovim
description: Search and read the locally installed Neovim help when developing Neovim configuration or plugins, especially for APIs, options, commands, events, and runtime behavior.
---

# Neovim help

Consult the installed Neovim help before relying on memory or the web. It matches the version actually being developed against.

## Discover help topics

Use `:helpgrep` to search core documentation. It accepts a Vim regex; append `\c` for case-insensitive matching. Opening and printing the quickfix list produces compact search results on stdout.

```bash
pattern='vim\.pack\.add'
nvim --clean --headless \
  "+silent helpgrep ${pattern}" \
  '+copen' \
  '+%print' \
  '+qa'
```

Use `--clean` by default so configuration startup errors and side effects do not affect core documentation searches.

When searching documentation supplied by configured plugins, omit `--clean` so the user's configuration can make those plugins and their help tags available:

```bash
pattern='telescope.*picker\c'
nvim --headless \
  "+silent helpgrep ${pattern}" \
  '+copen' \
  '+%print' \
  '+qa'
```

This executes the user's Neovim configuration. Use it only when plugin documentation is relevant.

## Read an exact help tag

After identifying a tag, print it with enough following context:

```bash
tag='vim.pack.add'
nvim --clean --headless \
  "+help ${tag}" \
  '+.,+50print' \
  '+qa'
```

Increase the range when the section continues. To print the entire containing help file, replace `'+.,+50print'` with `'+%print'`.

To locate the source file and line for targeted reading with file tools:

```bash
tag='vim.pack.add'
nvim --clean --headless \
  "+help ${tag}" \
  '+lua print(vim.api.nvim_buf_get_name(0) .. ":" .. vim.fn.line("."))' \
  '+qa'
```

Omit `--clean` from exact-tag commands when the tag belongs to a configured plugin.
