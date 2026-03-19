## Mandatory final review step

- After completing work and finishing verification, always run `code-review <prompt>` with the `Bash` Tool for a final review before reporting done.
  - `code-review` is long-running cli utility that invokes an API LLM; always invoke it with an extremely long timeout.
  - Use default mode for quick review of small edits; use `code-review --deep <prompt>` for larger or riskier changes.
- In the review prompt, explicitly state what you worked on and why (goal and intent), not how you implemented it.
- If work is tied to a task/plan, explicitly reference that task/plan so reviewer can assess alignment with original requirements.
- Treat reviewer output as required follow-up: action all material feedback before final hand-off.
- Re-review: small fixes do not need to go back through re-review
