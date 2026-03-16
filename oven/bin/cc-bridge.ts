// :module: Unix socket bridge for executing host commands from containers

import {chmodSync, existsSync, unlinkSync, writeFileSync} from "fs";
import {resolve} from "path";
import {parseArgs} from "util";
import {report, reportError} from "../shared/report";

function showHelp() {
	console.log(`cc-bridge - Unix socket bridge for executing host commands from containers

Usage:
  cc-bridge serve --allow cmd1,cmd2 [--socket path]
  cc-bridge exec <cmd> [args...]
  cc-bridge install --commands cmd1,cmd2 [--bin-dir dir]

Subcommands:
  serve       Start host daemon listening on a Unix socket
  exec        Send a command to the daemon via the socket
  install     Create shim scripts that transparently proxy commands

Options:
  --allow      Comma-separated list of allowed commands (serve)
  --socket, -s Socket path (default: /tmp/cc-bridge.sock, or CC_BRIDGE_SOCKET env)
  --commands   Comma-separated list of commands to shim (install)
  --bin-dir    Directory for shim scripts (default: ~/.local/bin)
  --help, -h   Show this help message

Note:
  Only supports stateless, fire-and-forget commands (no stdin forwarding).
  Commands like "obsidian open file.md" work; interactive commands do not.

Examples:
  # Start daemon on host
  cc-bridge serve --allow obsidian

  # Inside container, create transparent shims
  cc-bridge install --commands obsidian

  # Test a command via the bridge
  cc-bridge exec obsidian open "my note.md"
`);
	process.exit(0);
}

export interface CommandResult {
	exitCode: number;
	stdout: string;
	stderr: string;
}

interface BridgeRequest {
	cmd: string;
	args: string[];
}

const DEFAULT_SOCKET = "/tmp/cc-bridge.sock";

function getSocketPath(override?: string): string {
	return override || process.env.CC_BRIDGE_SOCKET || DEFAULT_SOCKET;
}

async function main() {
	const args = Bun.argv.slice(2);

	if (args.length === 0 || args[0] === "-h" || args[0] === "--help") {
		showHelp();
	}

	const subcommand = args[0];
	const rest = args.slice(1);

	try {
		switch (subcommand) {
			case "serve":
				await handleServe(rest);
				break;
			case "exec":
				await handleExec(rest);
				break;
			case "install":
				handleInstall(rest);
				break;
			default:
				console.error(`Unknown subcommand: ${subcommand}`);
				process.exit(1);
		}
	} catch (err) {
		reportError(err);
		process.exit(1);
	}
}

async function handleServe(args: string[]) {
	const {values} = parseArgs({
		args,
		options: {
			allow: {type: "string"},
			socket: {type: "string", short: "s"},
		},
		strict: false,
	});

	if (!values.allow || typeof values.allow !== "string") {
		console.error("Error: --allow is required");
		process.exit(1);
	}

	const allowList = values.allow.split(",").map((s: string) => s.trim());
	const socketPath = getSocketPath(typeof values.socket === "string" ? values.socket : undefined);
	await ccBridgeServe(allowList, socketPath);
}

async function handleExec(args: string[]) {
	// Support --socket/-s before the command name
	let socketOverride: string | undefined;
	let cmdArgs = args;

	if (args[0] === "--socket" || args[0] === "-s") {
		socketOverride = args[1];
		cmdArgs = args.slice(2);
	}

	if (cmdArgs.length === 0) {
		console.error("Error: no command specified");
		process.exit(1);
	}

	const cmd = cmdArgs[0];
	const commandArgs = cmdArgs.slice(1);
	const socketPath = getSocketPath(socketOverride);
	await ccBridgeExec(cmd, commandArgs, socketPath);
}

function handleInstall(args: string[]) {
	const {values} = parseArgs({
		args,
		options: {
			commands: {type: "string"},
			"bin-dir": {type: "string"},
		},
		strict: false,
	});

	if (!values.commands || typeof values.commands !== "string") {
		console.error("Error: --commands is required");
		process.exit(1);
	}

	const commands = values.commands.split(",").map((s: string) => s.trim());
	const home = process.env.HOME || "/home/user";
	const binDir = typeof values["bin-dir"] === "string" ? values["bin-dir"] : `${home}/.local/bin`;
	ccBridgeInstall(commands, binDir);
}

