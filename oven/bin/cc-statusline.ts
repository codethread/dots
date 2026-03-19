// :module: Claude Code statusline hook handler

import {$} from "bun";
import {parseArgs} from "util";
import {colorize} from "../shared/ansi";
import type {StatuslineInput} from "../shared/claude-hooks";
import {
	calculateContextSnapshot,
	extractUserText,
	formatTokenCount,
	isUserTextMessage,
} from "../shared/claude-transcript";
import {report, reportError} from "../shared/report";

function showHelp() {
	console.log(`cc-statusline - Process Claude Code statusline data and display custom status

Usage: cc-statusline [options]

Options:
  --help, -h     Show this help message

Description:
  Reads StatuslineInput from stdin and outputs formatted statusline information.
  Designed to be used as a Claude Code statusline hook.

Examples:
  # Test with example data
  echo '{"hook_event_name":"Status","session_id":"abc","transcript_path":"/path","cwd":"/Users/user/project","model":{"id":"claude-opus-4-1","display_name":"Opus"},"workspace":{"current_dir":"/Users/user/project","project_dir":"/Users/user/project"},"version":"1.0.80","output_style":{"name":"default"},"cost":{"total_cost_usd":0.01234,"total_duration_ms":45000,"total_api_duration_ms":2300,"total_lines_added":156,"total_lines_removed":23}}' | cc-statusline
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

	// Current directory with color
	const currentDir = input.workspace.current_dir;
	const projectDir = input.workspace.project_dir;
	const dirName = currentDir.split("/").pop() || currentDir;

	// Check if current dir is same as project dir (git root)
	const isGitRoot = currentDir === projectDir;
	const prefix = isGitRoot ? "" : "!";
	const dirDisplay = `${prefix}${dirName}`;
	parts.push(isGitRoot ? colorize.cyan(dirDisplay) : colorize.red(dirDisplay));

	// Fetch git branch, container status, and last prompt in parallel
	const [branch, inContainer, transcriptData] = await Promise.all([
		getGitBranch(currentDir),
		isInsideContainer(),
		getTranscriptData(input.transcript_path),
	]);

	// Container indicator
	if (inContainer) {
		parts.push(colorize.dimBlue(" "));
	}

	// Git branch
	if (branch) {
		parts.push(colorize.dimMagenta(`  ${branch}`));
	}

	// Model name
	const modelName = getShortModelName(input.model.display_name);
	parts.push(colorize.dimYellow(modelName));

	// Cost and token count formatted as ($0.77 | 132K +5K | 22%)
	const cost = input.cost.total_cost_usd.toFixed(2);
	const currentContext = formatTokenCount(transcriptData.contextSnapshot.currentContextSize);
	const delta = transcriptData.contextSnapshot.lastPromptDelta;
	const deltaDisplay = delta > 0 ? ` +${formatTokenCount(delta)}` : "";

	// Remaining percentage with color coding
	const remainingPercent = input.context_window?.remaining_percentage ?? 100;
	const remainingDisplay = `${remainingPercent.toFixed(0)}%`;
	const coloredRemaining =
		remainingPercent < 20
			? colorize.red(remainingDisplay)
			: remainingPercent < 50
				? colorize.yellow(remainingDisplay)
				: colorize.dim(remainingDisplay);

	parts.push(
		colorize.dim(`($${cost} | ${currentContext}${deltaDisplay} | `) + coloredRemaining + colorize.dim(")"),
	);

	// Last user prompt (truncated)
	// if (transcriptData.lastPrompt) {
	//   const truncated = truncateText(transcriptData.lastPrompt, 100);
	//   parts.push(colorize.dimItalic(`"${truncated}"`));
	// }

	return parts.join(" ");
}

async function getGitBranch(_cwd: string): Promise<string | null> {
	try {
		const result = await $`git branch --show-current`.text();
		return result.trim() || null;
	} catch {
		return null;
	}
}

async function isInsideContainer(): Promise<boolean> {
	// Podman/systemd-nspawn set the "container" env var (e.g. "podman", "oci")
	if (process.env.container) return true;

	try {
		const [containerenv, dockerenv] = await Promise.all([
			Bun.file("/.containerenv").exists(),
			Bun.file("/.dockerenv").exists(),
		]);
		if (containerenv || dockerenv) return true;

		// cgroup v1: /proc/1/cgroup contains /docker/ or container hash paths
		const cgroup = await Bun.file("/proc/1/cgroup").text();
		return /\/(docker|podman|kubepods|lxc)\//i.test(cgroup);
	} catch {
		return false;
	}
}

interface TranscriptData {
	lastPrompt: string | null;
	contextSnapshot: {currentContextSize: number; lastPromptDelta: number};
}

async function getTranscriptData(transcriptPath: string): Promise<TranscriptData> {
	try {
		// Read entire transcript file
		const result = await $`cat ${transcriptPath}`.text();
		const lines = result.trim().split("\n");

		const entries: unknown[] = [];
		let lastPrompt: string | null = null;

		// Parse all entries
		for (let i = 0; i < lines.length; i++) {
			try {
				const entry = JSON.parse(lines[i]);
				entries.push(entry);

				// Track last user prompt (search forward, so last one wins)
				if (isUserTextMessage(entry)) {
					const text = extractUserText(entry);
					if (text) {
						lastPrompt = text;
					}
				}
			} catch {}
		}

		// Calculate context snapshot
		const contextSnapshot = calculateContextSnapshot(entries);

		return {lastPrompt, contextSnapshot};
	} catch {
		return {
			lastPrompt: null,
			contextSnapshot: {currentContextSize: 0, lastPromptDelta: 0},
		};
	}
}

function getShortModelName(displayName: string): string {
	const lower = displayName.toLowerCase();
	if (lower.includes("opus")) return "opus";
	if (lower.includes("haiku")) return "haiku";
	return "sonnet";
}

function _truncateText(text: string, maxLength: number): string {
	// Remove newlines and extra whitespace
	const cleaned = text.replace(/\s+/g, " ").trim();
	if (cleaned.length <= maxLength) {
		return cleaned;
	}
	return `${cleaned.substring(0, maxLength - 1)}…`;
}

// Only run if executed directly
if (import.meta.main) {
	main();
}
