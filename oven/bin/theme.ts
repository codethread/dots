// :module: Apply a local theme and forward explicit state to a Rex host

import {mkdir} from "node:fs/promises";
import {homedir} from "node:os";
import {dirname, join} from "node:path";
import {parseArgs} from "node:util";
import {report, reportError} from "../shared/report";

const HELP = `theme - Apply a local theme and forward explicit state to a Rex host

Usage: theme [--family tokyonight|rose-pine] [light|dark|toggle]
       theme                         # show this machine's theme
       theme --family rose-pine      # switch family, keep current mode

Options:
  --family <family>  Select tokyonight or rose-pine
  --host            Apply locally only; never forward (JSON result)
  --help, -h        Show this help

Toggle resolves once on the machine executing this command. Apply locally,
then send explicit mode/family to a separate REX_SERVER. The same host/account
is applied once. Other viewers are unchanged. No applications are refreshed.`;

type Mode = "light" | "dark";
type Family = "tokyonight" | "rose-pine";
interface ThemeOptions {
	mode?: Mode | "toggle";
	family?: Family;
	host?: boolean;
	help?: boolean;
}

interface CommandResult {
	exitCode: number;
	stdout: string;
	stderr: string;
}

export interface ThemeState {
	family: Family;
	mode: Mode;
	palette: string;
	palettePath: string;
}

type RunCommand = (args: string[], stdin?: string) => Promise<CommandResult>;

interface RexIdentity {
	host_id: string;
	account: string;
	endpoint: string;
}

export interface ThemeRuntime {
	platform: string;
	stateDir: string;
	configDir: string;
	backgroundsDir: string;
	rexServer?: string;
	rexClient?: string;
	run: RunCommand;
}

// Clear inherited terminal routing; selected hosts are always explicit arguments.
const REX = [
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
];

const THEMES = {
	tokyonight: {
		light: {kitty: "tokyonight-day", rex: "TokyoNight Day"},
		dark: {kitty: "tokyonight-moon", rex: "TokyoNight Moon"},
	},
	"rose-pine": {
		light: {kitty: "rose-pine-dawn", rex: "Rose Pine Dawn"},
		dark: {kitty: "rose-pine", rex: "Rose Pine Moon"},
	},
};

const WALLPAPER_SCRIPT = `on run argv
  set wallpaperPath to item 1 of argv
  tell application "System Events"
    repeat with currentDesktop in desktops
      set picture of currentDesktop to wallpaperPath
    end repeat
  end tell
end run`;

async function main() {
	try {
		const options = parseThemeArgs(Bun.argv.slice(2));
		if (options.host && !options.help) {
			report((await themeLocalLib(options)).state, {format: "json"});
		} else {
			report(await themeLib(options));
		}
	} catch (error) {
		reportError(error);
		process.exitCode = 1;
	}
}

export function parseThemeArgs(args: string[]): ThemeOptions {
	const {values, positionals} = parseArgs({
		args,
		options: {
			family: {type: "string"},
			host: {type: "boolean"},
			help: {type: "boolean", short: "h"},
		},
		allowPositionals: true,
	});
	if (values.help) return {help: true};
	if (positionals.length > 1) throw new Error("Only one mode may be provided");
	const mode = positionals[0];
	if (mode !== undefined && mode !== "light" && mode !== "dark" && mode !== "toggle") {
		throw new Error(`Unsupported theme mode: ${mode}`);
	}
	const family = values.family;
	if (family !== undefined && family !== "tokyonight" && family !== "rose-pine") {
		throw new Error(`Unsupported theme family: ${family}`);
	}
	return {mode, family, ...(values.host ? {host: true} : {})};
}

export async function themeLib(options: ThemeOptions, runtime = defaultRuntime()): Promise<string> {
	if (options.help) return HELP;
	const {state, rex} = await themeLocalLib(options, runtime);
	if ((options.mode || options.family) && !options.host && runtime.rexServer) {
		try {
			const command = [...REX, "--server", runtime.rexServer];
			const reply = await runRequired(runtime, [...command, "whoami", "--json"]);
			const selected = parseRexIdentity(reply.stdout);
			if (!rex || rex.host_id !== selected.host_id || rex.account !== selected.account) {
				await runRequired(runtime, [
					...command,
					"api",
					"call",
					"client.action",
					JSON.stringify({action: "dots_theme", args: {mode: state.mode, family: state.family}}),
				]);
			}
		} catch (error) {
			throw new Error(
				`Local theme is now ${state.family} ${state.mode}; Rex host update failed: ${error}. Retry with 'theme ${state.mode}', not toggle.`,
			);
		}
	}
	return options.mode || options.family
		? `Theme: ${state.family} ${state.mode}`
		: `Current: ${state.family} ${state.mode}\n${HELP}`;
}

