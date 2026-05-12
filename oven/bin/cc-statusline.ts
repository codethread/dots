// :module: Claude Code statusline hook handler

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

	const [branch, inContainer] = await Promise.all([getGitBranch(), isInsideContainer()]);

	// Build dir | branch segment, wrapped in green [] if in container
	const dirPart = inContainer
		? colorize.green(dirDisplay)
		: isGitRoot
			? colorize.cyan(dirDisplay)
			: colorize.red(dirDisplay);
	const branchPart = branch ? colorize.magenta(`  ${branch}`) : "";
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
	parts.push(colorize.brightBlack(formatTime(new Date())));

	return parts.join(" ");
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

function formatTime(date: Date): string {
	const hh = date.getHours().toString().padStart(2, "0");
	const mm = date.getMinutes().toString().padStart(2, "0");
	return `[${hh}:${mm}]`;
}

function formatEffort(level: "low" | "medium" | "high" | "xhigh" | "max"): string {
	const labels: Record<string, string> = {low: "l", medium: "m", high: "h", xhigh: "xh", max: "m"};
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
	return "sonnet";
}

// Only run if executed directly
if (import.meta.main) {
	main();
}
