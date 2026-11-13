import {expect, test} from "bun:test";
import {mkdir, mkdtemp, rm, writeFile} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";

const root = new URL("../../", import.meta.url);
const botlake = "/opt/homebrew/opt/botlake/bin/botlake";

test("Homebrew provisions the CLIs used by the supervisor and UI", async () => {
	const config = Bun.TOML.parse(await Bun.file(new URL("mise.toml", root)).text()) as {
		bootstrap: {hooks: Record<string, string>};
		daemons: Record<string, {run: string; ready_cmd: string}>;
	};
	expect(config.bootstrap.hooks["pre-repos"]).toContain(
		"/opt/homebrew/bin/brew tap codethread/botlake https://github.com/codethread/botlake",
	);
	expect(config.bootstrap.hooks["pre-repos"]).toContain(
		"HOMEBREW_NO_INSTALL_UPGRADE=1 /opt/homebrew/bin/brew install codethread/botlake/botlake",
	);
	expect(config.daemons["botlake-supervisor"]?.run).toContain(`exec ${botlake} start`);
	expect(config.daemons["botlake-supervisor"]?.ready_cmd).toBe(`${botlake} status`);

	const ui = Bun.TOML.parse(await Bun.file(new URL(".mise/botlake-ui.toml", root)).text()) as {
		daemons: Record<string, {init: string; run: string}>;
	};
	expect(ui.daemons["botlake-ui"]?.init).toStartWith(`${botlake} lake start`);
	expect(ui.daemons["botlake-ui"]?.run).toContain('PATH="/opt/homebrew/opt/botlake/bin:');
});

async function startFixture(status: string, managedPid = "123", startExit = "0") {
	const state = await mkdtemp(join(tmpdir(), "dots-botlake-"));
	try {
		const bin = join(state, ".local/bin");
		await mkdir(bin, {recursive: true});
		const log = join(state, "commands");
		const brewBotlake = join(bin, "brew-botlake");
		const script = (await Bun.file(new URL("boot/start-botlake.sh", root)).text()).replaceAll(
			botlake,
			brewBotlake,
		);
		await writeFile(join(state, "start.sh"), script);
		await writeFile(
			brewBotlake,
			`#!/bin/bash
printf 'brew-botlake %s\\n' "$*" >> "$LOG"
if [ "$1" = status ]; then
  if [ "$STATUS" = stopped ]; then echo 'supervisor unavailable' >&2; exit 1; fi
  printf '%s\\n' "$STATUS"
fi
`,
			{mode: 0o755},
		);
		await writeFile(
			join(bin, "mise"),
			`#!/bin/bash
printf 'mise %s\\n' "$*" >> "$LOG"
if [ "$2" = status ]; then printf '{"pid":%s}\\n' "$MANAGED_PID"; fi
if [ "$2" = start ]; then exit "$START_EXIT"; fi
`,
			{mode: 0o755},
		);
		const child = Bun.spawn(["/bin/bash", join(state, "start.sh")], {
			env: {
				...process.env,
				HOME: state,
				PATH: `${bin}:/opt/homebrew/bin:/usr/bin:/bin`,
				LOG: log,
				STATUS: status,
				MANAGED_PID: managedPid,
				START_EXIT: startExit,
			},
			stdout: "pipe",
			stderr: "pipe",
		});
		const [code, stdout, stderr] = await Promise.all([
			child.exited,
			new Response(child.stdout).text(),
			new Response(child.stderr).text(),
		]);
		return {
			code,
			stdout,
			stderr,
			commands: (await Bun.file(log).text()).trim().split("\n"),
		};
	} finally {
		await rm(state, {recursive: true, force: true});
	}
}

test("startup starts a stopped managed supervisor before the checkout lake", async () => {
	const result = await startFixture("stopped");
	expect(result.code).toBe(0);
	expect(result.stderr).toContain("supervisor unavailable");
	expect(result.commands.slice(0, 2)).toEqual([
		"brew-botlake status",
		"mise daemons start botlake-supervisor",
	]);
	expect(result.commands[2]).toStartWith("brew-botlake lake start --workspace ");
});

test("startup reuses a supervisor already owned by mise", async () => {
	const result = await startFixture('{"pid":123}');
	expect(result.code).toBe(0);
	expect(result.stderr).toBe("");
	expect(result.commands.slice(0, 3)).toEqual([
		"brew-botlake status",
		"mise daemons status botlake-supervisor --json",
		"mise daemons start botlake-supervisor",
	]);
	expect(result.commands[3]).toStartWith("brew-botlake lake start --workspace ");
});

test("startup does not take over an externally owned supervisor", async () => {
	const result = await startFixture('{"pid":456}');
	expect(result.code).toBe(0);
	expect(result.stderr).toContain("running outside mise");
	expect(result.commands).toHaveLength(3);
	expect(result.commands[2]).toStartWith("brew-botlake lake start --workspace ");
});

test("failed managed startup does not attempt to start a lake", async () => {
	const result = await startFixture("stopped", "null", "17");
	expect(result.code).toBe(17);
	expect(result.commands).toEqual(["brew-botlake status", "mise daemons start botlake-supervisor"]);
});

test("malformed supervisor status fails visibly instead of taking ownership", async () => {
	const result = await startFixture("{}");
	expect(result.code).not.toBe(0);
	expect(result.commands).toEqual(["brew-botlake status"]);
});
