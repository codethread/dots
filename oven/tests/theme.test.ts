import {afterEach, describe, expect, test} from "bun:test";
import {mkdtemp, rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {parseThemeArgs, type ThemeRuntime, themeHostLib, themeLib, themeLocalLib} from "../bin/theme";

const cleanupPaths: string[] = [];
const ok = {exitCode: 0, stdout: "", stderr: ""};
const variants = [
	{family: "tokyonight", mode: "light", kitty: "tokyonight-day", rex: "TokyoNight Day"},
	{family: "tokyonight", mode: "dark", kitty: "tokyonight-moon", rex: "TokyoNight Moon"},
	{family: "rose-pine", mode: "light", kitty: "rose-pine-dawn", rex: "Rose Pine Dawn"},
	{family: "rose-pine", mode: "dark", kitty: "rose-pine", rex: "Rose Pine Moon"},
] as const;

afterEach(async () => {
	await Promise.all(cleanupPaths.splice(0).map((path) => rm(path, {recursive: true, force: true})));
});

async function fixture(platform = "linux"): Promise<ThemeRuntime> {
	const dir = await mkdtemp(join(tmpdir(), "theme-test-"));
	cleanupPaths.push(dir);
	const runtime: ThemeRuntime = {
		platform,
		stateDir: join(dir, "state"),
		configDir: join(dir, "config"),
		backgroundsDir: join(dir, "backgrounds with spaces"),
		run: async () => ok,
	};
	await Promise.all(
		variants.flatMap(({kitty, rex}) => [
			Bun.write(join(runtime.configDir, "kitty", "themes", `${kitty}.conf`), `# ${kitty}\n`),
			Bun.write(join(runtime.configDir, "rex", "themes", rex), `# ${rex}\n`),
		]),
	);
	return runtime;
}

function read(runtime: ThemeRuntime, path: string) {
	return Bun.file(join(runtime.stateDir, path)).text();
}

const localIdentity = {host_id: "caller", account: "ct", endpoint: "unix:///caller/rex.sock"};
const remoteIdentity = {host_id: "host", account: "ct", endpoint: "https://host"};
const localApp = {
	client_id: "local",
	info: {kind: "app"},
	principal: {transport: "unix"},
	connection_state: "connected",
};
const remoteApp = {...localApp, client_id: "remote", principal: {transport: "tailscale"}};
const clients = [remoteApp, localApp, {client_id: "cli", info: {kind: "cli"}, connection_state: "connected"}];

function rexReply(args: string[], selected = remoteIdentity) {
	if (args.includes("whoami"))
		return {...ok, stdout: JSON.stringify(args.includes("selected") ? selected : localIdentity)};
	if (args.includes("ls")) return {...ok, stdout: JSON.stringify({clients})};
	return ok;
}

function rpcCalls(calls: string[][]) {
	return calls.filter((args) => args.includes("client.action"));
}

function guiCalls(calls: string[][]) {
	return calls.filter((args) => args.includes("do"));
}

describe("theme CLI", () => {
	test.each([
		["--family"],
		["--family", "unknown"],
		["--family", ""],
		["light", "dark"],
		["unknown"],
		["--unknown"],
	] as const)("rejects invalid arguments %j", (...allArgs) => {
		expect(() => parseThemeArgs(allArgs.filter((arg) => typeof arg !== "function") as string[])).toThrow();
	});
	test("accepts family/mode order and the host-only flag", () => {
		expect(parseThemeArgs(["--family", "rose-pine", "toggle"])).toEqual({
			family: "rose-pine",
			mode: "toggle",
		});
		expect(parseThemeArgs(["light", "--host", "--family", "tokyonight"])).toEqual({
			family: "tokyonight",
			mode: "light",
			host: true,
		});
	});
	test("help needs no assets or commands", async () => {
		const runtime = await fixture();
		runtime.run = async () => {
			throw new Error("must not run");
		};
		expect(await themeLib({help: true}, runtime)).toStartWith("theme - ");
	});
});

describe("caller-first Rex theming", () => {
	test("applies caller state and its Rex app before forwarding explicit state", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		await Bun.write(join(runtime.stateDir, "color-theme"), "dark\n");
		await Bun.write(join(runtime.stateDir, "color-theme-family"), "rose-pine\n");
		const calls: string[][] = [];
		let stateAtForward: string | undefined;
		runtime.run = async (args) => {
			calls.push(args);
			if (args.includes("client.action")) stateAtForward = await read(runtime, "color-theme");
			return rexReply(args);
		};
		expect(await themeLib({mode: "toggle"}, runtime)).toBe("Theme: rose-pine light");
		expect(stateAtForward).toBe("light\n");
		const gui = guiCalls(calls);
		expect(gui).toHaveLength(2);
		expect(gui.map((args) => args.slice(args.indexOf("--server")))).toEqual([
			[
				"--server",
				localIdentity.endpoint,
				"-C",
				"local",
				"do",
				"client.appearance.switch_mode",
				"mode=light",
			],
			[
				"--server",
				localIdentity.endpoint,
				"-C",
				"local",
				"do",
				"client.theme.import",
				`path=${join(runtime.configDir, "rex/themes/Rose Pine Dawn")}`,
			],
		]);
		const rpc = rpcCalls(calls);
		expect(rpc).toHaveLength(1);
		expect(JSON.parse(rpc[0].at(-1)!)).toEqual({
			action: "dots_theme",
			args: {mode: "light", family: "rose-pine"},
		});
		expect(calls.indexOf(gui[1])).toBeLessThan(calls.indexOf(rpc[0]));
		expect(calls.filter((args) => args[0] === "kitty")).toHaveLength(1);
		const discovery = calls.find((args) => args.includes("whoami") && !args.includes("--server"))!;
		expect(discovery.slice(0, -2)).toEqual([
			"env",
			"-u",
			"REX_SERVER",
			"-u",
			"REX_CLIENT",
			"-u",
			"REX_SESSION",
			"-u",
			"REX_BLOCK",
			"rex",
			"--autostart=false",
		]);
	});

	test("same host/account applies once even through a different endpoint", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return rexReply(args, {...localIdentity, endpoint: "https://same-host"});
		};
		await themeLib({mode: "toggle"}, runtime);
		expect(rpcCalls(calls)).toEqual([]);
		expect(guiCalls(calls)).toHaveLength(2);
		expect(calls.filter((args) => args[0] === "kitty")).toHaveLength(1);
		expect(await read(runtime, "color-theme")).toBe("light\n");
	});

	test("a different account on the same host still receives explicit state", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return rexReply(args, {...localIdentity, account: "work"});
		};
		await themeLib({mode: "dark"}, runtime);
		expect(rpcCalls(calls)).toHaveLength(1);
	});

	test("without a selected remote server, only applies locally", async () => {
		const runtime = await fixture();
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return rexReply(args);
		};
		await themeLib({mode: "light"}, runtime);
		expect(rpcCalls(calls)).toEqual([]);
		expect(calls.filter((args) => args.includes("selected"))).toEqual([]);
		expect(guiCalls(calls)).toHaveLength(2);
	});

	test("the receiving host applies its own app and never forwards", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return rexReply(args);
		};
		expect((await themeLocalLib({mode: "light", family: "rose-pine"}, runtime)).state).toMatchObject({
			mode: "light",
			family: "rose-pine",
		});
		expect(rpcCalls(calls)).toEqual([]);
		expect(calls.filter((args) => args.includes("selected"))).toEqual([]);
		expect(guiCalls(calls)).toHaveLength(2);
	});

	test("--host through the library also prevents forwarding", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return rexReply(args);
		};
		await themeLib({host: true, mode: "light"}, runtime);
		expect(rpcCalls(calls)).toEqual([]);
	});

	test("status reads caller state without contacting Rex or changing apps", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		runtime.run = async () => {
			throw new Error("must not run");
		};
		expect(await themeLib({}, runtime)).toStartWith("Current: tokyonight dark\n");
	});

	test.each([127, 1])("local Rex unavailable (exit %s) does not prevent a local theme", async (exitCode) => {
		const runtime = await fixture();
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return args.includes("rex") ? {...ok, exitCode} : ok;
		};
		expect(await themeLib({mode: "light"}, runtime)).toBe("Theme: tokyonight light");
		expect(await read(runtime, "color-theme")).toBe("light\n");
		expect(calls.filter((args) => args.includes("rex"))).toHaveLength(1);
	});

	test("without a local Rex server, still forwards to a selected remote", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return args.includes("whoami") && !args.includes("--server") ? {...ok, exitCode: 1} : rexReply(args);
		};
		await themeLib({mode: "light"}, runtime);
		expect(guiCalls(calls)).toEqual([]);
		expect(rpcCalls(calls)).toHaveLength(1);
	});

	test.each([
		"unreachable",
		"action failure",
	])("remote %s leaves caller state applied and reports explicit retry", async (failure) => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			const fail =
				failure === "unreachable"
					? args.includes("selected") && args.includes("whoami")
					: args.includes("client.action");
			return fail ? {...ok, exitCode: 1, stderr: "host unavailable"} : rexReply(args);
		};
		await expect(themeLib({mode: "light"}, runtime)).rejects.toThrow("Retry with 'theme light', not toggle");
		expect(await read(runtime, "color-theme")).toBe("light\n");
		expect(guiCalls(calls)).toHaveLength(2);
	});

	test("local app failure stops forwarding after caller state is saved", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return args.includes("do") ? {...ok, exitCode: 1, stderr: "refused"} : rexReply(args);
		};
		await expect(themeLib({mode: "light"}, runtime)).rejects.toThrow("local Rex update failed");
		expect(rpcCalls(calls)).toEqual([]);
		expect(await read(runtime, "color-theme")).toBe("light\n");
	});

	test("a remote viewer is never substituted for an absent local app", async () => {
		const runtime = await fixture();
		runtime.rexServer = "selected";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return args.includes("ls") ? {...ok, stdout: JSON.stringify({clients: [remoteApp]})} : rexReply(args);
		};
		await themeLib({mode: "light"}, runtime);
		expect(guiCalls(calls)).toEqual([]);
		expect(rpcCalls(calls)).toHaveLength(1);
	});

	test("multiple local apps require an explicit choice", async () => {
		const runtime = await fixture();
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return args.includes("ls")
				? {...ok, stdout: JSON.stringify({clients: [localApp, {...localApp, client_id: "second"}]})}
				: rexReply(args);
		};
		await expect(themeLib({mode: "light"}, runtime)).rejects.toThrow("Multiple local Rex apps");
		expect(guiCalls(calls)).toEqual([]);
	});

	test.each([true, false])("REX_CLIENT must resolve to a local app: valid=%s", async (valid) => {
		const runtime = await fixture();
		runtime.rexClient = "chosen label";
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return args.includes("inspect")
				? {...ok, stdout: JSON.stringify({client: valid ? localApp : remoteApp})}
				: rexReply(args);
		};
		const result = await themeLib({mode: "light"}, runtime).catch((error: Error) => error.message);
		expect(result).toEqual(
			valid ? "Theme: tokyonight light" : expect.stringContaining("must identify a connected app local"),
		);
		expect(guiCalls(calls)).toHaveLength(valid ? 2 : 0);
	});
});