// Used both by the caller and by the receiving server's --host command.
// --host is deliberately terminal: it cannot forward or loop back to the caller.
export async function themeLocalLib(
	options: ThemeOptions,
	runtime = defaultRuntime(),
): Promise<{state: ThemeState; rex: RexIdentity | null}> {
	const state = await themeHostLib(options, runtime);
	if (!options.mode && !options.family) return {state, rex: null};
	try {
		return {state, rex: await updateLocalRex(runtime, state)};
	} catch (error) {
		throw new Error(
			`Local state is now ${state.family} ${state.mode}; local Rex update failed: ${error}. Retry with 'theme ${state.mode}', not toggle.`,
		);
	}
}

// Pure host-side workflow: state, assets, Kitty, and desktop updates.
export async function themeHostLib(options: ThemeOptions, runtime = defaultRuntime()): Promise<ThemeState> {
	const [family, current] = await Promise.all([
		options.family ?? currentFamily(runtime),
		options.mode === "light" || options.mode === "dark" ? options.mode : currentMode(runtime),
	]);
	const mode = options.mode === "toggle" ? (current === "dark" ? "light" : "dark") : current;
	const theme = THEMES[family][mode];
	const state = {
		family,
		mode,
		palette: theme.rex,
		palettePath: join(runtime.configDir, "rex", "themes", theme.rex),
	};
	if (!options.mode && !options.family) return state;
	const kittySource = join(runtime.configDir, "kitty", "themes", `${theme.kitty}.conf`);
	const [kittyConfig, wallpaper] = await Promise.all([
		Bun.file(kittySource).text(),
		runtime.platform === "darwin" ? findWallpaper(runtime.backgroundsDir, theme.kitty) : undefined,
	]);
	if (!(await Bun.file(state.palettePath).exists())) {
		throw new Error(`Missing Rex palette: ${state.palettePath}`);
	}

	const jobs: Promise<unknown>[] = [
		writeConfig(join(runtime.stateDir, "color-theme"), `${mode}\n`),
		writeConfig(join(runtime.stateDir, "color-theme-family"), `${family}\n`),
		updateKitty(runtime, kittyConfig),
	];
	if (wallpaper !== undefined) {
		jobs.push(
			runRequired(runtime, [
				"osascript",
				"-e",
				`tell app "System Events" to tell appearance preferences to set dark mode to ${mode === "dark"}`,
			]),
			runRequired(runtime, ["osascript", "-", wallpaper], WALLPAPER_SCRIPT),
		);
	}
	await finishUpdates(jobs);
	return state;
}

function parseRexIdentity(text: string): RexIdentity {
	const identity = JSON.parse(text) as RexIdentity;
	if (
		!identity ||
		typeof identity.host_id !== "string" ||
		typeof identity.account !== "string" ||
		typeof identity.endpoint !== "string"
	) {
		throw new Error("Rex did not report a valid host/account identity");
	}
	return identity;
}

async function updateLocalRex(runtime: ThemeRuntime, state: ThemeState): Promise<RexIdentity | null> {
	// Rex's default server is local. Strip terminal/remote routing without changing
	// the parent environment; never hardcode a socket or start a missing server.
	const probe = await runtime.run([...REX, "whoami", "--json"]);
	if (probe.exitCode !== 0) return null;
	const local = parseRexIdentity(probe.stdout);
	const command = [...REX, "--server", local.endpoint];
	const reply = await runRequired(runtime, [...command, "client", "ls", "--json"]);
	const {clients} = JSON.parse(reply.stdout) as {
		clients: {
			client_id: string;
			info?: {kind?: string};
			principal?: {transport?: string};
			connection_state: string;
		}[];
	};
	const apps = clients.filter(
		(client) =>
			client.info?.kind === "app" &&
			client.connection_state === "connected" &&
			client.principal?.transport === "unix",
	);
	let client: string;
	if (runtime.rexClient) {
		const inspected = await runRequired(runtime, [
			...command,
			"client",
			"inspect",
			runtime.rexClient,
			"--json",
		]);
		client = JSON.parse(inspected.stdout).client.client_id;
		if (!apps.some((app) => app.client_id === client)) {
			throw new Error("REX_CLIENT must identify a connected app local to this machine");
		}
	} else {
		if (apps.length === 0) return local;
		if (apps.length > 1)
			throw new Error("Multiple local Rex apps are connected; set REX_CLIENT to a local app ID or label");
		client = apps[0].client_id;
	}
	await runRequired(runtime, [
		...command,
		"-C",
		client,
		"do",
		"client.appearance.switch_mode",
		`mode=${state.mode}`,
	]);
	await runRequired(runtime, [
		...command,
		"-C",
		client,
		"do",
		"client.theme.import",
		`path=${state.palettePath}`,
	]);
	return local;
}

