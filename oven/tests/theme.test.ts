import {afterEach, describe, expect, test} from "bun:test";
import {mkdtemp, rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {parseThemeArgs, type ThemeRuntime, themeLib} from "../bin/theme";

const cleanupPaths: string[] = [];
const ok = {exitCode: 0, stdout: "", stderr: ""};
const noRexApp = {...ok, stdout: '{"clients":[]}'};
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
		run: async (args) => (args[0] === "rex" ? noRexApp : ok),
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

describe("theme CLI", () => {
	test.each([
		["--family"],
		["--family", "unknown"],
		["--family", ""],
		["light", "dark"],
		["unknown"],
		["--unknown"],
	] as const)("rejects invalid arguments %j", (...allArgs) => {
		const args = allArgs.filter((arg) => typeof arg !== "function") as string[];
		expect(() => parseThemeArgs(args)).toThrow();
	});

	test("accepts family and mode in either order", () => {
		expect(parseThemeArgs(["--family", "rose-pine", "toggle"])).toEqual({
			family: "rose-pine",
			mode: "toggle",
		});
		expect(parseThemeArgs(["light", "--family", "tokyonight"])).toEqual({
			family: "tokyonight",
			mode: "light",
		});
	});

	test("help needs no assets or system commands", async () => {
		const runtime = await fixture("darwin");
		runtime.run = async () => {
			throw new Error("must not run");
		};
		expect(await themeLib(parseThemeArgs(["-h"]), runtime)).toStartWith("theme - ");
	});
});

describe("Rex theme integration", () => {
	const probe = ["rex", "--autostart=false", "client", "ls", "--json"];
	const running = {
		...ok,
		stdout: JSON.stringify({clients: [{info: {kind: "app"}, connection_state: "connected"}]}),
	};

	test.each([...variants])("imports the checked-in $family $mode Rex palette", async (variant) => {
		const runtime = await fixture();
		const calls: string[][] = [];
		let importedConfig: string | undefined;
		runtime.run = async (args) => {
			calls.push(args);
			if (args.includes("client.theme.import")) {
				importedConfig = await Bun.file(args.at(-1)!.slice("path=".length)).text();
			}
			return args[0] === "rex" && args.includes("ls") ? running : ok;
		};
		await themeLib(variant, runtime);
		expect(importedConfig).toBe(`# ${variant.rex}\n`);
		expect(calls.filter((args) => args[0] === "rex")).toEqual([
			probe,
			["rex", "--autostart=false", "do", "client.appearance.switch_mode", `mode=${variant.mode}`],
			[
				"rex",
				"--autostart=false",
				"do",
				"client.theme.import",
				`path=${join(runtime.configDir, "rex", "themes", variant.rex)}`,
			],
		]);
	});

	test.each([
		{label: "CLI missing", exitCode: 127, stdout: ""},
		{label: "server stopped", exitCode: 1, stdout: ""},
		{label: "no clients", exitCode: 0, stdout: '{"clients":[]}'},
		{
			label: "no connected app",
			exitCode: 0,
			stdout: JSON.stringify({
				clients: [
					{info: {kind: "cli"}, connection_state: "connected"},
					{connection_state: "connected"},
					{info: {kind: "app"}, connection_state: "disconnected"},
				],
			}),
		},
	])("skips Rex mutations when $label", async ({exitCode, stdout}) => {
		const runtime = await fixture();
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return args[0] === "rex" ? {exitCode, stdout, stderr: ""} : ok;
		};
		expect(await themeLib({mode: "dark"}, runtime)).toBe("Theme: tokyonight dark");
		expect(calls.filter((args) => args[0] === "rex")).toEqual([probe]);
	});

	test.each([
		"client.appearance.switch_mode",
		"client.theme.import",
	])("reports %s failures after detecting a running app", async (action) => {
		const runtime = await fixture();
		runtime.run = async (args) => {
			if (args[0] === "rex" && args.includes("ls")) return running;
			return args.includes(action) ? {...ok, exitCode: 1, stderr: "Rex update failed"} : ok;
		};
		await expect(themeLib({mode: "light"}, runtime)).rejects.toThrow("Rex update failed");
	});
});

