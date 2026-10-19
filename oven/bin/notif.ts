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

Uses Kitty when KITTY_WINDOW_ID is present, with tmux passthrough when needed.
Also supports Ghostty via GHOSTTY_RESOURCES_DIR, TERM_PROGRAM or TERM.
Otherwise uses AppleScript. Notification duration follows system preferences.
Requires an attached terminal for terminal delivery. No buttons or click responses.
Ghostty title semicolons are displayed as fullwidth semicolons.

Inside tmux, uses CC Notify after 180 seconds without input across all attached
clients on that server, or immediately when all clients are detached.
Reads tmux client_activity only when notifying; no hook or background polling.
Outside tmux, always uses desktop delivery. Away delivery requires the local
cc-notify service; failures are reported without switching delivery channels.

Examples:
  notif "Build finished" "All checks passed"
  notif "Reminder" "Take a break"
`);
}

export interface Notification {
	title: string;
	details: string;
}

async function main() {
	const notification = parseNotifArgs(Bun.argv.slice(2));
	if (!notification) {
		showHelp();
		return;
	}
	await notifLib(notification);
}

export async function notifLib(notification: Notification, env = process.env): Promise<void> {
	const away = env.TMUX
		? tmuxIsAway(await $`tmux list-clients -F '#{client_activity}'`.env(env).quiet().text())
		: false;
	const delivery = notificationDelivery(notification, env, away);
	if (delivery.backend === "cc-notify") {
		await sendCcNotification(notification, env);
		return;
	}
	if (delivery.backend === "applescript") {
		const script = `on run argv
			display notification (item 2 of argv) with title (item 1 of argv)
		end run`;
		await $`osascript -e ${script} ${notification.title} ${notification.details}`.quiet();
		return;
	}

	const payload =
		delivery.backend === "ghostty"
			? delivery.payload
			: await $`kitten notify --only-print-escape-code ${delivery.args}`.quiet().text();
	const tty = openSync("/dev/tty", "w");
	try {
		writeFileSync(tty, delivery.tmux ? wrapTmuxNotification(payload) : payload);
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

export function notificationDelivery(notification: Notification, env: NodeJS.ProcessEnv, away = false) {
	if (away) return {backend: "cc-notify"} as const;
	if (env.KITTY_WINDOW_ID) {
		const args = ["--", notification.title, notification.details];
		return {backend: "kitty", args, tmux: Boolean(env.TMUX)} as const;
	}
	if (env.GHOSTTY_RESOURCES_DIR || env.TERM_PROGRAM === "ghostty" || env.TERM === "xterm-ghostty") {
		return {
			backend: "ghostty",
			payload: ghosttyNotification(notification),
			tmux: Boolean(env.TMUX),
		} as const;
	}
	return {backend: "applescript"} as const;
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
	return nowSeconds - Math.max(...timestamps) >= 180;
}

async function sendCcNotification(notification: Notification, env: NodeJS.ProcessEnv): Promise<void> {
	const stateHome = env.XDG_STATE_HOME || join(homedir(), ".local", "state");
	const port = (await Bun.file(join(stateHome, "cc-notify", "port")).text()).trim();
	if (!/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535) {
		throw new Error(`Invalid cc-notify port: ${JSON.stringify(port)}`);
	}
	const response = await fetch(`http://localhost:${port}/notify`, {
		method: "POST",
		headers: {"Content-Type": "application/json"},
		body: JSON.stringify({
			title: notification.title,
			message: notification.details || notification.title,
			session_id: `notif-${crypto.randomUUID()}`,
			notify_at: Date.now(),
		}),
	});
	if (!response.ok) {
		throw new Error(`cc-notify returned HTTP ${response.status}: ${await response.text()}`);
	}
}

export function ghosttyNotification(notification: Notification): string {
	// OSC 777 has no escaping for the title delimiter or terminal control characters.
	const text = (value: string) =>
		value.replace(/\p{Cc}/gu, (char) => (char === "\n" || char === "\t" ? char : ""));
	const title = text(notification.title).replaceAll(";", "；");
	return `\x1b]777;notify;${title};${text(notification.details)}\x1b\\`;
}

export function wrapTmuxNotification(payload: string): string {
	return `\x1bPtmux;${payload.replaceAll("\x1b", "\x1b\x1b")}\x1b\\`;
}

if (import.meta.main) {
	main().catch((error) => {
		reportError(error);
		process.exitCode = 1;
	});
}
