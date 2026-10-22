// :module: Notifications through the desktop or CC Notify when away from tmux

import {closeSync, openSync, writeFileSync} from "node:fs";
import {homedir} from "node:os";
import {join} from "node:path";
import {$} from "bun";
import {parseArgs} from "util";
import {reportError} from "../shared/report";

function showHelp() {
	console.log(`notif - Send desktop notifications, or CC Notify when away from tmux

Usage: notif <title> [details...]

Options:
  --help, -h  Show help

Delivery, in order of preference:
  1. CC Notify, inside tmux after ${AWAY_AFTER_SECONDS} seconds without input across all attached
     clients on that server, or immediately when all clients are detached.
  2. Terminal escape codes for Kitty (KITTY_WINDOW_ID) or Ghostty (GHOSTTY_RESOURCES_DIR,
     TERM_PROGRAM or TERM), with tmux passthrough when needed. Inside tmux they are
     written to the pane's tty, so headless shells in a pane can notify.
  3. AppleScript, otherwise, including outside tmux without a controlling terminal.

Reads tmux client_activity only when notifying; no hook or background polling.
CC Notify requires the local cc-notify service. Failures are reported without
switching delivery channels.

Notification duration follows system preferences. No buttons or click responses.
Ghostty title semicolons are displayed as fullwidth semicolons.

Examples:
  notif "Build finished" "All checks passed"
  notif "Reminder" "Take a break"
`);
}

export interface Notification {
	title: string;
	details: string;
}

type TerminalProtocol = "kitty" | "ghostty";

const AWAY_AFTER_SECONDS = 180;

async function main() {
	const notification = parseNotifArgs(Bun.argv.slice(2));
	if (!notification) {
		showHelp();
		return;
	}
	await notifLib(notification);
}

export async function notifLib(notification: Notification): Promise<void> {
	const inTmux = Boolean(process.env.TMUX);
	if (inTmux && tmuxIsAway(await $`tmux list-clients -F '#{client_activity}'`.quiet().text())) {
		await sendCcNotify(notification);
		return;
	}

	const protocol = terminalProtocol(process.env);
	const tty = protocol && (await openTerminal());
	if (tty === undefined) {
		await sendAppleScript(notification);
		return;
	}
	try {
		const payload = protocol === "kitty" ? await kittyPayload(notification) : ghosttyPayload(notification);
		writeFileSync(tty, inTmux ? wrapTmuxPassthrough(payload) : payload);
	} finally {
		closeSync(tty);
	}
}

export function parseNotifArgs(args: string[]): Notification | undefined {
	const {values, positionals} = parseArgs({
		args,
		options: {
			help: {type: "boolean", short: "h"},
		},
		allowPositionals: true,
	});
	if (values.help) return;
	const [title, ...details] = positionals;
	if (!title) throw new Error("A notification title is required. See notif --help.");
	return {title, details: details.join(" ")};
}

export function tmuxIsAway(clientActivity: string, nowSeconds = Date.now() / 1000): boolean {
	const activity = clientActivity.trim();
	if (!activity) return true;
	const timestamps = activity.split("\n").map((line) => {
		const timestamp = Number(line);
		if (!/^\d+$/.test(line) || !Number.isSafeInteger(timestamp)) {
			throw new Error(`Invalid tmux client_activity: ${JSON.stringify(line)}`);
		}
		return timestamp;
	});
	return nowSeconds - Math.max(...timestamps) >= AWAY_AFTER_SECONDS;
}

export function terminalProtocol(env: NodeJS.ProcessEnv): TerminalProtocol | undefined {
	if (env.KITTY_WINDOW_ID) return "kitty";
	if (env.GHOSTTY_RESOURCES_DIR || env.TERM_PROGRAM === "ghostty" || env.TERM === "xterm-ghostty") {
		return "ghostty";
	}
}

// Headless shells, such as agent tool calls, have no controlling terminal: /dev/tty fails with ENXIO.
// Inside tmux, the pane's tty reaches the same terminal regardless.
async function openTerminal(): Promise<number | undefined> {
	const pane = process.env.TMUX_PANE;
	if (pane) {
		const paneTty = await $`tmux display-message -p -t ${pane} '#{pane_tty}'`.quiet().text();
		return openSync(paneTty.trim(), "w");
	}
	try {
		return openSync("/dev/tty", "w");
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code === "ENXIO") return;
		throw error;
	}
}

async function kittyPayload({title, details}: Notification): Promise<string> {
	return $`kitten notify --only-print-escape-code -- ${title} ${details}`.quiet().text();
}

export function ghosttyPayload({title, details}: Notification): string {
	// OSC 777 has no escaping for the title delimiter or terminal control characters.
	const text = (value: string) =>
		value.replace(/\p{Cc}/gu, (char) => (char === "\n" || char === "\t" ? char : ""));
	return `\x1b]777;notify;${text(title).replaceAll(";", "；")};${text(details)}\x1b\\`;
}

export function wrapTmuxPassthrough(payload: string): string {
	return `\x1bPtmux;${payload.replaceAll("\x1b", "\x1b\x1b")}\x1b\\`;
}

async function sendAppleScript({title, details}: Notification): Promise<void> {
	const script = `on run argv
		display notification (item 2 of argv) with title (item 1 of argv)
	end run`;
	await $`osascript -e ${script} ${title} ${details}`.quiet();
}

async function sendCcNotify({title, details}: Notification): Promise<void> {
	const stateHome = process.env.XDG_STATE_HOME || join(homedir(), ".local", "state");
	const port = (await Bun.file(join(stateHome, "cc-notify", "port")).text()).trim();
	if (!/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535) {
		throw new Error(`Invalid cc-notify port: ${JSON.stringify(port)}`);
	}
	const response = await fetch(`http://localhost:${port}/notify`, {
		method: "POST",
		headers: {"Content-Type": "application/json"},
		body: JSON.stringify({
			title,
			message: details || title,
			session_id: `notif-${crypto.randomUUID()}`,
			notify_at: Date.now(),
		}),
	});
	if (!response.ok) {
		throw new Error(`cc-notify returned HTTP ${response.status}: ${await response.text()}`);
	}
}

if (import.meta.main) {
	main().catch((error) => {
		reportError(error);
		process.exitCode = 1;
	});
}
