#!/usr/bin/env bun
// :module: Claude Code statusline hook handler

import {rename} from "node:fs/promises";
import {$} from "bun";
import {parseArgs} from "util";
import {colorize} from "../shared/ansi";
import type {StatuslineInput} from "../shared/claude-hooks";
import {report, reportError} from "../shared/report";

function showHelp() {
	console.log(`cc-statusline - Process Claude Code statusline data and display custom status

Usage: cc-statusline [options]

Options:
  --help, -h     Show this help message

Description:
  Reads StatuslineInput from stdin and outputs formatted statusline information.
  Designed to be used as a Claude Code statusline hook.
`);
	process.exit(0);
}

// biome-ignore lint/suspicious/noEmptyInterface: Future options will be added here
export interface CcStatuslineOptions {}

async function main() {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			help: {type: "boolean", short: "h"},
		},
		strict: false,
	});

	if (values.help) {
		showHelp();
	}

	try {
		const stdinData = await Bun.stdin.text();
		const result = await ccStatuslineLib(stdinData, {});
		report(result);
	} catch (err) {
		reportError(err);
		process.exit(1);
	}
}

export async function ccStatuslineLib(stdinData: string, _options: CcStatuslineOptions): Promise<string> {
	if (!stdinData.trim()) {
		return "";
	}

	const statusInput = JSON.parse(stdinData) as StatuslineInput;
	return await formatStatusline(statusInput);
}

async function formatStatusline(input: StatuslineInput): Promise<string> {
	const parts: string[] = [];

	// Directory name, red with ! prefix if not at git root
	const currentDir = input.workspace.current_dir;
	const projectDir = input.workspace.project_dir;
	const dirName = currentDir.split("/").pop() || currentDir;
	const isGitRoot = currentDir === projectDir;
	const prefix = isGitRoot ? "" : "!";
	const dirDisplay = `${prefix}${dirName}`;

	const state = await readState(input.session_id);
	const [branch, inContainer, identity] = await Promise.all([
		getGitBranch(),
		isInsideContainer(),
		state.identity ? Promise.resolve(state.identity) : getBotlakeIdentity(input.cwd, input.session_id),
	]);
	const next = advanceState(
		{...state, identity: identity ?? state.identity},
		input.cost.total_api_duration_ms,
		Date.now(),
	);
	if (next !== state) await writeState(input.session_id, next);
	const lastMessage = next.lastMessageAt ? new Date(next.lastMessageAt) : null;

	// Build dir | branch segment, wrapped in green [] if in container
	const dirPart = inContainer
		? colorize.green(dirDisplay)
		: isGitRoot
			? colorize.cyan(dirDisplay)
			: colorize.red(dirDisplay);
	// Worktree dirs are named `<base>__<branch>`; the branch is already visible in the
	// dir name, so suppress the redundant branch segment when they match.
	const showBranch = branch && !branchMatchesWorktree(dirName, branch);
	const branchPart = showBranch ? colorize.magenta(`  ${branch}`) : "";
	const dirBranch = `${dirPart}${branchPart}`;

	if (inContainer) {
		parts.push(colorize.green("[") + dirBranch + colorize.green("]"));
	} else {
		parts.push(dirBranch);
	}

	// Model name
	parts.push(colorize.yellow(getShortModelName(input.model.display_name)));

	// Effort level
	if (input.effort) {
		parts.push(formatEffort(input.effort.level));
	}

	// Context window usage
	const cw = input.context_window;
	if (cw) {
		const usedPercent = cw.used_percentage;
		const contextDisplay = `${usedPercent.toFixed(0)}% / ${formatContextSize(cw.context_window_size)}`;
		const coloredContext =
			usedPercent >= 80
				? colorize.red(contextDisplay)
				: usedPercent >= 60
					? colorize.yellow(contextDisplay)
					: colorize.brightBlack(contextDisplay);
		parts.push(coloredContext);
	}

	parts.push(colorize.brightBlack(formatCost(input.cost.total_cost_usd)));
	const usage = formatRateLimits(input.rate_limits);
	if (usage) parts.push(colorize.brightBlack(usage));
	// Time of the last model response, not the wall clock: the prompt cache expires from here,
	// and a static value means the statusline doesn't need to tick to stay correct.
	// Shown only once a response has been observed this session.
	if (lastMessage) parts.push(colorize.brightBlack(formatTime(lastMessage)));

	if (!identity) return parts.join(" ");

	// Botlake agent identity (formatted like the pi statusline), right-aligned when the width is known.
	// If it can't fit in full, drop trailing segments (time, cost, context...) rather than clip it.
	const right = colorize.blue(formatBotlakeIdentity(identity));
	const width = await getTerminalWidth();
	if (width) {
		const budget = width - RENDER_MARGIN;
		while (parts.length > 1 && visibleWidth(parts.join(" ")) + 1 + visibleWidth(right) > budget) {
			parts.pop();
		}
	}
	return joinRightAligned(parts.join(" "), right, width);
}

