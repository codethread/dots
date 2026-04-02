# Nushell

## Syntax validation

After editing any `.nu` file, validate syntax before considering the change done:

```bash
nu -c 'nu-check --debug --as-module <file>'
```