describe("host engine", () => {
	test.each([...variants])("writes $family $mode before Kitty reload", async (variant) => {
		const runtime = await fixture();
		let reloadedConfig: string | undefined;
		runtime.run = async () => {
			reloadedConfig = await Bun.file(join(runtime.configDir, "kitty/themes/active.conf")).text();
			return ok;
		};
		expect(await themeHostLib(variant, runtime)).toEqual({
			family: variant.family,
			mode: variant.mode,
			palette: variant.rex,
			palettePath: join(runtime.configDir, "rex/themes", variant.rex),
		});
		expect(reloadedConfig).toBe(`# ${variant.kitty}\n`);
		expect(await read(runtime, "color-theme")).toBe(`${variant.mode}\n`);
		expect(await read(runtime, "color-theme-family")).toBe(`${variant.family}\n`);
	});

	test("status defaults without writes; toggle uses saved host mode, not macOS appearance", async () => {
		const runtime = await fixture("darwin");
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return {...ok, stdout: "false\n"};
		};
		expect(await themeHostLib({}, runtime)).toMatchObject({family: "tokyonight", mode: "dark"});
		expect(calls).toEqual([]);
		expect(await Bun.file(join(runtime.stateDir, "color-theme")).exists()).toBe(false);
		await Bun.write(join(runtime.stateDir, "color-theme"), " light \n");
		await Bun.write(join(runtime.stateDir, "color-theme-family"), "rose-pine\n");
		await Bun.write(join(runtime.backgroundsDir, "default.jpg"), "image");
		expect(await themeHostLib({mode: "toggle"}, runtime)).toMatchObject({family: "rose-pine", mode: "dark"});
		expect(calls).toContainEqual([
			"osascript",
			"-e",
			'tell app "System Events" to tell appearance preferences to set dark mode to true',
		]);
		expect(calls).toHaveLength(3);
	});

	test("family-only changes preserve saved mode; invalid state uses defaults", async () => {
		const runtime = await fixture();
		await Bun.write(join(runtime.stateDir, "color-theme"), "invalid\n");
		await Bun.write(join(runtime.stateDir, "color-theme-family"), "invalid\n");
		expect(await themeHostLib({}, runtime)).toMatchObject({family: "tokyonight", mode: "dark"});
		await Bun.write(join(runtime.stateDir, "color-theme"), "light\n");
		expect(await themeHostLib({family: "rose-pine"}, runtime)).toMatchObject({
			family: "rose-pine",
			mode: "light",
		});
	});

	test.each(["kitty", "palette", "wallpaper"])("missing %s fails before host mutations", async (missing) => {
		const runtime = await fixture("darwin");
		await Bun.write(join(runtime.backgroundsDir, "default.png"), "image");
		const paths = {
			kitty: join(runtime.configDir, "kitty/themes/tokyonight-day.conf"),
			palette: join(runtime.configDir, "rex/themes/TokyoNight Day"),
			wallpaper: join(runtime.backgroundsDir, "default.png"),
		};
		await rm(paths[missing as keyof typeof paths]);
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return ok;
		};
		await expect(themeHostLib({mode: "light"}, runtime)).rejects.toThrow();
		expect(calls).toEqual([]);
		expect(await Bun.file(join(runtime.stateDir, "color-theme")).exists()).toBe(false);
	});

	test.each([
		{files: ["default.jpg", "default.png"], selected: "default.jpg"},
		{files: ["default.png"], selected: "default.png"},
		{files: ["default.jpg", "tokyonight-day.png"], selected: "tokyonight-day.png"},
		{files: ["tokyonight-day.png", "tokyonight-day.jpg"], selected: "tokyonight-day.jpg"},
	])("wallpaper priority selects $selected", async ({files, selected}) => {
		const runtime = await fixture("darwin");
		await Promise.all(files.map((file) => Bun.write(join(runtime.backgroundsDir, file), "image")));
		const calls: {args: string[]; stdin?: string}[] = [];
		runtime.run = async (args, stdin) => {
			calls.push({args, stdin});
			return ok;
		};
		await themeHostLib({mode: "light"}, runtime);
		expect(calls).toContainEqual({
			args: ["osascript", "-", join(runtime.backgroundsDir, selected)],
			stdin: expect.stringContaining("repeat with currentDesktop in desktops"),
		});
	});

	test("Kitty fallback is ordered and absent-terminal reloads remain best effort", async () => {
		const runtime = await fixture();
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return {...ok, exitCode: 1};
		};
		await themeHostLib({mode: "dark"}, runtime);
		expect(calls).toEqual([
			["kitty", "@", "--to", "unix:/tmp/mykitty", "load-config"],
			["kitty", "@", "load-config"],
		]);
	});

	test.each([
		false,
		true,
	])("independent host updates overlap and drain, including failure=%s", async (fail) => {
		const runtime = await fixture("darwin");
		await Bun.write(join(runtime.backgroundsDir, "default.jpg"), "image");
		const gate = Promise.withResolvers<void>();
		const started = new Set<string>();
		const completed = new Set<string>();
		runtime.run = async (args) => {
			const name = args[0] === "osascript" ? args[1] : args[0];
			started.add(name);
			if (started.size === 3) gate.resolve();
			if (fail && name === "-e") return {...ok, exitCode: 1, stderr: "appearance denied"};
			await gate.promise;
			completed.add(name);
			return ok;
		};
		const result = await themeHostLib({mode: "light"}, runtime).then(
			() => "success",
			(error: Error) => error.message,
		);
		expect(result).toEqual(fail ? expect.stringContaining("appearance denied") : "success");
		expect(completed.size).toBe(fail ? 2 : 3);
	});
});