/**
 * Claude Code renders the statusline in `width - 2` columns after its own 2-column left
 * padding, so content gets `width - 4`; anything longer is clipped with an ellipsis.
 * Measured against a live session (126 columns rendered in a 128-column terminal).
 */
const RENDER_MARGIN = 4;

export function visibleWidth(text: string): number {
	// biome-ignore lint/suspicious/noControlCharactersInRegex: strip ANSI escape sequences
	return [...text.replace(/\u001b\[[0-9;]*m/g, "")].length;
}

/** Pad between `left` and `right` so `right` ends at the terminal edge; one space when it doesn't fit. */
export function joinRightAligned(left: string, right: string, width: number | null): string {
	if (!width) return `${left} ${right}`;
	const pad = width - RENDER_MARGIN - visibleWidth(left) - visibleWidth(right);
	return `${left}${" ".repeat(Math.max(pad, 1))}${right}`;
}

/**
 * Terminal width in columns, or null if unknown.
 *
 * The statusline runs with piped stdio and no controlling tty, so walk up the process
 * tree to the first ancestor that owns a tty (Claude Code) and ask `stty` for its size.
 */
async function getTerminalWidth(): Promise<number | null> {
	const direct = process.stdout.columns || Number(process.env.COLUMNS);
	if (direct > 0) return direct;

	try {
		let pid = process.ppid;
		for (let depth = 0; pid > 1 && depth < 6; depth++) {
			const info = (await $`ps -o tty=,ppid= -p ${pid}`.quiet().nothrow().text()).trim().split(/\s+/);
			const [tty, ppid] = info;
			if (tty && tty !== "??" && tty !== "?") {
				const dev = `/dev/${tty}`;
				const size = (await $`stty size < ${dev}`.quiet().nothrow().text()).trim().split(/\s+/);
				const cols = Number(size[1]);
				return cols > 0 ? cols : null;
			}
			pid = Number(ppid);
		}
	} catch {}
	return null;
}

const STATE_DIR = "/tmp/cc-statusline";

/** Per-session values persisted between statusline runs. */
export interface SessionState {
	/** Botlake identity; stable for a session, so resolved once. */
	identity?: string;
	/** `cost.total_api_duration_ms` at the last run, to detect a new model response. */
	apiMs?: number;
	/** Epoch ms when `apiMs` last changed, i.e. roughly when the last response finished. */
	lastMessageAt?: number;
}

/**
 * Advance state with this run's API duration. A changed duration means a response landed
 * since the last run, so stamp it; an unchanged one (timer refresh, resize) keeps the old stamp.
 */
export function advanceState(prev: SessionState, apiMs: number, now: number): SessionState {
	if (prev.apiMs === undefined) return {...prev, apiMs};
	if (prev.apiMs === apiMs) return prev;
	return {...prev, apiMs, lastMessageAt: now};
}

function statePath(sessionId: string): string {
	return `${STATE_DIR}/${sessionId.replace(/[^A-Za-z0-9_-]/g, "_")}.json`;
}

async function readState(sessionId: string): Promise<SessionState> {
	try {
		return (await Bun.file(statePath(sessionId)).json()) as SessionState;
	} catch {
		return {};
	}
}

async function writeState(sessionId: string, state: SessionState): Promise<void> {
	try {
		const path = statePath(sessionId);
		const tmp = `${path}.${process.pid}.tmp`;
		await Bun.write(tmp, JSON.stringify(state)); // creates STATE_DIR
		await rename(tmp, path); // atomic: concurrent runs never see a partial file
	} catch {}
}

function branchMatchesWorktree(dirName: string, branch: string): boolean {
	const idx = dirName.indexOf("__");
	if (idx === -1) return false;
	return dirName.slice(idx + 2) === branch;
}

export function formatBotlakeIdentity(actor: string): string {
	// biome-ignore lint/suspicious/noControlCharactersInRegex: strip terminal control characters
	return `bl: ${actor.replace(/[\u0000-\u001f\u007f]+/g, " ").trim()}`;
}

/**
 * Resolve this Claude session's Botlake identity.
 *
 * `BL_ACTOR` is only exported to Bash tool calls (via CLAUDE_ENV_FILE), so the statusline
 * process can't read it. Look the identity up by native session id instead.
 */
async function getBotlakeIdentity(cwd: string, sessionId: string): Promise<string | null> {
	const script = `
		const page = await api.call("node", {
			command: "list",
			where: q.and(
				q.eq(q.attr("identity/session"), true),
				q.eq(q.attr("identity/provider"), "claude"),
				q.eq(q.attr("identity/native-session-id"), ${JSON.stringify(sessionId)})
			),
			lean: false,
			limit: 2
		});
		return page.total === 1 ? page.nodes[0].attributes["identity/id"] : null;
	`;
	try {
		const out = await $`botlake lake eval ${script}`.cwd(cwd).quiet().nothrow().text();
		const identity: unknown = JSON.parse(out);
		return typeof identity === "string" && identity.trim() ? identity : null;
	} catch {
		return null;
	}
}

async function getGitBranch(): Promise<string | null> {
	try {
		const result = await $`git branch --show-current`.text();
		return result.trim() || null;
	} catch {
		return null;
	}
}

async function isInsideContainer(): Promise<boolean> {
	if (process.env.container) return true;

	try {
		const [containerenv, dockerenv] = await Promise.all([
			Bun.file("/.containerenv").exists(),
			Bun.file("/.dockerenv").exists(),
		]);
		if (containerenv || dockerenv) return true;

		const cgroup = await Bun.file("/proc/1/cgroup").text();
		return /\/(docker|podman|kubepods|lxc)\//i.test(cgroup);
	} catch {
		return false;
	}
}

function formatContextSize(tokens: number): string {
	if (tokens >= 500_000) return `${Math.round(tokens / 1_000_000)}m`;
	return `${Math.round(tokens / 1_000)}k`;
}

function formatCost(usd: number): string {
	return `$${usd.toFixed(2)}`;
}

/** `(session%/weekly%)`; a window the input doesn't report shows `-`, and none at all (e.g. API-key auth) shows nothing. */
export function formatRateLimits(limits: StatuslineInput["rate_limits"]): string | null {
	const session = limits?.five_hour?.used_percentage;
	const weekly = limits?.seven_day?.used_percentage;
	if (session === undefined && weekly === undefined) return null;
	const pct = (v: number | undefined) => (v === undefined ? "-" : `${Math.round(v)}%`);
	return `(${pct(session)}/${pct(weekly)})`;
}

function formatTime(date: Date): string {
	const hh = date.getHours().toString().padStart(2, "0");
	const mm = date.getMinutes().toString().padStart(2, "0");
	return `[${hh}:${mm}]`;
}

function formatEffort(level: "low" | "medium" | "high" | "xhigh" | "max"): string {
	const labels: Record<string, string> = {low: "l", medium: "m", high: "h", xhigh: "xh", max: "mx"};
	const label = labels[level] ?? level[0];
	if (level === "low") return colorize.blue(label);
	if (level === "medium") return colorize.cyan(label);
	if (level === "high") return colorize.green(label);
	if (level === "xhigh") return colorize.magenta(label);
	return colorize.red(label);
}

function getShortModelName(displayName: string): string {
	const lower = displayName.toLowerCase();
	if (lower.includes("opus")) return "opus";
	if (lower.includes("haiku")) return "haiku";
	if (lower.includes("fable")) return "fable";
	return "sonnet";
}

// Only run if executed directly
if (import.meta.main) {
	main();
}