// --- Exported lib functions ---

export async function ccBridgeServe(allowList: string[], socketPath: string): Promise<void> {
	if (existsSync(socketPath)) {
		unlinkSync(socketPath);
	}

	const buffers = new Map<object, string>();

	const server = Bun.listen({
		unix: socketPath,
		socket: {
			open(socket) {
				buffers.set(socket, "");
			},
			data(socket, data) {
				const buf = (buffers.get(socket) || "") + data.toString();
				const newlineIdx = buf.indexOf("\n");
				if (newlineIdx === -1) {
					buffers.set(socket, buf);
					return;
				}

				const line = buf.slice(0, newlineIdx);
				processRequest(line, allowList).then((result) => {
					socket.write(`${JSON.stringify(result)}\n`);
					socket.end();
				});
			},
			close(socket) {
				buffers.delete(socket);
			},
			error(_socket, error) {
				console.error("Socket error:", error);
			},
		},
	});

	const cleanup = () => {
		server.stop();
		if (existsSync(socketPath)) {
			unlinkSync(socketPath);
		}
		process.exit(0);
	};

	process.on("SIGINT", cleanup);
	process.on("SIGTERM", cleanup);

	report(`cc-bridge listening on ${socketPath}\nAllowed commands: ${allowList.join(", ")}`);

	// Keep process alive
	await new Promise(() => {});
}

async function processRequest(line: string, allowList: string[]): Promise<CommandResult> {
	try {
		const req = JSON.parse(line) as BridgeRequest;
		return await executeCommand(req.cmd, req.args, allowList);
	} catch (err) {
		return {exitCode: 1, stdout: "", stderr: `Invalid request: ${err}`};
	}
}

async function executeCommand(cmd: string, args: string[], allowList: string[]): Promise<CommandResult> {
	if (!allowList.includes(cmd)) {
		return {exitCode: 1, stdout: "", stderr: `Command not allowed: ${cmd}. Allowed: ${allowList.join(", ")}`};
	}

	const proc = Bun.spawn([cmd, ...args], {
		stdout: "pipe",
		stderr: "pipe",
	});

	const [stdout, stderr] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
	]);
	const exitCode = await proc.exited;

	return {exitCode, stdout, stderr};
}

export async function ccBridgeExec(cmd: string, args: string[], socketPath: string): Promise<never> {
	const request = `${JSON.stringify({cmd, args} satisfies BridgeRequest)}\n`;

	let responseData = "";

	const result = await new Promise<CommandResult>((resolve, reject) => {
		Bun.connect({
			unix: socketPath,
			socket: {
				open(socket) {
					socket.write(request);
				},
				data(_socket, data) {
					responseData += data.toString();
				},
				close() {
					try {
						resolve(JSON.parse(responseData.trim()));
					} catch {
						reject(new Error(`Invalid response from bridge: ${responseData}`));
					}
				},
				error(_socket, error) {
					reject(error);
				},
			},
		}).catch((err) => {
			if (
				(err as NodeJS.ErrnoException).code === "ENOENT" ||
				(err as NodeJS.ErrnoException).code === "ECONNREFUSED"
			) {
				reject(new Error(`cc-bridge daemon not running (socket not found at ${socketPath})`));
			} else {
				reject(err);
			}
		});
	});

	if (result.stdout) process.stdout.write(result.stdout);
	if (result.stderr) process.stderr.write(result.stderr);
	process.exit(result.exitCode);
}

export function ccBridgeInstall(commands: string[], binDir: string): void {
	for (const cmd of commands) {
		const shimPath = resolve(binDir, cmd);
		const script = `#!/usr/bin/env bash\nexec cc-bridge exec ${cmd} "$@"\n`;
		writeFileSync(shimPath, script);
		chmodSync(shimPath, 0o755);
	}
	report(`Installed shims in ${binDir}: ${commands.join(", ")}`);
}

if (import.meta.main) {
	main();
}
