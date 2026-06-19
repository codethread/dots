---
allowed-tools: Bash(cc-speak:*)
argument-hint: [optional initial message]
description: Enable audio communication mode for the session
disable-model-invocation: true
---

# Enable Audio Communication Mode

From this point forward in our session, use the `cc-speak` utility to provide audio versions of your responses and any relavent documentation. This enables hands-free interaction during coding sessions.

## Instructions for Claude Code

**IMPORTANT**: After executing this command, you must use the `cc-speak` utility for ALL subsequent responses in this session.

### How to Use cc-speak

The `cc-speak` command converts text to speech using TTS and plays it through the system audio. It automatically strips markdown formatting for better audio output.

#### Basic Usage Patterns:

1. **Speak text responses**:

   ```bash
   cc-speak --text "Your response text here"
   # Or shorthand:
   cc-speak -t "Your response text here"
   ```

2. **Speak entire files** (automatically strips markdown):

   ```bash
   cc-speak --file README.md
   # Or shorthand:
   cc-speak -f README.md
   ```

3. **Speak specific sections of files** using line numbers (1-indexed, inclusive):

   ```bash
   # Read lines 5 through 20
   cc-speak --file README.md --start=5 --end=20

   # Read from line 10 to end of file
   cc-speak --file README.md --start=10

   # Read from beginning to line 50
   cc-speak --file README.md --end=50
   ```

4. **Combine text and file** (text is spoken first, then file):
   ```bash
   cc-speak --text "Here's the documentation:" --file README.md
   ```

### Line Number Notes:

- Line numbers are 1-indexed (first line is 1, not 0)
- Both --start and --end are inclusive
- Negative indices are NOT supported
- If --end exceeds file length, an error will occur
- --start without --end reads from start line to EOF
- --end without --start reads from line 1 to end line

### Session Requirements:

1. **Always** speak your main responses using `cc-speak --text "..."`
2. **Include** both text and audio - show the text response normally, then speak it
3. **Continue** this behavior for the entire session until explicitly told to stop
4. Use concise, clear language optimized for audio comprehension

## Session Behavior Changes

- All responses should be spoken aloud via TTS
- Use concise, clear language optimized for audio
- Continue speaking responses until told `/stop-speaking` or session ends
- The cc-speak utility will automatically handle markdown cleanup and media pause/resume

## Initial message (optional)

$ARGUMENTS

---

**Audio mode is now ENABLED for this session. All subsequent responses will be spoken.**
