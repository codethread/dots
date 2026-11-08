#!/usr/bin/env bun
// :module: Claude Code hook that redirects npm/npx/node commands to the detected package manager (pnpm, bun, yarn)

import {existsSync} from "fs";
import {dirname, isAbsolute, resolve} from "path";
import {parseArgs} from "util";
import type {HookInput, PreToolUseInput} from "../shared/claude-hooks";
import {reportError} from "../shared/report";

function showHelp() {
	console.log(`
cc-hook--npm-redirect - Claude Code hook that redirects npm/npx/node commands to detected package manager

Usage: cc-hook--npm-redirect [options]

Options:
  --help, -h      Show this help message

This hook is designed to be called from Claude Code PreToolUse Bash hooks to automatically
redirect npm/npx/node commands to the appropriate package manager (pnpm, bun, yarn) based on
lock files in the project directory.

The hook will redirect:
- npm/npx commands to the detected package manager (pnpm, bun, yarn)
- node commands to bun in Bun projects (with compatibility warnings)

The hook ignores commands executed within Claude Code skill/plugin contexts to avoid interfering
with plugin marketplace skills or user-defined skills.

The hook reads stdin for the Claude Code hook input and will block the command with exit code 2
if a package manager mismatch is detected, suggesting the correct command to use instead.
`);
	process.exit(0);
}

export interface PackageManagerRedirectOptions {
	command: string;
	cwd?: string;
}

export interface NpmRedirectResult {
	shouldBlock: boolean;
	blockedCommand: string | null;
	suggestedCommand: string | null;
	detectedPackageManager: string;
	warning?: string;
}

async function main() {
	// Handle both direct execution and Claude Code invocation
	// Claude Code passes the command name as first argument after the script
	let args = Bun.argv.slice(2);
	if (args[0] === "cc-hook--npm-redirect") {
		args = args.slice(1);
	}

	const {values} = parseArgs({
		args,
		options: {
			help: {type: "boolean", short: "h"},
		},
		strict: true,
		allowPositionals: false,
	});

	if (values.help) {
		showHelp();
	}

	try {
		// Read stdin data from Claude Code hook
		const stdinData = await Bun.stdin.text();
		if (!stdinData.trim()) {
			process.exit(0);
		}

		const hookInput = JSON.parse(stdinData) as HookInput;

		// Only process PreToolUse Bash events
		if (hookInput.hook_event_name !== "PreToolUse") {
			process.exit(0);
		}

		const preToolUseInput = hookInput as PreToolUseInput;
		if (preToolUseInput.tool_name !== "Bash") {
			process.exit(0);
		}

		const commandValue = preToolUseInput.tool_input?.command;
		if (!commandValue || typeof commandValue !== "string") {
			process.exit(0);
		}

		const result = await ccHookNpmRedirectLib({
			command: commandValue,
			cwd: hookInput.cwd,
		});

		if (result.shouldBlock) {
			// Send error message to stderr for Claude to see
			let errorMessage = `Error: Use '${result.suggestedCommand}' instead of '${result.blockedCommand}'`;
			if (result.warning) {
				errorMessage += `\n${result.warning}`;
			}
			console.error(errorMessage);
			// Exit with code 2 to signal Claude to correct
			process.exit(2);
		}

		// Command is allowed, exit successfully
		process.exit(0);
	} catch (err) {
		reportError(err);
		process.exit(1);
	}
}

function isClaudeCodeSkillContext(cwd?: string): boolean {
	if (!cwd) {
		return false;
	}

	// Check if the path contains Claude Code skill/plugin markers
	// Skills from the plugin marketplace typically run in:
	// - .claude/plugins/* directories
	// - .claude/skills/* directories (user-defined skills)
	// - Plugin marketplace skills have paths like ~/.local/share/claude/plugins/
	const skillPatterns = ["/.claude/plugins/", "/.claude/skills/", "/claude/plugins/", "/claude/skills/"];

	return skillPatterns.some((pattern) => cwd.includes(pattern));
}

export async function ccHookNpmRedirectLib(
	options: PackageManagerRedirectOptions,
): Promise<NpmRedirectResult> {
	const {command, cwd} = options;

	// Ignore commands executed within Claude Code skill/plugin contexts
	// Skills from the plugin marketplace run in their own directory contexts
	if (isClaudeCodeSkillContext(cwd)) {
		// Detect the package manager but don't block
		const detectedPM = detectPackageManager(command, cwd);
		return {
			shouldBlock: false,
			blockedCommand: null,
			suggestedCommand: null,
			detectedPackageManager: detectedPM,
		};
	}

	// Detect the appropriate package manager based on lock files
	const detectedPM = detectPackageManager(command, cwd);

	// Check for package manager commands
	const result = checkPackageManagerMismatch(command, detectedPM);

	return {
		shouldBlock: result.blockedCommand !== null,
		blockedCommand: result.blockedCommand,
		suggestedCommand: result.suggestedCommand,
		detectedPackageManager: detectedPM,
		warning: result.warning,
	};
}

