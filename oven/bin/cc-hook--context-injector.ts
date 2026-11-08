#!/usr/bin/env bun
// :module: Claude Code hook that provides project context at session start

import {existsSync, readFileSync, unlinkSync, writeFileSync} from "fs";
import {join} from "path";
import {parseArgs} from "util";
import type {HookInput} from "../shared/claude-hooks";
import {report, reportError} from "../shared/report";

function showHelp() {
	console.log(`
cc-hook--context-injector - Claude Code hook that provides project context at session start

Usage: cc-hook--context-injector <command> [options]

Commands:
  session-start    Initialize session and provide README.md listing (called from SessionStart hook)
  session-end      Clean up session tracking (called from SessionEnd hook)

Options:
  --help, -h      Show this help message

This tool is designed to be called from Claude Code hooks to automatically provide
project README.md listing at session start.
`);
	process.exit(0);
}

export interface SessionState {
	sessionId: string;
	projectRoot: string;
}

export interface AgentContextOptions {
	command: "session-start" | "session-end";
	sessionId?: string;
	projectRoot?: string;
}

async function main() {
	const {positionals, values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			help: {type: "boolean", short: "h"},
		},
		allowPositionals: true,
	});

	if (values.help) {
		showHelp();
	}

	if (positionals.length === 0) {
		console.error("Error: command is required");
		showHelp();
	}

	const command = positionals[0] as "session-start" | "session-end";

	if (!["session-start", "session-end"].includes(command)) {
		console.error("Error: Invalid command. Must be session-start or session-end");
		process.exit(1);
	}

	try {
		// Read stdin data like claude-code-logger does
		const stdinData = await Bun.stdin.text();
		let hookInput: Partial<HookInput> = {};

		if (stdinData.trim()) {
			hookInput = JSON.parse(stdinData) as HookInput;
		}

		// Extract relevant data based on hook type
		const sessionId = hookInput.session_id;
		const projectRoot = hookInput.cwd;

		const result = await ccHookContextInjectorLib({
			command,
			sessionId,
			projectRoot,
		});

		// Handle special case for session-start contextOutput
		if (
			command === "session-start" &&
			result &&
			typeof result === "object" &&
			"contextOutput" in result &&
			result.contextOutput
		) {
			// Output context directly to stdout for Claude to see
			console.log(result.contextOutput);
		}

		report(result);
	} catch (err) {
		reportError(err);
		process.exit(1);
	}
}

export async function ccHookContextInjectorLib(options: AgentContextOptions): Promise<HandlerResult> {
	switch (options.command) {
		case "session-start":
			return await handleSessionStart(options);
		case "session-end":
			return await handleSessionEnd(options);
		default:
			throw new Error(`Unknown command: ${options.command}`);
	}
}

type SessionStartResult = {
	success: boolean;
	message: string;
	contextOutput?: string;
};

type SessionEndResult = {
	success: boolean;
	message: string;
};

type HandlerResult = SessionStartResult | SessionEndResult;

async function handleSessionStart(options: AgentContextOptions): Promise<SessionStartResult> {
	if (!options.sessionId) {
		throw new Error("Session ID is required for session-start");
	}

	if (!options.projectRoot) {
		throw new Error("Project root is required for session-start");
	}

	const sessionState: SessionState = {
		sessionId: options.sessionId,
		projectRoot: options.projectRoot,
	};

	const sessionFile = getSessionFilePath(options.sessionId);
	writeSessionState(sessionFile, sessionState);

	// Provide introductory context about the project documentation
	const introMessage = `<project-context>
IMPORTANT: Ensure you read related documentation when working in nested areas of the codebase`;

	// Find all README.md files in the project to list them
	const readmeFiles: string[] = [];
	function findAllReadmeFiles(dir: string) {
		const readmeGlob = new Bun.Glob("**/README.md");
		for (const file of readmeGlob.scanSync({cwd: dir, absolute: false})) {
			if (!file.includes("node_modules") && !file.includes(".git")) {
				readmeFiles.push(file);
			}
		}
	}

	try {
		findAllReadmeFiles(options.projectRoot);
	} catch (_e) {
		// Ignore errors in finding files
	}

	let contextOutput: string | undefined;
	if (readmeFiles.length > 0) {
		const sortedReadmeFiles = readmeFiles.sort();
		contextOutput = `${introMessage}
Project documentation:
${sortedReadmeFiles.map((f) => `- ${f}`).join("\n")}
</project-context>`;
	}

	return {
		success: true,
		message: `Initialized agent context session: ${options.sessionId}`,
		contextOutput,
	};
}

async function handleSessionEnd(options: AgentContextOptions): Promise<SessionEndResult> {
	if (!options.sessionId) {
		throw new Error("Session ID is required for session-end");
	}

	const sessionFile = getSessionFilePath(options.sessionId);
	if (existsSync(sessionFile)) {
		unlinkSync(sessionFile);
	}

	return {
		success: true,
		message: `Cleaned up agent context session: ${options.sessionId}`,
	};
}

function getSessionFilePath(sessionId: string): string {
	return join("/tmp", `claude-agent-context-${sessionId}.json`);
}

function _readSessionState(sessionFile: string): SessionState {
	const data = readFileSync(sessionFile, "utf8");
	return JSON.parse(data);
}

function writeSessionState(sessionFile: string, sessionState: SessionState): void {
	writeFileSync(sessionFile, JSON.stringify(sessionState, null, 2));
}

// Only run if executed directly
if (import.meta.main) {
	main();
}
