# macOS notifications with Computer Use

Verified on 2026-10-05 using `mcp__cua_repl.js` and `cc-notify` (experiment bead: `dots-1ql`). No screen-capture script was needed.

## Clear everything from the shell

Run `clear-notifications` with no arguments. Its source is [`home/.local/bin/clear-notifications`](../../home/.local/bin/clear-notifications). It clears banners and saved history from all apps using only macOS's `Close` and `Clear All` actions. It briefly opens the history panel through the menu-bar Clock control and closes it afterward, without activating an app or sending keyboard events. The active app, window, and focused input stayed unchanged in smoke checks. Mixed browser/native notifications took about 1.2 seconds; five consecutive empty runs took about 0.85 seconds each. The launcher needs Accessibility access and permission to automate System Events. Action labels match this Mac's English UI.

## Create a test notification

Run through the shell tool:

```bash
cc-notify --after 1s 'Agent notification test'
printf '%s\n' 'First body line' 'Second body line' | cc-notify --after 1s 'Agent notification test'
```

The command returns a scheduled status and session ID. Wait for delivery before inspecting. Use labelled test messages and clean them up afterward, within the user's authorization.

## Read the live notification

On the first Computer Use call, execute only this entrypoint and read the returned tool documentation:

```javascript
var nc = await cua.getApp("/System/Library/CoreServices/NotificationCenter.app");
```

The full path worked; the name `Notification Center` failed to resolve on this Mac (the app reports `Notification Centre`). The initial accessibility tree includes the current banner's source, title, body, and available actions. On a subsequent call:

```javascript
await nc.getAXStateAndScreenshot({ disableDiffing: true });
```

This showed the actual banner, including its icons and image. The surrounding desktop appeared white: this is a view of the notification app's layer, not the complete desktop. Observations are snapshots, not a continuous feed. A collapsed stack exposed only its newest notification; complete history listing was not verified.

## Dismiss

Use the notification container's index from the latest accessibility tree as `index`:

```javascript
await nc.performSecondaryAction(index, "Close"); // Single banner.
// Or, when the current tree offers it:
await nc.performSecondaryAction(index, "Clear All"); // Stack.
await nc.getAXState();
```

Both actions worked. The follow-up observation returned `noWindowsAvailable` after the final banner disappeared; that indicates no visible notification window, not proof that stored history is empty. `Show Details` and `Hide Details` expand/collapse a banner's contents. `Delete` appeared among Pushover's custom actions; use `Close` or `Clear All` for macOS dismissal.

Refresh the accessibility tree before choosing actions. A standalone `getScreenshot()` invalidated previously returned element indices in testing; use `getAXStateAndScreenshot()` or fetch a fresh tree afterward. Re-read state after every mutation, and only invoke actions actually offered by that state.
