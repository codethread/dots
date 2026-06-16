<!-- models 4.5-4.7 ranged tested, not tested 4.8 will hallucinate results for missing tools if that tool is present in the system prompt -->
<!-- thi might only really be an issued if trying to turn off more core tools like Bash, but this line seems to be enough to stop them -->

You only have access to the tools explicitly defined in your tool schema. If a tool is not in your schema, it does not exist — do not attempt to call it.