async function finishUpdates(jobs: Promise<unknown>[]): Promise<void> {
	const results = await Promise.allSettled(jobs);
	const errors = results.flatMap((result) => (result.status === "rejected" ? [result.reason] : []));
	if (errors.length) {
		throw new AggregateError(errors, `Theme switch failed: ${errors.map(String).join("; ")}`);
	}
}

function defaultRuntime(): ThemeRuntime {
	const home = homedir();
	return {
		platform: process.platform,
		stateDir: process.env.XDG_STATE_HOME || join(home, ".local", "state"),
		configDir: process.env.XDG_CONFIG_HOME || join(home, ".config"),
		backgroundsDir: process.env.CT_BACKGROUNDS_DIR || join(home, "sync", "images", "backgrounds"),
		rexServer: process.env.REX_SERVER || undefined,
		rexClient: process.env.REX_CLIENT || undefined,
		run: runCommand,
	};
}

async function currentFamily(runtime: ThemeRuntime): Promise<Family> {
	const family = await readState(join(runtime.stateDir, "color-theme-family"));
	return family === "rose-pine" ? family : "tokyonight";
}

async function currentMode(runtime: ThemeRuntime): Promise<Mode> {
	return (await readState(join(runtime.stateDir, "color-theme"))) === "light" ? "light" : "dark";
}

async function readState(path: string): Promise<string> {
	// Missing, unreadable or invalid state uses the documented host defaults.
	return Bun.file(path)
		.text()
		.then((text) => text.replace(/\s/g, ""))
		.catch(() => "");
}

async function findWallpaper(directory: string, name: string): Promise<string> {
	const candidates = [`${name}.jpg`, `${name}.png`, "default.jpg", "default.png"].map((file) =>
		join(directory, file),
	);
	const exists = await Promise.all(candidates.map((file) => Bun.file(file).exists()));
	const wallpaper = candidates.find((_, index) => exists[index]);
	if (!wallpaper) throw new Error(`Missing wallpaper for: ${name} in ${directory}`);
	return wallpaper;
}

async function writeConfig(path: string, content: string): Promise<void> {
	await mkdir(dirname(path), {recursive: true});
	await Bun.write(path, content);
}

async function updateKitty(runtime: ThemeRuntime, config: string): Promise<void> {
	await writeConfig(join(runtime.configDir, "kitty", "themes", "active.conf"), config);
	const result = await runtime.run(["kitty", "@", "--to", "unix:/tmp/mykitty", "load-config"]);
	if (result.exitCode !== 0 && result.exitCode !== 127) await runtime.run(["kitty", "@", "load-config"]);
}

async function runRequired(runtime: ThemeRuntime, args: string[], stdin?: string): Promise<CommandResult> {
	const result = await runtime.run(args, stdin);
	if (result.exitCode !== 0)
		throw new Error(`${args.join(" ")} exited ${result.exitCode}: ${result.stderr.trim()}`);
	return result;
}

async function runCommand(args: string[], stdin?: string): Promise<CommandResult> {
	const executable = Bun.which(args[0]);
	if (!executable) return {exitCode: 127, stdout: "", stderr: `${args[0]} not found`};
	const child = Bun.spawn([executable, ...args.slice(1)], {
		stdin: stdin === undefined ? "ignore" : new Blob([stdin]),
		stdout: "pipe",
		stderr: "pipe",
	});
	const [exitCode, stdout, stderr] = await Promise.all([
		child.exited,
		new Response(child.stdout).text(),
		new Response(child.stderr).text(),
	]);
	return {exitCode, stdout, stderr};
}

if (import.meta.main) void main();
