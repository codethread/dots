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
	const branchPart = branch ? colorize.dimMagenta(`  ${branch}`) : "";
	const dirBranch = `${dirPart}${branchPart}`;

	if (inContainer) {
		parts.push(colorize.green("[") + dirBranch + colorize.green("]"));
	} else {
		parts.push(dirBranch);
	}

	// Model name
	parts.push(colorize.dimYellow(getShortModelName(input.model.display_name)));

	// Token usage and remaining percentage
	const cw = input.context_window;
	const totalTokens = (cw?.total_input_tokens ?? 0) + (cw?.total_output_tokens ?? 0);
	parts.push(colorize.dim(formatTokenCount(totalTokens)));

	const remainingPercent = cw?.remaining_percentage ?? 100;
	const remainingDisplay = `${remainingPercent.toFixed(0)}%`;
	const coloredRemaining =
		remainingPercent < 20
			? colorize.red(remainingDisplay)
			: remainingPercent < 50
				? colorize.yellow(remainingDisplay)
				: colorize.dim(remainingDisplay);
	parts.push(coloredRemaining);

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

function formatTokenCount(tokens: number): string {
	if (tokens < 1000) return `${tokens}`;
	return `${Math.round(tokens / 1000)}k`;
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
