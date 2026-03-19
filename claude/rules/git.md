## Git Rules

### Committing

- Only commit when explicitly asked
- Summarize the "why" not the "what" in commit messages (1-2 sentences)
- Always pass commit messages via HEREDOC:
  ```
  git commit -m "$(cat <<'EOF'
  Commit message here.
  EOF
  )"
  ```

### Safety

- Investigate unexpected state (unfamiliar files, branches, lock files) before deleting or overwriting
- Resolve merge conflicts rather than discarding changes