function isInsideQuotes(text: string, position: number): boolean {
	let inSingleQuote = false;
	let inDoubleQuote = false;
	let inBacktick = false;

	for (let i = 0; i < position; i++) {
		const char = text[i];
		const prevChar = i > 0 ? text[i - 1] : "";

		// Skip escaped quotes
		if (prevChar === "\\") {
			continue;
		}

		if (char === "'" && !inDoubleQuote && !inBacktick) {
			inSingleQuote = !inSingleQuote;
		} else if (char === '"' && !inSingleQuote && !inBacktick) {
			inDoubleQuote = !inDoubleQuote;
		} else if (char === "`" && !inSingleQuote && !inDoubleQuote) {
			inBacktick = !inBacktick;
		}
	}

	return inSingleQuote || inDoubleQuote || inBacktick;
}

function checkPackageManagerMismatch(
	command: string,
	detectedPM: string,
): {blockedCommand: string | null; suggestedCommand: string | null; warning?: string} {
	// Match package manager commands at word boundaries
	const npmPattern = /\bnpm\s+/g;
	const npxPattern = /\bnpx\s+/g;
	const yarnPattern = /\byarn\s+/g;
	const pnpmPattern = /\bpnpm\s+/g;
	const nodePattern = /\bnode\s+/g;

	let blockedCommand: string | null = null;
	let suggestedCommand: string | null = null;
	let warning: string | undefined;

	// Check npm pattern
	let match = npmPattern.exec(command);
	if (match && !isInsideQuotes(command, match.index) && detectedPM !== "npm") {
		blockedCommand = command;
		suggestedCommand = command.replace(/\bnpm\s+/g, `${detectedPM} `);
		return {blockedCommand, suggestedCommand, warning};
	}

	// Reset regex
	npmPattern.lastIndex = 0;

	// Check npx pattern
	match = npxPattern.exec(command);
	if (match && !isInsideQuotes(command, match.index) && detectedPM !== "npm") {
		blockedCommand = command;
		const execCommand = getExecutorCommand(detectedPM);
		suggestedCommand = command.replace(/\bnpx\s+/g, `${execCommand} `);
		return {blockedCommand, suggestedCommand, warning};
	}

	// Reset regex
	npxPattern.lastIndex = 0;

	// Check yarn pattern
	match = yarnPattern.exec(command);
	if (match && !isInsideQuotes(command, match.index) && detectedPM !== "yarn") {
		blockedCommand = command;
		suggestedCommand = command.replace(/\byarn\s+/g, `${detectedPM} `);
		return {blockedCommand, suggestedCommand, warning};
	}

	// Reset regex
	yarnPattern.lastIndex = 0;

	// Check pnpm pattern
	match = pnpmPattern.exec(command);
	if (match && !isInsideQuotes(command, match.index) && detectedPM !== "pnpm") {
		blockedCommand = command;
		suggestedCommand = command.replace(/\bpnpm\s+/g, `${detectedPM} `);
		return {blockedCommand, suggestedCommand, warning};
	}

	// Reset regex
	pnpmPattern.lastIndex = 0;

	// Check node pattern
	match = nodePattern.exec(command);
	if (match && !isInsideQuotes(command, match.index) && detectedPM === "bun") {
		blockedCommand = command;
		suggestedCommand = command.replace(/\bnode\s+/g, "bun ");
		warning =
			"Note: Node.js and Bun have different CLI flags. You may need to adjust any node-specific flags for Bun compatibility.";
		return {blockedCommand, suggestedCommand, warning};
	}

	return {blockedCommand, suggestedCommand, warning};
}

function getExecutorCommand(packageManager: string): string {
	switch (packageManager) {
		case "bun":
			return "bunx";
		case "pnpm":
			return "pnpm exec";
		case "yarn":
			return "yarn dlx";
		default:
			return "npx";
	}
}

function detectPackageManager(command: string, targetDir?: string): string {
	// If command has cd, extract the target directory
	let searchDir = process.cwd();
	if (targetDir) {
		searchDir = targetDir;
	} else if (command.includes("cd ")) {
		const cdMatch = command.match(/cd\s+([^\s&&]+)/);
		if (cdMatch) {
			searchDir = cdMatch[1];
			// Handle relative paths
			if (!isAbsolute(searchDir)) {
				searchDir = resolve(process.cwd(), searchDir);
			}
		}
	}

	// Walk up the directory tree to find lock files
	// Priority: bun.lock > bun.lockb > pnpm-lock.yaml > yarn.lock > package-lock.json
	let currentDir = searchDir;
	while (currentDir !== dirname(currentDir)) {
		if (existsSync(resolve(currentDir, "bun.lock"))) {
			return "bun";
		}
		if (existsSync(resolve(currentDir, "bun.lockb"))) {
			return "bun";
		}
		if (existsSync(resolve(currentDir, "pnpm-lock.yaml"))) {
			return "pnpm";
		}
		if (existsSync(resolve(currentDir, "yarn.lock"))) {
			return "yarn";
		}
		if (existsSync(resolve(currentDir, "package-lock.json"))) {
			return "npm";
		}
		currentDir = dirname(currentDir);
	}
	return "npm"; // default fallback
}

// Only run if executed directly
if (import.meta.main) {
	main();
}