describe("theme switching", () => {
	test.each([...variants])("writes $family $mode and reloads only after config writes", async (variant) => {
		const runtime = await fixture();
		const calls: string[][] = [];
		let configAtReload: string | undefined;
		runtime.run = async (args) => {
			calls.push(args);
			if (args[0] === "kitty") {
				configAtReload = await Bun.file(join(runtime.configDir, "kitty/themes/active.conf")).text();
			}
			return args[0] === "rex" ? noRexApp : ok;
		};
		expect(await themeLib(variant, runtime)).toBe(`Theme: ${variant.family} ${variant.mode}`);
		expect(configAtReload).toBe(`# ${variant.kitty}\n`);
		expect(await read(runtime, "color-theme")).toBe(`${variant.mode}\n`);
		expect(await read(runtime, "color-theme-family")).toBe(`${variant.family}\n`);
		expect(calls).toHaveLength(2);
		expect(calls).toContainEqual(["kitty", "@", "--to", "unix:/tmp/mykitty", "load-config"]);
	});

	test("status defaults without writes; toggle preserves saved family", async () => {
		const runtime = await fixture();
		expect(await themeLib({}, runtime)).toStartWith("Current: tokyonight dark\n");
		expect(await Bun.file(join(runtime.stateDir, "color-theme")).exists()).toBe(false);
		await Bun.write(join(runtime.stateDir, "color-theme"), " light \n");
		await Bun.write(join(runtime.stateDir, "color-theme-family"), "rose-pine\n");
		expect(await themeLib({mode: "toggle"}, runtime)).toBe("Theme: rose-pine dark");
	});

	test.each([
		{stdout: "true\n", exitCode: 0, mode: "dark"},
		{stdout: "false\n", exitCode: 0, mode: "light"},
		{stdout: "unexpected", exitCode: 0, mode: "light"},
		{stdout: "true", exitCode: 1, mode: "light"},
	])("system mode precedence: $stdout / $exitCode", async ({stdout, exitCode, mode}) => {
		const runtime = await fixture("darwin");
		await Bun.write(join(runtime.stateDir, "color-theme"), "light\n");
		runtime.run = async () => ({exitCode, stdout, stderr: ""});
		expect(await themeLib({}, runtime)).toStartWith(`Current: tokyonight ${mode}\n`);
	});

	test("invalid state uses defaults and family-only preserves current mode", async () => {
		const runtime = await fixture();
		await Bun.write(join(runtime.stateDir, "color-theme"), "invalid\n");
		await Bun.write(join(runtime.stateDir, "color-theme-family"), "invalid\n");
		expect(await themeLib({}, runtime)).toStartWith("Current: tokyonight dark\n");
		await Bun.write(join(runtime.stateDir, "color-theme"), "light\n");
		expect(await themeLib({family: "rose-pine"}, runtime)).toBe("Theme: rose-pine light");
	});

	test.each(["kitty", "wallpaper"])("missing %s fails before mutations", async (missing) => {
		const runtime = await fixture("darwin");
		if (missing === "kitty") {
			await rm(join(runtime.configDir, "kitty", "themes", "tokyonight-day.conf"));
			await Bun.write(join(runtime.backgroundsDir, "default.png"), "image");
		}
		const calls: string[][] = [];
		runtime.run = async (args) => {
			calls.push(args);
			return ok;
		};
		await expect(themeLib({mode: "light"}, runtime)).rejects.toThrow();
		expect(calls).toEqual([]);
		expect(await Bun.file(join(runtime.stateDir, "color-theme")).exists()).toBe(false);
		expect(await Bun.file(join(runtime.configDir, "kitty", "themes", "active.conf")).exists()).toBe(false);
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
			return args[0] === "rex" ? noRexApp : ok;
		};
		await themeLib({mode: "light"}, runtime);
		expect(calls).toContainEqual({
			args: ["osascript", "-", join(runtime.backgroundsDir, selected)],
			stdin: expect.stringContaining("repeat with currentDesktop in desktops"),
		});
		expect(calls).toContainEqual({
			args: [
				"osascript",
				"-e",
				'tell app "System Events" to tell appearance preferences to set dark mode to false',
			],
			stdin: undefined,
		});
		expect(calls).toHaveLength(4); // Explicit mode never queries System Events.
	});

	test("Kitty fallback is ordered and terminal reload failures are best effort", async () => {
		const runtime = await fixture();
		const kitty: string[][] = [];
		runtime.run = async (args) => {
			if (args[0] === "kitty") kitty.push(args);
			return {...ok, exitCode: 1};
		};
		expect(await themeLib({mode: "dark"}, runtime)).toBe("Theme: tokyonight dark");
		expect(kitty).toEqual([
			["kitty", "@", "--to", "unix:/tmp/mykitty", "load-config"],
			["kitty", "@", "load-config"],
		]);
	});

	test.each([
		false,
		true,
	])("all independent updates overlap and finish, including on failure=%s", async (fail) => {
		const runtime = await fixture("darwin");
		await Bun.write(join(runtime.backgroundsDir, "default.jpg"), "image");
		const gate = Promise.withResolvers<void>();
		const started = new Set<string>();
		const completed = new Set<string>();
		runtime.run = async (args) => {
			if (args[0] === "rex") return noRexApp;
			const name = args[0] === "osascript" ? args[1] : args[0];
			started.add(name);
			if (started.size === 3) gate.resolve();
			if (fail && name === "-e") return {...ok, exitCode: 1, stderr: "appearance denied"};
			await gate.promise;
			completed.add(name);
			return ok;
		};
		const switching = themeLib({mode: "light"}, runtime);
		const result = await switching.catch((error: Error) => error.message);
		expect(result).toEqual(fail ? expect.stringContaining("appearance denied") : "Theme: tokyonight light");
		expect(started.size).toBe(3);
		expect(completed.size).toBe(fail ? 2 : 3);
		expect(await read(runtime, "color-theme")).toBe("light\n");
	});
});
